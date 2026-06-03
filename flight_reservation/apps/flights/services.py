import logging

from django.core.cache import cache

from core.duffel_client import DuffelClient

logger = logging.getLogger("flights")
duffel = DuffelClient()

OFFER_CACHE_TTL = 60 * 15  # 15 minutes — offers expire quickly


def _offer_has_baggage(offer: dict) -> bool:
    slices = offer.get("slices") or []
    for slice_ in slices:
        for segment in slice_.get("segments") or []:
            for passenger in segment.get("passengers") or []:
                if passenger.get("baggages"):
                    return True
    return False


def _offer_is_refundable(offer: dict) -> bool:
    conditions = offer.get("conditions") or {}
    if isinstance(conditions, dict) and conditions.get("refundable") is True:
        return True

    for slice_ in offer.get("slices") or []:
        for segment in slice_.get("segments") or []:
            seg_conditions = segment.get("conditions") or {}
            if isinstance(seg_conditions, dict) and seg_conditions.get("refundable") is True:
                return True
    return False


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
) -> dict:
    """
    Search for available flights via Duffel.

    Optionally caches results in Redis for OFFER_CACHE_TTL seconds.
    Cache is keyed on origin/destination/date/cabin — NOT on passengers,
    because pricing is recalculated at booking time.

    Note: Duffel offers expire quickly. Enabling the cache is a trade-off
    between API call reduction and showing slightly stale pricing.
    """
    cache_key = (
        f"flight_offers:{origin}:{destination}:{departure_date}:{cabin_class}:{non_stop}:{has_baggage}:{is_refundable}"
        + (f":{return_date}" if return_date else "")
    )

    if use_cache:
        cached = cache.get(cache_key)
        if cached:
            logger.info(
                "Flight search cache HIT: %s→%s %s", origin, destination, departure_date
            )
            return cached

    logger.info(
        "Flight search: %s→%s on %s class=%s pax=%d round_trip=%s",
        origin,
        destination,
        departure_date,
        cabin_class,
        len(passengers),
        bool(return_date),
    )

    result = duffel.search_offers(
        origin=origin,
        destination=destination,
        departure_date=departure_date,
        passengers=passengers,
        cabin_class=cabin_class,
        return_date=return_date,
    )

    if non_stop and result.get("offers") is not None:
        direct_offers = [
            offer for offer in result["offers"]
            if all(len(s.get("segments", [])) == 1 for s in offer.get("slices", []))
        ]
        result = {**result, "offers": direct_offers}

    if has_baggage and result.get("offers") is not None:
        baggage_offers = [
            offer for offer in result["offers"]
            if _offer_has_baggage(offer)
        ]
        result = {**result, "offers": baggage_offers}

    if is_refundable and result.get("offers") is not None:
        refundable_offers = [
            offer for offer in result["offers"]
            if _offer_is_refundable(offer)
        ]
        result = {**result, "offers": refundable_offers}

    if use_cache:
        cache.set(cache_key, result, timeout=OFFER_CACHE_TTL)
        logger.info(
            "Flight search cached for %ds: %s→%s %s",
            OFFER_CACHE_TTL,
            origin,
            destination,
            departure_date,
        )

    return result
