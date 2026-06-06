import logging

from django.core.cache import cache

from core.amadeus_client import AmadeusClient

logger = logging.getLogger("flights")
amadeus = AmadeusClient()

OFFER_CACHE_TTL = 60 * 10  # 10 min — Amadeus offers expire quickly


# ── Helpers ───────────────────────────────────────────────────────────────────

def _offer_has_baggage(offer: dict) -> bool:
    """True if any traveler in any segment has ≥ 1 included checked bag."""
    for tp in offer.get("travelerPricings", []):
        for seg in tp.get("fareDetailsBySegment", []):
            bags = seg.get("includedCheckedBags", {})
            if bags.get("quantity", 0) > 0 or bags.get("weight", 0) > 0:
                return True
    return False


def _offer_is_refundable(offer: dict) -> bool:
    """True if the offer's pricingOptions marks it as refundable."""
    return bool(
        offer.get("pricingOptions", {}).get("refundableFare", False)
    )


def _offer_is_direct(offer: dict) -> bool:
    """True if every itinerary has exactly 1 segment (no stops)."""
    return all(
        len(it.get("segments", [])) == 1
        for it in offer.get("itineraries", [])
    )


# ── Main service ──────────────────────────────────────────────────────────────

def search_flights(
    origin: str,
    destination: str,
    departure_date: str,
    passengers: list[dict],
    cabin_class: str = "economy",
    non_stop: bool = False,
    has_baggage: bool = False,
    is_refundable: bool = False,
    use_cache: bool = False,
    return_date: str | None = None,
    currency: str = "EUR",
    max_results: int = 20,
) -> dict:
    """
    Search flights via Amadeus and return the raw response dict:
      { "data": [...offers...], "dictionaries": {...} }

    Filters (non_stop, has_baggage, is_refundable) are applied client-side
    because Amadeus does not support all of them as query parameters.
    """
    cache_key = (
        f"amadeus_offers:{origin}:{destination}:{departure_date}:"
        f"{cabin_class}:{non_stop}:{has_baggage}:{is_refundable}"
        + (f":{return_date}" if return_date else "")
    )

    if use_cache:
        cached = cache.get(cache_key)
        if cached:
            logger.info("Flight search cache HIT: %s→%s %s", origin, destination, departure_date)
            return cached

    logger.info(
        "Flight search: %s→%s on %s class=%s pax=%d round_trip=%s",
        origin, destination, departure_date, cabin_class, len(passengers), bool(return_date),
    )

    result = amadeus.search_offers(
        origin=origin,
        destination=destination,
        departure_date=departure_date,
        passengers=passengers,
        cabin_class=cabin_class,
        return_date=return_date,
        non_stop=non_stop,
        currency=currency,
        max_results=max_results,
    )

    offers = result.get("data", [])

    if non_stop:
        offers = [o for o in offers if _offer_is_direct(o)]
    if has_baggage:
        offers = [o for o in offers if _offer_has_baggage(o)]
    if is_refundable:
        offers = [o for o in offers if _offer_is_refundable(o)]

    result = {**result, "offers": offers}

    if use_cache:
        cache.set(cache_key, result, timeout=OFFER_CACHE_TTL)

    return result
