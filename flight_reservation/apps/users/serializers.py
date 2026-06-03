from rest_framework import serializers
from apps.users.models import User


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    password2 = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = [
            "email", "first_name", "last_name",
            "phone", "password", "password2",
        ]

    def validate(self, data):
        if data["password"] != data.pop("password2"):
            raise serializers.ValidationError({"password2": "Passwords do not match."})
        return data

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)


class UserSerializer(serializers.ModelSerializer):
    has_livreur_profile = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id", "email", "first_name", "last_name",
            "phone", "role", "has_livreur_profile", "created_at",
        ]
        read_only_fields = ["id", "role", "created_at"]

    def get_has_livreur_profile(self, obj):
        return hasattr(obj, "livreur_profile")
