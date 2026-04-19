from django.urls import path
from . import views

urlpatterns = [
    path("users/register/", views.RegisterView.as_view(), name="user-register"),
    path("users/me/", views.MeView.as_view(), name="user-me"),
]
