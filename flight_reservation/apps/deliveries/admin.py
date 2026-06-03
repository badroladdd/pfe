from django.contrib import admin
from apps.deliveries.models import Sector, Livreur, Colis, EmailVerificationToken


@admin.register(Sector)
class SectorAdmin(admin.ModelAdmin):
    list_display = ("name", "code", "radius_km", "is_active", "created_at")
    list_filter = ("is_active", "created_at")
    search_fields = ("name", "code")
    readonly_fields = ("id", "created_at", "updated_at")
    fieldsets = (
        ("Basic Information", {
            "fields": ("id", "name", "code", "description")
        }),
        ("Location", {
            "fields": ("latitude", "longitude", "radius_km")
        }),
        ("Status", {
            "fields": ("is_active",)
        }),
        ("Timestamps", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )


@admin.register(Livreur)
class LivreurAdmin(admin.ModelAdmin):
    list_display = ("get_full_name", "sector", "status", "vehicle_type", "current_packages_count", "max_packages_per_day")
    list_filter = ("status", "sector", "vehicle_type", "created_at")
    search_fields = ("user__email", "user__first_name", "user__last_name")
    readonly_fields = ("id", "current_packages_count", "created_at", "updated_at")
    fieldsets = (
        ("User Information", {
            "fields": ("id", "user",)
        }),
        ("Sector & Status", {
            "fields": ("sector", "status")
        }),
        ("Vehicle Information", {
            "fields": ("vehicle_type", "vehicle_plate")
        }),
        ("Capacity", {
            "fields": ("max_packages_per_day", "current_packages_count")
        }),
        ("Location", {
            "fields": ("latitude", "longitude")
        }),
        ("Timestamps", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )

    def get_full_name(self, obj):
        return obj.user.full_name
    get_full_name.short_description = "Livreur"


@admin.register(Colis)
class ColisAdmin(admin.ModelAdmin):
    list_display = ("tracking_number", "recipient_name", "sector", "livreur", "status", "priority", "created_at")
    list_filter = ("status", "priority", "sector", "created_at")
    search_fields = ("tracking_number", "recipient_name", "recipient_phone")
    readonly_fields = ("id", "tracking_number", "assigned_at", "delivered_at", "created_at", "updated_at")
    fieldsets = (
        ("Package Information", {
            "fields": ("id", "tracking_number", "priority", "status")
        }),
        ("Recipient Information", {
            "fields": ("recipient_name", "recipient_phone", "recipient_email", "delivery_address")
        }),
        ("Location", {
            "fields": ("latitude", "longitude", "sector")
        }),
        ("Physical Details", {
            "fields": ("weight_kg", "dimensions", "contents")
        }),
        ("Assignment", {
            "fields": ("livreur", "assigned_at")
        }),
        ("Delivery", {
            "fields": ("delivered_at", "delivery_note")
        }),
        ("Timestamps", {
            "fields": ("created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )

    def get_readonly_fields(self, request, obj=None):
        if obj:  # Editing an existing object
            return self.readonly_fields + ("tracking_number", "sector")
        return self.readonly_fields


@admin.register(EmailVerificationToken)
class EmailVerificationTokenAdmin(admin.ModelAdmin):
    list_display = ("user", "is_verified", "created_at", "expires_at")
    list_filter = ("is_verified", "created_at")
    search_fields = ("user__email",)
    readonly_fields = ("id", "token", "created_at")
    fieldsets = (
        ("User", {
            "fields": ("id", "user")
        }),
        ("Token", {
            "fields": ("token",)
        }),
        ("Verification", {
            "fields": ("is_verified", "expires_at")
        }),
        ("Timestamps", {
            "fields": ("created_at",),
            "classes": ("collapse",)
        }),
    )
