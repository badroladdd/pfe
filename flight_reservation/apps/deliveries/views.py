from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone
from django.core.mail import send_mail
from django.conf import settings
import logging

from apps.deliveries.models import Sector, Livreur, Colis, EmailVerificationToken
from apps.deliveries.serializers import (
    SectorSerializer, LivreurSerializer, ColisSerializer,
    LivreurCreateSerializer, ColisAssignSerializer,
)
from apps.deliveries.permissions import IsAdmin, IsLivreur, IsAdminOrReadOnly
from apps.users.models import User
from apps.users.serializers import UserSerializer, RegisterSerializer

logger = logging.getLogger(__name__)


# ─── Email Verification Views ─────────────────────────────────────────────────

class RegisterWithEmailVerificationView(APIView):
    """Register a new user and send email verification."""
    permission_classes = [AllowAny]

    def post(self, request):
        # If a previous registration with this email was never verified, remove it
        # so the user can re-register freely.
        email = request.data.get("email", "").strip().lower()
        User.objects.filter(email__iexact=email, is_active=False).delete()

        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        # Account stays inactive until email is verified
        user.is_active = False
        user.save(update_fields=["is_active"])
        
        # Create and send verification token
        token_obj = EmailVerificationToken.create_token(user)
        self._send_verification_email(user, token_obj.token)
        
        return Response(
            {
                "detail": "User registered. Please check your email to verify your account.",
                "user": UserSerializer(user).data,
            },
            status=status.HTTP_201_CREATED,
        )

    def _send_verification_email(self, user, token):
        subject = "Code de vérification - FlyApp"
        message = (
            f"Bonjour {user.first_name},\n\n"
            f"Votre code de vérification est :\n\n"
            f"        {token}\n\n"
            f"⚠️  Ce code expire dans 1 minute.\n\n"
            f"Si vous n'avez pas créé de compte, ignorez cet email.\n\n"
            f"L'équipe FlyApp"
        )
        try:
            send_mail(
                subject,
                message,
                settings.DEFAULT_FROM_EMAIL,
                [user.email],
                fail_silently=False,
            )
        except Exception as e:
            logger.error(f"Failed to send verification email to {user.email}: {e}")


class ResendVerificationView(APIView):
    """Resend a new verification code to the user's email."""
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get("email")
        if not email:
            return Response({"detail": "Email requis."}, status=status.HTTP_400_BAD_REQUEST)
        try:
            user = User.objects.get(email=email, is_active=False)
        except User.DoesNotExist:
            # Return 200 to avoid email enumeration
            return Response({"detail": "Si ce compte existe, un nouveau code a été envoyé."})

        token_obj = EmailVerificationToken.create_token(user)
        RegisterWithEmailVerificationView()._send_verification_email(user, token_obj.token)
        return Response({"detail": "Un nouveau code a été envoyé."})


class VerifyEmailView(APIView):
    """Verify email with token and activate account."""
    permission_classes = [AllowAny]

    def post(self, request):
        token = request.data.get("token")
        if not token:
            return Response(
                {"detail": "Token is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            token_obj = EmailVerificationToken.objects.get(token=token)
        except EmailVerificationToken.DoesNotExist:
            return Response(
                {"detail": "Invalid token."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Check if token is valid
        if not token_obj.is_valid():
            return Response(
                {"detail": "Token has expired or already been used."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Activate user and mark token as verified
        user = token_obj.user
        user.is_active = True
        user.save(update_fields=["is_active"])
        
        token_obj.is_verified = True
        token_obj.save(update_fields=["is_verified"])

        return Response(
            {
                "detail": "Email verified successfully. Your account is now active.",
                "user": UserSerializer(user).data,
            },
            status=status.HTTP_200_OK,
        )


# ─── Sector Views ─────────────────────────────────────────────────────────────

class SectorViewSet(viewsets.ModelViewSet):
    """Manage geographic sectors."""
    queryset = Sector.objects.all()
    serializer_class = SectorSerializer
    permission_classes = [IsAdminOrReadOnly]
    filterset_fields = ["is_active"]
    search_fields = ["name", "code"]

    def get_queryset(self):
        if not (self.request.user.is_authenticated and
                (self.request.user.is_staff or self.request.user.role == "admin")):
            return Sector.objects.filter(is_active=True)
        return Sector.objects.all()

    def list(self, request, *args, **kwargs):
        response = super().list(request, *args, **kwargs)
        response.data = {"results": response.data}
        return response


# ─── Livreur Views ────────────────────────────────────────────────────────────

class LivreurCreateView(APIView):
    """Admin creates a new Livreur account."""
    permission_classes = [IsAuthenticated, IsAdmin]

    def post(self, request):
        serializer = LivreurCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        livreur = serializer.save()
        return Response(
            LivreurSerializer(livreur).data,
            status=status.HTTP_201_CREATED,
        )


class LivreurListView(APIView):
    """List all livreurs (admin) or get livreur profile (agent)."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Admin can see all livreurs
        if request.user.role == "admin":
            livreurs = Livreur.objects.select_related("user", "sector")
            sector_filter = request.query_params.get("sector")
            status_filter = request.query_params.get("status")
            
            if sector_filter:
                livreurs = livreurs.filter(sector_id=sector_filter)
            if status_filter:
                livreurs = livreurs.filter(status=status_filter)
            
            return Response({"results": LivreurSerializer(livreurs, many=True).data})
        
        # Livreur can only see their own profile
        if request.user.role == "livreur":
            try:
                livreur = request.user.livreur_profile
                return Response(LivreurSerializer(livreur).data)
            except Livreur.DoesNotExist:
                return Response(
                    {"detail": "Livreur profile not found."},
                    status=status.HTTP_404_NOT_FOUND,
                )
        
        return Response(
            {"detail": "Permission denied."},
            status=status.HTTP_403_FORBIDDEN,
        )


class LivreurUpdateLocationView(APIView):
    """Livreur updates their current location."""
    permission_classes = [IsAuthenticated, IsLivreur]

    def patch(self, request):
        try:
            livreur = request.user.livreur_profile
        except Livreur.DoesNotExist:
            return Response(
                {"detail": "Livreur profile not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        latitude = request.data.get("latitude")
        longitude = request.data.get("longitude")

        if latitude is None or longitude is None:
            return Response(
                {"detail": "Latitude and longitude are required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        livreur.latitude = latitude
        livreur.longitude = longitude
        livreur.save(update_fields=["latitude", "longitude"])

        return Response(
            LivreurSerializer(livreur).data,
            status=status.HTTP_200_OK,
        )


# ─── Colis (Package) Views ────────────────────────────────────────────────────

class ColisListView(APIView):
    """List packages - filtered by role."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        status_filter = request.query_params.get("status")
        sector_filter = request.query_params.get("sector")

        # Admin can see all packages
        if request.user.role == "admin":
            queryset = Colis.objects.select_related("livreur__user", "sector")
            if status_filter:
                queryset = queryset.filter(status=status_filter)
            if sector_filter:
                queryset = queryset.filter(sector_id=sector_filter)
            return Response({"results": ColisSerializer(queryset, many=True).data})

        # Livreur can only see their assigned packages
        if request.user.role == "livreur":
            try:
                livreur = request.user.livreur_profile
                queryset = Colis.objects.filter(livreur=livreur).select_related("sector")
                if status_filter:
                    queryset = queryset.filter(status=status_filter)
                return Response({"results": ColisSerializer(queryset, many=True).data})
            except Livreur.DoesNotExist:
                return Response(
                    {"detail": "Livreur profile not found."},
                    status=status.HTTP_404_NOT_FOUND,
                )

        return Response(
            {"detail": "Permission denied."},
            status=status.HTTP_403_FORBIDDEN,
        )


class ColisCreateView(APIView):
    """Create a new package (admin only)."""
    permission_classes = [IsAuthenticated, IsAdmin]

    def post(self, request):
        # Generate tracking number
        import uuid
        tracking_number = f"PKG-{uuid.uuid4().hex[:12].upper()}"
        
        # Prepare data with tracking number
        data = request.data.copy()
        data["tracking_number"] = tracking_number
        
        serializer = ColisSerializer(data=data)
        serializer.is_valid(raise_exception=True)
        colis = serializer.save()
        
        # Attempt automatic assignment if no livreur specified
        if not colis.livreur:
            self._auto_assign_colis(colis)

        return Response(
            ColisSerializer(colis).data,
            status=status.HTTP_201_CREATED,
        )

    def _auto_assign_colis(self, colis):
        """Automatically assign package to available livreur in the sector."""
        available_livreurs = Livreur.objects.filter(
            sector=colis.sector,
            status=Livreur.Status.ACTIVE,
        ).select_related("user")

        for livreur in available_livreurs:
            if livreur.can_accept_package():
                colis.assign_to_livreur(livreur)
                logger.info(f"Colis {colis.tracking_number} auto-assigned to {livreur.user.full_name}")
                return

        logger.warning(f"No available livreur found for colis {colis.tracking_number}")


class ColisAssignView(APIView):
    """Admin manually assigns/overrides package assignment."""
    permission_classes = [IsAuthenticated, IsAdmin]

    def post(self, request):
        serializer = ColisAssignSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        colis = Colis.objects.get(id=serializer.validated_data["colis_id"])
        livreur_id = serializer.validated_data.get("livreur_id")

        # Unassign from current livreur if any
        if colis.livreur:
            colis.unassign_from_livreur()

        # Assign to new livreur
        if livreur_id:
            livreur = Livreur.objects.get(id=livreur_id)
            colis.assign_to_livreur(livreur)
            logger.info(f"Colis {colis.tracking_number} assigned to {livreur.user.full_name} by admin")

        return Response(
            ColisSerializer(colis).data,
            status=status.HTTP_200_OK,
        )


class ColisDetailView(APIView):
    """Get, update, or delete a package detail."""
    permission_classes = [IsAuthenticated]

    def get(self, request, colis_id):
        try:
            colis = Colis.objects.select_related("livreur__user", "sector").get(id=colis_id)
        except Colis.DoesNotExist:
            return Response(
                {"detail": "Colis not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Livreur can only see their own packages
        if request.user.role == "agent":
            try:
                livreur = request.user.livreur_profile
                if colis.livreur_id != livreur.id:
                    return Response(
                        {"detail": "You do not have permission to view this package."},
                        status=status.HTTP_403_FORBIDDEN,
                    )
            except Livreur.DoesNotExist:
                return Response(
                    {"detail": "Livreur profile not found."},
                    status=status.HTTP_404_NOT_FOUND,
                )

        return Response(ColisSerializer(colis).data)

    def patch(self, request, colis_id):
        """Update package status (admin or assigned livreur)."""
        try:
            colis = Colis.objects.get(id=colis_id)
        except Colis.DoesNotExist:
            return Response(
                {"detail": "Colis not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Only admin or assigned livreur can update
        if request.user.role == "agent":
            try:
                livreur = request.user.livreur_profile
                if colis.livreur_id != livreur.id:
                    return Response(
                        {"detail": "You do not have permission to update this package."},
                        status=status.HTTP_403_FORBIDDEN,
                    )
            except Livreur.DoesNotExist:
                return Response(
                    {"detail": "Livreur profile not found."},
                    status=status.HTTP_404_NOT_FOUND,
                )
        elif request.user.role != "admin":
            return Response(
                {"detail": "Permission denied."},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = ColisSerializer(colis, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        
        # If status changed to delivered, record delivery time
        if serializer.validated_data.get("status") == Colis.Status.DELIVERED:
            serializer.validated_data["delivered_at"] = timezone.now()

        serializer.save()
        colis.refresh_from_db()
        return Response(ColisSerializer(colis).data)
