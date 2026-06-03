from django.urls import path, include
from rest_framework.routers import DefaultRouter
from apps.deliveries.views import (
    RegisterWithEmailVerificationView,
    ResendVerificationView,
    VerifyEmailView,
    SectorViewSet,
    LivreurCreateView,
    LivreurListView,
    LivreurUpdateLocationView,
    ColisListView,
    ColisCreateView,
    ColisAssignView,
    ColisDetailView,
)

router = DefaultRouter()
router.register(r"sectors", SectorViewSet, basename="sector")

urlpatterns = [
    # Email verification
    path("auth/register-with-verification/", RegisterWithEmailVerificationView.as_view(), name="register_with_verification"),
    path("auth/verify-email/",              VerifyEmailView.as_view(),              name="verify_email"),
    path("auth/resend-verification/",       ResendVerificationView.as_view(),       name="resend_verification"),

    # Sectors
    path("", include(router.urls)),

    # Livreurs (Delivery Persons)
    path("livreurs/", LivreurListView.as_view(), name="livreur_list"),
    path("livreurs/create/", LivreurCreateView.as_view(), name="livreur_create"),
    path("livreurs/update-location/", LivreurUpdateLocationView.as_view(), name="livreur_update_location"),

    # Colis (Packages)
    path("colis/", ColisListView.as_view(), name="colis_list"),
    path("colis/create/", ColisCreateView.as_view(), name="colis_create"),
    path("colis/assign/", ColisAssignView.as_view(), name="colis_assign"),
    path("colis/<uuid:colis_id>/", ColisDetailView.as_view(), name="colis_detail"),
]
