from django.urls import path
from . import views

urlpatterns = [
    path(
        "reservations/",
        views.ReservationListCreateView.as_view(),
        name="reservation-list-create",
    ),
    path(
        "reservations/<uuid:pk>/",
        views.ReservationDetailView.as_view(),
        name="reservation-detail",
    ),
    path(
        "webhooks/duffel/",
        views.DuffelWebhookView.as_view(),
        name="duffel-webhook",
    ),
]
