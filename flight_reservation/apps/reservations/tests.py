"""
Unit tests for the reservation service layer.

Run with:  python manage.py test apps.reservations.tests
"""
from datetime import date
from decimal import Decimal
from unittest.mock import MagicMock, patch

from django.test import TestCase

from apps.users.models import User
from apps.reservations.models import Passenger, Reservation
from apps.reservations import services
from core.exceptions import (
    CancellationNotAllowedException,
    DuplicateBookingException,
    ReservationNotFoundException,
)


# ─────────────────────────────────────────────
#  Fixtures
# ─────────────────────────────────────────────

def make_user(**kwargs):
    defaults = dict(
        email="test@example.com",
        first_name="John",
        last_name="Doe",
        role="client",
    )
    defaults.update(kwargs)
    return User.objects.create_user(password="testpass123", **defaults)


PASSENGER_DATA = [
    {
        "type": "adult",
        "title": "mr",
        "given_name": "John",
        "family_name": "Doe",
        "born_on": date(1990, 1, 15),
        "email": "john@example.com",
        "phone_number": "+1234567890",
        "identity_documents": [],
    }
]

PAYMENT_DATA = {
    "type": "balance",
    "amount": Decimal("250.00"),
    "currency": "USD",
}

MOCK_OFFER = {
    "id": "off_0000A3tQSmKyqa6oqnqMss",
    "total_amount": "250.00",
    "total_currency": "USD",
}

MOCK_ORDER = {
    "id": "ord_0000A3tQSmKyqa6oqnqMss",
    "booking_reference": "ABCDEF",
    "total_amount": "250.00",
    "total_currency": "USD",
    "passengers": [
        {
            "given_name": "John",
            "family_name": "Doe",
            "base_amount": "200.00",
            "tax_amount": "50.00",
        }
    ],
}


# ─────────────────────────────────────────────
#  Tests
# ─────────────────────────────────────────────

class CreateReservationTest(TestCase):
    def setUp(self):
        self.user = make_user()
        self.offer_id = "off_0000A3tQSmKyqa6oqnqMss"

    @patch("apps.reservations.services.duffel")
    def test_creates_reservation_and_passengers(self, mock_duffel):
        mock_duffel.get_offer.return_value = MOCK_OFFER
        mock_duffel.create_order.return_value = MOCK_ORDER

        reservation = services.create_reservation(
            user=self.user,
            offer_id=self.offer_id,
            passengers_data=PASSENGER_DATA,
            payment_data=PAYMENT_DATA,
        )

        self.assertEqual(reservation.external_order_id, MOCK_ORDER["id"])
        self.assertEqual(reservation.status, Reservation.Status.CONFIRMED)
        self.assertEqual(reservation.booking_reference, "ABCDEF")
        self.assertEqual(reservation.total_amount, Decimal("250.00"))
        self.assertEqual(Passenger.objects.filter(reservation=reservation).count(), 1)

    @patch("apps.reservations.services.duffel")
    def test_raises_on_duplicate_booking(self, mock_duffel):
        # Create an existing active reservation
        Reservation.objects.create(
            user=self.user,
            offer_id=self.offer_id,
            external_order_id="ord_existing",
            status=Reservation.Status.CONFIRMED,
            total_amount=Decimal("250.00"),
            currency="USD",
        )

        with self.assertRaises(DuplicateBookingException):
            services.create_reservation(
                user=self.user,
                offer_id=self.offer_id,
                passengers_data=PASSENGER_DATA,
                payment_data=PAYMENT_DATA,
            )

        # Duffel must NOT have been called
        mock_duffel.create_order.assert_not_called()

    @patch("apps.reservations.services.duffel")
    def test_rolls_back_db_on_error(self, mock_duffel):
        mock_duffel.get_offer.return_value = MOCK_OFFER
        mock_duffel.create_order.return_value = MOCK_ORDER

        # Simulate a DB error during save
        with patch(
            "apps.reservations.services.Reservation.objects.create",
            side_effect=Exception("DB connection lost"),
        ):
            with self.assertRaises(Exception):
                services.create_reservation(
                    user=self.user,
                    offer_id=self.offer_id,
                    passengers_data=PASSENGER_DATA,
                    payment_data=PAYMENT_DATA,
                )

        # DB should be clean
        self.assertEqual(Reservation.objects.count(), 0)
        self.assertEqual(Passenger.objects.count(), 0)


class GetReservationTest(TestCase):
    def setUp(self):
        self.admin = make_user(email="admin@example.com", role="admin")
        self.client_user = make_user(email="client@example.com", role="client")
        self.other_user = make_user(email="other@example.com", role="client")
        self.reservation = Reservation.objects.create(
            user=self.client_user,
            offer_id="off_123",
            external_order_id="ord_123",
            status=Reservation.Status.CONFIRMED,
            total_amount=Decimal("300.00"),
            currency="USD",
        )

    def test_client_can_access_own_reservation(self):
        result = services.get_reservation(self.reservation.id, self.client_user)
        self.assertEqual(result.id, self.reservation.id)

    def test_client_cannot_access_others_reservation(self):
        with self.assertRaises(ReservationNotFoundException):
            services.get_reservation(self.reservation.id, self.other_user)

    def test_admin_can_access_any_reservation(self):
        result = services.get_reservation(self.reservation.id, self.admin)
        self.assertEqual(result.id, self.reservation.id)

    def test_raises_for_nonexistent_reservation(self):
        import uuid
        with self.assertRaises(ReservationNotFoundException):
            services.get_reservation(uuid.uuid4(), self.client_user)


class CancelReservationTest(TestCase):
    def setUp(self):
        self.user = make_user()
        self.reservation = Reservation.objects.create(
            user=self.user,
            offer_id="off_456",
            external_order_id="ord_456",
            status=Reservation.Status.CONFIRMED,
            total_amount=Decimal("500.00"),
            currency="USD",
        )

    @patch("apps.reservations.services.duffel")
    def test_cancels_reservation(self, mock_duffel):
        mock_duffel.cancel_order.return_value = {
            "id": "can_123",
            "refund_amount": "500.00",
            "refund_currency": "USD",
        }

        result = services.cancel_reservation(self.reservation.id, self.user)
        self.assertEqual(result.status, Reservation.Status.CANCELLED)
        mock_duffel.cancel_order.assert_called_once_with("ord_456")

    def test_raises_if_already_cancelled(self):
        self.reservation.status = Reservation.Status.CANCELLED
        self.reservation.save()

        with self.assertRaises(CancellationNotAllowedException):
            services.cancel_reservation(self.reservation.id, self.user)
