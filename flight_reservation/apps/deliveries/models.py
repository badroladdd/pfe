import uuid
import secrets
from django.conf import settings
from django.db import models
from django.utils import timezone
from datetime import timedelta


class Sector(models.Model):
    """Geographic sector for delivery organization."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100, unique=True)
    code = models.CharField(max_length=20, unique=True)
    description = models.TextField(blank=True)
    latitude = models.FloatField()
    longitude = models.FloatField()
    radius_km = models.FloatField(default=5.0)  # Sector coverage radius
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "sectors"
        indexes = [
            models.Index(fields=["code"]),
            models.Index(fields=["is_active"]),
        ]

    def __str__(self):
        return f"{self.name} ({self.code})"


class Livreur(models.Model):
    """Delivery Person - can only be created by admin."""
    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        INACTIVE = "inactive", "Inactive"
        ON_LEAVE = "on_leave", "On Leave"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="livreur_profile",
    )
    sector = models.ForeignKey(
        Sector,
        on_delete=models.PROTECT,
        related_name="livreurs",
    )
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.ACTIVE,
    )
    vehicle_type = models.CharField(
        max_length=50,
        choices=[
            ("motorcycle", "Motorcycle"),
            ("car", "Car"),
            ("van", "Van"),
            ("truck", "Truck"),
        ],
        default="motorcycle",
    )
    vehicle_plate = models.CharField(max_length=50, blank=True)
    max_packages_per_day = models.IntegerField(default=50)
    current_packages_count = models.IntegerField(default=0)
    latitude = models.FloatField(null=True, blank=True)  # Current location
    longitude = models.FloatField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "livreurs"
        indexes = [
            models.Index(fields=["sector", "status"]),
            models.Index(fields=["user"]),
        ]

    def __str__(self):
        return f"{self.user.full_name} - {self.sector.name}"

    def can_accept_package(self):
        """Check if livreur can accept more packages today."""
        return (
            self.status == self.Status.ACTIVE
            and self.current_packages_count < self.max_packages_per_day
        )


class Colis(models.Model):
    """Package to be delivered."""
    class Status(models.TextChoices):
        PENDING = "pending", "Pending Assignment"
        ASSIGNED = "assigned", "Assigned to Livreur"
        IN_TRANSIT = "in_transit", "In Transit"
        DELIVERED = "delivered", "Delivered"
        FAILED = "failed", "Delivery Failed"
        CANCELLED = "cancelled", "Cancelled"

    class Priority(models.TextChoices):
        NORMAL = "normal", "Normal"
        EXPRESS = "express", "Express"
        URGENT = "urgent", "Urgent"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tracking_number = models.CharField(max_length=50, unique=True, db_index=True)
    sector = models.ForeignKey(
        Sector,
        on_delete=models.PROTECT,
        related_name="colis_list",
    )
    livreur = models.ForeignKey(
        Livreur,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="packages",
    )
    recipient_name = models.CharField(max_length=150)
    recipient_phone = models.CharField(max_length=20)
    recipient_email = models.EmailField(blank=True)
    delivery_address = models.CharField(max_length=500)
    latitude = models.FloatField()
    longitude = models.FloatField()
    weight_kg = models.FloatField()
    dimensions = models.CharField(max_length=100, blank=True)  # e.g., "10x10x10"
    contents = models.TextField()
    priority = models.CharField(
        max_length=20,
        choices=Priority.choices,
        default=Priority.NORMAL,
    )
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
        db_index=True,
    )
    assigned_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    delivery_note = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "colis"
        indexes = [
            models.Index(fields=["tracking_number"]),
            models.Index(fields=["status", "sector"]),
            models.Index(fields=["livreur", "status"]),
            models.Index(fields=["created_at"]),
        ]

    def __str__(self):
        return f"Colis {self.tracking_number} - {self.recipient_name}"

    def assign_to_livreur(self, livreur):
        """Assign package to a livreur (called by automatic or manual assignment)."""
        self.livreur = livreur
        self.status = self.Status.ASSIGNED
        self.assigned_at = timezone.now()
        self.save(update_fields=["livreur", "status", "assigned_at"])
        # Increment livreur's package count
        livreur.current_packages_count += 1
        livreur.save(update_fields=["current_packages_count"])

    def unassign_from_livreur(self):
        """Unassign package from current livreur."""
        if self.livreur:
            self.livreur.current_packages_count -= 1
            self.livreur.save(update_fields=["current_packages_count"])
        self.livreur = None
        self.status = self.Status.PENDING
        self.assigned_at = None
        self.save(update_fields=["livreur", "status", "assigned_at"])


class EmailVerificationToken(models.Model):
    """Token for email verification after registration."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="email_verification_token",
    )
    token = models.CharField(max_length=255, unique=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_verified = models.BooleanField(default=False)

    class Meta:
        db_table = "email_verification_tokens"

    def __str__(self):
        return f"Token for {self.user.email}"

    def is_valid(self):
        """Check if token is still valid and not expired."""
        return not self.is_verified and timezone.now() < self.expires_at

    @classmethod
    def create_token(cls, user, expiry_minutes=10):
        """Create a 6-digit verification code for a user."""
        cls.objects.filter(user=user).delete()
        code = f"{secrets.randbelow(1_000_000):06d}"
        expires_at = timezone.now() + timedelta(minutes=expiry_minutes)
        return cls.objects.create(
            user=user,
            token=code,
            expires_at=expires_at,
        )
