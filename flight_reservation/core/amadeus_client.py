"""
Amadeus REST API client — replaces DuffelClient.

Endpoints used:
  POST /v1/security/oauth2/token          → OAuth2 access token
  GET  /v2/shopping/flight-offers         → search flights
  POST /v1/shopping/flight-offers/pricing → confirm/refresh price
  GET  /v1/reference-data/locations       → airport search
  POST /v1/booking/flight-orders          → create booking
  GET  /v1/booking/flight-orders/{id}     → get order details
  DELETE /v1/booking/flight-orders/{id}   → cancel order
"""

import logging
import threading
import time

import requests
from django.conf import settings

from core.exceptions import (
    DuffelAPIException as AmadeusAPIException,
    DuffelOfferExpiredException as AmadeusOfferExpiredException,
    DuffelTimeoutException as AmadeusTimeoutException,
    DuffelValidationException as AmadeusValidationException,
)

logger = logging.getLogger("amadeus")

_BASE_V1 = "https://test.travel.api.amadeus.com/v1"
_BASE_V2 = "https://test.travel.api.amadeus.com/v2"

_CABIN_MAP = {
    "economy":         "ECONOMY",
    "premium_economy": "PREMIUM_ECONOMY",
    "business":        "BUSINESS",
    "first":           "FIRST",
}


class AmadeusClient:
    """
    Stateless (except for cached OAuth2 token) wrapper over the Amadeus API.
    Token is refreshed automatically 60 s before expiry. Thread-safe.
    """

    def __init__(self):
        self._client_id     = getattr(settings, "AMADEUS_CLIENT_ID", "")
        self._client_secret = getattr(settings, "AMADEUS_CLIENT_SECRET", "")
        self._token         = None
        self._expires_at    = 0.0
        self._lock          = threading.Lock()
        self.session        = requests.Session()
        self.timeout        = getattr(settings, "AMADEUS_TIMEOUT_SECONDS", 30)

    # ── Auth ──────────────────────────────────────────────────────────────────

    def _token_headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self._get_token()}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    def _get_token(self) -> str:
        with self._lock:
            if self._token and time.time() < self._expires_at - 60:
                return self._token

            resp = requests.post(
                f"{_BASE_V1}/security/oauth2/token",
                headers={"Content-Type": "application/x-www-form-urlencoded"},
                data={
                    "grant_type":    "client_credentials",
                    "client_id":     self._client_id,
                    "client_secret": self._client_secret,
                },
                timeout=15,
            )
            if resp.status_code != 200:
                logger.error("Amadeus auth failed: %s %s", resp.status_code, resp.text[:300])
                raise AmadeusAPIException("Amadeus authentication failed.")

            data              = resp.json()
            self._token       = data["access_token"]
            self._expires_at  = time.time() + data.get("expires_in", 1799)
            logger.info("Amadeus token obtained, valid for %ds", data.get("expires_in", 1799))
            return self._token

    # ── Flight offers ─────────────────────────────────────────────────────────

    def search_offers(
        self,
        origin: str,
        destination: str,
        departure_date: str,
        passengers: list[dict],
        cabin_class: str = "economy",
        return_date: str | None = None,
        non_stop: bool = False,
        currency: str = "EUR",
        max_results: int = 20,
    ) -> dict:
        """GET /v2/shopping/flight-offers → returns raw Amadeus response dict."""
        adults   = sum(1 for p in passengers if p.get("type") == "adult")
        children = sum(1 for p in passengers if p.get("type") == "child" or "age" in p)
        infants  = sum(1 for p in passengers
                      if p.get("type") in ("infant", "infant_without_seat", "infant_with_seat"))

        params: dict = {
            "originLocationCode":      origin.upper(),
            "destinationLocationCode": destination.upper(),
            "departureDate":           departure_date,
            "adults":                  max(adults, 1),
            "currencyCode":            currency.upper(),
            "max":                     min(max_results, 250),
            "travelClass":             _CABIN_MAP.get(cabin_class.lower(), "ECONOMY"),
        }
        if children  > 0: params["children"] = children
        if infants   > 0: params["infants"]  = infants
        if non_stop:       params["nonStop"]  = "true"
        if return_date:    params["returnDate"] = return_date

        logger.info(
            "Amadeus search_offers: %s→%s on %s cabin=%s A=%d C=%d I=%d",
            origin, destination, departure_date, cabin_class, adults, children, infants,
        )
        return self._request("GET", f"{_BASE_V2}/shopping/flight-offers", params=params)

    def confirm_offer_price(self, flight_offer: dict) -> dict:
        """POST /v1/shopping/flight-offers/pricing — returns re-priced offer."""
        payload = {
            "data": {
                "type":        "flight-offers-pricing",
                "flightOffers": [flight_offer],
            }
        }
        logger.info("Amadeus confirm_offer_price: offer_id=%s", flight_offer.get("id"))
        resp   = self._request("POST", f"{_BASE_V1}/shopping/flight-offers/pricing", json=payload)
        offers = resp.get("data", {}).get("flightOffers", [])
        if not offers:
            raise AmadeusOfferExpiredException("Offer pricing could not be confirmed.")
        return offers[0]

    def search_airports(self, keyword: str) -> list:
        """GET /v1/reference-data/locations — AIRPORT + CITY autocomplete."""
        params = {"keyword": keyword, "subType": "AIRPORT,CITY", "page[limit]": 10}
        logger.info("Amadeus search_airports: %s", keyword)
        try:
            return self._request(
                "GET", f"{_BASE_V1}/reference-data/locations", params=params
            ).get("data", [])
        except Exception:
            return []

    # ── Orders (bookings) ─────────────────────────────────────────────────────

    def create_order(
        self,
        flight_offer: dict,
        travelers: list[dict],
        payment_method: str = "CASH",
        contact: dict | None = None,
    ) -> dict:
        """POST /v1/booking/flight-orders → returns flight-order dict."""
        contacts = [contact] if contact else [{
            "addresseeName": {"firstName": "FLYAPP", "lastName": "CONTACT"},
            "companyName": "FlyApp",
            "purpose": "STANDARD",
            "phones": [{"deviceType": "LANDLINE",
                        "countryCallingCode": "213",
                        "number": "0000000000"}],
            "emailAddress": "contact@flyapp.dz",
            "address": {
                "lines": ["Alger Centre"],
                "postalCode": "16000",
                "cityName": "Alger",
                "countryCode": "DZ",
            },
        }]

        payload = {
            "data": {
                "type":         "flight-order",
                "flightOffers": [flight_offer],
                "travelers":    travelers,
                "ticketingAgreement": {"option": "DELAY_TO_CANCEL", "delay": "6D"},
                "contacts":     contacts,
                # Amadeus only accepts CASH/CHECK here.
                # CIB/Edahabia are handled internally — always send CASH to Amadeus.
                "formOfPayments": [{
                    "other": {
                        "method":         "CASH",
                        "flightOfferIds": ["1"],
                    }
                }],
            }
        }

        logger.info(
            "Amadeus create_order: offer_id=%s travelers=%d payment=%s",
            flight_offer.get("id"), len(travelers), payment_method,
        )
        # Use a fresh connection for booking (avoid stale session keep-alive issues)
        import requests as _req
        try:
            raw = _req.post(
                f"{_BASE_V1}/booking/flight-orders",
                headers=self._token_headers(),
                json=payload,
                timeout=self.timeout,
            )
        except _req.Timeout:
            raise AmadeusTimeoutException(f"Amadeus booking timed out after {self.timeout}s.")
        except _req.ConnectionError as exc:
            raise AmadeusAPIException(f"Cannot connect to Amadeus booking: {exc}")
        self._handle_errors(raw)
        resp_data = raw.json() if raw.content else {}
        order     = resp_data.get("data", {})
        assoc     = order.get("associatedRecords", [{}])
        book_ref  = assoc[0].get("reference", "") if assoc else ""
        logger.info(
            "Amadeus order created: order_id=%s booking_ref=%s",
            order.get("id"), book_ref,
        )
        return order

    def get_order(self, order_id: str) -> dict:
        """GET /v1/booking/flight-orders/{id}."""
        logger.info("Amadeus get_order: %s", order_id)
        return self._request("GET", f"{_BASE_V1}/booking/flight-orders/{order_id}").get("data", {})

    def cancel_order(self, order_id: str) -> dict:
        """DELETE /v1/booking/flight-orders/{id} → 204 No Content."""
        logger.info("Amadeus cancel_order: %s", order_id)
        url = f"{_BASE_V1}/booking/flight-orders/{order_id}"
        try:
            resp = self.session.delete(
                url, headers=self._token_headers(), timeout=self.timeout
            )
        except requests.Timeout:
            raise AmadeusTimeoutException(f"Amadeus cancel timed out after {self.timeout}s.")
        except requests.ConnectionError as exc:
            raise AmadeusAPIException(f"Cannot connect to Amadeus: {exc}")

        if resp.status_code == 204:
            return {"cancelled": True, "order_id": order_id}
        self._handle_errors(resp)
        return resp.json() if resp.content else {"cancelled": True}

    # ── HTTP plumbing ─────────────────────────────────────────────────────────

    def _request(self, method: str, url: str, **kwargs) -> dict:
        try:
            resp = self.session.request(
                method, url, headers=self._token_headers(), timeout=self.timeout, **kwargs
            )
        except requests.Timeout:
            logger.error("Amadeus timeout: %s %s", method, url)
            raise AmadeusTimeoutException(f"Amadeus did not respond in {self.timeout}s.")
        except requests.ConnectionError as exc:
            logger.error("Amadeus connection error: %s", exc)
            raise AmadeusAPIException("Cannot connect to Amadeus API.")

        self._handle_errors(resp)
        return resp.json() if resp.content else {}

    def _handle_errors(self, resp: requests.Response) -> None:
        if resp.status_code < 400:
            return

        try:
            body   = resp.json()
            errors = body.get("errors", [])
            first  = errors[0] if errors else {}
            code   = first.get("code", resp.status_code)
            title  = first.get("title", resp.reason or "Unknown error")
            detail = first.get("detail", "")
        except Exception:
            code, title, detail, errors = resp.status_code, resp.reason or "", "", []

        logger.error(
            "Amadeus %s %s → %s: code=%s title=%s detail=%s body=%s",
            resp.request.method if resp.request else "?",
            resp.url, resp.status_code, code, title, detail, resp.text[:500],
        )

        if resp.status_code == 401:
            self._token = None  # force re-auth
            raise AmadeusAPIException("Amadeus authentication failed — token revoked?")
        if resp.status_code == 429:
            raise AmadeusAPIException("Amadeus rate limit exceeded. Retry later.")
        if resp.status_code in (400, 422):
            msg = f"{title}: {detail}" if detail else title
            raise AmadeusValidationException(msg, errors=errors)
        if resp.status_code == 404:
            raise AmadeusOfferExpiredException("Offer or order not found on Amadeus.")
        raise AmadeusAPIException(f"Amadeus error {resp.status_code}: {title}")
