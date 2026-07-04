from django.core.mail import send_mail
from django.conf import settings

from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.users.models import PasswordResetToken, User
from apps.users.serializers import RegisterSerializer, UserSerializer


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user).data)

    def patch(self, request):
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class AdminUsersView(APIView):
    """GET /api/v1/admin/users/ — list all users (admin only)."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role != "admin":
            return Response({"detail": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)
        users = User.objects.all().order_by("-created_at")
        return Response({"results": UserSerializer(users, many=True).data})


class AdminCreateUserView(APIView):
    """POST /api/v1/admin/users/create/ — create a new user (admin only)."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.role != "admin":
            return Response({"detail": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        role = request.data.get("role", "client")
        if role in ("admin", "agent", "client"):
            user.role = role
            user.save(update_fields=["role"])
        return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)


class AdminUserDetailView(APIView):
    """
    GET    /api/v1/admin/users/{id}/  — get user detail
    PATCH  /api/v1/admin/users/{id}/  — update role / is_active
    DELETE /api/v1/admin/users/{id}/  — delete user
    """

    permission_classes = [IsAuthenticated]

    def _get_user(self, user_id):
        try:
            return User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return None

    def get(self, request, user_id):
        if request.user.role != "admin":
            return Response({"detail": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)
        user = self._get_user(user_id)
        if not user:
            return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)
        return Response(UserSerializer(user).data)

    def patch(self, request, user_id):
        if request.user.role != "admin":
            return Response({"detail": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)
        user = self._get_user(user_id)
        if not user:
            return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)
        allowed = {"role", "is_active", "first_name", "last_name", "phone"}
        data = {k: v for k, v in request.data.items() if k in allowed}
        serializer = UserSerializer(user, data=data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

    def delete(self, request, user_id):
        if request.user.role != "admin":
            return Response({"detail": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)
        if str(request.user.pk) == str(user_id):
            return Response({"detail": "Cannot delete your own account."}, status=status.HTTP_400_BAD_REQUEST)
        user = self._get_user(user_id)
        if not user:
            return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)
        user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        old_password = request.data.get("old_password")
        new_password = request.data.get("new_password")

        if not old_password or not new_password:
            return Response(
                {"detail": "Both old_password and new_password are required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not request.user.check_password(old_password):
            return Response(
                {"detail": "Old password is incorrect."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if len(new_password) < 8:
            return Response(
                {"detail": "New password must be at least 8 characters."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        request.user.set_password(new_password)
        request.user.save()
        return Response({"detail": "Password changed successfully."})


class ForgotPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get("email", "").strip().lower()
        if not email:
            return Response({"detail": "Email is required."}, status=status.HTTP_400_BAD_REQUEST)

        if not User.objects.filter(email=email).exists():
            return Response(
                {"detail": "Aucun compte associé à cet email."},
                status=status.HTTP_404_NOT_FOUND,
            )

        token = PasswordResetToken.create_for(email)
        send_mail(
            subject="Réinitialisation de votre mot de passe FlyApp",
            message=(
                f"Votre code de réinitialisation est : {token.code}\n\n"
                f"Ce code est valable 15 minutes.\n"
                f"Si vous n'avez pas demandé cette réinitialisation, ignorez cet email."
            ),
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[email],
            fail_silently=True,
        )
        return Response({"detail": "Code envoyé à votre email."})


class ResetPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get("email", "").strip().lower()
        code = request.data.get("code", "").strip()
        new_password = request.data.get("new_password", "")

        if not email or not code or not new_password:
            return Response(
                {"detail": "email, code and new_password are required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if len(new_password) < 8:
            return Response(
                {"detail": "Le mot de passe doit contenir au moins 8 caractères."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        token = PasswordResetToken.objects.filter(email=email, code=code).order_by("-created_at").first()

        if not token or not token.is_valid():
            return Response(
                {"detail": "Code invalide ou expiré."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({"detail": "Utilisateur introuvable."}, status=status.HTTP_404_NOT_FOUND)

        user.set_password(new_password)
        user.save()
        token.used = True
        token.save(update_fields=["used"])

        return Response({"detail": "Mot de passe réinitialisé avec succès."})
