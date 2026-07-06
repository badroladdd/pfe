from django.urls import path
from . import views

urlpatterns = [
    path("flights/search/",        views.FlightSearchView.as_view(),    name="flight-search"),
    path("flights/confirm-price/", views.ConfirmPriceView.as_view(),    name="flight-confirm-price"),
    path("airports/",              views.AirportSearchView.as_view(),   name="airport-search"),
    path("recommendations/",       views.RecommendationsView.as_view(), name="recommendations"),
    path("flights/calendar/",           views.FlightCalendarView.as_view(),  name="flight-calendar"),
    path("airlines/logo/<str:code>/",   views.AirlineLogoView.as_view(),     name="airline-logo"),
]
