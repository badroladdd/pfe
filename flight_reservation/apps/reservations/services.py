import logging
from decimal import Decimal

from django.db import transaction

from apps.reservations.models import Passenger, Reservation
from core.duffel_client import DuffelClient
from core.exceptions import (
    CancellationNotAllowedException,
    DuplicateBookingException,
    ReservationNotFoundException,
)

logger = logging.getLogger("reservations")

# Module-level singleton — one session reused across requests
duffel = DuffelClient()


# ══════════════════════════════════════════════════════════════════════
#  CREATE RESERVATION
# ══════════════════════════════════════════════════════════════════════

def create_reservation(
    user,
    offer_id: str,
    passengers_data: list[dict],
    payment_data: dict,
    payment_method: str = "cash",
    promo_code: str | None = None,
) -> Reservation:
    """
    Deux flux selon le mode de paiement :

    - cash (à la livraison) : sauvegarde PENDING, agent confirme plus tard
    - cib  (carte bancaire) : appelle Duffel immédiatement → CONFIRMED
    """

    # ── 0. Valider et appliquer le code promo ────────────────────────
    promo = None
    if promo_code:
        from apps.reservations.models import PromoCode
        try:
            promo = PromoCode.objects.get(code=promo_code.upper())
            if not promo.is_valid:
                promo = None
        except PromoCode.DoesNotExist:
            promo = None

    # ── 1. Duplicate guard ────────────────────────────────────────────
    already_exists = Reservation.objects.filter(
        user=user,
        offer_id=offer_id,
        status__in=[Reservation.Status.PENDING, Reservation.Status.CONFIRMED],
    ).exists()
    if already_exists:
        raise DuplicateBookingException()

    # ── 2. Validate offer is still live ──────────────────────────────
    offer = duffel.get_offer(offer_id)
    logger.info(
        "Offer validated: id=%s total=%s %s",
        offer_id,
        offer.get("total_amount"),
        offer.get("total_currency"),
    )

    duffel_passengers = _build_duffel_passengers(passengers_data)
    duffel_payment    = _build_duffel_payment(payment_data)

    # ── 3a. Paiement carte (CIB) — confirmation immédiate ────────────
    if payment_method == "cib":
        duffel_order = duffel.create_order(
            offer_id=offer_id,
            passengers=duffel_passengers,
            payment=duffel_payment,
            metadata={"user_id": str(user.id), "payment_method": "cib"},
        )
        with transaction.atomic():
            reservation = Reservation.objects.create(
                user=user,
                offer_id=offer_id,
                status=Reservation.Status.CONFIRMED,
                total_amount=Decimal(str(duffel_order.get("total_amount", "0"))),
                currency=duffel_order.get("total_currency", "EUR"),
                external_order_id=duffel_order["id"],
                booking_reference=duffel_order.get("booking_reference", ""),
                raw_duffel_order=duffel_order,
                pending_booking_data=None,
            )
            Passenger.objects.bulk_create([
                _build_passenger_obj(reservation, p, duffel_order)
                for p in passengers_data
            ])
            if promo:
                promo.used_count += 1
                promo.save(update_fields=["used_count"])
            logger.info(
                "Reservation confirmed instantly (CIB): id=%s order=%s user=%s",
                reservation.id, duffel_order["id"], user.email,
            )
            return reservation

    # ── 3b. Paiement ultérieurement (cash) — attente agent ───────────
    with transaction.atomic():
        reservation = Reservation.objects.create(
            user=user,
            offer_id=offer_id,
            status=Reservation.Status.PENDING,
            total_amount=Decimal(str(offer.get("total_amount", "0"))),
            currency=offer.get("total_currency", "EUR"),
            raw_duffel_order=offer,
            pending_booking_data={
                "duffel_passengers": duffel_passengers,
                "payment": duffel_payment,
            },
        )
        Passenger.objects.bulk_create([
            _build_passenger_obj_pending(reservation, p)
            for p in passengers_data
        ])
        if promo:
            promo.used_count += 1
            promo.save(update_fields=["used_count"])
        logger.info(
            "Reservation created (pending/cash): id=%s user=%s offer=%s",
            reservation.id, user.email, offer_id,
        )
        return reservation


def confirm_reservation(reservation: Reservation, agent) -> Reservation:
    """
    Agent confirmation flow:
      1. Read stored pending_booking_data
      2. Call Duffel create_order (irreversible)
      3. Update DB with order data and set status=CONFIRMED
    """
    if reservation.status != Reservation.Status.PENDING:
        from core.exceptions import CancellationNotAllowedException
        raise CancellationNotAllowedException("Only pending reservations can be confirmed.")

    data = reservation.pending_booking_data or {}
    duffel_passengers = data.get("duffel_passengers", [])
    payment = data.get("payment", {})

    # ── Call Duffel — outside atomic block ────────────────────────────
    duffel_order = duffel.create_order(
        offer_id=reservation.offer_id,
        passengers=duffel_passengers,
        payment=payment,
        metadata={"user_id": str(reservation.user.id), "confirmed_by": str(agent.id)},
    )
    external_order_id = duffel_order["id"]

    try:
        with transaction.atomic():
            reservation.external_order_id = external_order_id
            reservation.status = Reservation.Status.CONFIRMED
            reservation.total_amount = Decimal(str(duffel_order["total_amount"]))
            reservation.currency = duffel_order["total_currency"]
            reservation.booking_reference = duffel_order.get("booking_reference", "")
            reservation.raw_duffel_order = duffel_order
            reservation.pending_booking_data = None
            reservation.save(update_fields=[
                "external_order_id", "status", "total_amount", "currency",
                "booking_reference", "raw_duffel_order", "pending_booking_data", "updated_at",
            ])
            logger.info(
                "Reservation confirmed by agent: id=%s order=%s agent=%s",
                reservation.id, external_order_id, agent.email,
            )
            return reservation
    except Exception as db_error:
        logger.critical(
            "DB WRITE FAILED after Duffel order! RECONCILE: external_order_id=%s reservation=%s error=%s",
            external_order_id, reservation.id, db_error, exc_info=True,
        )
        raise


# ══════════════════════════════════════════════════════════════════════
#  RETRIEVE RESERVATIONS
# ══════════════════════════════════════════════════════════════════════

def get_reservation(reservation_id, user) -> Reservation:
    """
    Fetch a single reservation.
    - Admin / Agent: can access any reservation.
    - Client: can only access their own.
    """
    try:
        qs = Reservation.objects.select_related("user").prefetch_related("passengers")
        if user.role == "client":
            qs = qs.filter(user=user)
        return qs.get(id=reservation_id)
    except Reservation.DoesNotExist:
        raise ReservationNotFoundException()


def list_reservations(user, filters: dict | None = None):
    """
    List reservations with optional filtering.
    - Admin / Agent: see all.
    - Client: see only their own.
    """
    qs = Reservation.objects.select_related("user").prefetch_related("passengers")

    if user.role == "client":
        qs = qs.filter(user=user)

    if filters:
        if status := filters.get("status"):
            qs = qs.filter(status=status)
        if from_date := filters.get("from_date"):
            qs = qs.filter(created_at__date__gte=from_date)
        if to_date := filters.get("to_date"):
            qs = qs.filter(created_at__date__lte=to_date)

    return qs.order_by("-created_at")


# ══════════════════════════════════════════════════════════════════════
#  CANCEL RESERVATION
# ══════════════════════════════════════════════════════════════════════

def cancel_reservation(reservation_id, user) -> Reservation:
    """
    Cancel a reservation:
      1. Fetch and validate the reservation
      2. Call Duffel cancellation API (two-step: quote → confirm)
      3. Update local status to CANCELLED inside transaction.atomic()
    """
    reservation = get_reservation(reservation_id, user)

    if reservation.status == Reservation.Status.CANCELLED:
        raise CancellationNotAllowedException("Reservation is already cancelled.")
    if reservation.status == Reservation.Status.FAILED:
        raise CancellationNotAllowedException(
            "Failed reservations cannot be cancelled."
        )

    # ── Sync cancellation with Duffel ────────────────────────────────
    if reservation.external_order_id:
        cancellation = duffel.cancel_order(reservation.external_order_id)
        logger.info(
            "Duffel cancellation confirmed: order_id=%s refund=%s %s",
            reservation.external_order_id,
            cancellation.get("refund_amount"),
            cancellation.get("refund_currency"),
        )

    # ── Update local DB ───────────────────────────────────────────────
    with transaction.atomic():
        reservation.status = Reservation.Status.CANCELLED
        reservation.save(update_fields=["status", "updated_at"])

    logger.info("Reservation cancelled: id=%s user=%s", reservation.id, user.email)
    return reservation


# ══════════════════════════════════════════════════════════════════════
#  PRIVATE HELPERS
# ══════════════════════════════════════════════════════════════════════

def _build_duffel_passengers(passengers_data: list[dict]) -> list[dict]:
    """Map validated serializer data → Duffel passenger schema."""
    result = []
    for p in passengers_data:
        passenger: dict = {
            "type": p.get("type", "adult"),
            "title": p["title"],
            "given_name": p["given_name"],
            "family_name": p["family_name"],
            "born_on": str(p["born_on"]),
            "email": p["email"],
            "gender": p.get("gender", "m"),
        }
        # Duffel requires the passenger ID from the original offer
        if p.get("id"):
            passenger["id"] = p["id"]
        # Only include phone_number when non-empty (Duffel rejects empty strings)
        phone = p.get("phone_number", "")
        if phone:
            passenger["phone_number"] = phone
        if p.get("identity_documents"):
            passenger["identity_documents"] = [
                {
                    "type": doc["type"],
                    "unique_identifier": doc["unique_identifier"],
                    "expires_on": str(doc["expires_on"]),
                    "issuing_country_code": doc["issuing_country_code"],
                }
                for doc in p["identity_documents"]
            ]
        result.append(passenger)
    return result


def _build_duffel_payment(payment_data: dict) -> dict:
    """Map validated payment data → Duffel payment schema."""
    return {
        "type": payment_data["type"],
        "amount": str(payment_data["amount"]),
        "currency": payment_data["currency"],
    }


def _build_passenger_obj_pending(reservation: Reservation, p: dict) -> Passenger:
    """Build a Passenger object from serializer data without a Duffel order."""
    docs = p.get("identity_documents", [])
    first_doc = docs[0] if docs else {}
    return Passenger(
        reservation=reservation,
        type=p.get("type", Passenger.Type.ADULT),
        title=p["title"],
        first_name=p["given_name"],
        last_name=p["family_name"],
        born_on=p["born_on"],
        email=p["email"],
        phone=p.get("phone_number", ""),
        id_document_type=first_doc.get("type", ""),
        id_document_number=first_doc.get("unique_identifier", ""),
        id_document_expiry=first_doc.get("expires_on"),
        nationality=first_doc.get("issuing_country_code", ""),
    )


def _build_passenger_obj(
    reservation: Reservation,
    p: dict,
    duffel_order: dict,
) -> Passenger:
    """
    Construct a Passenger model instance from serializer data.
    Attempts to extract per-passenger price breakdown from the Duffel order.
    """
    docs = p.get("identity_documents", [])
    first_doc = docs[0] if docs else {}

    # Try to find matching passenger pricing in the Duffel order
    base_amount = None
    tax_amount = None
    for duffel_pax in duffel_order.get("passengers", []):
        if (
            duffel_pax.get("given_name", "").lower() == p["given_name"].lower()
            and duffel_pax.get("family_name", "").lower() == p["family_name"].lower()
        ):
            base_amount = duffel_pax.get("base_amount")
            tax_amount = duffel_pax.get("tax_amount")
            break

    return Passenger(
        reservation=reservation,
        type=p.get("type", Passenger.Type.ADULT),
        title=p["title"],
        first_name=p["given_name"],
        last_name=p["family_name"],
        born_on=p["born_on"],
        email=p["email"],
        phone=p.get("phone_number", ""),
        id_document_type=first_doc.get("type", ""),
        id_document_number=first_doc.get("unique_identifier", ""),
        id_document_expiry=first_doc.get("expires_on"),
        nationality=first_doc.get("issuing_country_code", ""),
        base_amount=Decimal(str(base_amount)) if base_amount else None,
        tax_amount=Decimal(str(tax_amount)) if tax_amount else None,
    )
