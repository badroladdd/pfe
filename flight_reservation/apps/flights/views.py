import requests as req_lib

from django.http import HttpResponse

from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.flights import services
from core.amadeus_client import AmadeusClient
from core.duffel_client import DuffelClient

amadeus = AmadeusClient()
duffel  = DuffelClient()   # used for airport search only


class FlightSearchView(APIView):
    """
    GET /api/v1/flights/search/
    Query params: origin, destination, departure_date, return_date,
                  adults, children, infants, children_ages,
                  travel_class, non_stop, has_baggage, refundable,
                  currency_code, max_results
    """

    permission_classes = [AllowAny]

    def get(self, request):
        origin      = request.query_params.get("origin", "").strip().upper()
        destination = request.query_params.get("destination", "").strip().upper()
        departure_date = request.query_params.get("departure_date", "").strip()
        return_date = request.query_params.get("return_date", "").strip() or None
        cabin_class = request.query_params.get("travel_class", "economy").lower()
        currency    = request.query_params.get("currency_code", "EUR").upper()

        try:
            adults   = int(request.query_params.get("adults",   1))
            children = int(request.query_params.get("children", 0))
            infants  = int(request.query_params.get("infants",  0))
        except (ValueError, TypeError):
            return Response(
                {"detail": "adults, children and infants must be integers."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not origin or not destination or not departure_date:
            return Response(
                {"detail": "origin, destination and departure_date are required."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if origin == destination:
            return Response(
                {"detail": "Origin and destination cannot be the same."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Build passengers list for Amadeus
        passengers = [{"type": "adult"}] * max(adults, 1)
        raw_ages   = request.query_params.get("children_ages", "")
        ages       = [int(a) for a in raw_ages.split(",") if a.strip().isdigit()]
        for i in range(children):
            passengers.append({"type": "child", "age": ages[i]} if i < len(ages) else {"type": "child"})
        passengers += [{"type": "infant"}] * infants

        def _bool(param: str) -> bool:
            return request.query_params.get(param, "false").lower() in ("1", "true", "yes", "on")

        try:
            max_results = int(request.query_params.get("max_results", 20))
        except (ValueError, TypeError):
            max_results = 20

        result = services.search_flights(
            origin=origin,
            destination=destination,
            departure_date=departure_date,
            passengers=passengers,
            cabin_class=cabin_class,
            non_stop=_bool("non_stop"),
            has_baggage=_bool("has_baggage"),
            is_refundable=_bool("refundable"),
            return_date=return_date,
            currency=currency,
            max_results=max_results,
        )

        dictionaries = result.get("dictionaries", {})
        offers = [_attach_summary(o, dictionaries) for o in result.get("offers", [])]
        return Response({"results": offers, "count": len(offers)})


def _attach_summary(offer: dict, dictionaries: dict | None = None) -> dict:
    """Add a _summary key with pre-computed fields for Flutter.
    Also attaches `dictionaries` to the offer so Flutter can look up
    carrier/aircraft names in FlightDetailScreen.
    """
    dicts       = dictionaries or {}
    carriers    = dicts.get("carriers", {})
    aircraft_db = dicts.get("aircraft", {})

    itineraries = offer.get("itineraries", [])
    first_it    = itineraries[0] if itineraries else {}
    first_segs  = first_it.get("segments", [])
    first_seg   = first_segs[0]  if first_segs else {}
    last_seg    = first_segs[-1] if first_segs else {}

    origin_iata = (first_seg.get("departure") or {}).get("iataCode", "")
    dest_iata   = (last_seg.get("arrival")    or {}).get("iataCode", "")
    dep_at      = (first_seg.get("departure") or {}).get("at", "")
    arr_at      = (last_seg.get("arrival")    or {}).get("at", "")
    carrier_code = first_seg.get("carrierCode", "")
    carrier_name = carriers.get(carrier_code, carrier_code)
    flight_num   = carrier_code + first_seg.get("number", "")
    stops        = max(len(first_segs) - 1, 0)

    price    = offer.get("price", {})
    total    = price.get("grandTotal", price.get("total", "0"))
    currency = price.get("currency", "EUR")

    # Baggage from travelerPricings
    has_baggage = False
    for tp in offer.get("travelerPricings", []):
        for seg in tp.get("fareDetailsBySegment", []):
            if (seg.get("includedCheckedBags") or {}).get("quantity", 0) > 0:
                has_baggage = True
                break

    # Refundable
    is_refundable = bool(offer.get("pricingOptions", {}).get("refundableFare", False))

    # Round-trip
    is_round_trip = len(itineraries) >= 2
    return_info   = None
    if is_round_trip:
        ret_it    = itineraries[1]
        ret_segs  = ret_it.get("segments", [])
        ret_first = ret_segs[0]  if ret_segs else {}
        ret_last  = ret_segs[-1] if ret_segs else {}
        return_info = {
            "origin":       (ret_first.get("departure") or {}).get("iataCode", ""),
            "destination":  (ret_last.get("arrival")    or {}).get("iataCode", ""),
            "departure_at": (ret_first.get("departure") or {}).get("at", ""),
            "arrival_at":   (ret_last.get("arrival")    or {}).get("at", ""),
            "duration":     ret_it.get("duration", ""),
        }

    offer["_summary"] = {
        "origin":          origin_iata,
        "destination":     dest_iata,
        "departure_at":    dep_at,
        "arrival_at":      arr_at,
        "carrier":         carrier_name,
        "carrier_code":    carrier_code,
        "flight_number":   flight_num,
        "stops":           stops,
        "duration":        first_it.get("duration", ""),
        "total_price":     total,
        "base_price":      price.get("base", total),
        "currency":        currency,
        "seats_available": offer.get("numberOfBookableSeats"),
        "has_baggage":     has_baggage,
        "is_refundable":   is_refundable,
        "is_round_trip":   is_round_trip,
        "return":          return_info,
        "last_ticketing_date": offer.get("lastTicketingDate", ""),
        "logo_url": (
            f"https://assets.duffel.com/img/airlines/for-light-background"
            f"/full-color-logo/{carrier_code}.svg"
            if carrier_code else ""
        ),
    }

    # Attach dictionaries so Flutter can resolve carrier/aircraft names
    offer["dictionaries"] = {
        "carriers": carriers,
        "aircraft": aircraft_db,
        "locations": dicts.get("locations", {}),
    }
    return offer


class AirportSearchView(APIView):
    """GET /api/v1/airports/?query=alger — proxied to Duffel airport search."""

    permission_classes = [AllowAny]

    def get(self, request):
        query = request.query_params.get("query", "").strip()
        if len(query) < 2:
            return Response({"data": []})

        places  = duffel.search_airports(query)
        results = []
        seen    = set()

        def _add(a):
            iata = a.get("iata_code", "")
            if not iata or iata in seen:
                return
            seen.add(iata)
            results.append({
                "iata":    iata,
                "name":    a.get("name", ""),
                "city":    a.get("city_name", ""),
                "country": a.get("iata_country_code", ""),
            })

        for p in places:
            if p.get("type") == "city":
                for a in p.get("airports", []):
                    _add(a)
            elif p.get("type") == "airport":
                _add(p)

        return Response({"data": results})


class ConfirmPriceView(APIView):
    """
    POST /api/v1/flights/confirm-price/
    Body: { "flight_offer": { ...full Amadeus offer... } }
    """

    permission_classes = [AllowAny]

    def post(self, request):
        flight_offer = request.data.get("flight_offer", {})
        if not flight_offer.get("id"):
            return Response(
                {"detail": "flight_offer is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        confirmed = amadeus.confirm_offer_price(flight_offer)
        dicts = flight_offer.get("dictionaries", {})
        return Response({"data": _attach_summary(confirmed, dicts)})


class RecommendationsView(APIView):
    """
    GET /api/v1/recommendations/?origin=ALG
    A priori algorithm on confirmed reservations.
    """

    permission_classes = [AllowAny]

    def get(self, request):
        origin      = request.query_params.get("origin", "").strip().upper()
        destination = request.query_params.get("destination", "").strip().upper()

        if not origin or len(origin) != 3:
            return Response(
                {"detail": "origin (IATA 3-letter code) is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from apps.flights.apriori_service import get_recommendations
        results = get_recommendations(origin, destination)
        return Response({"origin": origin, "destination": destination, "results": results})


class AirlineLogoView(APIView):
    """
    GET /api/v1/airlines/logo/<code>/
    Proxies the airline logo SVG from Duffel's CDN so Flutter web avoids CORS.
    Logos are served with a 24-hour cache header.
    """

    permission_classes = [AllowAny]

    # In-process cache: code -> (svg_bytes | None)
    _cache: dict = {}

    def get(self, request, code: str):
        code = code.strip().upper()
        if not code.isalpha() or len(code) > 4:
            return HttpResponse(status=400)

        if code in self._cache:
            data = self._cache[code]
            if data is None:
                return HttpResponse(status=404)
            return HttpResponse(data, content_type="image/svg+xml",
                                headers={"Cache-Control": "public, max-age=86400"})

        url = (
            f"https://assets.duffel.com/img/airlines/for-light-background"
            f"/full-color-logo/{code}.svg"
        )
        try:
            resp = req_lib.get(url, timeout=6)
            if resp.status_code == 200 and resp.content:
                self._cache[code] = resp.content
                return HttpResponse(resp.content, content_type="image/svg+xml",
                                    headers={"Cache-Control": "public, max-age=86400"})
            self._cache[code] = None
            return HttpResponse(status=404)
        except Exception:
            self._cache[code] = None
            return HttpResponse(status=502)
