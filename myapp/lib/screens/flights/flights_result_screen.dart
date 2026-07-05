import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/data/airports.dart';
import 'package:myapp/models/flight.dart';
import 'package:myapp/screens/flights/flight_detail_screen.dart';
import 'package:myapp/utils/currency.dart';
import 'package:myapp/widgets/airport_search_field.dart';
import 'package:myapp/widgets/airline_logo.dart';

const _kBlue = Color(0xFF3B82F6);

class FlightsResultScreen extends StatefulWidget {
  final List<Flight> flights;
  final List<Map<String, dynamic>> rawOffers;
  final int passengersCount;
  final VoidCallback onBookingCreated;
  final String? forUserId;
  final String initialFrom;
  final String initialTo;
  final String initialDepartureDate;
  final String? initialReturnDate;
  final String initialFlightClass;
  final int initialPassengers;

  const FlightsResultScreen({
    super.key,
    required this.flights,
    required this.rawOffers,
    required this.passengersCount,
    required this.onBookingCreated,
    this.forUserId,
    this.initialFrom = '',
    this.initialTo = '',
    this.initialDepartureDate = '',
    this.initialReturnDate,
    this.initialFlightClass = 'Economique',
    this.initialPassengers = 1,
  });

  @override
  State<FlightsResultScreen> createState() => _FlightsResultScreenState();
}

class _FlightsResultScreenState extends State<FlightsResultScreen> {
  final _scrollCtrl = ScrollController();
  final _api = ApiClient();
  bool _showCompactRoute = false;
  bool _searching = false;

  List<Flight> _flights = [];
  List<Map<String, dynamic>> _rawOffers = [];

  // ── Computed caches — cleared on every setState ───────────────────────────
  List<int>?    _cachedIndices;
  List<String>? _cachedCarriers;

  @override
  void setState(VoidCallback fn) {
    _cachedIndices  = null;
    _cachedCarriers = null;
    super.setState(fn);
  }

  // ── Current search params (updated after each _doSearch) ──────────────────
  String    _currentFrom        = '';
  String    _currentTo          = '';
  String    _currentDepartureDate = '';
  String?   _currentReturnDate;
  String    _currentFlightClass  = 'Economique';
  int       _currentPassengers   = 1;
  int       _currentChildren = 0;
  int       _currentInfants  = 0;

  String _sortBy = 'price_asc';

  // ── Filter state ────────────────────────────────────────────────────────────
  double _priceMin = 0;
  double _priceMax = 9999999;
  RangeValues _priceRange = const RangeValues(0, 9999999);
  Set<String> _stopsFilter    = {'direct', '1stop', '2plus'};
  Set<String> _selectedCarriers = {};
  Set<String> _arrivalSlots   = {'early', 'morning', 'afternoon', 'evening'};
  Set<String> _departureSlots = {'early', 'morning', 'afternoon', 'evening'};
  bool _filterRefundable = false;
  bool _filterReschedule = false;

  static const _sortOptions = [
    ('price_asc',    'Prix le plus bas'),
    ('direct_first', 'Directs en premier'),
    ('dep_earliest', 'Départ le plus tôt'),
    ('dep_latest',   'Départ le plus tard'),
    ('arr_earliest', 'Arrivée la plus tôt'),
    ('arr_latest',   'Arrivée la plus tard'),
    ('duration_asc', 'Durée la plus courte'),
  ];

  @override
  void initState() {
    super.initState();
    _flights              = List.from(widget.flights);
    _rawOffers            = List.from(widget.rawOffers);
    _currentFrom          = widget.initialFrom;
    _currentTo            = widget.initialTo;
    _currentDepartureDate = widget.initialDepartureDate;
    _currentReturnDate    = widget.initialReturnDate;
    _currentFlightClass   = widget.initialFlightClass;
    _currentPassengers    = widget.initialPassengers;
    _currentChildren = 0;
    _currentInfants  = 0;
    _scrollCtrl.addListener(() {
      final collapsed = _scrollCtrl.offset > 120;
      if (collapsed != _showCompactRoute) {
        setState(() => _showCompactRoute = collapsed);
      }
    });
    _initFilters();
  }

  Future<void> _doSearch({
    required String fromCode,
    required String toCode,
    required DateTime departureDate,
    DateTime? returnDate,
    required int passengers,
    required int children,
    required int infants,
    required String flightClass,
  }) async {
    if (fromCode.isEmpty || toCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner les aéroports de départ et d\'arrivée.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _searching = true);
    try {
      String travelClass;
      switch (flightClass) {
        case 'Affaires': travelClass = 'BUSINESS'; break;
        case 'Première': travelClass = 'FIRST';    break;
        default:         travelClass = 'ECONOMY';
      }
      String fmt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

      final results = await _api.searchFlights(
        origin:        fromCode,
        destination:   toCode,
        departureDate: fmt(departureDate),
        adults:        passengers,
        children:      children,
        infants:       infants,
        travelClass:   travelClass,
        returnDate:    returnDate != null ? fmt(returnDate) : null,
      );

      final validOffers = results.where((o) => o['_summary'] != null).toList();
      final newFlights = validOffers.map((offer) {
        final s = offer['_summary'] as Map<String, dynamic>;
        return Flight(
          from:         s['origin']?.toString()      ?? '',
          to:           s['destination']?.toString() ?? '',
          date:         (s['departure_at']?.toString() ?? '').split('T')[0],
          passengers:   passengers.toString(),
          flightClass:  flightClass,
          isDirect:     (s['stops'] ?? 1) == 0,
          hasBaggage:   s['has_baggage']  == true,
          isRefundable: s['is_refundable'] == true,
          price:        double.tryParse(s['total_price']?.toString() ?? '0') ?? 0,
          departureAt:  s['departure_at']?.toString() ?? '',
          arrivalAt:    s['arrival_at']?.toString()   ?? '',
        );
      }).toList();

      if (!mounted) return;

      final prices = newFlights.map((f) => f.price).toList();
      double newMin = prices.isEmpty ? 0.0   : prices.reduce((a, b) => a < b ? a : b);
      double newMax = prices.isEmpty ? 100000.0 : prices.reduce((a, b) => a > b ? a : b);
      if (newMin == newMax) newMax = newMin + 1;

      final newCarriers = <String>{};
      for (final o in validOffers) {
        final c = (o['_summary'] as Map<String, dynamic>?)?['carrier']?.toString() ?? '';
        if (c.isNotEmpty) newCarriers.add(c);
      }

      setState(() {
        _flights              = newFlights;
        _rawOffers            = validOffers;
        _searching            = false;
        _currentFrom          = fromCode;
        _currentTo            = toCode;
        _currentDepartureDate = fmt(departureDate);
        _currentReturnDate    = returnDate != null ? fmt(returnDate) : null;
        _currentFlightClass   = flightClass;
        _currentPassengers = passengers;
        _currentChildren   = children;
        _currentInfants    = infants;
        _priceMin         = newMin;
        _priceMax         = newMax;
        _priceRange       = RangeValues(newMin, newMax);
        _selectedCarriers = newCarriers;
        _stopsFilter      = {'direct', '1stop', '2plus'};
        _arrivalSlots     = {'early', 'morning', 'afternoon', 'evening'};
        _departureSlots   = {'early', 'morning', 'afternoon', 'evening'};
        _filterRefundable = false;
        _filterReschedule = false;
        _sortBy           = 'price_asc';
      });
      _scrollCtrl.jumpTo(0);
    } catch (e) {
      if (mounted) {
        setState(() => _searching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _initFilters() {
    final prices = _flights.map((f) => f.price).toList();
    _priceMin = prices.isEmpty ? 0 : prices.reduce((a, b) => a < b ? a : b);
    _priceMax = prices.isEmpty ? 100000 : prices.reduce((a, b) => a > b ? a : b);
    if (_priceMin == _priceMax) _priceMax = _priceMin + 1;
    _priceRange = RangeValues(_priceMin, _priceMax);
    _selectedCarriers = Set.from(_allCarriers);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _cityName(String iata) {
    try {
      return kAirports
          .firstWhere((a) => a.iata == iata.toUpperCase())
          .city;
    } catch (_) {
      return iata;
    }
  }

  List<String> get _allCarriers => _cachedCarriers ??= _computeAllCarriers();

  List<String> _computeAllCarriers() {
    final set = <String>{};
    for (final offer in _rawOffers) {
      final c = (offer['_summary'] as Map<String, dynamic>?)?['carrier']?.toString() ?? '';
      if (c.isNotEmpty) set.add(c);
    }
    return set.toList()..sort();
  }

  bool get _hasActiveFilters {
    final all = _allCarriers;
    return _priceRange.start > _priceMin ||
        _priceRange.end < _priceMax ||
        _stopsFilter.length < 3 ||
        _selectedCarriers.length < all.length ||
        _arrivalSlots.length < 4 ||
        _departureSlots.length < 4 ||
        _filterRefundable ||
        _filterReschedule;
  }

  int _durationMinutes(String? dep, String? arr) {
    if (dep == null || arr == null) return 0;
    try {
      return DateTime.parse(arr).difference(DateTime.parse(dep)).inMinutes;
    } catch (_) {
      return 0;
    }
  }

  String _timeSlot(String iso) {
    try {
      final h = DateTime.parse(iso).toLocal().hour;
      if (h < 6)  return 'early';
      if (h < 12) return 'morning';
      if (h < 18) return 'afternoon';
      return 'evening';
    } catch (_) { return 'morning'; }
  }

  List<int> get _filteredIndices => _cachedIndices ??= _computeFilteredIndices();

  List<int> _computeFilteredIndices() {
    List<int> indices = List.generate(_flights.length, (i) => i);

    // Price
    indices = indices.where((i) {
      final p = _flights[i].price;
      return p >= _priceRange.start && p <= _priceRange.end;
    }).toList();

    // Stops
    if (_stopsFilter.length < 3) {
      indices = indices.where((i) {
        final s = _rawOffers[i]['_summary'] as Map<String, dynamic>?;
        final stops = (s?['stops'] as num?)?.toInt() ?? (_flights[i].isDirect ? 0 : 1);
        if (stops == 0 && _stopsFilter.contains('direct')) return true;
        if (stops == 1 && _stopsFilter.contains('1stop'))  return true;
        if (stops >= 2 && _stopsFilter.contains('2plus'))  return true;
        return false;
      }).toList();
    }

    // Airlines
    final allC = _allCarriers;
    if (_selectedCarriers.length < allC.length) {
      indices = indices.where((i) {
        final c = (_rawOffers[i]['_summary'] as Map<String, dynamic>?)?['carrier']?.toString() ?? '';
        return _selectedCarriers.contains(c);
      }).toList();
    }

    // Departure time
    if (_departureSlots.length < 4) {
      indices = indices.where((i) =>
        _departureSlots.contains(_timeSlot(_flights[i].departureAt))
      ).toList();
    }

    // Arrival time
    if (_arrivalSlots.length < 4) {
      indices = indices.where((i) =>
        _arrivalSlots.contains(_timeSlot(_flights[i].arrivalAt))
      ).toList();
    }

    // Refundable
    if (_filterRefundable) {
      indices = indices.where((i) {
        final s = _rawOffers[i]['_summary'] as Map<String, dynamic>?;
        return s?['refundable'] == true;
      }).toList();
    }

    // Reschedule
    if (_filterReschedule) {
      indices = indices.where((i) {
        final s = _rawOffers[i]['_summary'] as Map<String, dynamic>?;
        return s?['reschedule'] == true;
      }).toList();
    }

    indices.sort((a, b) {
      final fa = _flights[a];
      final fb = _flights[b];
      switch (_sortBy) {
        case 'price_asc':
          return fa.price.compareTo(fb.price);
        case 'direct_first':
          if (fa.isDirect == fb.isDirect) return 0;
          return fa.isDirect ? -1 : 1;
        case 'dep_earliest':
          return fa.departureAt.compareTo(fb.departureAt);
        case 'dep_latest':
          return fb.departureAt.compareTo(fa.departureAt);
        case 'arr_earliest':
          return fa.arrivalAt.compareTo(fb.arrivalAt);
        case 'arr_latest':
          return fb.arrivalAt.compareTo(fa.arrivalAt);
        case 'duration_asc':
          return _durationMinutes(fa.departureAt, fa.arrivalAt)
              .compareTo(_durationMinutes(fb.departureAt, fb.arrivalAt));
        default:
          return fa.price.compareTo(fb.price);
      }
    });
    return indices;
  }

  void _showEditSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSearchSheet(
        initialFrom:          _currentFrom.isNotEmpty ? _currentFrom : (_flights.isNotEmpty ? _flights.first.from : ''),
        initialTo:            _currentTo.isNotEmpty   ? _currentTo   : (_flights.isNotEmpty ? _flights.first.to   : ''),
        initialDepartureDate: _currentDepartureDate,
        initialReturnDate:    _currentReturnDate,
        initialFlightClass:   _currentFlightClass,
        initialPassengers:    _currentPassengers,
        initialChildren: _currentChildren,
        initialInfants:  _currentInfants,
        onSearch: _doSearch,
      ),
    );
  }

  void _showSortSheet() {
    String tempSort = _sortBy;
    final sheetHeight = MediaQuery.of(context).size.height * 0.72;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => SizedBox(
          height: sheetHeight,
          child: Column(
            children: [
              // ── Handle ───────────────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Trier',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              Divider(height: 20, color: Colors.grey.shade200),

              // ── Options (scrollable) ──────────────────────────────────
              Expanded(
                child: ListView(
                  children: _sortOptions.map((opt) => RadioListTile<String>(
                    value: opt.$1,
                    groupValue: tempSort,
                    activeColor: _kBlue,
                    onChanged: (v) => setModal(() => tempSort = v!),
                    title: Text(opt.$2,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                  )).toList(),
                ),
              ),

              // ── Buttons ───────────────────────────────────────────────
              Divider(height: 1, color: Colors.grey.shade200),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Annuler',
                            style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _sortBy = tempSort);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Appliquer',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    RangeValues tempPrice    = _priceRange;
    Set<String> tempStops    = Set.from(_stopsFilter);
    Set<String> tempCarriers = Set.from(_selectedCarriers);
    Set<String> tempArrival  = Set.from(_arrivalSlots);
    Set<String> tempDep      = Set.from(_departureSlots);
    bool tempRefundable      = _filterRefundable;
    bool tempReschedule      = _filterReschedule;
    final allCarriers        = _allCarriers;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          final sheetH = MediaQuery.of(context).size.height * 0.9;

          Widget section(String title, {String? trailing, VoidCallback? onTrailing, required Widget child}) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  if (trailing != null)
                    GestureDetector(
                      onTap: onTrailing,
                      child: Text(trailing, style: const TextStyle(color: _kBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                ]),
                const SizedBox(height: 12),
                child,
              ]),
            );
          }

          Widget checkItem(String label, bool value, ValueChanged<bool> onChange) {
            return InkWell(
              onTap: () => onChange(!value),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: value ? _kBlue : Colors.transparent,
                      border: Border.all(color: value ? _kBlue : Colors.grey.shade400, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: value ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                ]),
              ),
            );
          }

          Widget timeSlot(String label, String sub, String key, Set<String> slots, Function(String, bool) toggle) {
            final sel = slots.contains(key);
            return GestureDetector(
              onTap: () => toggle(key, !sel),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: sel ? _kBlue : Colors.grey.shade300, width: sel ? 2 : 1),
                  borderRadius: BorderRadius.circular(10),
                  color: sel ? _kBlue.withValues(alpha: 0.06) : Colors.transparent,
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? _kBlue : Colors.black87), textAlign: TextAlign.center),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontSize: 11, color: sel ? _kBlue : Colors.grey.shade500)),
                ]),
              ),
            );
          }

          Widget timeGrid(Set<String> slots, Function(String, bool) toggle) {
            return GridView.count(
              crossAxisCount: 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.6,
              children: [
                timeSlot('Tôt matin',   '00:00 - 06:00', 'early',     slots, toggle),
                timeSlot('Matin',       '06:00 - 12:00', 'morning',   slots, toggle),
                timeSlot('Après-midi',  '12:00 - 18:00', 'afternoon', slots, toggle),
                timeSlot('Soir',        '18:00 - 00:00', 'evening',   slots, toggle),
              ],
            );
          }

          void resetAll() => setModal(() {
            tempPrice = RangeValues(_priceMin, _priceMax);
            tempStops = {'direct', '1stop', '2plus'};
            tempCarriers = Set.from(allCarriers);
            tempArrival = {'early', 'morning', 'afternoon', 'evening'};
            tempDep = {'early', 'morning', 'afternoon', 'evening'};
            tempRefundable = false;
            tempReschedule = false;
          });

          return SizedBox(
            height: sheetH,
            child: Column(children: [
              // ── Header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                    visualDensity: VisualDensity.compact,
                  ),
                  const Expanded(
                    child: Text('Filtrer', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: resetAll,
                    child: const Text('Réinitialiser',
                        style: TextStyle(color: _kBlue, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
              Divider(height: 16, color: Colors.grey.shade200),

              // ── Scrollable content ────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    // Price range
                    section('Fourchette de prix',
                      trailing: '${formatDzd(tempPrice.start)} - ${formatDzd(tempPrice.end)}',
                      child: RangeSlider(
                        values: tempPrice,
                        min: _priceMin, max: _priceMax,
                        activeColor: _kBlue,
                        inactiveColor: Colors.grey.shade200,
                        onChanged: (v) => setModal(() => tempPrice = v),
                      ),
                    ),
                    Divider(color: Colors.grey.shade100, height: 24),

                    // Stops
                    section("Nombre d'escales", child: Row(children: [
                      for (final s in [('direct', 'Direct'), ('1stop', '1 Escale'), ('2plus', '2+ Escales')])
                        Expanded(child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setModal(() {
                              if (tempStops.contains(s.$1)) tempStops.remove(s.$1);
                              else tempStops.add(s.$1);
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: tempStops.contains(s.$1) ? _kBlue : Colors.grey.shade300,
                                  width: tempStops.contains(s.$1) ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                color: tempStops.contains(s.$1)
                                    ? _kBlue.withValues(alpha: 0.07) : Colors.transparent,
                              ),
                              child: Text(s.$2, style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: tempStops.contains(s.$1) ? _kBlue : Colors.black87,
                              )),
                            ),
                          ),
                        )),
                    ])),
                    Divider(color: Colors.grey.shade100, height: 24),

                    // Airlines
                    if (allCarriers.isNotEmpty) ...[
                      section('Compagnies aériennes',
                        trailing: tempCarriers.length == allCarriers.length
                            ? 'Tout désélectionner' : 'Tout sélectionner',
                        onTrailing: () => setModal(() {
                          if (tempCarriers.length == allCarriers.length) tempCarriers.clear();
                          else tempCarriers = Set.from(allCarriers);
                        }),
                        child: Column(children: allCarriers.map((c) =>
                          checkItem(c, tempCarriers.contains(c), (v) => setModal(() {
                            if (v) tempCarriers.add(c); else tempCarriers.remove(c);
                          })),
                        ).toList()),
                      ),
                      Divider(color: Colors.grey.shade100, height: 24),
                    ],

                    // Arrival time
                    section("Heure d'arrivée",
                      trailing: tempArrival.length == 4 ? 'Tout désélectionner' : 'Tout sélectionner',
                      onTrailing: () => setModal(() {
                        if (tempArrival.length == 4) tempArrival.clear();
                        else tempArrival = {'early', 'morning', 'afternoon', 'evening'};
                      }),
                      child: timeGrid(tempArrival, (k, v) => setModal(() {
                        if (v) tempArrival.add(k); else tempArrival.remove(k);
                      })),
                    ),
                    Divider(color: Colors.grey.shade100, height: 24),

                    // Departure time
                    section("Heure de départ",
                      trailing: tempDep.length == 4 ? 'Tout désélectionner' : 'Tout sélectionner',
                      onTrailing: () => setModal(() {
                        if (tempDep.length == 4) tempDep.clear();
                        else tempDep = {'early', 'morning', 'afternoon', 'evening'};
                      }),
                      child: timeGrid(tempDep, (k, v) => setModal(() {
                        if (v) tempDep.add(k); else tempDep.remove(k);
                      })),
                    ),
                    Divider(color: Colors.grey.shade100, height: 24),

                    // Refund & Reschedule
                    section('Remboursement & Modification',
                      trailing: (tempRefundable || tempReschedule) ? 'Tout désélectionner' : null,
                      onTrailing: () => setModal(() { tempRefundable = false; tempReschedule = false; }),
                      child: Column(children: [
                        checkItem('Remboursable', tempRefundable,
                            (v) => setModal(() => tempRefundable = v)),
                        checkItem('Modification disponible', tempReschedule,
                            (v) => setModal(() => tempReschedule = v)),
                      ]),
                    ),
                  ],
                ),
              ),

              // ── Footer ────────────────────────────────────────────────
              Divider(height: 1, color: Colors.grey.shade200),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _priceRange = RangeValues(_priceMin, _priceMax);
                          _stopsFilter = {'direct', '1stop', '2plus'};
                          _selectedCarriers = Set.from(allCarriers);
                          _arrivalSlots = {'early', 'morning', 'afternoon', 'evening'};
                          _departureSlots = {'early', 'morning', 'afternoon', 'evening'};
                          _filterRefundable = false;
                          _filterReschedule = false;
                        });
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Réinitialiser',
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _priceRange     = tempPrice;
                          _stopsFilter    = tempStops;
                          _selectedCarriers = tempCarriers;
                          _arrivalSlots   = tempArrival;
                          _departureSlots = tempDep;
                          _filterRefundable = tempRefundable;
                          _filterReschedule = tempReschedule;
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Appliquer',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final from    = _flights.isNotEmpty ? _flights.first.from : '';
    final to      = _flights.isNotEmpty ? _flights.first.to   : '';
    final indices = _filteredIndices;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              // ── Collapsible blue header ──────────────────────────────────
              SliverAppBar(
                expandedHeight: 190,
                pinned: true,
                floating: false,
                backgroundColor: _kBlue,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: AnimatedOpacity(
                  opacity: _showCompactRoute ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: _showEditSearch,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(from,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward,
                              color: Colors.white, size: 16),
                        ),
                        Text(to,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.calendar_today_outlined,
                        color: Colors.white),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: GestureDetector(
                    onTap: _showEditSearch,
                    child: _buildExpandedHeader(from, to),
                  ),
                ),
              ),

              // ── Results count ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    '${indices.length} vol${indices.length > 1 ? "s" : ""} trouvé${indices.length > 1 ? "s" : ""}',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
              ),

              // ── Flight list ──────────────────────────────────────────────
              indices.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _flights.isEmpty
                                    ? Icons.flight_takeoff
                                    : Icons.filter_alt_off_outlined,
                                size: 56,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _flights.isEmpty
                                    ? 'Aucun vol disponible\npour cette destination et cette date'
                                    : 'Aucun vol ne correspond\nà vos filtres',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_flights.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () => setState(() {
                                    _priceRange       = RangeValues(_priceMin, _priceMax);
                                    _stopsFilter      = {'direct', '1stop', '2plus'};
                                    _selectedCarriers = Set.from(_allCarriers);
                                    _arrivalSlots     = {'early', 'morning', 'afternoon', 'evening'};
                                    _departureSlots   = {'early', 'morning', 'afternoon', 'evening'};
                                    _filterRefundable = false;
                                    _filterReschedule = false;
                                  }),
                                  child: const Text('Réinitialiser les filtres'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final idx     = indices[i];
                            final flight  = _flights[idx];
                            final summary = _rawOffers[idx]
                                ['_summary'] as Map<String, dynamic>?;
                            final carrier     = summary?['carrier']?.toString() ?? '';
                            final carrierCode = summary?['carrier_code']?.toString() ?? '';
                            final isRoundTrip = summary?['is_round_trip'] == true;
                            final returnInfo  = summary?['return']
                                as Map<String, dynamic>?;

                            return _FlightCard(
                              flight:         flight,
                              carrier:        carrier,
                              carrierCode:    carrierCode,
                              isRoundTrip:    isRoundTrip,
                              returnInfo:     returnInfo,
                              cityFrom:       _cityName(flight.from),
                              cityTo:         _cityName(flight.to),
                              seatsAvailable: (summary?['seats_available'] as num?)?.toInt() ?? 0,
                              onBook: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FlightDetailScreen(
                                    rawOffer: _rawOffers[idx],
                                    flight:   flight,
                                    onBookingCreated: widget.onBookingCreated,
                                    forUserId: widget.forUserId,
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: indices.length,
                        ),
                      ),
                    ),
            ],
          ),

          // ── Floating Sort / Filter bar ───────────────────────────────────
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sortFilterBtn(
                      icon: Icons.swap_vert,
                      label: 'Trier',
                      onTap: _showSortSheet,
                      highlighted: _sortBy != 'price_asc',
                    ),
                    Container(
                        width: 1,
                        height: 32,
                        color: Colors.grey.shade200),
                    _sortFilterBtn(
                      icon: Icons.tune,
                      label: 'Filtrer',
                      onTap: _showFilterSheet,
                      highlighted: _hasActiveFilters,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Loading overlay ──────────────────────────────────────────────
          if (_searching)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Colors.black26,
                  child: Center(
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 32, vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: _kBlue),
                            SizedBox(height: 16),
                            Text('Recherche en cours…',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sortFilterBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    final color = highlighted ? _kBlue : Colors.black87;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedHeader(String from, String to) {
    final fromCity = _cityName(from);
    final toCity   = _cityName(to);
    final seats    = _currentPassengers;
    final cls      = _flights.isNotEmpty
        ? _flights.first.flightClass
        : 'Economique';

    return Container(
      color: _kBlue,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight,
        left: 24,
        right: 24,
        bottom: 20,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _WorldMapPainter()),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          // Route row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Origin
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(from,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  Text(fromCity,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
              // Arc + label
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 44,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(painter: _ArcPainter()),
                            ),
                            Align(
                              alignment: Alignment.topCenter,
                              child: Transform.rotate(
                                angle: math.pi / 2,
                                child: const Icon(Icons.airplanemode_active,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$seats Siège${seats > 1 ? 's' : ''} · $cls',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              // Destination
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(to,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  Text(toCity,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            ],
          ),
        ],
          ),
        ],
      ),
    );
  }
}

// ── Arc painter ──────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // control_y = 2*peakY - height so actual Bezier peak lands at peakY=10
    const peakY = 10.0;
    final controlY = 2 * peakY - size.height;

    final path = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(size.width / 2, controlY, size.width, size.height);
    canvas.drawPath(path, paint);

    // endpoint dots
    final dot = Paint()
      ..color = Colors.white54
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(0, size.height), 3.5, dot);
    canvas.drawCircle(Offset(size.width, size.height), 3.5, dot);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── World map painter ────────────────────────────────────────────────────────

class _WorldMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..style = PaintingStyle.fill;

    void poly(List<Offset> pts) {
      final path = Path()
        ..moveTo(pts[0].dx * size.width, pts[0].dy * size.height);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx * size.width, pts[i].dy * size.height);
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    // North America
    poly([
      const Offset(0.05, 0.14), const Offset(0.14, 0.06),
      const Offset(0.22, 0.07), const Offset(0.28, 0.12),
      const Offset(0.30, 0.22), const Offset(0.26, 0.35),
      const Offset(0.22, 0.46), const Offset(0.19, 0.58),
      const Offset(0.21, 0.64), const Offset(0.16, 0.70),
      const Offset(0.10, 0.66), const Offset(0.07, 0.58),
      const Offset(0.04, 0.42), const Offset(0.03, 0.28),
    ]);
    // Greenland
    poly([
      const Offset(0.27, 0.04), const Offset(0.35, 0.02),
      const Offset(0.39, 0.07), const Offset(0.36, 0.14),
      const Offset(0.29, 0.15), const Offset(0.26, 0.10),
    ]);
    // South America
    poly([
      const Offset(0.18, 0.57), const Offset(0.28, 0.54),
      const Offset(0.33, 0.62), const Offset(0.31, 0.73),
      const Offset(0.26, 0.82), const Offset(0.22, 0.92),
      const Offset(0.18, 0.97), const Offset(0.14, 0.90),
      const Offset(0.12, 0.79), const Offset(0.14, 0.68),
    ]);
    // Europe
    poly([
      const Offset(0.44, 0.09), const Offset(0.52, 0.07),
      const Offset(0.56, 0.11), const Offset(0.57, 0.20),
      const Offset(0.53, 0.29), const Offset(0.50, 0.33),
      const Offset(0.47, 0.31), const Offset(0.44, 0.26),
      const Offset(0.43, 0.17),
    ]);
    // Africa
    poly([
      const Offset(0.44, 0.31), const Offset(0.56, 0.27),
      const Offset(0.61, 0.32), const Offset(0.62, 0.43),
      const Offset(0.60, 0.56), const Offset(0.57, 0.67),
      const Offset(0.53, 0.76), const Offset(0.50, 0.82),
      const Offset(0.46, 0.76), const Offset(0.43, 0.65),
      const Offset(0.42, 0.52), const Offset(0.43, 0.40),
    ]);
    // Asia
    poly([
      const Offset(0.55, 0.07), const Offset(0.72, 0.04),
      const Offset(0.86, 0.09), const Offset(0.93, 0.18),
      const Offset(0.91, 0.30), const Offset(0.86, 0.39),
      const Offset(0.80, 0.44), const Offset(0.74, 0.49),
      const Offset(0.68, 0.46), const Offset(0.63, 0.42),
      const Offset(0.58, 0.38), const Offset(0.54, 0.30),
      const Offset(0.53, 0.20), const Offset(0.54, 0.13),
    ]);
    // Australia
    poly([
      const Offset(0.79, 0.61), const Offset(0.89, 0.59),
      const Offset(0.93, 0.65), const Offset(0.91, 0.76),
      const Offset(0.86, 0.81), const Offset(0.79, 0.79),
      const Offset(0.75, 0.73), const Offset(0.76, 0.65),
    ]);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Flight card ──────────────────────────────────────────────────────────────

class _FlightCard extends StatelessWidget {
  final Flight flight;
  final String carrier;
  final String carrierCode;
  final bool isRoundTrip;
  final Map<String, dynamic>? returnInfo;
  final String cityFrom;
  final String cityTo;
  final int seatsAvailable;
  final VoidCallback onBook;

  const _FlightCard({
    required this.flight,
    required this.carrier,
    required this.carrierCode,
    required this.isRoundTrip,
    required this.returnInfo,
    required this.cityFrom,
    required this.cityTo,
    required this.seatsAvailable,
    required this.onBook,
  });

  Widget _badge(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.length >= 16 ? iso.substring(11, 16) : iso;
    }
  }

  String _duration(String? dep, String? arr) {
    if (dep == null || arr == null) return '';
    try {
      final diff = DateTime.parse(arr).difference(DateTime.parse(dep));
      final h    = diff.inHours;
      final m    = diff.inMinutes.remainder(60);
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onBook,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ── Top: airline + price ──────────────────────────────────
              Row(
                children: [
                  AirlineLogo(code: carrierCode, size: 40, circle: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      carrier.isNotEmpty ? carrier : 'Compagnie',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Price
                  Text(
                    formatDzd(flight.price),
                    style: const TextStyle(
                      color: _kBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Divider(height: 1, color: Colors.grey.shade100),
              const SizedBox(height: 14),

              // ── Outbound leg ──────────────────────────────────────────
              _buildLeg(
                depTime:  _formatTime(flight.departureAt),
                arrTime:  _formatTime(flight.arrivalAt),
                duration: _duration(flight.departureAt, flight.arrivalAt),
                isDirect: flight.isDirect,
                fromCode: flight.from,
                toCode:   flight.to,
                fromCity: cityFrom,
                toCity:   cityTo,
              ),

              // ── Return leg ────────────────────────────────────────────
              if (isRoundTrip && returnInfo != null) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 12),
                _buildLeg(
                  depTime:  _formatTime(
                      returnInfo!['departure_at']?.toString()),
                  arrTime:  _formatTime(
                      returnInfo!['arrival_at']?.toString()),
                  duration: _duration(
                      returnInfo!['departure_at']?.toString(),
                      returnInfo!['arrival_at']?.toString()),
                  isDirect: flight.isDirect,
                  fromCode: returnInfo!['origin']?.toString() ?? flight.to,
                  toCode:   returnInfo!['destination']?.toString() ?? flight.from,
                  fromCity: cityTo,
                  toCity:   cityFrom,
                  label: 'Retour',
                ),
              ],

              // ── Info badges ───────────────────────────────────────────
              if (seatsAvailable > 0 || flight.hasBaggage || flight.isRefundable) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (seatsAvailable > 0)
                      _badge(
                        Icons.event_seat_outlined,
                        '$seatsAvailable place${seatsAvailable > 1 ? "s" : ""}',
                        seatsAvailable <= 3 ? Colors.orange : Colors.teal,
                      ),
                    if (flight.hasBaggage)
                      _badge(Icons.luggage_outlined, 'Bagages inclus', Colors.green),
                    if (flight.isRefundable)
                      _badge(Icons.replay, 'Remboursable', Colors.blue),
                  ],
                ),
              ],

              const SizedBox(height: 14),

              // ── Book button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Réserver',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeg({
    required String depTime,
    required String arrTime,
    required String duration,
    required bool isDirect,
    required String fromCode,
    required String toCode,
    required String fromCity,
    required String toCity,
    String? label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Departure
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fromCity,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45,
                          fontWeight: FontWeight.w600)),
                  Text(depTime,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(fromCode,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black45)),
                ],
              ),
            ),

            // Arc + info
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  SizedBox(
                    height: 44,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _CardArcPainter()),
                        ),
                        Align(
                          alignment: Alignment.topCenter,
                          child: Transform.rotate(
                            angle: math.pi / 2,
                            child: const Icon(Icons.airplanemode_active,
                                color: _kBlue, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (duration.isNotEmpty)
                    Text(duration,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center),
                  Text(
                    isDirect ? 'Direct' : 'Escale',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDirect ? Colors.teal : Colors.orange,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Arrival
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(toCity,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45,
                          fontWeight: FontWeight.w600)),
                  Text(arrTime,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(toCode,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black45)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CardArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // control_y = 2*peakY - height so the actual Bezier peak lands at peakY=10
    const peakY = 10.0;
    final controlY = 2 * peakY - size.height;

    final path = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(size.width / 2, controlY, size.width, size.height);
    canvas.drawPath(path, paint);

    final dot = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(0, size.height), 4, dot);
    canvas.drawCircle(Offset(size.width, size.height), 4, dot);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Edit Search Bottom Sheet ──────────────────────────────────────────────────

class _EditSearchSheet extends StatefulWidget {
  final String initialFrom;
  final String initialTo;
  final String initialDepartureDate;
  final String? initialReturnDate;
  final String initialFlightClass;
  final int initialPassengers;
  final int initialChildren;
  final int initialInfants;
  final void Function({
    required String fromCode,
    required String toCode,
    required DateTime departureDate,
    DateTime? returnDate,
    required int passengers,
    required int children,
    required int infants,
    required String flightClass,
  }) onSearch;

  const _EditSearchSheet({
    required this.initialFrom,
    required this.initialTo,
    required this.initialDepartureDate,
    this.initialReturnDate,
    required this.initialFlightClass,
    required this.initialPassengers,
    this.initialChildren = 0,
    this.initialInfants = 0,
    required this.onSearch,
  });

  @override
  State<_EditSearchSheet> createState() => _EditSearchSheetState();
}

class _EditSearchSheetState extends State<_EditSearchSheet> {
  int      _tripType      = 0;
  String   _fromCode      = '';
  String   _fromLabel     = '';
  String   _toCode        = '';
  String   _toLabel       = '';
  DateTime _departureDate = DateTime.now();
  DateTime? _returnDate;
  String   _flightClass   = 'Economique';
  int _passengers = 1;
  int _children   = 0;
  int _infants    = 0;

  static const _classes = ['Economique', 'Affaires', 'Première'];

  @override
  void initState() {
    super.initState();
    _fromCode      = widget.initialFrom;
    _toCode        = widget.initialTo;
    _fromLabel     = _cityLabel(widget.initialFrom);
    _toLabel       = _cityLabel(widget.initialTo);
    _departureDate = _parseDate(widget.initialDepartureDate) ??
        DateTime.now().add(const Duration(days: 7));
    _returnDate    = _parseDate(widget.initialReturnDate);
    _tripType      = _returnDate != null ? 1 : 0;
    _flightClass   = widget.initialFlightClass;
    _passengers    = widget.initialPassengers;
    _children = widget.initialChildren;
    _infants  = widget.initialInfants;
  }

  String _cityLabel(String iata) {
    if (iata.isEmpty) return iata;
    try {
      final a = kAirports.firstWhere((a) => a.iata == iata.toUpperCase());
      return '${a.city} ($iata)';
    } catch (_) {
      return iata;
    }
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try { return DateTime.parse(raw.split('T')[0]); } catch (_) { return null; }
  }

  String _fmt(DateTime d) {
    const months = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
    const days   = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _pickDate({required bool isReturn}) async {
    final first = isReturn
        ? _departureDate.add(const Duration(days: 1))
        : DateTime.now();
    final init = isReturn ? (_returnDate ?? first) : _departureDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kBlue),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isReturn) {
        _returnDate = picked;
      } else {
        _departureDate = picked;
        // Si la date de retour est maintenant avant ou égale au départ, on la décale
        if (_returnDate != null && !_returnDate!.isAfter(_departureDate)) {
          _returnDate = _departureDate.add(const Duration(days: 1));
        }
      }
    });
  }

  Future<void> _pickAirport({required bool isFrom}) async {
    final result = await showAirportSearch(context, label: isFrom ? 'Départ' : 'Arrivée');
    if (result == null) return;
    setState(() {
      final label = '${result['city']} (${result['iata']})';
      if (isFrom) { _fromCode = result['iata']!; _fromLabel = label; }
      else        { _toCode   = result['iata']!; _toLabel   = label; }
    });
  }

  void _swap() => setState(() {
    final tc = _fromCode; final tl = _fromLabel;
    _fromCode = _toCode;  _fromLabel = _toLabel;
    _toCode = tc;         _toLabel = tl;
  });

  void _pickPassengers() {
    int adults   = _passengers;
    int children = _children;
    int infants  = _infants;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Passagers'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _counterRow('Adultes', '12 ans et +', adults,
                  onMinus: adults > 1 ? () => setDlg(() { adults--; if (infants > adults) infants = adults; }) : null,
                  onPlus:  adults < 9 ? () => setDlg(() => adults++) : null),
              const Divider(height: 24),
              _counterRow('Enfants', '2 – 11 ans', children,
                  onMinus: children > 0 ? () => setDlg(() => children--) : null,
                  onPlus:  children < 8 ? () => setDlg(() => children++) : null),
              const Divider(height: 24),
              _counterRow('Bébés', 'Moins de 2 ans', infants,
                  onMinus: infants > 0        ? () => setDlg(() => infants--) : null,
                  onPlus:  infants < adults   ? () => setDlg(() => infants++) : null),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue),
              onPressed: () {
                setState(() {
                  _passengers = adults;
                  _children   = children;
                  _infants    = infants;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Confirmer',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _pickClass() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Classe de voyage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _classes.map((cls) => ListTile(
            title: Text(cls),
            trailing: _flightClass == cls
                ? const Icon(Icons.check, color: _kBlue)
                : null,
            onTap: () {
              setState(() => _flightClass = cls);
              Navigator.pop(ctx);
            },
          )).toList(),
        ),
      ),
    );
  }

  Widget _counterRow(String title, String subtitle, int count,
      {VoidCallback? onMinus, VoidCallback? onPlus}) {
    return Row(
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ),
        IconButton(
          onPressed: onMinus,
          icon: Icon(Icons.remove_circle_outline,
              color: onMinus != null ? _kBlue : Colors.grey.shade300),
        ),
        SizedBox(
          width: 28,
          child: Text('$count',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        IconButton(
          onPressed: onPlus,
          icon: Icon(Icons.add_circle_outline,
              color: onPlus != null ? _kBlue : Colors.grey.shade300),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Trip type tabs
            Row(
              children: [
                _tab('Aller Simple', 0),
                const SizedBox(width: 8),
                _tab('Aller-Retour', 1),
                const SizedBox(width: 8),
                _tab('Multi-dest.', 2),
              ],
            ),
            const SizedBox(height: 16),

            // From / To with swap
            Stack(
              clipBehavior: Clip.none,
              children: [
                Column(children: [
                  _airportField('Départ',
                      _fromLabel.isEmpty ? 'Origine' : _fromLabel,
                      Icons.flight_takeoff, isFrom: true),
                  const SizedBox(height: 8),
                  _airportField('Destination',
                      _toLabel.isEmpty ? 'Destination' : _toLabel,
                      Icons.flight_land, isFrom: false),
                ]),
                Positioned(
                  right: 12, top: 0, bottom: 0, width: 44,
                  child: Center(
                    child: GestureDetector(
                      onTap: _swap,
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
            ),
            const SizedBox(height: 8),

            _dateField('Date de départ', _fmt(_departureDate), isReturn: false),
            const SizedBox(height: 8),

            if (_tripType == 1) ...[
              _dateField('Date de retour',
                  _returnDate != null ? _fmt(_returnDate!) : 'Date de retour',
                  isReturn: true),
              const SizedBox(height: 8),
            ],

            Row(children: [
              Expanded(
                child: _infoField(
                    'Passagers',
                    [
                      '$_passengers Adulte${_passengers > 1 ? 's' : ''}',
                      if (_children > 0) '$_children Enfant${_children > 1 ? 's' : ''}',
                      if (_infants  > 0) '$_infants Bébé${_infants  > 1 ? 's' : ''}',
                    ].join(', '),
                    Icons.person_outline,
                    onTap: () => _pickPassengers()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoField('Classe', _flightClass,
                    Icons.airline_seat_recline_normal_outlined,
                    onTap: () => _pickClass()),
              ),
            ]),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSearch(
                    fromCode:      _fromCode,
                    toCode:        _toCode,
                    departureDate: _departureDate,
                    returnDate:    _tripType == 1 ? _returnDate : null,
                    passengers:  _passengers,
                    children:    _children,
                    infants:     _infants,
                    flightClass: _flightClass,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Rechercher des vols',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, int index) {
    final sel = _tripType == index;
    return GestureDetector(
      onTap: () => setState(() => _tripType = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? _kBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? _kBlue : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: sel ? Colors.white : Colors.black54,
            )),
      ),
    );
  }

  Widget _airportField(String label, String value, IconData icon,
      {required bool isFrom}) {
    return GestureDetector(
      onTap: () => _pickAirport(isFrom: isFrom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 50, 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(icon, size: 18, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: (value == 'Origine' || value == 'Destination')
                          ? Colors.grey.shade400
                          : Colors.black87),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _dateField(String label, String value, {required bool isReturn}) {
    return GestureDetector(
      onTap: () => _pickDate(isReturn: isReturn),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.calendar_today_outlined, size: 18,
                color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }

  Widget _infoField(String label, String value, IconData icon,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(icon, size: 18, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ]),
      ),
    );
  }
}
