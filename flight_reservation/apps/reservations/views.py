import logging
from decimal import Decimal

from django.db.models import Count, Q, Sum
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.reservations import services
from apps.reservations.models import PromoCode, Reservation
from apps.reservations.serializers import (
    CreateReservationSerializer,
    PromoCodeInputSerializer,
    PromoCodeOutputSerializer,
    ReservationOutputSerializer,
    ValidatePromoSerializer,
)
from apps.users.models import User
from core.permissions import IsOwnerOrStaff

logger = logging.getLogger("reservations")


class ReservationListCreateView(APIView):
    """
    GET  /api/v1/reservations/  — list reservations (filtered by role)
    POST /api/v1/reservations/  — create a reservation from a Flutter flight offer
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        filters = {
            "status":    request.query_params.get("status"),
            "from_date": request.query_params.get("from_date"),
            "to_date":   request.query_params.get("to_date"),
        }
        reservations = services.list_reservations(request.user, filters=filters)
        serializer = ReservationOutputSerializer(reservations, many=True)
        return Response({"results": serializer.data})

    def post(self, request):
        # Flutter sends: { flight_offer: {...}, passengers: [...], accept_price_change: bool }
        flight_offer = request.data.get("flight_offer", {})
        offer_id = flight_offer.get("id") or flight_offer.get("offer_id")

        if not offer_id:
            return Response(
                {"detail": "flight_offer.id is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        flutter_passengers = request.data.get("passengers", [])
        if not flutter_passengers:
            return Response(
                {"detail": "At least one passenger is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Offer passengers carry the Duffel passenger IDs that must be echoed
        # back in the order creation request.
        offer_passengers = flight_offer.get("passengers", [])
        amount = Decimal(str(flight_offer.get("total_amount", "0"))).quantize(Decimal("0.01"))

        payload = {
            "offer_id": offer_id,
            "passengers": _convert_flutter_passengers(flutter_passengers, offer_passengers),
            "payment": {
                "type": "balance",
                "amount": str(amount),
                "currency": flight_offer.get("total_currency", "EUR"),
            },
        }

        serializer = CreateReservationSerializer(data=payload)
        serializer.is_valid(raise_exception=True)
        d = serializer.validated_data

        payment_method = request.data.get("payment_method", "cash")
        promo_code     = request.data.get("promo_code")

        reservation = services.create_reservation(
            user=request.user,
            offer_id=d["offer_id"],
            passengers_data=d["passengers"],
            payment_data=d["payment"],
            payment_method=payment_method,
            promo_code=promo_code,
        )
        output = ReservationOutputSerializer(reservation)
        return Response({"data": output.data}, status=status.HTTP_201_CREATED)


class ReservationDetailView(APIView):
    """
    GET    /api/v1/reservations/{id}/  — retrieve reservation
    DELETE /api/v1/reservations/{id}/  — cancel reservation
    """

    permission_classes = [IsAuthenticated, IsOwnerOrStaff]

    def get(self, request, pk):
        reservation = services.get_reservation(pk, request.user)
        serializer = ReservationOutputSerializer(reservation)
        return Response({"data": serializer.data})

    def delete(self, request, pk):
        reservation = services.cancel_reservation(pk, request.user)
        serializer = ReservationOutputSerializer(reservation)
        return Response({"data": serializer.data})


class DuffelWebhookView(APIView):
    """
    POST /api/v1/webhooks/duffel/
    """

    permission_classes = []
    authentication_classes = []

    def post(self, request):
        event_type = request.data.get("type", "")
        data = request.data.get("data", {}).get("object", {})

        logger.info("Duffel webhook received: type=%s", event_type)

        if event_type == "order.updated":
            order_id = data.get("id")
            if order_id:
                from apps.reservations.models import Reservation
                reservation = Reservation.objects.filter(
                    external_order_id=order_id
                ).first()
                if reservation:
                    reservation.raw_duffel_order = data
                    reservation.save(update_fields=["raw_duffel_order", "updated_at"])
                    logger.info(
                        "Reservation synced from webhook: external_order_id=%s", order_id
                    )

        return Response({"received": True})


class AdminReservationsView(APIView):
    """GET /api/v1/admin/reservations/ — list ALL reservations (admin only)."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role not in ("admin", "agent"):
            return Response({"detail": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)
        qs = Reservation.objects.select_related("user").order_by("-created_at")
        status_filter = request.query_params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter)
        serializer = ReservationOutputSerializer(qs, many=True)
        return Response({"results": serializer.data})


class AgentReservationsView(APIView):
    """
    GET   /api/v1/agent/reservations/        — list all reservations (agent/admin)
    PATCH /api/v1/agent/reservations/{id}/   — confirm or cancel a reservation
    POST  /api/v1/agent/reservations/        — create reservation on behalf of a client
    """

    permission_classes = [IsAuthenticated]

    def _check_agent(self, request):
        if request.user.role not in ("agent", "admin"):
            return Response({"detail": "Agent access required."}, status=status.HTTP_403_FORBIDDEN)
        return None

    def get(self, request):
        err = self._check_agent(request)
        if err:
            return err
        qs = Reservation.objects.select_related("user").order_by("-created_at")
        status_filter = request.query_params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter)
        serializer = ReservationOutputSerializer(qs, many=True)
        return Response({"results": serializer.data})

    def post(self, request):
        """Create a reservation on behalf of a client (agent flow)."""
        err = self._check_agent(request)
        if err:
            return err

        flight_offer      = request.data.get("flight_offer", {})
        offer_id          = flight_offer.get("id") or flight_offer.get("offer_id")
        flutter_passengers = request.data.get("passengers", [])
        for_user_id       = request.data.get("for_user_id")

        if not offer_id:
            return Response({"detail": "flight_offer.id is required."}, status=status.HTTP_400_BAD_REQUEST)
        if not flutter_passengers:
            return Response({"detail": "At least one passenger is required."}, status=status.HTTP_400_BAD_REQUEST)

        # Resolve target user
        booking_user = request.user
        if for_user_id:
            try:
                from apps.users.models import User as UserModel
                booking_user = UserModel.objects.get(pk=for_user_id)
            except UserModel.DoesNotExist:
                return Response({"detail": "Client not found."}, status=status.HTTP_404_NOT_FOUND)

        offer_passengers = flight_offer.get("passengers", [])
        payload = {
            "offer_id": offer_id,
            "passengers": _convert_flutter_passengers(flutter_passengers, offer_passengers),
            "payment": {
                "type": "balance",
                "amount": str(flight_offer.get("total_amount", "0")),
                "currency": flight_offer.get("total_currency", "EUR"),
            },
        }
        serializer = CreateReservationSerializer(data=payload)
        serializer.is_valid(raise_exception=True)
        d = serializer.validated_data
        reservation = services.create_reservation(
            user=booking_user,
            offer_id=d["offer_id"],
            passengers_data=d["passengers"],
            payment_data=d["payment"],
        )
        return Response({"data": ReservationOutputSerializer(reservation).data}, status=status.HTTP_201_CREATED)


class AgentReservationActionView(APIView):
    """
    PATCH /api/v1/agent/reservations/{id}/  — confirm or cancel
    """

    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        if request.user.role not in ("agent", "admin"):
            return Response({"detail": "Agent access required."}, status=status.HTTP_403_FORBIDDEN)

        new_status = request.data.get("status")
        if new_status not in ("confirmed", "emis", "cancelled"):
            return Response(
                {"detail": "status must be 'confirmed', 'emis' or 'cancelled'."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            reservation = Reservation.objects.get(pk=pk)
        except Reservation.DoesNotExist:
            return Response({"detail": "Reservation not found."}, status=status.HTTP_404_NOT_FOUND)

        if reservation.status == "cancelled":
            return Response({"detail": "Reservation is already cancelled."}, status=status.HTTP_400_BAD_REQUEST)

        if new_status == "confirmed":
            if reservation.status != Reservation.Status.PENDING:
                return Response({"detail": "Only pending reservations can be confirmed."}, status=status.HTTP_400_BAD_REQUEST)
            reservation = services.confirm_reservation(reservation, request.user)

        elif new_status == "emis":
            if reservation.status != Reservation.Status.CONFIRMED:
                return Response({"detail": "Only confirmed reservations can be marked as emis."}, status=status.HTTP_400_BAD_REQUEST)
            reservation.status = Reservation.Status.EMIS
            reservation.save(update_fields=["status", "updated_at"])

        elif new_status == "assign_livreur":
            if reservation.status in (Reservation.Status.PENDING, Reservation.Status.CANCELLED):
                return Response(
                    {"detail": "Impossible d'affecter un livreur à une réservation en attente ou annulée."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            from apps.deliveries.models import Livreur
            livreur_id = request.data.get("livreur_id")
            if not livreur_id:
                return Response({"detail": "livreur_id is required."}, status=status.HTTP_400_BAD_REQUEST)
            try:
                livreur = Livreur.objects.get(id=livreur_id)
            except Livreur.DoesNotExist:
                return Response({"detail": "Livreur not found."}, status=status.HTTP_404_NOT_FOUND)
            reservation.livreur = livreur
            reservation.save(update_fields=["livreur", "updated_at"])

        else:
            # Cancel: trigger Duffel if already booked, otherwise just mark cancelled
            if reservation.external_order_id:
                reservation = services.cancel_reservation(str(pk), request.user)
            else:
                reservation.status = Reservation.Status.CANCELLED
                reservation.pending_booking_data = None
                reservation.save(update_fields=["status", "pending_booking_data", "updated_at"])

        reservation.refresh_from_db()
        return Response({"data": ReservationOutputSerializer(reservation).data})


class LivreurBilletsView(APIView):
    """GET /api/v1/agent/livreurs/{livreur_id}/billets/ — billets assigned to a livreur (admin/agent view)."""

    permission_classes = [IsAuthenticated]

    def get(self, request, livreur_id):
        if request.user.role not in ("agent", "admin"):
            return Response({"detail": "Agent access required."}, status=status.HTTP_403_FORBIDDEN)
        qs = Reservation.objects.select_related("user", "livreur__user").filter(
            livreur_id=livreur_id
        ).order_by("-created_at")
        status_filter = request.query_params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter)
        return Response({"results": ReservationOutputSerializer(qs, many=True).data})


class LivreurMyBilletsView(APIView):
    """GET /api/v1/livreurs/my-billets/ — billets assigned to the authenticated livreur."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role != "livreur":
            return Response({"detail": "Accès réservé aux livreurs."}, status=status.HTTP_403_FORBIDDEN)
        livreur = request.user.livreur_profile
        qs = Reservation.objects.select_related("user").filter(
            livreur=livreur
        ).order_by("-created_at")
        status_filter = request.query_params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter)
        return Response({"results": ReservationOutputSerializer(qs, many=True).data})


class AdminStatsView(APIView):
    """GET /api/v1/admin/stats/ — summary stats for the admin dashboard."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role not in ["admin", "agent"]:
            return Response({"detail": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)

        agg = Reservation.objects.aggregate(
            total=Count("id"),
            confirmed=Count("id", filter=Q(status="confirmed")),
            cancelled=Count("id", filter=Q(status="cancelled")),
            pending=Count("id", filter=Q(status="pending")),
            revenue=Sum("total_amount", filter=Q(status="confirmed")),
        )

        return Response({
            "total_users":              User.objects.count(),
            "total_reservations":       agg["total"] or 0,
            "confirmed_reservations":   agg["confirmed"] or 0,
            "cancelled_reservations":   agg["cancelled"] or 0,
            "pending_reservations":     agg["pending"] or 0,
            "total_revenue":            str(agg["revenue"] or "0.00"),
        })


class AdminPromoCodesView(APIView):
    """
    GET  /api/v1/admin/promo-codes/  — list all promo codes (admin)
    POST /api/v1/admin/promo-codes/  — create a promo code (admin)
    """

    permission_classes = [IsAuthenticated]

    def _check_admin(self, request):
        if request.user.role != "admin":
            return Response({"detail": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)
        return None

    def get(self, request):
        if err := self._check_admin(request):
            return err
        qs = PromoCode.objects.order_by("-created_at")
        return Response({"results": PromoCodeOutputSerializer(qs, many=True).data})

    def post(self, request):
        if err := self._check_admin(request):
            return err
        serializer = PromoCodeInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        d = serializer.validated_data
        promo = PromoCode.objects.create(
            code=d["code"].upper(),
            discount_type=d["discount_type"],
            discount_value=d["discount_value"],
            max_uses=d["max_uses"],
            expires_at=d["expires_at"],
        )
        return Response({"data": PromoCodeOutputSerializer(promo).data}, status=status.HTTP_201_CREATED)


class AdminPromoCodeDetailView(APIView):
    """
    PATCH  /api/v1/admin/promo-codes/{id}/  — toggle active / update
    DELETE /api/v1/admin/promo-codes/{id}/  — delete
    """

    permission_classes = [IsAuthenticated]

    def _get_promo(self, pk):
        try:
            return PromoCode.objects.get(pk=pk)
        except PromoCode.DoesNotExist:
            return None

    def patch(self, request, pk):
        if request.user.role != "admin":
            return Response({"detail": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)
        promo = self._get_promo(pk)
        if not promo:
            return Response({"detail": "Code promo introuvable."}, status=status.HTTP_404_NOT_FOUND)
        for field in ("is_active", "max_uses", "expires_at"):
            if field in request.data:
                setattr(promo, field, request.data[field])
        promo.save()
        return Response({"data": PromoCodeOutputSerializer(promo).data})

    def delete(self, request, pk):
        if request.user.role != "admin":
            return Response({"detail": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)
        promo = self._get_promo(pk)
        if not promo:
            return Response({"detail": "Code promo introuvable."}, status=status.HTTP_404_NOT_FOUND)
        promo.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ValidatePromoCodeView(APIView):
    """POST /api/v1/promo-codes/validate/ — validate a code and return the discounted amount."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ValidatePromoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        code   = serializer.validated_data["code"].upper()
        amount = serializer.validated_data["amount"]

        try:
            promo = PromoCode.objects.get(code=code)
        except PromoCode.DoesNotExist:
            return Response({"detail": "Code promo invalide."}, status=status.HTTP_404_NOT_FOUND)

        if not promo.is_valid:
            return Response({"detail": "Code promo expiré ou épuisé."}, status=status.HTTP_400_BAD_REQUEST)

        discounted = promo.apply(amount)
        discounted = discounted.quantize(Decimal("0.01"))
        saved = (amount - discounted).quantize(Decimal("0.01"))
        return Response({
            "code":           promo.code,
            "discount_type":  promo.discount_type,
            "discount_value": str(promo.discount_value),
            "original_amount": str(amount.quantize(Decimal("0.01"))),
            "discounted_amount": str(discounted),
            "saved": str(saved),
        })


# ── Private helpers ────────────────────────────────────────────────────────────

def _convert_flutter_passengers(flutter_passengers: list, offer_passengers: list | None = None) -> list:
    """Map Flutter PassengerInput fields → Django PassengerInputSerializer fields."""
    offer_passengers = offer_passengers or []
    result = []
    for i, p in enumerate(flutter_passengers):
        gender = p.get("gender", "M")
        title = "mrs" if gender == "F" else "mr"

        # Format phone to E.164 (Duffel requirement: must start with '+')
        phone        = p.get("phone", "").strip()
        country_code = p.get("phone_country_code", "213").strip().lstrip("+")
        if phone:
            if phone.startswith("+"):
                pass  # deja E.164
            elif phone.startswith("0"):
                # 0550123456 → +213550123456
                phone = f"+{country_code}{phone[1:]}"
            else:
                # 550123456 → +213550123456
                phone = f"+{country_code}{phone}"
        # Valider longueur minimale
        if len(phone) < 8:
            phone = ""

        pax_type = p.get("passenger_type", "adult")
        # Normaliser : infant/infant_without_seat → infant_without_seat pour Duffel
        if "infant" in pax_type:
            pax_type = "infant_without_seat"

        django_passenger = {
            "type":         pax_type,
            "title":        title,
            "given_name":   p.get("first_name", ""),
            "family_name":  p.get("last_name", ""),
            "born_on":      p.get("date_of_birth", ""),
            "email":        p.get("email", ""),
            "phone_number": phone,
            "gender":       "f" if gender == "F" else "m",
        }

        # Attach the Duffel passenger ID from the offer (required by Duffel order API)
        if i < len(offer_passengers):
            offer_pax_id = offer_passengers[i].get("id", "")
            if offer_pax_id:
                django_passenger["id"] = offer_pax_id

        passport_number  = p.get("passport_number", "")
        passport_expiry  = p.get("passport_expiry", "")
        passport_country = p.get("passport_country", "")
        if passport_number and passport_expiry and passport_country:
            django_passenger["identity_documents"] = [
                {
                    "type":                "passport",
                    "unique_identifier":   passport_number,
                    "expires_on":          passport_expiry,
                    "issuing_country_code": passport_country,
                }
            ]

        result.append(django_passenger)
    return result
