import logging

from django.core.cache import cache

from core.duffel_client import DuffelClient

logger = logging.getLogger("flights")
duffel = DuffelClient()

OFFER_CACHE_TTL = 60 * 15  # 15 minutes — offers expire quickly


def search_flights(
    origin: str,
    destination: str,
    departure_date: str,
    passengers: list[dict],
    cabin_class: str = "economy",
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
        f"flight_offers:{origin}:{destination}:{departure_date}:{cabin_class}"
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
