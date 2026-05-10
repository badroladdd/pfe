from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.flights import services
from core.duffel_client import DuffelClient

duffel = DuffelClient()


class FlightSearchView(APIView):
    """
    GET /api/v1/flights/search/

    Query params: origin, destination, departure_date, adults, children,
                  infants, travel_class (ECONOMY|BUSINESS|FIRST|PREMIUM_ECONOMY)
    """

    permission_classes = [AllowAny]

    def get(self, request):
        origin = request.query_params.get("origin", "").strip().upper()
        destination = request.query_params.get("destination", "").strip().upper()
        departure_date = request.query_params.get("departure_date", "").strip()
        return_date = request.query_params.get("return_date", "").strip() or None
        cabin_class = request.query_params.get("travel_class", "economy").lower()

        try:
            adults   = int(request.query_params.get("adults", 1))
            children = int(request.query_params.get("children", 0))
            infants  = int(request.query_params.get("infants", 0))
        except (ValueError, TypeError):
            return Response(
                {"detail": "adults, children, and infants must be integers."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # children_ages: comma-separated ages e.g. "5,8"
        raw_ages = request.query_params.get("children_ages", "")
        children_ages = []
        if raw_ages:
            try:
                children_ages = [int(a) for a in raw_ages.split(",") if a.strip()]
            except ValueError:
                pass

        if not origin or not destination or not departure_date:
            return Response(
                {"detail": "origin, destination, and departure_date are required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if origin == destination:
            return Response(
                {"detail": "Origin and destination cannot be the same."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if adults + children + infants == 0:
            return Response(
                {"detail": "At least one passenger is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Duffel v2 : pour les enfants, utiliser SOIT type SOIT age (pas les deux)
        child_passengers = []
        for i in range(children):
            if i < len(children_ages):
                # Avec age : Duffel infere automatiquement le type
                child_passengers.append({"age": children_ages[i]})
            else:
                # Sans age : utiliser type uniquement
                child_passengers.append({"type": "child"})

        passengers = (
            [{"type": "adult"}] * adults
            + child_passengers
        )

        result = services.search_flights(
            origin=origin,
            destination=destination,
            departure_date=departure_date,
            passengers=passengers,
            cabin_class=cabin_class,
            return_date=return_date,
        )

        offers = [_attach_summary(o) for o in result.get("offers", [])]
        return Response({"results": offers})


def _attach_summary(offer: dict) -> dict:
    """Add a _summary key with pre-computed fields so Flutter can read them easily."""
    slices = offer.get("slices") or []
    first_slice = slices[0] if slices else {}
    outbound_slice = slices[0] if slices else {}
    first_seg = (first_slice.get("segments") or [{}])[0]
    last_seg = (outbound_slice.get("segments") or [{}])[-1]

    stops = sum(max(len(s.get("segments", [])) - 1, 0) for s in slices)
    carrier = (first_seg.get("marketing_carrier") or {}).get("name", "")
    flight_number = (first_seg.get("marketing_carrier") or {}).get("iata_code", "") + \
                    first_seg.get("marketing_carrier_flight_number", "")

    is_round_trip = len(slices) >= 2
    return_info = None
    if is_round_trip:
        ret_slice = slices[1]
        ret_first_seg = (ret_slice.get("segments") or [{}])[0]
        ret_last_seg  = (ret_slice.get("segments") or [{}])[-1]
        return_info = {
            "origin":       (ret_slice.get("origin") or {}).get("iata_code", ""),
            "destination":  (ret_slice.get("destination") or {}).get("iata_code", ""),
            "departure_at": ret_first_seg.get("departing_at", ""),
            "arrival_at":   ret_last_seg.get("arriving_at", ""),
            "duration":     ret_slice.get("duration", ""),
        }

    offer["_summary"] = {
        "origin":       (first_slice.get("origin") or {}).get("iata_code", ""),
        "destination":  (outbound_slice.get("destination") or {}).get("iata_code", ""),
        "departure_at": first_seg.get("departing_at", ""),
        "arrival_at":   last_seg.get("arriving_at", ""),
        "carrier":      carrier,
        "flight_number": flight_number,
        "stops":        stops,
        "duration":     first_slice.get("duration", ""),
        "total_price":  offer.get("total_amount", "0"),
        "currency":     offer.get("total_currency", "EUR"),
        "seats_available": offer.get("available_seats"),
        "is_round_trip": is_round_trip,
        "return":       return_info,
    }
    return offer


class AirportSearchView(APIView):
    """GET /api/v1/airports/?query=paris — proxy to Duffel airport search."""

    permission_classes = [AllowAny]

    def get(self, request):
        query = request.query_params.get("query", "").strip()
        if len(query) < 2:
            return Response({"data": []})
        places = duffel.search_airports(query)
        results = []
        seen = set()

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
                # expand nested airports
                for a in p.get("airports", []):
                    _add(a)
            elif p.get("type") == "airport":
                _add(p)

        return Response({"data": results})


class ConfirmPriceView(APIView):
    """
    POST /api/v1/flights/confirm-price/
    Body: { "flight_offer": { "id": "off_..." } }
    """

    permission_classes = [AllowAny]

    def post(self, request):
        flight_offer = request.data.get("flight_offer", {})
        offer_id = flight_offer.get("id") or flight_offer.get("offer_id")

        if not offer_id:
            return Response(
                {"detail": "flight_offer.id is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        offer = duffel.get_offer(offer_id)
        return Response({"data": offer})


class RecommendationsView(APIView):
    """
    GET /api/v1/recommendations/?origin=ALG
    Applique l'algorithme A priori sur les reservations confirmees
    et retourne les destinations les plus souvent associees a l'origine.
    """

    permission_classes = [AllowAny]

    def get(self, request):
        origin      = request.query_params.get("origin",      "").strip().upper()
        destination = request.query_params.get("destination", "").strip().upper()

        if not origin or len(origin) != 3:
            return Response(
                {"detail": "origin (code IATA 3 lettres) est requis."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from apps.flights.apriori_service import get_recommendations
        results = get_recommendations(origin, destination)
        return Response({"origin": origin, "destination": destination, "results": results})
