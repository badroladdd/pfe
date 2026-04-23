from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from apps.users.views import AdminCreateUserView, AdminUserDetailView, AdminUsersView, ChangePasswordView, MeView, RegisterView
from apps.reservations.views import (
    AdminPromoCodeDetailView, AdminPromoCodesView,
    AdminReservationsView, AdminStatsView,
    AgentReservationActionView, AgentReservationsView,
    ValidatePromoCodeView,
)

urlpatterns = [
    path("admin/", admin.site.urls),

    # Auth
    path("api/v1/auth/login/",           TokenObtainPairView.as_view(),   name="token_login"),
    path("api/v1/auth/refresh/",         TokenRefreshView.as_view(),      name="token_refresh"),
    path("api/v1/auth/register/",        RegisterView.as_view(),          name="user_register"),
    path("api/v1/auth/me/",              MeView.as_view(),                name="user_me"),
    path("api/v1/auth/change-password/", ChangePasswordView.as_view(),    name="change_password"),

    # Admin API
    path("api/v1/admin/stats/",              AdminStatsView.as_view(),        name="admin_stats"),
    path("api/v1/admin/users/",              AdminUsersView.as_view(),        name="admin_users"),
    path("api/v1/admin/users/create/",       AdminCreateUserView.as_view(),   name="admin_create_user"),
    path("api/v1/admin/users/<str:user_id>/",AdminUserDetailView.as_view(),   name="admin_user_detail"),
    path("api/v1/admin/reservations/",            AdminReservationsView.as_view(),       name="admin_reservations"),
    path("api/v1/admin/promo-codes/",             AdminPromoCodesView.as_view(),         name="admin_promo_codes"),
    path("api/v1/admin/promo-codes/<int:pk>/",    AdminPromoCodeDetailView.as_view(),    name="admin_promo_code_detail"),
    path("api/v1/agent/reservations/",            AgentReservationsView.as_view(),       name="agent_reservations"),
    path("api/v1/agent/reservations/<uuid:pk>/",  AgentReservationActionView.as_view(),  name="agent_reservation_action"),
    path("api/v1/promo-codes/validate/",          ValidatePromoCodeView.as_view(),       name="validate_promo_code"),

    # Feature routes
    path("api/v1/", include("apps.flights.urls")),
    path("api/v1/", include("apps.reservations.urls")),
]
