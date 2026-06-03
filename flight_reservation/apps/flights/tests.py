"""
Unit tests for the flight search service.

Run with: python manage.py test apps.flights.tests
"""
from unittest.mock import patch

from django.test import TestCase

from apps.flights import services


class SearchFlightsTest(TestCase):
    @patch("apps.flights.services.duffel")
    def test_search_flights_filters_non_stop_offers(self, mock_duffel):
        mock_duffel.search_offers.return_value = {
            "offers": [
                {
                    "id": "off_direct",
                    "slices": [
                        {"segments": [{"id": "seg1"}]},
                    ],
                },
                {
                    "id": "off_connecting",
                    "slices": [
                        {"segments": [{"id": "seg1"}, {"id": "seg2"}]},
                    ],
                },
            ]
        }

        result = services.search_flights(
            origin="ALG",
            destination="CDG",
            departure_date="2026-10-01",
            passengers=[{"type": "adult"}],
            non_stop=True,
        )

        self.assertEqual(len(result["offers"]), 1)
        self.assertEqual(result["offers"][0]["id"], "off_direct")

    @patch("apps.flights.services.duffel")
    def test_search_flights_returns_all_offers_when_non_stop_disabled(self, mock_duffel):
        mock_duffel.search_offers.return_value = {
            "offers": [
                {
                    "id": "off_direct",
                    "slices": [
                        {"segments": [{"id": "seg1"}]},
                    ],
                },
                {
                    "id": "off_connecting",
                    "slices": [
                        {"segments": [{"id": "seg1"}, {"id": "seg2"}]},
                    ],
                },
            ]
        }

        result = services.search_flights(
            origin="ALG",
            destination="CDG",
            departure_date="2026-10-01",
            passengers=[{"type": "adult"}],
            non_stop=False,
        )

        self.assertEqual(len(result["offers"]), 2)

    @patch("apps.flights.services.duffel")
    def test_search_flights_filters_offers_with_baggage(self, mock_duffel):
        mock_duffel.search_offers.return_value = {
            "offers": [
                {
                    "id": "off_with_baggage",
                    "slices": [
                        {
                            "segments": [
                                {
                                    "id": "seg1",
                                    "passengers": [
                                        {"baggages": [{"type": "hold", "quantity": 1}]}
                                    ]
                                }
                            ]
                        }
                    ],
                },
                {
                    "id": "off_without_baggage",
                    "slices": [
                        {
                            "segments": [
                                {
                                    "id": "seg1",
                                    "passengers": [{"baggages": []}]
                                }
                            ]
                        }
                    ],
                },
            ]
        }

        result = services.search_flights(
            origin="ALG",
            destination="CDG",
            departure_date="2026-10-01",
            passengers=[{"type": "adult"}],
            has_baggage=True,
        )

        self.assertEqual(len(result["offers"]), 1)
        self.assertEqual(result["offers"][0]["id"], "off_with_baggage")

    @patch("apps.flights.services.duffel")
    def test_search_flights_filters_refundable_offers(self, mock_duffel):
        mock_duffel.search_offers.return_value = {
            "offers": [
                {
                    "id": "off_refundable",
                    "conditions": {"refundable": True},
                    "slices": [{"segments": [{"id": "seg1"}]}],
                },
                {
                    "id": "off_non_refundable",
                    "conditions": {"refundable": False},
                    "slices": [{"segments": [{"id": "seg1"}]}],
                },
            ]
        }

        result = services.search_flights(
            origin="ALG",
            destination="CDG",
            departure_date="2026-10-01",
            passengers=[{"type": "adult"}],
            is_refundable=True,
        )

        self.assertEqual(len(result["offers"]), 1)
        self.assertEqual(result["offers"][0]["id"], "off_refundable")
