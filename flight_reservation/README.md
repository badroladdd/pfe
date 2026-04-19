# ✈️ Flight Reservation System — Django + Duffel API

A production-ready flight reservation backend built with Django REST Framework
and integrated with the [Duffel API v2](https://duffel.com/docs/api/v2).

---

## 🏗️ Architecture

```
Client → JWT Auth → Views (no logic) → Services (all logic) → Duffel API
                                                            → MySQL DB
```

| Layer       | Responsibility                                  |
|-------------|--------------------------------------------------|
| Models      | DB schema only                                   |
| Serializers | Input validation + output shaping                |
| Views       | Auth, call service, return response              |
| Services    | ALL business logic, Duffel calls, DB writes      |
| DuffelClient| HTTP wrapper, error mapping, logging             |

---

## ⚡ Quick Start

### 1. Clone and set up environment

```bash
python -m venv venv
source venv/bin/activate       # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your DB credentials and Duffel API key
```

### 2. Create the database

```sql
CREATE DATABASE flight_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 3. Run migrations

```bash
python manage.py makemigrations
python manage.py migrate
```

### 4. Create a superuser

```bash
python manage.py createsuperuser
```

### 5. Run the development server

```bash
python manage.py runserver
```

---

## 🔑 Environment Variables

| Variable              | Required | Description                          |
|-----------------------|----------|--------------------------------------|
| `DJANGO_SECRET_KEY`   | ✅       | Django secret key                    |
| `DEBUG`               | ✅       | `True` for dev, `False` for prod     |
| `DB_NAME`             | ✅       | MySQL database name                  |
| `DB_USER`             | ✅       | MySQL user                           |
| `DB_PASSWORD`         | ✅       | MySQL password                       |
| `DB_HOST`             | ✅       | MySQL host                           |
| `DUFFEL_API_KEY`      | ✅       | Duffel API key (starts with `duffel_test_`) |
| `DUFFEL_TIMEOUT_SECONDS` | —    | HTTP timeout for Duffel (default: 30)|
| `REDIS_URL`           | —        | Redis URL for caching + Celery       |

---

## 📡 API Endpoints

### Auth

| Method | Endpoint                    | Description          |
|--------|-----------------------------|----------------------|
| POST   | `/api/auth/token/`          | Get JWT tokens       |
| POST   | `/api/auth/token/refresh/`  | Refresh access token |
| POST   | `/api/auth/token/verify/`   | Verify token         |

### Users

| Method | Endpoint              | Description          |
|--------|-----------------------|----------------------|
| POST   | `/api/users/register/`| Register new user    |
| GET    | `/api/users/me/`      | Get current user     |
| PATCH  | `/api/users/me/`      | Update current user  |

### Flights

| Method | Endpoint               | Description          |
|--------|------------------------|----------------------|
| POST   | `/api/flights/search/` | Search for flights   |

### Reservations

| Method | Endpoint                      | Description          |
|--------|-------------------------------|----------------------|
| GET    | `/api/reservations/`          | List reservations    |
| POST   | `/api/reservations/`          | Create reservation   |
| GET    | `/api/reservations/{id}/`     | Get reservation      |
| DELETE | `/api/reservations/{id}/`     | Cancel reservation   |

### Webhooks

| Method | Endpoint                 | Description          |
|--------|--------------------------|----------------------|
| POST   | `/api/webhooks/duffel/`  | Duffel event webhook |

---

## 🔄 Booking Flow

```
1. POST /api/flights/search/
   └─ Returns offers[], each with an offer_id

2. User selects an offer_id

3. POST /api/reservations/
   {
     "offer_id": "off_...",
     "passengers": [...],
     "payment": {"type": "balance", "amount": "250.00", "currency": "USD"}
   }

   Backend:
   ├─ Validates: no duplicate booking
   ├─ GET /air/offers/{offer_id}    → confirm offer still live
   ├─ POST /air/orders              → Duffel locks offer + charges payment
   │   └─ Returns: order_id, booking_reference
   └─ transaction.atomic():
       ├─ Reservation.create(external_order_id=order_id)
       └─ Passenger.bulk_create(...)

4. Returns 201 with full reservation + external_order_id
```

---

## ⚠️ Critical Design Decisions

### Why `external_order_id` is nullable
The field is `null=True` because it only exists after Duffel confirms the order.
A reservation in PENDING status has no order ID yet. Once confirmed, it becomes
`unique=True` — the uniqueness constraint prevents phantom duplicates.

### Why Duffel call is outside `transaction.atomic()`
HTTP requests cannot be rolled back. If we wrapped the Duffel call inside a
transaction and the DB write failed, Django would roll back the DB — but the
Duffel charge would remain. Instead:

- Call Duffel FIRST (outside transaction)
- Write to DB inside `transaction.atomic()`
- If DB write fails after a successful Duffel call → log CRITICAL with
  `external_order_id` for manual reconciliation

### Why `raw_duffel_order = JSONField`
Full audit trail. If Duffel's schema changes or a dispute arises, you can
always reconstruct exactly what was returned at booking time.

---

## 🧪 Running Tests

```bash
python manage.py test apps.reservations.tests
python manage.py test apps.users
```

---

## 🚀 Celery (Async Tasks)

Start Redis, then run the Celery worker:

```bash
redis-server
celery -A config.celery worker --loglevel=info
```

Available tasks:
- `sync_reservation_status(reservation_id)` — Sync status from Duffel with retry

---

## 👥 User Roles

| Role   | Can access                                 |
|--------|--------------------------------------------|
| Admin  | All reservations, all users                |
| Agent  | All reservations                           |
| Client | Only their own reservations                |

---

## 🔒 Security Checklist

- [x] JWT authentication on all endpoints
- [x] Role-based access control
- [x] No secrets in code (all via `.env`)
- [x] `unique=True` on `external_order_id`
- [x] `UniqueConstraint` on `(user, offer_id)` for active reservations
- [x] `transaction.atomic()` on all DB writes
- [x] CRITICAL logging on reconciliation failures
- [ ] Duffel webhook HMAC signature verification (stub in `DuffelWebhookView`)
- [ ] Rate limiting on public endpoints
- [ ] HTTPS in production
