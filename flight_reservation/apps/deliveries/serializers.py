from rest_framework import serializers
from apps.deliveries.models import Sector, Livreur, Colis, EmailVerificationToken
from apps.users.models import User
from apps.users.serializers import UserSerializer


class SectorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Sector
        fields = [
            "id", "name", "code", "description", "latitude", "longitude",
            "radius_km", "is_active", "created_at",
        ]
        read_only_fields = ["id", "created_at"]


class LivreurSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    sector_name = serializers.CharField(source="sector.name", read_only=True)

    class Meta:
        model = Livreur
        fields = [
            "id", "user", "sector", "sector_name", "status", "vehicle_type",
            "vehicle_plate", "max_packages_per_day", "current_packages_count",
            "latitude", "longitude", "created_at",
        ]
        read_only_fields = ["id", "user", "current_packages_count", "created_at"]


class ColisSerializer(serializers.ModelSerializer):
    livreur_name = serializers.SerializerMethodField()
    sector_name = serializers.CharField(source="sector.name", read_only=True)

    def get_livreur_name(self, obj):
        if obj.livreur is None:
            return None
        return obj.livreur.user.full_name

    class Meta:
        model = Colis
        fields = [
            "id", "tracking_number", "sector", "sector_name", "livreur", "livreur_name",
            "recipient_name", "recipient_phone", "recipient_email", "delivery_address",
            "latitude", "longitude", "weight_kg", "dimensions", "contents", "priority",
            "status", "assigned_at", "delivered_at", "delivery_note", "created_at",
        ]
        read_only_fields = [
            "id", "tracking_number", "assigned_at", "delivered_at", "created_at",
        ]


class LivreurCreateSerializer(serializers.Serializer):
    """Serializer to create a Livreur (admin only)."""
    email = serializers.EmailField()
    first_name = serializers.CharField(max_length=100)
    last_name = serializers.CharField(max_length=100)
    phone = serializers.CharField(max_length=20)
    password = serializers.CharField(write_only=True, min_length=8)
    sector_id = serializers.UUIDField()
    vehicle_type = serializers.ChoiceField(
        choices=["motorcycle", "car", "van", "truck"],
        default="motorcycle"
    )
    vehicle_plate = serializers.CharField(max_length=50, required=False, allow_blank=True)
    max_packages_per_day = serializers.IntegerField(default=50, min_value=1)

    def validate_sector_id(self, value):
        """Ensure sector exists."""
        if not Sector.objects.filter(id=value).exists():
            raise serializers.ValidationError("Sector not found.")
        return value

    def validate_email(self, value):
        """Ensure email is unique."""
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return value

    def create(self, validated_data):
        """Create user and livreur."""
        sector_id = validated_data.pop("sector_id")
        vehicle_type = validated_data.pop("vehicle_type", "motorcycle")
        vehicle_plate = validated_data.pop("vehicle_plate", "")
        max_packages = validated_data.pop("max_packages_per_day", 50)
        
        # Create user with LIVREUR role
        user = User.objects.create_user(
            email=validated_data["email"],
            first_name=validated_data["first_name"],
            last_name=validated_data["last_name"],
            phone=validated_data["phone"],
            password=validated_data["password"],
        )
        user.role = "livreur"
        user.save(update_fields=["role"])
        
        # Create livreur profile
        sector = Sector.objects.get(id=sector_id)
        livreur = Livreur.objects.create(
            user=user,
            sector=sector,
            vehicle_type=vehicle_type,
            vehicle_plate=vehicle_plate,
            max_packages_per_day=max_packages,
        )
        return livreur


class ColisAssignSerializer(serializers.Serializer):
    """Serializer for admin to manually assign or override package assignment."""
    colis_id = serializers.UUIDField()
    livreur_id = serializers.UUIDField(required=False, allow_null=True)
    
    def validate_colis_id(self, value):
        """Ensure colis exists."""
        if not Colis.objects.filter(id=value).exists():
            raise serializers.ValidationError("Colis not found.")
        return value

    def validate_livreur_id(self, value):
        """Ensure livreur exists if provided."""
        if value and not Livreur.objects.filter(id=value).exists():
            raise serializers.ValidationError("Livreur not found.")
        return value

    def validate(self, data):
        """Validate the assignment. Admin can assign to any livreur regardless of sector."""
        livreur_id = data.get("livreur_id")
        if livreur_id:
            livreur = Livreur.objects.get(id=livreur_id)
            if livreur.status != Livreur.Status.ACTIVE:
                raise serializers.ValidationError(
                    "Livreur is not active and cannot accept packages."
                )
        return data
