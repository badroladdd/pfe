import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/models/flight.dart';
import 'package:myapp/screens/flights/flights_result_screen.dart';
import 'package:myapp/widgets/airport_search_field.dart';
import 'package:myapp/widgets/loading_overlay.dart';

const _kBlue = Color(0xFF2B5FF8);

class HomeScreen extends StatefulWidget {
  final VoidCallback onBookingCreated;
  const HomeScreen({super.key, required this.onBookingCreated});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSearching = false;

  // 0=Aller Simple, 1=Aller-Retour, 2=Multi-dest
  int _tripType = 0;

  String _fromCode  = 'ALG';
  String _fromLabel = 'Origine';
  bool   _fromSelected = false;
  String _toCode    = 'CDG';
  String _toLabel   = 'Destination';
  bool   _toSelected   = false;

  DateTime? _departureDate;
  DateTime? _returnDate;

  int       _adults       = 1;
  int       _children     = 0;
  List<int> _childrenAges = [];
  String    _flightClass  = 'Economique';

  bool isDirect     = false;
  bool hasBaggage   = false;
  bool isRefundable = false;

  final ApiClient _api = ApiClient();
  String _firstName = '';

  @override
  void initState() {
    super.initState();
    _departureDate = DateTime.now().add(const Duration(days: 7));
    _returnDate    = DateTime.now().add(const Duration(days: 14));
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final loggedIn = await _api.isLoggedIn;
      if (!loggedIn || !mounted) return;
      final profile = await _api.getProfile();
      if (mounted) {
        setState(() {
          _firstName = (profile['first_name'] ?? '').toString().trim();
        });
      }
    } catch (_) {}
  }

  String _formatDisplayDate(DateTime? date) {
    if (date == null) return 'Date de départ';
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day} ${date.year}';
  }

  String _formatReturnDate(DateTime? date) {
    if (date == null) return 'Date de retour';
    return _formatDisplayDate(date);
  }

  String _formatApiDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool _isIataCode(String v) =>
      RegExp(r'^[A-Za-z]{3}$').hasMatch(v.trim());

  String _toTravelClass(String v) {
    switch (v) {
      case 'Affaires': return 'BUSINESS';
      case 'Première': return 'FIRST';
      default:         return 'ECONOMY';
    }
  }


  Future<void> _searchFlights() async {
    if (!_isIataCode(_fromCode) || !_isIataCode(_toCode)) {
      _snack('Veuillez sélectionner des aéroports valides.');
      return;
    }
    if (_fromCode.toUpperCase() == _toCode.toUpperCase()) {
      _snack('L\'aéroport de départ et d\'arrivée doit être différent.');
      return;
    }
    if (_departureDate == null) {
      _snack('Veuillez sélectionner une date de départ.');
      return;
    }
    if (_tripType == 1 && _returnDate == null) {
      _snack('Veuillez sélectionner une date de retour.');
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _api.searchFlights(
        origin:        _fromCode.toUpperCase(),
        destination:   _toCode.toUpperCase(),
        departureDate: _formatApiDate(_departureDate!),
        adults:        _adults,
        children:      _children,
        infants:       0,
        childrenAges:  _childrenAges,
        travelClass:   _toTravelClass(_flightClass),
        nonStop:       isDirect,
        hasBaggage:    hasBaggage,
        refundable:    isRefundable,
        returnDate:    _tripType == 1 ? _formatApiDate(_returnDate!) : null,
      );
      final validOffers = results.where((o) => o['_summary'] != null).toList();
      final flights = validOffers.map((offer) {
        final s = offer['_summary'] as Map<String, dynamic>;
        return Flight(
          from:         s['origin']?.toString() ?? '',
          to:           s['destination']?.toString() ?? '',
          date:         (s['departure_at']?.toString() ?? '').split('T')[0],
          passengers:   _adults.toString(),
          flightClass:  _flightClass,
          isDirect:     (s['stops'] ?? 1) == 0,
          hasBaggage:   s['has_baggage'] == true,
          isRefundable: s['is_refundable'] == true,
          price:        double.tryParse(s['total_price']?.toString() ?? '0') ?? 0,
          departureAt:  s['departure_at']?.toString() ?? '',
          arrivalAt:    s['arrival_at']?.toString() ?? '',
        );
      }).toList();
      if (flights.isEmpty) { _snack('Aucun vol trouvé pour ces critères.'); return; }
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => FlightsResultScreen(
          flights:                flights,
          rawOffers:              validOffers,
          passengersCount:        _adults + _children,
          onBookingCreated:       widget.onBookingCreated,
          initialFrom:            _fromCode,
          initialTo:              _toCode,
          initialDepartureDate:   _departureDate != null
              ? _departureDate!.toIso8601String().split('T')[0]
              : '',
          initialReturnDate:      _tripType == 1 && _returnDate != null
              ? _returnDate!.toIso8601String().split('T')[0]
              : null,
          initialFlightClass:     _flightClass,
          initialPassengers:      _adults + _children,
        ),
      ));
    } catch (e) {
      _snack('Erreur de recherche: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _swapAirports() {
    if (!_fromSelected && !_toSelected) return;
    setState(() {
      final tc = _fromCode; final tl = _fromLabel; final ts = _fromSelected;
      _fromCode = _toCode; _fromLabel = _toLabel; _fromSelected = _toSelected;
      _toCode = tc; _toLabel = tl; _toSelected = ts;
    });

  }

  Future<void> _pickAirport({required bool isFrom}) async {
    final result = await showAirportSearch(context, label: isFrom ? 'Départ' : 'Arrivée');
    if (result == null || !mounted) return;
    final code  = result['iata'] ?? '';
    final city  = result['city'] ?? '';
    final label = city.isNotEmpty ? '$city ($code)' : code;
    setState(() {
      if (isFrom) { _fromCode = code; _fromLabel = label; _fromSelected = true; }
      else        { _toCode   = code; _toLabel   = label; _toSelected   = true; }
    });

  }

  Future<void> _pickDate({required bool isDeparture}) async {
    final initial = isDeparture
        ? (_departureDate ?? DateTime.now())
        : (_returnDate ?? (_departureDate?.add(const Duration(days: 1)) ?? DateTime.now()));
    final first = isDeparture ? DateTime.now() : (_departureDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate:   first,
      lastDate:    DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isDeparture) {
        _departureDate = picked;
        if (_returnDate != null && _returnDate!.isBefore(picked)) {
          _returnDate = picked.add(const Duration(days: 1));
        }
      } else {
        _returnDate = picked;
      }
    });
  }

  void _showPassengerDialog() {
    int adults = _adults;
    int children = _children;
    List<int> childrenAges = List.from(_childrenAges);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          void changeChildren(int delta) {
            final next = (children + delta).clamp(0, 8);
            if (next > children) {
              showDialog<int>(
                context: ctx,
                builder: (_) {
                  int selectedAge = 5;
                  return StatefulBuilder(
                    builder: (ageCtx, setAge) => AlertDialog(
                      title: const Text('Âge de l\'enfant'),
                      content: SizedBox(
                        height: 120,
                        child: DropdownButton<int>(
                          value: selectedAge,
                          isExpanded: true,
                          items: List.generate(10, (i) => i + 2)
                              .map((age) => DropdownMenuItem(value: age, child: Text('$age ans')))
                              .toList(),
                          onChanged: (v) => setAge(() => selectedAge = v!),
                        ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ageCtx), child: const Text('Annuler')),
                        ElevatedButton(onPressed: () => Navigator.pop(ageCtx, selectedAge), child: const Text('Confirmer')),
                      ],
                    ),
                  );
                },
              ).then((age) {
                if (age != null) setDlg(() { children = next; childrenAges.add(age); });
              });
            } else {
              setDlg(() { children = next; if (childrenAges.isNotEmpty) childrenAges.removeLast(); });
            }
          }

          return AlertDialog(
            title: const Text('Passagers'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _passengerRow('Adultes', '12 ans et +', adults,
                    onMinus: adults > 1 ? () => setDlg(() => adults--) : null,
                    onPlus:  adults < 9 ? () => setDlg(() => adults++) : null),
                const Divider(height: 24),
                _passengerRow('Enfants', '2 – 11 ans', children,
                    onMinus: children > 0 ? () => changeChildren(-1) : null,
                    onPlus:  children < 8 ? () => changeChildren(1)  : null),
                if (childrenAges.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, children: childrenAges.asMap().entries.map((e) =>
                    Chip(label: Text('Enfant ${e.key+1}: ${e.value} ans', style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.blue.shade50)).toList()),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  setState(() { _adults = adults; _children = children; _childrenAges = childrenAges; });
                  Navigator.pop(ctx);
                },
                child: const Text('Confirmer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _passengerRow(String title, String subtitle, int count,
      {VoidCallback? onMinus, VoidCallback? onPlus}) {
    return Row(
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ])),
        IconButton(onPressed: onMinus,
            icon: Icon(Icons.remove_circle_outline,
                color: onMinus != null ? Colors.blue : Colors.grey.shade300)),
        SizedBox(width: 28,
            child: Text('$count', textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        IconButton(onPressed: onPlus,
            icon: Icon(Icons.add_circle_outline,
                color: onPlus != null ? Colors.blue : Colors.grey.shade300)),
      ],
    );
  }

  void _showClassDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Classe de voyage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Economique', 'Affaires', 'Première'].map((v) => ListTile(
                title: Text(v),
                onTap: () { setState(() => _flightClass = v); Navigator.pop(ctx); },
              )).toList(),
        ),
      ),
    );
  }

  String get _passengersLabel {
    final parts = <String>[];
    if (_adults   > 0) parts.add('$_adults Siège${_adults > 1 ? 's' : ''}');
    if (_children > 0) parts.add('$_children Enfant${_children > 1 ? 's' : ''}');
    return parts.isEmpty ? 'Sièges' : parts.join(', ');
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isSearching,
      message: 'Recherche de vols…',
      child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header avec world map (hauteur fixe) ────────────────────────
          Stack(
            children: [
              // World map zoomée et centrée
              Positioned.fill(
                child: ClipRect(
                  child: Transform.scale(
                    scale: 1.8,
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/images/download.jpg',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),
              // Overlay bleu
              Positioned.fill(
                child: ColoredBox(color: _kBlue.withValues(alpha: 0.85)),
              ),
              // Contenu
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: _buildHeader(),
              ),
            ],
          ),
          // ── Carte de recherche sur fond bleu solide ──────────────────────
          Container(
            color: _kBlue,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: _buildSearchCard(),
          ),
          // ── Light grey body ──────────────────────────────────────────────
          Container(
            color: const Color(0xFFF4F6FF),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: _buildSpecialOffers(),
          ),
        ],
      ),
    ),
  );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _firstName.isNotEmpty ? 'Bienvenue, $_firstName' : 'Bienvenue',
                style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        // Bell
        Stack(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38, width: 1.5),
              ),
              child: const Icon(Icons.notifications_outlined,
                  color: Colors.white, size: 22),
            ),
            Positioned(
              top: 8, right: 8,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Search card ───────────────────────────────────────────────────────────────

  Widget _buildSearchCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTripTabs(),
          const SizedBox(height: 18),
          _buildFromToSection(),
          const SizedBox(height: 12),
          _buildDateField(
            label: 'Date de départ',
            value: _departureDate == null
                ? 'Date de départ'
                : _formatDisplayDate(_departureDate),
            isPlaceholder: _departureDate == null,
            onTap: () => _pickDate(isDeparture: true),
          ),
          if (_tripType == 1) ...[
            const SizedBox(height: 12),
            _buildDateField(
              label: 'Date de retour',
              value: _returnDate == null
                  ? 'Date de retour'
                  : _formatReturnDate(_returnDate),
              isPlaceholder: _returnDate == null,
              onTap: () => _pickDate(isDeparture: false),
            ),
          ],
          const SizedBox(height: 12),
          _buildPassengerClassRow(),
          const SizedBox(height: 12),
          _buildQuickFilters(),
          const SizedBox(height: 20),
          _buildSearchButton(),
        ],
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────────

  Widget _buildTripTabs() {
    final tabs = ['Aller Simple', 'Aller-Retour'];
    return Row(
      children: tabs.asMap().entries.map((e) {
        final active = _tripType == e.key;
        return Padding(
          padding: EdgeInsets.only(right: e.key < tabs.length - 1 ? 8 : 0),
          child: GestureDetector(
            onTap: () => setState(() => _tripType = e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: active ? _kBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: active ? _kBlue : Colors.grey.shade300,
                ),
              ),
              child: Text(
                e.value,
                style: TextStyle(
                  color: active ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── From / To ─────────────────────────────────────────────────────────────────

  Widget _buildFromToSection() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            GestureDetector(
              onTap: () => _pickAirport(isFrom: true),
              child: _fieldBox(
                label: 'Départ',
                value: _fromSelected ? _fromLabel : 'Origine',
                icon: Icons.flight_takeoff,
                isPlaceholder: !_fromSelected,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _pickAirport(isFrom: false),
              child: _fieldBox(
                label: 'Destination',
                value: _toSelected ? _toLabel : 'Destination',
                icon: Icons.flight_land,
                isPlaceholder: !_toSelected,
              ),
            ),
          ],
        ),
        Positioned(
          right: 14,
          width: 44,
          top: 0,
          bottom: 0,
          child: Center(
            child: GestureDetector(
              onTap: _swapAirports,
              child: Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(
                    color: _kBlue, shape: BoxShape.circle),
                child: const Icon(Icons.swap_vert,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Date field ────────────────────────────────────────────────────────────────

  Widget _buildDateField({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool isPlaceholder = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _fieldBox(
        label: label,
        value: value,
        icon: Icons.calendar_month_outlined,
        isPlaceholder: isPlaceholder,
      ),
    );
  }

  // ── Passenger + Class ──────────────────────────────────────────────────────────

  Widget _buildPassengerClassRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _showPassengerDialog,
            child: _fieldBox(
              label: 'Passagers',
              value: _passengersLabel,
              icon: Icons.person_outline,
              isPlaceholder: _adults == 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _showClassDialog,
            child: _fieldBox(
              label: 'Classe',
              value: _flightClass,
              icon: Icons.airline_seat_recline_normal_outlined,
              isPlaceholder: false,
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared field box ───────────────────────────────────────────────────────────

  Widget _fieldBox({
    required String label,
    required String value,
    required IconData icon,
    bool isPlaceholder = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: isPlaceholder
                      ? Colors.grey.shade400
                      : Colors.black87),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isPlaceholder
                        ? FontWeight.w400
                        : FontWeight.w600,
                    color: isPlaceholder
                        ? Colors.grey.shade400
                        : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Quick filters ─────────────────────────────────────────────────────────────

  Widget _buildQuickFilters() {
    Widget chip(String label, IconData icon, bool active, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? _kBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: active ? _kBlue : Colors.grey.shade300),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: active ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: active ? Colors.white : Colors.grey.shade700,
            )),
          ]),
        ),
      );
    }

    return Row(children: [
      chip('Direct', Icons.flight, isDirect,
          () => setState(() => isDirect = !isDirect)),
      const SizedBox(width: 8),
      chip('Bagages', Icons.luggage, hasBaggage,
          () => setState(() => hasBaggage = !hasBaggage)),
      const SizedBox(width: 8),
      chip('Remboursable', Icons.replay, isRefundable,
          () => setState(() => isRefundable = !isRefundable)),
    ]);
  }

  // ── Search button ──────────────────────────────────────────────────────────────

  Widget _buildSearchButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _searchFlights,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kBlue,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: const Text(
          'Rechercher des vols',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Special offers ─────────────────────────────────────────────────────────────

  Widget _buildSpecialOffers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Offres spéciales',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Row(
                children: [
                  Text('Voir tout',
                      style: TextStyle(
                          color: _kBlue, fontWeight: FontWeight.w600)),
                  Icon(Icons.chevron_right, color: _kBlue, size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Promo banner card
        Container(
          height: 140,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A47CC), Color(0xFF3B82F6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('25% DE RÉDUCTION',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Sur tous les vols internationaux',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13)),
                  ],
                ),
              ),
              Positioned(
                right: -10,
                top: 0,
                bottom: 0,
                child: Opacity(
                  opacity: 0.3,
                  child: const Icon(Icons.flight,
                      size: 100, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
