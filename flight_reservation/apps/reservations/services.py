import logging
from decimal import Decimal

from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction

from apps.reservations.models import Passenger, Reservation
from core.amadeus_client import AmadeusClient
from core.exceptions import (
    CancellationNotAllowedException,
    DuplicateBookingException,
    ReservationNotFoundException,
)

logger = logging.getLogger("reservations")

amadeus = AmadeusClient()


# ── Email helpers ─────────────────────────────────────────────────────────────

def _extract_flight_info(offer: dict) -> dict:
    """Extract key flight details from an Amadeus offer or order."""
    itineraries = offer.get("itineraries") or []
    if not itineraries:
        # Amadeus order wraps offers
        offers = offer.get("flightOffers") or []
        if offers:
            itineraries = offers[0].get("itineraries") or []

    if not itineraries:
        return {}

    segs  = itineraries[0].get("segments") or []
    first = segs[0]  if segs else {}
    last  = segs[-1] if segs else {}

    dicts    = offer.get("dictionaries") or {}
    carriers = dicts.get("carriers", {})
    code     = first.get("carrierCode", "")

    return {
        "origin":      (first.get("departure") or {}).get("iataCode", ""),
        "destination": (last.get("arrival")    or {}).get("iataCode", ""),
        "departure_at": (first.get("departure") or {}).get("at", ""),
        "arrival_at":   (last.get("arrival")    or {}).get("at", ""),
        "carrier":      carriers.get(code, code),
        "flight_number": code + (first.get("number") or ""),
        "stops":        len(segs) - 1,
    }


def send_ticket_email(reservation: Reservation) -> None:
    """Send ticket confirmation email to the client after CIB/electronic payment."""
    user   = reservation.user
    flight = _extract_flight_info(reservation.raw_duffel_order or {})

    dep = flight.get("departure_at", "")[:16].replace("T", " à ")
    arr = flight.get("arrival_at",   "")[:16].replace("T", " à ")

    subject = f"Votre billet FlyApp — {flight.get('origin','?')} → {flight.get('destination','?')}"
    message = (
        f"Bonjour {user.first_name},\n\n"
        f"Votre billet a été émis avec succès. Voici vos détails de vol :\n\n"
        f"  Référence PNR    : {reservation.booking_reference}\n"
        f"  Vol              : {flight.get('flight_number','')}\n"
        f"  Compagnie        : {flight.get('carrier','')}\n"
        f"  Départ           : {flight.get('origin','?')}  {dep}\n"
        f"  Arrivée          : {flight.get('destination','?')}  {arr}\n"
        f"  Escales          : {flight.get('stops', 0)}\n"
        f"  Montant payé     : {reservation.total_amount} {reservation.currency}\n\n"
        f"Passagers :\n"
        + "".join(
            f"  - {p.first_name} {p.last_name} ({p.type})\n"
            for p in reservation.passengers.all()
        )
        + "\nMerci d'avoir choisi FlyApp. Bon voyage !\n\n"
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
        logger.info("Ticket email sent to %s for reservation %s", user.email, reservation.id)
    except Exception as e:
        logger.error("Failed to send ticket email to %s: %s", user.email, e)


# ══════════════════════════════════════════════════════════════════════
#  CREATE RESERVATION
# ══════════════════════════════════════════════════════════════════════

def create_reservation(
    user,
    offer_id: str,
    passengers_data: list[dict],
    payment_data: dict,
    flight_offer: dict | None = None,
    payment_method: str = "cash",
    promo_code: str | None = None,
) -> Reservation:
    """
    Deux flux selon le mode de paiement :
    - cash : sauvegarde PENDING, agent confirme plus tard via Amadeus
    - cib  : appelle Amadeus immédiatement → CONFIRMED

    `flight_offer` must be the full Amadeus offer object (required for booking).
    `offer_id` is kept for de-duplication only.
    """

    # ── 0. Promo code ────────────────────────────────────────────────
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

    offer        = flight_offer or {}
    price        = offer.get("price", {})
    total_str    = price.get("grandTotal", price.get("total", str(payment_data.get("amount", "0"))))
    currency     = price.get("currency", payment_data.get("currency", "EUR"))
    travelers    = _build_amadeus_travelers(passengers_data)

    logger.info(
        "Offer validated: id=%s total=%s %s",
        offer_id, total_str, currency,
    )

    reservation_amount = Decimal(str(payment_data.get("amount", total_str)))

    # ── 3a. CIB — immediate Amadeus booking, auto-emis + email ──────────
    if payment_method == "cib":
        amadeus_order = amadeus.create_order(
            flight_offer=offer,
            travelers=travelers,
        )
        ext_id   = amadeus_order.get("id", "")
        book_ref = _extract_booking_ref(amadeus_order)

        with transaction.atomic():
            reservation = Reservation.objects.create(
                user=user,
                offer_id=offer_id,
                status=Reservation.Status.EMIS,   # auto-emitted for electronic payment
                total_amount=reservation_amount,
                currency=currency,
                external_order_id=ext_id,
                booking_reference=book_ref,
                raw_duffel_order=amadeus_order,
                pending_booking_data=None,
            )
            Passenger.objects.bulk_create([
                _build_passenger_obj(reservation, p)
                for p in passengers_data
            ])
            if promo:
                promo.used_count += 1
                promo.save(update_fields=["used_count"])
            logger.info(
                "Reservation emis instantly (CIB): id=%s order=%s user=%s promo=%s",
                reservation.id, ext_id, user.email, promo.code if promo else None,
            )

        # Send ticket email outside transaction (non-critical)
        send_ticket_email(reservation)
        return reservation

    # ── 3b. Cash — PENDING, agent will confirm later ──────────────────
    with transaction.atomic():
        reservation = Reservation.objects.create(
            user=user,
            offer_id=offer_id,
            status=Reservation.Status.PENDING,
            total_amount=reservation_amount,
            currency=currency,
            raw_duffel_order=offer,           # store the full Amadeus offer
            pending_booking_data={
                "flight_offer":      offer,
                "amadeus_travelers": travelers,
            },
        )
        Passenger.objects.bulk_create([
            _build_passenger_obj(reservation, p)
            for p in passengers_data
        ])
        if promo:
            promo.used_count += 1
            promo.save(update_fields=["used_count"])
        logger.info(
            "Reservation created (pending/cash): id=%s user=%s offer=%s promo=%s",
            reservation.id, user.email, offer_id, promo.code if promo else None,
        )
        return reservation


# ══════════════════════════════════════════════════════════════════════
#  CONFIRM RESERVATION  (agent action → calls Amadeus)
# ══════════════════════════════════════════════════════════════════════

def confirm_reservation(reservation: Reservation, agent) -> Reservation:
    """
    Agent confirmation:
      1. Read pending_booking_data (flight_offer + amadeus_travelers)
      2. Call Amadeus create_order (irreversible)
      3. Update DB → CONFIRMED
    """
    if reservation.status != Reservation.Status.PENDING:
        raise CancellationNotAllowedException("Only pending reservations can be confirmed.")

    data          = reservation.pending_booking_data or {}
    flight_offer  = data.get("flight_offer", {})
    travelers     = data.get("amadeus_travelers", [])

    if not flight_offer:
        raise CancellationNotAllowedException("Missing flight offer data — cannot confirm.")

    # Call Amadeus — outside atomic block (irreversible)
    amadeus_order     = amadeus.create_order(
        flight_offer=flight_offer,
        travelers=travelers,
        payment_method="CASH",
    )
    external_order_id = amadeus_order.get("id", "")
    booking_reference = _extract_booking_ref(amadeus_order)

    try:
        with transaction.atomic():
            reservation.external_order_id  = external_order_id
            reservation.status             = Reservation.Status.CONFIRMED
            reservation.booking_reference  = booking_reference
            reservation.raw_duffel_order   = amadeus_order
            reservation.pending_booking_data = None
            reservation.save(update_fields=[
                "external_order_id", "status", "booking_reference",
                "raw_duffel_order", "pending_booking_data", "updated_at",
            ])
            logger.info(
                "Reservation confirmed by agent: id=%s order=%s booking_ref=%s agent=%s",
                reservation.id, external_order_id, booking_reference, agent.email,
            )
            return reservation
    except Exception as db_error:
        logger.critical(
            "DB WRITE FAILED after Amadeus order! RECONCILE: "
            "external_order_id=%s reservation=%s error=%s",
            external_order_id, reservation.id, db_error, exc_info=True,
        )
        raise


# ══════════════════════════════════════════════════════════════════════
#  RETRIEVE RESERVATIONS
# ══════════════════════════════════════════════════════════════════════

def get_reservation(reservation_id, user) -> Reservation:
    try:
        qs = Reservation.objects.select_related("user").prefetch_related("passengers")
        if user.role == "client":
            qs = qs.filter(user=user)
        return qs.get(id=reservation_id)
    except Reservation.DoesNotExist:
        raise ReservationNotFoundException()


def list_reservations(user, filters: dict | None = None):
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
    Cancel via Amadeus DELETE /booking/flight-orders/{id} then mark local DB.
    """
    reservation = get_reservation(reservation_id, user)

    if reservation.status == Reservation.Status.CANCELLED:
        raise CancellationNotAllowedException("Reservation is already cancelled.")
    if reservation.status == Reservation.Status.FAILED:
        raise CancellationNotAllowedException("Failed reservations cannot be cancelled.")

    if reservation.external_order_id:
        result = amadeus.cancel_order(reservation.external_order_id)
        logger.info(
            "Amadeus cancellation confirmed: order_id=%s result=%s",
            reservation.external_order_id, result,
        )

    with transaction.atomic():
        reservation.status = Reservation.Status.CANCELLED
        reservation.save(update_fields=["status", "updated_at"])

    logger.info("Reservation cancelled: id=%s user=%s", reservation.id, user.email)
    return reservation


# ══════════════════════════════════════════════════════════════════════
#  PRIVATE HELPERS
# ══════════════════════════════════════════════════════════════════════

def _extract_booking_ref(amadeus_order: dict) -> str:
    """Extract PNR/booking reference from Amadeus order."""
    records = amadeus_order.get("associatedRecords", [])
    return records[0].get("reference", "") if records else ""


def _build_amadeus_travelers(passengers_data: list[dict]) -> list[dict]:
    """
    Convert validated passenger dicts (from PassengerInputSerializer) to
    Amadeus traveler format. Travelers are numbered 1…N sequentially —
    Amadeus assigns travelerPricings in the same order as the search passengers.
    """
    travelers = []
    for i, p in enumerate(passengers_data, start=1):
        gender = "MALE" if p.get("gender", "m").lower() in ("m", "male") else "FEMALE"

        traveler: dict = {
            "id":          str(i),
            "dateOfBirth": str(p.get("born_on", "")),
            "name": {
                "firstName": p.get("given_name", "").upper(),
                "lastName":  p.get("family_name", "").upper(),
            },
            "gender": gender,
            "contact": {
                "emailAddress": p.get("email", ""),
                "phones": [],
            },
        }

        phone        = p.get("phone_number", "")
        country_code = "213"                         # default Algeria
        if phone:
            # strip country prefix if present in the number
            phone = phone.lstrip("+").lstrip("0")
            traveler["contact"]["phones"].append({
                "deviceType":        "MOBILE",
                "countryCallingCode": country_code,
                "number":            phone,
            })

        # Passport
        docs      = p.get("identity_documents", [])
        first_doc = docs[0] if docs else {}
        passport  = first_doc.get("unique_identifier", "")
        if passport:
            traveler["documents"] = [{
                "documentType":    "PASSPORT",
                "number":          passport,
                "expiryDate":      str(first_doc.get("expires_on", "")),
                "issuanceCountry": first_doc.get("issuing_country_code", "DZ"),
                "nationality":     first_doc.get("issuing_country_code", "DZ"),
                "holder":          True,
            }]

        travelers.append(traveler)

    return travelers


def _normalize_passenger_type(pax_type: str) -> str:
    if "infant" in pax_type:
        return Passenger.Type.INFANT
    if "child" in pax_type:
        return Passenger.Type.CHILD
    return Passenger.Type.ADULT


def _build_passenger_obj(reservation: Reservation, p: dict) -> Passenger:
    """Build Passenger from validated serializer data (works for pending and confirmed)."""
    docs      = p.get("identity_documents", [])
    first_doc = docs[0] if docs else {}

    return Passenger(
        reservation=reservation,
        type=_normalize_passenger_type(p.get("type", Passenger.Type.ADULT)),
        title=p.get("title", "mr"),
        first_name=p.get("given_name", ""),
        last_name=p.get("family_name", ""),
        born_on=p.get("born_on"),
        email=p.get("email", ""),
        phone=p.get("phone_number", ""),
        id_document_type=first_doc.get("type", ""),
        id_document_number=first_doc.get("unique_identifier", ""),
        id_document_expiry=first_doc.get("expires_on"),
        nationality=first_doc.get("issuing_country_code", ""),
    )
