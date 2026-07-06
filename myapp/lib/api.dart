// api.dart — Django Flight Reservation Backend Client
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

/// Change this to your production URL when deploying.
/// Pour téléphone physique : utiliser l'IP locale du PC (même réseau WiFi)
/// Pour émulateur Android : utiliser 10.0.2.2
const String _kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.51.191.139:8000/api/v1',
);

const String _kAccessTokenKey  = 'access_token';
const String _kRefreshTokenKey = 'refresh_token';
const Duration _kTimeout        = Duration(seconds: 60);

// ─── Exception types ──────────────────────────────────────────────────────────

/// Base class for all API errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code; // Matches Django error codes: DUFFEL_ERROR, PRICE_CHANGED, etc.

  const ApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Session expirée. Veuillez vous reconnecter.'])
      : super.new(statusCode: 401, code: 'UNAUTHORIZED');
}

class NetworkException extends ApiException {
  const NetworkException([super.message = 'Impossible de joindre le serveur. Vérifiez votre connexion.'])
      : super.new(statusCode: null, code: 'NETWORK_ERROR');
}

/// Raised when Duffel reports a price change between search and booking.
/// The UI should show old/new price and let the user re-confirm.
class PriceChangedException extends ApiException {
  final String oldPrice;
  final String newPrice;
  final String currency;

  const PriceChangedException({
    required this.oldPrice,
    required this.newPrice,
    required this.currency,
  }) : super(
          'Le prix a changé de $oldPrice à $newPrice $currency.',
          statusCode: 409,
          code: 'PRICE_CHANGED',
        );
}

class DuplicateBookingException extends ApiException {
  const DuplicateBookingException([super.message = 'Vous avez déjà une réservation confirmée pour ce vol.'])
      : super.new(statusCode: 409, code: 'DUPLICATE_BOOKING');
}

// ─── Token storage (SharedPreferences) ────────────────────────────────────────

class _TokenStore {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  static Future<void> save({required String access, required String refresh}) async {
    final prefs = await _instance;
    await prefs.setString(_kAccessTokenKey, access);
    await prefs.setString(_kRefreshTokenKey, refresh);
  }

  static Future<String?> getAccess() async =>
      (await _instance).getString(_kAccessTokenKey);

  static Future<String?> getRefresh() async =>
      (await _instance).getString(_kRefreshTokenKey);

  static Future<void> clear() async {
    final prefs = await _instance;
    await prefs.remove(_kAccessTokenKey);
    await prefs.remove(_kRefreshTokenKey);
  }
}

// ─── Main API Client ──────────────────────────────────────────────────────────

class ApiClient {
  ApiClient({String? baseUrl}) : _base = baseUrl ?? _kBaseUrl;

  final String _base;

  // Shared HTTP client — reuses TCP connections across requests
  static final _http = http.Client();

  // Flight search cache — TTL 5 minutes
  static final Map<String, ({List<Map<String, dynamic>> data, DateTime at})> _searchCache = {};
  static const _cacheTtl = Duration(minutes: 2);

  // ══════════════════════════════════════════════════════════════════
  // AUTH
  // ══════════════════════════════════════════════════════════════════

  /// Login with email + password. Stores JWT tokens on success.
  /// Returns the full user profile map.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final data = await _post(
      '/auth/login/',
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );

    // Django SimpleJWT returns { access, refresh }
    await _TokenStore.save(
      access:  data['access'],
      refresh: data['refresh'],
    );

    debugPrint('[API] Login successful for $email');
    return data;
  }

  /// Register a new client account.
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String password2,
    required String firstName,
    required String lastName,
    String phone = '',
  }) async {
    return await _post(
      '/auth/register/',
      body: {
        'email':      email,
        'password':   password,
        'password2':  password2,
        'first_name': firstName,
        'last_name':  lastName,
        'phone':      phone,
        'role':       'client',
      },
      requiresAuth: false,
    );
  }

  /// Fetch the authenticated user's profile.
  Future<Map<String, dynamic>> getProfile() async {
    return await _get('/auth/me/');
  }

  /// Update the authenticated user's profile fields.
  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['first_name'] = firstName;
    if (lastName  != null) body['last_name']  = lastName;
    if (phone     != null) body['phone']       = phone;

    return await _patch('/auth/me/', body: body);
  }

  /// Change password.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _post(
      '/auth/change-password/',
      body: {'old_password': oldPassword, 'new_password': newPassword},
    );
  }

  /// Log out by clearing stored tokens.
  Future<void> logout() async {
    await _TokenStore.clear();
    debugPrint('[API] Logged out — tokens cleared');
  }

  /// Whether a stored access token exists (does not validate it).
  Future<bool> get isLoggedIn async =>
      (await _TokenStore.getAccess()) != null;

  // ══════════════════════════════════════════════════════════════════
  // FLIGHTS
  // ══════════════════════════════════════════════════════════════════

  /// Search for available flight offers via Duffel.
  ///
  /// Returns a list of offer maps. Each map contains:
  ///   - All raw Duffel fields (id, slices, total_amount, passengers…)
  ///   - A `_summary` key with pre-computed convenience fields:
  ///       origin, destination, departure_at, arrival_at,
  ///       carrier, flight_number, stops, duration,
  ///       total_price, base_price, currency, seats_available
  ///
  /// Example:
  ///   final offers = await api.searchFlights(
  ///     origin: 'ALG', destination: 'CDG',
  ///     departureDate: '2025-08-15', adults: 1,
  ///   );
  Future<List<Map<String, dynamic>>> searchFlights({
    required String origin,
    required String destination,
    required String departureDate, // YYYY-MM-DD
    int adults        = 1,
    int children      = 0,
    int infants       = 0,
    List<int> childrenAges = const [],
    String travelClass = 'ECONOMY',
    bool nonStop      = false,
    bool hasBaggage   = false,
    bool refundable   = false,
    String currency   = 'EUR',
    int maxResults    = 100,
    String? returnDate,
  }) async {
    final cacheKey =
        '${origin.toUpperCase()}|${destination.toUpperCase()}|$departureDate'
        '|$adults|$travelClass|${returnDate ?? ''}';
    final cached = _searchCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.at) < _cacheTtl) {
      debugPrint('[API] searchFlights cache hit: $cacheKey');
      return cached.data;
    }

    final query = <String, String>{
      'origin':         origin.toUpperCase(),
      'destination':    destination.toUpperCase(),
      'departure_date': departureDate,
      'adults':         adults.toString(),
      'children':       children.toString(),
      'infants':        infants.toString(),
      'travel_class':   travelClass,
      'non_stop':       nonStop.toString(),
      'has_baggage':    hasBaggage.toString(),
      'refundable':     refundable.toString(),
      'currency_code':  currency.toUpperCase(),
      'max_results':    maxResults.toString(),
    };
    if (returnDate != null) query['return_date'] = returnDate;
    if (childrenAges.isNotEmpty) {
      query['children_ages'] = childrenAges.join(',');
    }

    final data = await _get('/flights/search/', queryParams: query, requiresAuth: false);
    final results = (data['results'] as List<dynamic>).cast<Map<String, dynamic>>();
    _searchCache[cacheKey] = (data: results, at: DateTime.now());
    return results;
  }

  /// Confirm that a flight offer's price is still valid before booking.
  /// Always call this between search and booking — Duffel prices change.
  ///
  /// Returns the price-confirmed offer (same structure as searchFlights result).
  Future<Map<String, dynamic>> confirmFlightPrice(
    Map<String, dynamic> flightOffer,
  ) async {
    final data = await _post(
      '/flights/confirm-price/',
      body: {'flight_offer': flightOffer},
    );
    return data['data'] as Map<String, dynamic>;
  }

  // ══════════════════════════════════════════════════════════════════
  // RESERVATIONS
  // ══════════════════════════════════════════════════════════════════

  /// Create a reservation. This is the main booking flow:
  ///
  ///   1. Pass the raw Duffel `flightOffer` from searchFlights/confirmFlightPrice.
  ///   2. Pass a list of passenger maps (see PassengerInput.toMap()).
  ///   3. Set acceptPriceChange=true if you already showed the user a price
  ///      change warning and they confirmed.
  ///
  /// Returns the full Reservation map containing:
  ///   id, pnr, status, origin_iata, destination_iata, total_price,
  ///   currency, passengers, created_at …
  ///
  /// Throws:
  ///   PriceChangedException  — price changed; show user and re-submit
  ///   DuplicateBookingException — already booked this flight
  ///   ApiException(502)       — Duffel API error
  ///   ApiException(504)       — Duffel timeout
  Future<Map<String, dynamic>> createReservation({
    required Map<String, dynamic> flightOffer,
    required List<Map<String, dynamic>> passengers,
    bool acceptPriceChange = false,
    String paymentMethod = 'cash',
    String? promoCode,
  }) async {
    final data = await _post(
      '/reservations/',
      body: {
        'flight_offer':        flightOffer,
        'passengers':          passengers,
        'accept_price_change': acceptPriceChange,
        'payment_method':      paymentMethod,
        'promo_code': promoCode,
      },
    );
    return data['data'] as Map<String, dynamic>;
  }

  /// List the authenticated user's reservations.
  ///
  /// Optional filters: status ('pending'|'confirmed'|'cancelled'|'failed'), pnr
  Future<List<Map<String, dynamic>>> listReservations({
    String? status,
    String? pnr,
  }) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    if (pnr    != null) query['pnr']    = pnr;

    final data = await _get('/reservations/', queryParams: query);
    final results = data['results'] as List<dynamic>;
    return results.cast<Map<String, dynamic>>();
  }

  /// Get full detail of a single reservation (includes passenger list).
  Future<Map<String, dynamic>> getReservation(String reservationId) async {
    final data = await _get('/reservations/$reservationId/');
    return data['data'] as Map<String, dynamic>;
  }

  // ══════════════════════════════════════════════════════════════════
  // ADMIN
  // ══════════════════════════════════════════════════════════════════

  /// Summary stats for the admin dashboard.
  Future<Map<String, dynamic>> getAdminStats() async {
    return await _get('/admin/stats/');
  }

  /// List all users (admin only).
  Future<List<Map<String, dynamic>>> listAdminUsers() async {
    final data = await _get('/admin/users/');
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }

  /// Create a new user (admin only).
  Future<Map<String, dynamic>> createAdminUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String phone = '',
  }) async {
    return await _post('/admin/users/create/', body: {
      'email':      email,
      'password':   password,
      'password2':  password,
      'first_name': firstName,
      'last_name':  lastName,
      'phone':      phone,
      'role':       role,
    });
  }

  /// Update a user's role or active status (admin only).
  Future<Map<String, dynamic>> updateAdminUser(String userId, Map<String, dynamic> fields) async {
    return await _patch('/admin/users/$userId/', body: fields);
  }

  /// Delete a user (admin only).
  Future<void> deleteAdminUser(String userId) async {
    await _delete('/admin/users/$userId/');
  }

  /// List ALL reservations (admin only).
  Future<List<Map<String, dynamic>>> listAdminReservations({String? status}) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    final data = await _get('/admin/reservations/', queryParams: query);
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }

  // ══════════════════════════════════════════════════════════════════
  // AGENT
  // ══════════════════════════════════════════════════════════════════

  /// List all reservations (agent/admin).
  Future<List<Map<String, dynamic>>> listAgentReservations({String? status}) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    final data = await _get('/agent/reservations/', queryParams: query);
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }

  /// Confirm, emit, or cancel a reservation (agent action).
  Future<Map<String, dynamic>> updateReservationStatus(String reservationId, String status) async {
    final data = await _patch('/agent/reservations/$reservationId/', body: {'status': status});
    return data['data'] as Map<String, dynamic>;
  }

  /// Assign a livreur to deliver a reservation's ticket.
  Future<Map<String, dynamic>> assignLivreurToReservation(
      String reservationId, String livreurId) async {
    final data = await _patch(
      '/agent/reservations/$reservationId/',
      body: {'status': 'assign_livreur', 'livreur_id': livreurId},
    );
    return data['data'] as Map<String, dynamic>;
  }

  /// List all reservations assigned to a specific livreur (admin/agent view).
  Future<List<Map<String, dynamic>>> listLivreurBillets(String livreurId,
      {String? status}) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    final data = await _get('/agent/livreurs/$livreurId/billets/', queryParams: query);
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }

  /// List billets assigned to the authenticated livreur (livreur self-view).
  Future<List<Map<String, dynamic>>> listMyBillets({String? status}) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    final data = await _get('/livreurs/my-billets/', queryParams: query);
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }

  /// Create a reservation on behalf of a client (agent flow).
  Future<Map<String, dynamic>> createReservationForClient({
    required Map<String, dynamic> flightOffer,
    required List<Map<String, dynamic>> passengers,
    String? forUserId,
    String paymentMethod = 'cash',
    String? promoCode,
  }) async {
    final body = <String, dynamic>{
      'flight_offer':   flightOffer,
      'passengers':     passengers,
      'for_user_id':    forUserId,
      'payment_method': paymentMethod,
      'promo_code':     promoCode,
    };
    final data = await _post('/agent/reservations/', body: body);
    return data['data'] as Map<String, dynamic>;
  }

  // ══════════════════════════════════════════════════════════════════
  // FLIGHT CALENDAR
  // ══════════════════════════════════════════════════════════════════

  /// Fetches cheapest price + carrier for every (dep × ret) date cell in one call.
  /// Returns a map keyed "YYYY-MM-DD|YYYY-MM-DD" → {price, carrier_code} or null.
  Future<Map<String, dynamic>> getFlightCalendar({
    required String origin,
    required String destination,
    required String depStart,
    required String depEnd,
    required String retStart,
    required String retEnd,
    int adults      = 1,
    int children    = 0,
    int infants     = 0,
    String travelClass = 'ECONOMY',
  }) async {
    final data = await _get(
      '/flights/calendar/',
      queryParams: {
        'origin':       origin,
        'destination':  destination,
        'dep_start':    depStart,
        'dep_end':      depEnd,
        'ret_start':    retStart,
        'ret_end':      retEnd,
        'adults':       adults.toString(),
        'children':     children.toString(),
        'infants':      infants.toString(),
        'travel_class': travelClass.toLowerCase(),
      },
      requiresAuth: false,
    );
    return (data['cells'] as Map<String, dynamic>?) ?? {};
  }

  // ══════════════════════════════════════════════════════════════════
  // RECOMMENDATIONS (A priori)
  // ══════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getRecommendations(String origin, {String destination = ''}) async {
    try {
      final params = <String, String>{'origin': origin};
      if (destination.isNotEmpty) params['destination'] = destination;
      final data = await _get('/recommendations/', queryParams: params, requiresAuth: false);
      return (data['results'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // AIRPORTS
  // ══════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> searchAirports(String query) async {
    final data = await _get('/airports/', queryParams: {'query': query}, requiresAuth: false);
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  // ══════════════════════════════════════════════════════════════════
  // PROMO CODES
  // ══════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> validatePromoCode(String code, double amount) async {
    final data = await _post('/promo-codes/validate/',
        body: {'code': code, 'amount': amount.toStringAsFixed(2)});
    return data;
  }

  Future<List<Map<String, dynamic>>> listPromoCodes() async {
    final data = await _get('/admin/promo-codes/');
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createPromoCode(Map<String, dynamic> body) async {
    final data = await _post('/admin/promo-codes/', body: body);
    return data['data'] as Map<String, dynamic>;
  }

  Future<void> togglePromoCode(int id, bool isActive) async {
    await _patch('/admin/promo-codes/$id/', body: {'is_active': isActive});
  }

  Future<void> deletePromoCode(int id) async {
    await _delete('/admin/promo-codes/$id/');
  }

  /// Cancel a confirmed reservation. Syncs cancellation with Duffel.
  ///
  /// Returns the updated reservation map with status='cancelled'.
  Future<Map<String, dynamic>> cancelReservation(String reservationId) async {
    final data = await _delete('/reservations/$reservationId/');
    return data['data'] as Map<String, dynamic>;
  }

  // ══════════════════════════════════════════════════════════════════
  // DELIVERIES (LIVREUR & PACKAGES)
  // ══════════════════════════════════════════════════════════════════

  /// List packages assigned to the authenticated livreur.
  /// Optional filter by status: 'assigned', 'in_transit', 'delivered', etc.
  Future<Map<String, dynamic>> listAssignedPackages({String? status}) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    return await _get('/colis/', queryParams: query);
  }

  /// Get a specific package details by ID.
  Future<Map<String, dynamic>> getPackageDetail(String colisId) async {
    return await _get('/colis/$colisId/');
  }

  /// Update package status (e.g., mark as 'in_transit' or 'delivered').
  /// Can also add a delivery note.
  Future<Map<String, dynamic>> updatePackageStatus(
    String colisId, {
    required String status,
    String? deliveryNote,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (deliveryNote != null) body['delivery_note'] = deliveryNote;
    return await _patch('/colis/$colisId/', body: body);
  }

  /// Get the authenticated livreur's profile.
  Future<Map<String, dynamic>> getLivreurProfile() async {
    return await _get('/livreurs/');
  }

  /// Update the livreur's current location (latitude/longitude).
  Future<Map<String, dynamic>> updateLivreurLocation({
    required double latitude,
    required double longitude,
  }) async {
    return await _patch(
      '/livreurs/update-location/',
      body: {'latitude': latitude, 'longitude': longitude},
    );
  }

  /// List all sectors (geographic areas for deliveries).
  Future<Map<String, dynamic>> listSectors() async {
    return await _get('/sectors/', requiresAuth: false);
  }

  // ══════════════════════════════════════════════════════════════════
  // ADMIN — LIVREURS
  // ══════════════════════════════════════════════════════════════════

  /// List all livreurs (admin only). Optional filters: sector, status.
  Future<List<Map<String, dynamic>>> adminListLivreurs({
    String? sector,
    String? status,
  }) async {
    final query = <String, String>{};
    if (sector != null) query['sector'] = sector;
    if (status != null) query['status'] = status;
    final data = await _get('/livreurs/', queryParams: query);
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }

  /// Create a livreur account (admin only).
  Future<Map<String, dynamic>> adminCreateLivreur({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String sectorId,
    String vehicleType = 'motorcycle',
    String vehiclePlate = '',
    int maxPackagesPerDay = 50,
  }) async {
    return await _post('/livreurs/create/', body: {
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'sector_id': sectorId,
      'vehicle_type': vehicleType,
      'vehicle_plate': vehiclePlate,
      'max_packages_per_day': maxPackagesPerDay,
    });
  }

  // ══════════════════════════════════════════════════════════════════
  // ADMIN — COLIS (PACKAGES)
  // ══════════════════════════════════════════════════════════════════

  /// List all packages (admin). Optional filters: status, sector.
  Future<List<Map<String, dynamic>>> adminListColis({
    String? status,
    String? sector,
  }) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    if (sector != null) query['sector'] = sector;
    final data = await _get('/colis/', queryParams: query);
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }

  /// Create a new package (admin only). Auto-assigns to a livreur in the sector.
  Future<Map<String, dynamic>> adminCreateColis(Map<String, dynamic> body) async {
    return await _post('/colis/create/', body: body);
  }

  /// Manually assign (or override) a package to a specific livreur (admin only).
  Future<Map<String, dynamic>> adminAssignColis({
    required String colisId,
    required String livreurId,
  }) async {
    return await _post('/colis/assign/', body: {
      'colis_id': colisId,
      'livreur_id': livreurId,
    });
  }

  /// Register a new user with email verification.
  /// After registration, user must verify email before account is active.
  Future<Map<String, dynamic>> registerWithEmailVerification({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String phone = '',
  }) async {
    return await _post(
      '/auth/register-with-verification/',
      body: {
        'email': email,
        'password': password,
        'password2': password,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
      },
      requiresAuth: false,
    );
  }

  /// Verify email with a token sent to the user's inbox.
  Future<Map<String, dynamic>> verifyEmail(String token) async {
    return await _post(
      '/auth/verify-email/',
      body: {'token': token},
      requiresAuth: false,
    );
  }

  /// Resend the verification code to the given email.
  Future<void> resendVerificationCode(String email) async {
    await _post(
      '/auth/resend-verification/',
      body: {'email': email},
      requiresAuth: false,
    );
  }

  /// Send a 6-digit OTP to [email] for password reset.
  Future<void> forgotPassword(String email) async {
    await _post(
      '/auth/forgot-password/',
      body: {'email': email},
      requiresAuth: false,
    );
  }

  /// Reset password using the OTP received by email.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _post(
      '/auth/reset-password/',
      body: {'email': email, 'code': code, 'new_password': newPassword},
      requiresAuth: false,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // PRIVATE HTTP HELPERS
  // ══════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    final uri = _buildUri(path, queryParams);
    debugPrint('[API] GET $uri');
    final response = await _withRetry(() async => _http.get(
      uri,
      headers: await _headers(requiresAuth: requiresAuth),
    ));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
    bool requiresAuth = true,
  }) async {
    final uri = _buildUri(path);
    debugPrint('[API] POST $uri — ${body.keys.join(', ')}');
    final response = await _withRetry(() async => _http.post(
      uri,
      headers: await _headers(requiresAuth: requiresAuth),
      body: jsonEncode(body),
    ));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _patch(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final uri = _buildUri(path);
    debugPrint('[API] PATCH $uri');
    final response = await _withRetry(() async => _http.patch(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    ));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final uri = _buildUri(path);
    debugPrint('[API] DELETE $uri');
    final response = await _withRetry(() async => _http.delete(
      uri,
      headers: await _headers(),
    ));
    return _handleResponse(response);
  }

  // ── Token refresh ──────────────────────────────────────────────────────────

  /// Attempt a transparent token refresh.
  /// Called automatically when the server returns 401.
  Future<void> _refreshTokens() async {
    final refresh = await _TokenStore.getRefresh();
    if (refresh == null) throw const UnauthorizedException();

    final uri = _buildUri('/auth/refresh/');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh': refresh}),
        )
        .timeout(_kTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // Django rotates refresh tokens — save both
      await _TokenStore.save(
        access:  data['access'],
        refresh: data['refresh'] ?? refresh,
      );
      debugPrint('[API] Tokens refreshed successfully');
    } else {
      await _TokenStore.clear();
      throw const UnauthorizedException();
    }
  }

  // ── Request wrapper with auto-refresh ─────────────────────────────────────

  /// Execute [request], and if it returns 401, refresh tokens and retry once.
  Future<http.Response> _withRetry(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(_kTimeout);

      if (response.statusCode == 401) {
        debugPrint('[API] 401 received — attempting token refresh');
        await _refreshTokens();
        // Retry once with fresh token
        return await request().timeout(_kTimeout);
      }

      return response;
    } on SocketException {
      throw const NetworkException();
    } on HttpException {
      throw const NetworkException();
    } on TimeoutException {
      throw const ApiException(
        'Le serveur met trop de temps à répondre.',
        statusCode: 504,
        code: 'GATEWAY_TIMEOUT',
      );
    }
  }

  // ── Response parsing ──────────────────────────────────────────────────────

  static dynamic _decodeJson(String raw) => jsonDecode(raw);

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    debugPrint('[API] ← ${response.statusCode} (${response.body.length} bytes)');

    if (response.statusCode == 204) return {};

    Map<String, dynamic> body;
    try {
      // Offload heavy JSON (> 50 KB) to a background isolate
      final dynamic decoded = response.body.length > 50000
          ? await compute(_decodeJson, response.body)
          : jsonDecode(response.body);
      body = decoded as Map<String, dynamic>;
    } catch (_) {
      if (response.statusCode >= 200 && response.statusCode < 300) return {};
      throw ApiException(
        'Réponse invalide du serveur.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    // ── Map Django error codes to typed exceptions ────────────────────────
    final code   = body['code']   as String?;
    final detail = body['detail'] as String? ?? 'Une erreur est survenue.';

    switch (code) {
      case 'PRICE_CHANGED':
        throw PriceChangedException(
          oldPrice: body['old_price']?.toString() ?? '?',
          newPrice: body['new_price']?.toString() ?? '?',
          currency: body['currency']?.toString() ?? 'EUR',
        );
      case 'DUPLICATE_BOOKING':
        throw DuplicateBookingException(detail);
      case 'UNAUTHORIZED':
        throw UnauthorizedException(detail);
    }

    switch (response.statusCode) {
      case 401:
        throw UnauthorizedException(detail);
      case 404:
        throw ApiException(detail, statusCode: 404, code: 'NOT_FOUND');
      case 409:
        throw ApiException(detail, statusCode: 409, code: code);
      case 502:
        throw ApiException(detail, statusCode: 502, code: 'DUFFEL_ERROR');
      case 504:
        throw ApiException(
          'Le service de réservation est temporairement indisponible.',
          statusCode: 504,
          code: 'GATEWAY_TIMEOUT',
        );
      default:
        throw ApiException(detail, statusCode: response.statusCode, code: code);
    }
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final full = '$_base$path';
    final uri  = Uri.parse(full);
    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  Future<Map<String, String>> _headers({bool requiresAuth = true}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept':       'application/json',
    };
    if (requiresAuth) {
      final token = await _TokenStore.getAccess();
      if (token != null) {
        h['Authorization'] = 'Bearer $token';
      }
    }
    return h;
  }
}

// ─── Data Transfer Objects ─────────────────────────────────────────────────────
// Use these to build the passenger payload for createReservation().

class PassengerInput {
  final String firstName;
  final String lastName;
  final String dateOfBirth;   // YYYY-MM-DD
  final String gender;        // 'M' | 'F' | 'O'
  final String nationality;   // ISO 3166-1 alpha-2, e.g. 'DZ'
  final String passengerType; // 'adult' | 'child' | 'infant'
  final String email;
  final String phone;
  final String phoneCountryCode; // e.g. '213' for Algeria
  final String passportNumber;
  final String passportExpiry;   // YYYY-MM-DD
  final String passportCountry;  // ISO 3166-1 alpha-2

  const PassengerInput({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.nationality,
    required this.passengerType,
    required this.email,
    required this.phone,
    required this.phoneCountryCode,
    required this.passportNumber,
    required this.passportExpiry,
    required this.passportCountry,
  });

  Map<String, dynamic> toMap() => {
    'first_name':          firstName,
    'last_name':           lastName,
    'date_of_birth':       dateOfBirth,
    'gender':              gender,
    'nationality':         nationality,
    'passenger_type':      passengerType,
    'email':               email,
    'phone':               phone,
    'phone_country_code':  phoneCountryCode,
    'passport_number':     passportNumber,
    'passport_expiry':     passportExpiry,
    'passport_country':    passportCountry,
  };
}

/// Helper to convert a Django reservation map into your local Booking model.
///
/// Usage:
///   final booking = ReservationMapper.toBooking(reservationMap);
class ReservationMapper {
  static Map<String, dynamic> summary(Map<String, dynamic> reservation) {
    return {
      'id':         reservation['id'],
      'pnr':        reservation['pnr'],
      'status':     reservation['status'],
      'from':       reservation['origin_iata'],
      'to':         reservation['destination_iata'],
      'departure':  reservation['departure_datetime'],
      'arrival':    reservation['arrival_datetime'],
      'flight':     reservation['flight_number'],
      'cabin':      reservation['cabin_class'],
      'price':      reservation['total_price'],
      'currency':   reservation['currency'],
      'passengers': reservation['passengers'] ?? [],
      'created_at': reservation['created_at'],
    };
  }
}
