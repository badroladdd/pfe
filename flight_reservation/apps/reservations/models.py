import uuid

from django.conf import settings
from django.db import models


class Reservation(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        CONFIRMED = "confirmed", "Confirmed"
        CANCELLED = "cancelled", "Cancelled"
        FAILED = "failed", "Failed"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="reservations",
    )
    # offer_id: Duffel offer selected by the user BEFORE booking
    offer_id = models.CharField(max_length=255, db_index=True)
    # external_order_id: returned by Duffel AFTER booking — NEVER generated locally
    external_order_id = models.CharField(
        max_length=255, unique=True, null=True, blank=True, db_index=True
    )
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PENDING, db_index=True
    )
    total_amount = models.DecimalField(max_digits=12, decimal_places=2)
    currency = models.CharField(max_length=3, default="USD")
    # booking_reference: airline PNR, returned by Duffel inside the order object
    booking_reference = models.CharField(max_length=50, blank=True)
    # Full Duffel order snapshot — invaluable for debugging and audit
    raw_duffel_order = models.JSONField(null=True, blank=True)
    # Duffel-ready booking data stored when client books — used by agent to confirm
    pending_booking_data = models.JSONField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "reservations"
        constraints = [
            # Prevent the same user from booking the same offer twice
            # while the reservation is still active (pending or confirmed).
            models.UniqueConstraint(
                fields=["user", "offer_id"],
                condition=models.Q(status__in=["pending", "confirmed"]),
                name="unique_active_user_offer",
            )
        ]
        indexes = [
            models.Index(fields=["user", "status"]),
            models.Index(fields=["external_order_id"]),
            models.Index(fields=["created_at"]),
        ]

    def __str__(self):
        return (
            f"Reservation {self.id} "
            f"[{self.status}] order={self.external_order_id}"
        )


class Passenger(models.Model):
    class Type(models.TextChoices):
        ADULT = "adult", "Adult"
        CHILD = "child", "Child"
        INFANT = "infant", "Infant"

    class Title(models.TextChoices):
        MR = "mr", "Mr"
        MRS = "mrs", "Mrs"
        MS = "ms", "Ms"
        DR = "dr", "Dr"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reservation = models.ForeignKey(
        Reservation, on_delete=models.CASCADE, related_name="passengers"
    )
    type = models.CharField(max_length=10, choices=Type.choices, default=Type.ADULT)
    title = models.CharField(max_length=5, choices=Title.choices)
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    born_on = models.DateField()
    email = models.EmailField()
    phone = models.CharField(max_length=20, blank=True)
    # Travel document
    id_document_type = models.CharField(max_length=30, blank=True)
    id_document_number = models.CharField(max_length=50, blank=True)
    id_document_expiry = models.DateField(null=True, blank=True)
    nationality = models.CharField(max_length=2, blank=True)  # ISO 3166-1 alpha-2
    # Price breakdown per passenger (populated from Duffel response)
    base_amount = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    tax_amount = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)

    class Meta:
        db_table = "passengers"
        indexes = [models.Index(fields=["reservation"])]

    def __str__(self):
        return f"{self.title} {self.first_name} {self.last_name} ({self.type})"


class FlightCache(models.Model):
    """
    Optional short-lived cache for Duffel offer search results.
    Reduces API calls for repeated searches within the TTL window.
    TTL should be short (≤15 min) — offers expire quickly.
    """

    offer_id = models.CharField(max_length=255, primary_key=True)
    origin = models.CharField(max_length=3)
    destination = models.CharField(max_length=3)
    departure_date = models.DateField()
    raw_offer = models.JSONField()
    expires_at = models.DateTimeField(db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "flight_cache"
        indexes = [
            models.Index(fields=["origin", "destination", "departure_date"]),
            models.Index(fields=["expires_at"]),
        ]

    def __str__(self):
        return f"FlightCache {self.offer_id} ({self.origin}→{self.destination})"


class Payment(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        COMPLETED = "completed", "Completed"
        FAILED = "failed", "Failed"
        REFUNDED = "refunded", "Refunded"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reservation = models.OneToOneField(
        Reservation, on_delete=models.PROTECT, related_name="payment"
    )
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    currency = models.CharField(max_length=3)
    method = models.CharField(max_length=30)  # balance, arc_bsp_cash, etc.
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PENDING
    )
    duffel_payment_id = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "payments"

    def __str__(self):
        return f"Payment {self.id} [{self.status}] {self.amount} {self.currency}"
