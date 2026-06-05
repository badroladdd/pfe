from datetime import date

from rest_framework import serializers

from apps.reservations.models import Passenger, Reservation, PromoCode


# ─────────────────────────────────────────────
#  Input serializers (validation only)
# ─────────────────────────────────────────────

class IdentityDocumentSerializer(serializers.Serializer):
    type = serializers.ChoiceField(
        choices=["passport", "national_identity_card"]
    )
    unique_identifier = serializers.CharField(max_length=50)
    expires_on = serializers.DateField()
    issuing_country_code = serializers.CharField(min_length=2, max_length=2)

    def validate_expires_on(self, value):
        if value <= date.today():
            raise serializers.ValidationError(
                "Identity document must not be expired."
            )
        return value


class PassengerInputSerializer(serializers.Serializer):
    id = serializers.CharField(max_length=100, required=False, allow_blank=True, default="")
    type = serializers.ChoiceField(
        choices=["adult", "child", "infant", "infant_without_seat", "infant_with_seat"],
        default="adult"
    )
    title = serializers.ChoiceField(choices=["mr", "mrs", "ms", "dr"])
    gender = serializers.ChoiceField(choices=["m", "f"], required=False, default="m")
    given_name = serializers.CharField(max_length=100)
    family_name = serializers.CharField(max_length=100)
    born_on = serializers.DateField()
    email = serializers.EmailField()
    phone_number = serializers.CharField(
        max_length=20, required=False, allow_blank=True, default=""
    )
    identity_documents = IdentityDocumentSerializer(
        many=True, required=False, default=list
    )

    def validate_born_on(self, value):
        if value >= date.today():
            raise serializers.ValidationError(
                "Date of birth must be in the past."
            )
        return value


class PaymentInputSerializer(serializers.Serializer):
    """
    Duffel payment object.
    Use type=balance for test/sandbox (charges your Duffel balance).
    Use type=arc_bsp_cash for production airline payments.
    """

    type = serializers.ChoiceField(choices=["balance", "arc_bsp_cash"])
    amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    currency = serializers.CharField(min_length=3, max_length=3)


class CreateReservationSerializer(serializers.Serializer):
    offer_id = serializers.CharField(max_length=255)
    passengers = PassengerInputSerializer(many=True)
    payment = PaymentInputSerializer()

    def validate_passengers(self, value):
        if not value:
            raise serializers.ValidationError(
                "At least one passenger is required."
            )
        adult_count = sum(1 for p in value if p.get("type") == "adult")
        infant_count = sum(1 for p in value if p.get("type") == "infant")
        if adult_count == 0:
            raise serializers.ValidationError(
                "At least one adult passenger is required."
            )
        if infant_count > adult_count:
            raise serializers.ValidationError(
                "Each infant must be accompanied by an adult."
            )
        return value


class FlightSearchSerializer(serializers.Serializer):
    origin = serializers.CharField(min_length=3, max_length=3)
    destination = serializers.CharField(min_length=3, max_length=3)
    departure_date = serializers.DateField()
    cabin_class = serializers.ChoiceField(
        choices=["economy", "premium_economy", "business", "first"],
        default="economy",
    )
    passengers = PassengerInputSerializer(many=True)

    def validate_departure_date(self, value):
        if value < date.today():
            raise serializers.ValidationError(
                "Departure date cannot be in the past."
            )
        return value

    def validate(self, data):
        if data["origin"].upper() == data["destination"].upper():
            raise serializers.ValidationError(
                "Origin and destination cannot be the same airport."
            )
        if not data.get("passengers"):
            raise serializers.ValidationError(
                "At least one passenger is required."
            )
        return data


# ─────────────────────────────────────────────
#  Output serializers (read-only)
# ─────────────────────────────────────────────

class PassengerOutputSerializer(serializers.ModelSerializer):
    class Meta:
        model = Passenger
        fields = [
            "id",
            "type",
            "title",
            "first_name",
            "last_name",
            "born_on",
            "email",
            "phone",
            "nationality",
            "base_amount",
            "tax_amount",
        ]


class ReservationOutputSerializer(serializers.ModelSerializer):
    passengers       = PassengerOutputSerializer(many=True, read_only=True)
    user_email       = serializers.EmailField(source="user.email", read_only=True)
    user_full_name   = serializers.CharField(source="user.full_name", read_only=True)
    user_phone       = serializers.CharField(source="user.phone", read_only=True)
    origin_iata      = serializers.SerializerMethodField()
    destination_iata = serializers.SerializerMethodField()
    departure_at     = serializers.SerializerMethodField()
    arrival_at       = serializers.SerializerMethodField()
    carrier_name     = serializers.SerializerMethodField()
    flight_number    = serializers.SerializerMethodField()
    livreur_id       = serializers.SerializerMethodField()
    livreur_name     = serializers.SerializerMethodField()

    def _itinerary_segments(self, obj):
        """
        Extract the first itinerary's segment list from whatever is stored
        in raw_duffel_order, handling two Amadeus shapes:
          - Pending (offer):    {"itineraries": [...], ...}
          - Confirmed (order):  {"flightOffers": [{"itineraries": [...]}], ...}
        """
        raw = obj.raw_duffel_order or {}
        # Shape 1: direct offer
        itineraries = raw.get("itineraries")
        if not itineraries:
            # Shape 2: Amadeus order wraps offers
            offers = raw.get("flightOffers") or []
            if offers:
                itineraries = offers[0].get("itineraries") or []
        if not itineraries:
            return []
        return itineraries[0].get("segments") or []

    def get_origin_iata(self, obj):
        segs = self._itinerary_segments(obj)
        if not segs:
            return ""
        return (segs[0].get("departure") or {}).get("iataCode", "")

    def get_destination_iata(self, obj):
        segs = self._itinerary_segments(obj)
        if not segs:
            return ""
        return (segs[-1].get("arrival") or {}).get("iataCode", "")

    def get_departure_at(self, obj):
        segs = self._itinerary_segments(obj)
        if not segs:
            return ""
        return (segs[0].get("departure") or {}).get("at", "")

    def get_arrival_at(self, obj):
        segs = self._itinerary_segments(obj)
        if not segs:
            return ""
        return (segs[-1].get("arrival") or {}).get("at", "")

    def get_carrier_name(self, obj):
        segs = self._itinerary_segments(obj)
        if not segs:
            return ""
        seg = segs[0]
        # Amadeus segment uses carrierCode; resolve name from dictionaries if available
        raw    = obj.raw_duffel_order or {}
        offers = raw.get("flightOffers") or []
        dicts  = raw.get("dictionaries") or (offers[0].get("dictionaries") if offers else None) or {}
        carriers = dicts.get("carriers", {})
        code = seg.get("carrierCode", "")
        return carriers.get(code, code)

    def get_flight_number(self, obj):
        segs = self._itinerary_segments(obj)
        if not segs:
            return ""
        seg = segs[0]
        carrier_code = seg.get("carrierCode", "")
        number = seg.get("number", "")
        return f"{carrier_code} {number}".strip() if carrier_code or number else ""

    def get_livreur_id(self, obj):
        return str(obj.livreur_id) if obj.livreur_id else None

    def get_livreur_name(self, obj):
        if obj.livreur is None:
            return None
        return obj.livreur.user.full_name

    class Meta:
        model = Reservation
        fields = [
            "id", "user_email", "user_full_name", "user_phone",
            "offer_id", "external_order_id", "booking_reference",
            "status", "total_amount", "currency",
            "origin_iata", "destination_iata", "departure_at", "arrival_at",
            "carrier_name", "flight_number", "livreur_id", "livreur_name",
            "passengers", "created_at", "updated_at",
        ]


# ─────────────────────────────────────────────
#  PromoCode serializers
# ─────────────────────────────────────────────

class PromoCodeInputSerializer(serializers.Serializer):
    code           = serializers.CharField(max_length=20)
    discount_type  = serializers.ChoiceField(choices=["percent", "fixed"])
    discount_value = serializers.DecimalField(max_digits=8, decimal_places=2)
    max_uses       = serializers.IntegerField(min_value=1, default=1)
    expires_at     = serializers.DateTimeField()


class PromoCodeOutputSerializer(serializers.ModelSerializer):
    is_valid = serializers.BooleanField(read_only=True)

    class Meta:
        model = PromoCode
        fields = [
            "id", "code", "discount_type", "discount_value",
            "max_uses", "used_count", "expires_at", "is_active",
            "is_valid", "created_at",
        ]


class ValidatePromoSerializer(serializers.Serializer):
    code   = serializers.CharField(max_length=20)
    amount = serializers.DecimalField(max_digits=12, decimal_places=2)
