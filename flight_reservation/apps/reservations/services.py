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
) -> Reservation:
    """
    Full booking flow:

      1. Guard — prevent duplicate bookings for same user + offer
      2. Validate — confirm the offer is still live on Duffel
      3. Duffel — POST /air/orders  (irreversible external call)
      4. DB — save Reservation + Passengers inside transaction.atomic()
      5. Return Reservation

    ⚠️  Architecture note:
        The Duffel HTTP call is intentionally placed OUTSIDE transaction.atomic().
        HTTP requests cannot be rolled back. If we placed the Duffel call inside
        the transaction and it succeeded but the DB write failed, the rollback
        would only undo the DB — the Duffel charge would remain.

        Instead:
        - Call Duffel first (outside transaction)
        - Write to DB inside transaction.atomic()
        - If DB write fails after a successful Duffel call, log a CRITICAL alert
          containing the external_order_id for manual reconciliation.
    """

    # ── 1. Duplicate guard ────────────────────────────────────────────
    already_exists = Reservation.objects.filter(
        user=user,
        offer_id=offer_id,
        status__in=[Reservation.Status.PENDING, Reservation.Status.CONFIRMED],
    ).exists()

    if already_exists:
        raise DuplicateBookingException()

    # ── 2. Validate offer is still live ──────────────────────────────
    # Raises DuffelOfferExpiredException if the offer has expired.
    offer = duffel.get_offer(offer_id)
    logger.info(
        "Offer validated: id=%s total=%s %s",
        offer_id,
        offer.get("total_amount"),
        offer.get("total_currency"),
    )

    # ── 3. Call Duffel — outside atomic block ─────────────────────────
    duffel_order = duffel.create_order(
        offer_id=offer_id,
        passengers=_build_duffel_passengers(passengers_data),
        payment=_build_duffel_payment(payment_data),
        metadata={"user_id": str(user.id), "user_email": user.email},
    )

    # At this point, Duffel has confirmed the booking and (if applicable)
    # charged the payment method. We MUST persist external_order_id.
    external_order_id = duffel_order["id"]

    # ── 4. Persist to DB ──────────────────────────────────────────────
    try:
        with transaction.atomic():
            reservation = Reservation.objects.create(
                user=user,
                offer_id=offer_id,
                external_order_id=external_order_id,
                status=Reservation.Status.CONFIRMED,
                total_amount=Decimal(str(duffel_order["total_amount"])),
                currency=duffel_order["total_currency"],
                booking_reference=duffel_order.get("booking_reference", ""),
                raw_duffel_order=duffel_order,
            )

            # Build all Passenger objects and insert in a single query
            passenger_objs = [
                _build_passenger_obj(reservation, p, duffel_order)
                for p in passengers_data
            ]
            Passenger.objects.bulk_create(passenger_objs)

            logger.info(
                "Reservation saved: id=%s external_order_id=%s user=%s pax=%d",
                reservation.id,
                external_order_id,
                user.email,
                len(passenger_objs),
            )
            return reservation

    except Exception as db_error:
        # ⚠️  CRITICAL — Duffel order succeeded but DB write failed.
        #     The booking exists on Duffel but NOT in our database.
        #     This external_order_id must be reconciled manually.
        logger.critical(
            "DB WRITE FAILED after successful Duffel order! "
            "MANUAL RECONCILIATION REQUIRED. "
            "external_order_id=%s user=%s offer_id=%s error=%s",
            external_order_id,
            user.email,
            offer_id,
            db_error,
            exc_info=True,
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
