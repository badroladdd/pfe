from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from apps.users.views import AdminUsersView, ChangePasswordView, MeView, RegisterView
from apps.reservations.views import AdminStatsView

urlpatterns = [
    path("admin/", admin.site.urls),

    # Auth
    path("api/v1/auth/login/",           TokenObtainPairView.as_view(), name="token_login"),
    path("api/v1/auth/refresh/",         TokenRefreshView.as_view(),    name="token_refresh"),
    path("api/v1/auth/register/",        RegisterView.as_view(),        name="user_register"),
    path("api/v1/auth/me/",              MeView.as_view(),              name="user_me"),
    path("api/v1/auth/change-password/", ChangePasswordView.as_view(),  name="change_password"),

    # Admin API
    path("api/v1/admin/stats/",          AdminStatsView.as_view(),      name="admin_stats"),
    path("api/v1/admin/users/",          AdminUsersView.as_view(),      name="admin_users"),

    # Feature routes
    path("api/v1/", include("apps.flights.urls")),
    path("api/v1/", include("apps.reservations.urls")),
]
