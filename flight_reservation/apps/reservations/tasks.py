import logging

from celery import shared_task
from celery.utils.log import get_task_logger

from core.duffel_client import DuffelClient

logger = get_task_logger(__name__)
duffel = DuffelClient()


@shared_task(
    bind=True,
    max_retries=3,
    default_retry_delay=60,
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_backoff_max=300,
)
def sync_reservation_status(self, reservation_id: str):
    """
    Celery task: Sync a reservation's status from Duffel.

    Use cases:
    - Schedule changes pushed via webhook
    - Polling to detect cancellations initiated by airlines
    - Post-booking status verification

    Retries up to 3 times with exponential backoff (60s → 120s → 240s).
    """
    from apps.reservations.models import Reservation

    try:
        reservation = Reservation.objects.get(id=reservation_id)

        if not reservation.external_order_id:
            logger.warning(
                "sync_reservation_status: no external_order_id for %s",
                reservation_id,
            )
            return

        order = duffel.get_order(reservation.external_order_id)
        duffel_status = order.get("status")

        # Map Duffel order status to our internal status
        status_map = {
            "confirmed": Reservation.Status.CONFIRMED,
            "cancelled": Reservation.Status.CANCELLED,
        }
        new_status = status_map.get(duffel_status)

        changed = False
        if new_status and new_status != reservation.status:
            reservation.status = new_status
            changed = True

        reservation.raw_duffel_order = order
        reservation.save(
            update_fields=["raw_duffel_order", "status", "updated_at"]
            if changed
            else ["raw_duffel_order", "updated_at"]
        )

        logger.info(
            "Reservation %s synced: status=%s changed=%s",
            reservation_id,
            reservation.status,
            changed,
        )

    except Reservation.DoesNotExist:
        logger.error(
            "sync_reservation_status: reservation %s not found", reservation_id
        )
    except Exception as exc:
        logger.warning(
            "sync_reservation_status failed for %s: %s — retrying",
            reservation_id,
            exc,
        )
        raise self.retry(exc=exc)
