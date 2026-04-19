from rest_framework import status
from rest_framework.exceptions import APIException
from rest_framework.views import exception_handler


# ─────────────────────────────────────────────
#  Duffel-specific exceptions
# ─────────────────────────────────────────────

class DuffelAPIException(APIException):
    status_code = status.HTTP_502_BAD_GATEWAY
    default_detail = "Duffel API error."

    def __init__(self, detail=None, errors=None):
        super().__init__(detail)
        self.duffel_errors = errors or []


class DuffelTimeoutException(DuffelAPIException):
    status_code = status.HTTP_504_GATEWAY_TIMEOUT
    default_detail = "Duffel API timed out."


class DuffelOfferExpiredException(DuffelAPIException):
    status_code = status.HTTP_410_GONE
    default_detail = "Selected offer is no longer available."


class DuffelValidationException(DuffelAPIException):
    status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
    default_detail = "Invalid booking data sent to Duffel."


# ─────────────────────────────────────────────
#  Domain exceptions
# ─────────────────────────────────────────────

class DuplicateBookingException(APIException):
    status_code = status.HTTP_409_CONFLICT
    default_detail = "You already have an active booking for this offer."


class ReservationNotFoundException(APIException):
    status_code = status.HTTP_404_NOT_FOUND
    default_detail = "Reservation not found."


class CancellationNotAllowedException(APIException):
    status_code = status.HTTP_400_BAD_REQUEST
    default_detail = "This reservation cannot be cancelled."


class PermissionDeniedException(APIException):
    status_code = status.HTTP_403_FORBIDDEN
    default_detail = "You do not have permission to perform this action."


# ─────────────────────────────────────────────
#  Global exception handler
# ─────────────────────────────────────────────

# Maps Django exception class names → Flutter-readable error codes
_CODE_MAP = {
    "DuplicateBookingException":      "DUPLICATE_BOOKING",
    "ReservationNotFoundException":   "NOT_FOUND",
    "CancellationNotAllowedException": "CANCELLATION_NOT_ALLOWED",
    "DuffelAPIException":             "DUFFEL_ERROR",
    "DuffelTimeoutException":         "GATEWAY_TIMEOUT",
    "DuffelOfferExpiredException":    "OFFER_EXPIRED",
    "DuffelValidationException":      "DUFFEL_VALIDATION_ERROR",
    "PermissionDeniedException":      "PERMISSION_DENIED",
    "AuthenticationFailed":           "UNAUTHORIZED",
    "NotAuthenticated":               "UNAUTHORIZED",
}


def custom_exception_handler(exc, context):
    """
    Returns a flat envelope that Flutter's api.dart can read:
    {
        "code":   "MACHINE_READABLE_CODE",
        "detail": "Human-readable message.",
        "duffel_errors": [...]   # only for Duffel errors
    }
    """
    response = exception_handler(exc, context)

    if response is not None:
        exc_class = type(exc).__name__
        code = _CODE_MAP.get(exc_class, exc_class)

        raw_detail = response.data.get("detail", None)
        if raw_detail is None:
            # Serializer validation errors — flatten to a single string
            detail = "; ".join(
                f"{field}: {', '.join(str(e) for e in errs)}"
                if isinstance(errs, list) else str(errs)
                for field, errs in response.data.items()
            )
        elif not isinstance(raw_detail, str):
            detail = str(raw_detail)
        else:
            detail = raw_detail

        payload = {"code": code, "detail": detail}

        if hasattr(exc, "duffel_errors") and exc.duffel_errors:
            payload["duffel_errors"] = exc.duffel_errors

        response.data = payload

    return response
