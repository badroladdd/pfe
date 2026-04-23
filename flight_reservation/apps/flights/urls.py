from django.urls import path
from . import views

urlpatterns = [
    path("flights/search/",        views.FlightSearchView.as_view(),   name="flight-search"),
    path("flights/confirm-price/", views.ConfirmPriceView.as_view(),   name="flight-confirm-price"),
    path("airports/",              views.AirportSearchView.as_view(),  name="airport-search"),
]
