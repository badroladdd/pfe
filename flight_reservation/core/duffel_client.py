import logging

import requests
from django.conf import settings

from core.exceptions import (
    DuffelAPIException,
    DuffelOfferExpiredException,
    DuffelTimeoutException,
    DuffelValidationException,
)

logger = logging.getLogger("duffel")

DUFFEL_BASE_URL = "https://api.duffel.com"
DUFFEL_API_VERSION = "v2"


class DuffelClient:
    """
    Thin, stateless wrapper over the Duffel REST API.

    Responsibilities:
      - Build authenticated HTTP requests
      - Map HTTP / Duffel error codes to typed Python exceptions
      - Log every outbound request and inbound response

    NOT responsible for:
      - Business logic
      - Database writes
      - Retries (handled at service / Celery task level)
    """

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update(
            {
                "Authorization": f"Bearer {settings.DUFFEL_API_KEY}",
                "Duffel-Version": DUFFEL_API_VERSION,
                "Content-Type": "application/json",
                "Accept": "application/json",
            }
        )
        self.timeout = getattr(settings, "DUFFEL_TIMEOUT_SECONDS", 30)

    # ──────────────────────────────────────────
    #  Offers
    # ──────────────────────────────────────────

    def search_offers(
        self,
        origin: str,
        destination: str,
        departure_date: str,
        passengers: list[dict],
        cabin_class: str = "economy",
        return_date: str | None = None,
    ) -> dict:
        """
        POST /air/offer_requests  (with return_offers=True so we get
        offers inline instead of a separate GET call).
        For round trips, pass return_date to add a second slice.
        """
        slices = [{"origin": origin, "destination": destination, "departure_date": departure_date}]
        if return_date:
            slices.append({"origin": destination, "destination": origin, "departure_date": return_date})

        payload = {
            "data": {
                "slices": slices,
                "passengers": passengers,
                "cabin_class": cabin_class,
                "return_offers": True,
            }
        }
        logger.info(
            "Duffel search_offers: %s→%s on %s cabin=%s pax=%d round_trip=%s",
            origin,
            destination,
            departure_date,
            cabin_class,
            len(passengers),
            bool(return_date),
        )
        response = self._post("/air/offer_requests", payload)
        return response["data"]

    def get_offer(self, offer_id: str) -> dict:
        """
        Validate that an offer is still live before attempting to book.
        Raises DuffelOfferExpiredException if not.
        """
        logger.info("Duffel get_offer: %s", offer_id)
        return self._get(f"/air/offers/{offer_id}")["data"]

    # ──────────────────────────────────────────
    #  Orders (bookings)
    # ──────────────────────────────────────────

    def create_order(
        self,
        offer_id: str,
        passengers: list[dict],
        payment: dict,
        metadata: dict | None = None,
    ) -> dict:
        """
        POST /air/orders
        Locks the offer, charges the payment, and returns a Duffel Order
        with a globally unique order_id and a booking_reference (airline PNR).

        ⚠️  This call is IRREVERSIBLE once it returns 200.
            The caller (service layer) must persist external_order_id
            immediately after this returns.
        """
        payload = {
            "data": {
                "type": "instant",
                "selected_offers": [offer_id],
                "passengers": passengers,
                "payments": [payment],
                **({"metadata": metadata} if metadata else {}),
            }
        }
        logger.info(
            "Duffel create_order: offer_id=%s pax=%d payload=%s",
            offer_id, len(passengers),
            str(payload)[:800],
        )
        response = self._post("/air/orders", payload)
        order = response["data"]
        logger.info(
            "Duffel order created: order_id=%s booking_ref=%s total=%s %s",
            order.get("id"),
            order.get("booking_reference"),
            order.get("total_amount"),
            order.get("total_currency"),
        )
        return order

    def get_order(self, order_id: str) -> dict:
        """Fetch full order details (used for status sync)."""
        logger.info("Duffel get_order: %s", order_id)
        return self._get(f"/air/orders/{order_id}")["data"]

    def cancel_order(self, order_id: str) -> dict:
        """
        Two-step cancellation:
          1. POST /air/order_cancellations  → get cancellation quote + id
          2. POST /air/order_cancellations/{id}/actions/confirm
        Returns the confirmed cancellation object (includes refund amount).
        """
        # Step 1: request cancellation quote
        quote_payload = {"data": {"order_id": order_id}}
        quote = self._post("/air/order_cancellations", quote_payload)["data"]
        cancellation_id = quote["id"]
        logger.info(
            "Duffel cancellation quote: id=%s refund=%s %s",
            cancellation_id,
            quote.get("refund_amount"),
            quote.get("refund_currency"),
        )

        # Step 2: confirm cancellation
        confirmed = self._post(
            f"/air/order_cancellations/{cancellation_id}/actions/confirm", {}
        )["data"]
        logger.info("Duffel cancellation confirmed: order_id=%s", order_id)
        return confirmed

    # ──────────────────────────────────────────
    #  HTTP plumbing
    # ──────────────────────────────────────────

    def _get(self, path: str) -> dict:
        return self._request("GET", path)

    def _post(self, path: str, payload: dict) -> dict:
        return self._request("POST", path, json=payload)

    def _request(self, method: str, path: str, **kwargs) -> dict:
        url = f"{DUFFEL_BASE_URL}{path}"
        try:
            resp = self.session.request(method, url, timeout=self.timeout, **kwargs)
        except requests.Timeout:
            logger.error("Duffel timeout: %s %s (timeout=%ds)", method, path, self.timeout)
            raise DuffelTimeoutException(
                f"Duffel API did not respond within {self.timeout}s."
            )
        except requests.ConnectionError as exc:
            logger.error("Duffel connection error: %s %s — %s", method, path, exc)
            raise DuffelAPIException("Could not connect to Duffel API.")

        self._handle_errors(resp)
        return resp.json()

    def _handle_errors(self, resp: requests.Response) -> None:
        if resp.status_code < 400:
            return

        try:
            body = resp.json()
            errors = body.get("errors", [])
            first = errors[0] if errors else {}
            code = first.get("code", "")
            title = first.get("title", resp.reason or "Unknown error")
        except Exception:
            errors, code, title = [], "", resp.text

        message = first.get("message", "")
        source  = first.get("source", {})
        pointer = source.get("pointer", "") if isinstance(source, dict) else ""

        logger.error(
            "Duffel API error %s: code=%s title=%s message=%s pointer=%s body=%s path=%s",
            resp.status_code,
            code,
            title,
            message,
            pointer,
            resp.text[:800],
            resp.url,
        )

        if resp.status_code == 410 or "offer_no_longer_available" in code:
            raise DuffelOfferExpiredException("This offer is no longer available.")
        if resp.status_code in (400, 422):
            detail = f"{title} — {pointer}: {message}" if (pointer or message) else title
            raise DuffelValidationException(detail, errors=errors)
        if resp.status_code == 401:
            raise DuffelAPIException("Duffel authentication failed. Check DUFFEL_API_KEY.")
        if resp.status_code == 429:
            raise DuffelAPIException("Duffel rate limit reached. Retry later.")
        raise DuffelAPIException(f"Duffel API error {resp.status_code}: {title}")
