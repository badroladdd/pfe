from django.contrib import admin
from apps.reservations.models import FlightCache, Passenger, Payment, Reservation


class PassengerInline(admin.TabularInline):
    model = Passenger
    extra = 0
    readonly_fields = ["id", "base_amount", "tax_amount"]


@admin.register(Reservation)
class ReservationAdmin(admin.ModelAdmin):
    list_display = [
        "id", "user", "status", "external_order_id",
        "booking_reference", "total_amount", "currency", "created_at",
    ]
    list_filter = ["status", "currency", "created_at"]
    search_fields = ["external_order_id", "booking_reference", "user__email"]
    readonly_fields = ["id", "external_order_id", "raw_duffel_order", "created_at", "updated_at"]
    inlines = [PassengerInline]
    ordering = ["-created_at"]


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ["id", "reservation", "amount", "currency", "method", "status", "created_at"]
    list_filter = ["status", "method"]
    readonly_fields = ["id", "created_at"]


@admin.register(FlightCache)
class FlightCacheAdmin(admin.ModelAdmin):
    list_display = ["offer_id", "origin", "destination", "departure_date", "expires_at"]
    list_filter = ["origin", "destination"]
