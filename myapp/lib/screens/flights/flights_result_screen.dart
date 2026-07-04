import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:myapp/data/airports.dart';
import 'package:myapp/models/flight.dart';
import 'package:myapp/screens/flights/flight_detail_screen.dart';
import 'package:myapp/utils/currency.dart';
import 'package:myapp/widgets/airport_search_field.dart';

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
  bool _showCompactRoute = false;

  String  _sortOrder     = 'asc';
  String? _filterCarrier;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final collapsed = _scrollCtrl.offset > 120;
      if (collapsed != _showCompactRoute) {
        setState(() => _showCompactRoute = collapsed);
      }
    });
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

  List<String> get _carriers {
    final set = <String>{};
    for (final offer in widget.rawOffers) {
      final c = (offer['_summary'] as Map<String, dynamic>?)?['carrier']
              ?.toString() ??
          '';
      if (c.isNotEmpty) set.add(c);
    }
    return ['Toutes', ...set.toList()..sort()];
  }

  List<int> get _filteredIndices {
    List<int> indices = List.generate(widget.flights.length, (i) => i);
    if (_filterCarrier != null && _filterCarrier != 'Toutes') {
      indices = indices.where((i) {
        final c = (widget.rawOffers[i]['_summary'] as Map<String, dynamic>?)?[
                'carrier']
            ?.toString() ??
            '';
        return c == _filterCarrier;
      }).toList();
    }
    indices.sort((a, b) {
      final pa = widget.flights[a].price;
      final pb = widget.flights[b].price;
      return _sortOrder == 'asc' ? pa.compareTo(pb) : pb.compareTo(pa);
    });
    return indices;
  }

  void _showEditSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSearchSheet(
        initialFrom:          widget.initialFrom.isNotEmpty ? widget.initialFrom : (widget.flights.isNotEmpty ? widget.flights.first.from : ''),
        initialTo:            widget.initialTo.isNotEmpty   ? widget.initialTo   : (widget.flights.isNotEmpty ? widget.flights.first.to   : ''),
        initialDepartureDate: widget.initialDepartureDate,
        initialReturnDate:    widget.initialReturnDate,
        initialFlightClass:   widget.initialFlightClass,
        initialPassengers:    widget.initialPassengers,
        onSearch: () => Navigator.pop(context),
      ),
    );
  }

  void _showCarrierFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtrer par compagnie',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _carriers.map((c) {
                  final selected = (_filterCarrier ?? 'Toutes') == c;
                  return ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    selectedColor: Colors.blue.shade100,
                    onSelected: (_) {
                      setState(
                          () => _filterCarrier = c == 'Toutes' ? null : c);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final from    = widget.flights.isNotEmpty ? widget.flights.first.from : '';
    final to      = widget.flights.isNotEmpty ? widget.flights.first.to   : '';
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
                  ? const SliverFillRemaining(
                      child: Center(
                          child: Text('Aucun vol pour ces filtres')),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final idx     = indices[i];
                            final flight  = widget.flights[idx];
                            final summary = widget.rawOffers[idx]
                                ['_summary'] as Map<String, dynamic>?;
                            final carrier    = summary?['carrier']?.toString() ?? '';
                            final isRoundTrip = summary?['is_round_trip'] == true;
                            final returnInfo  = summary?['return']
                                as Map<String, dynamic>?;

                            return _FlightCard(
                              flight:      flight,
                              carrier:     carrier,
                              isRoundTrip: isRoundTrip,
                              returnInfo:  returnInfo,
                              cityFrom: _cityName(flight.from),
                              cityTo:   _cityName(flight.to),
                              onBook: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FlightDetailScreen(
                                    rawOffer: widget.rawOffers[idx],
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
                      onTap: () => setState(() =>
                          _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc'),
                    ),
                    Container(
                        width: 1,
                        height: 32,
                        color: Colors.grey.shade200),
                    _sortFilterBtn(
                      icon: Icons.tune,
                      label: 'Filtrer',
                      onTap: _showCarrierFilter,
                      highlighted: _filterCarrier != null &&
                          _filterCarrier != 'Toutes',
                    ),
                  ],
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
    final seats    = widget.passengersCount;
    final cls      = widget.flights.isNotEmpty
        ? widget.flights.first.flightClass
        : 'Economique';

    return Container(
      color: _kBlue,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight,
        left: 24,
        right: 24,
        bottom: 20,
      ),
      child: Column(
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

// ── Flight card ──────────────────────────────────────────────────────────────

class _FlightCard extends StatelessWidget {
  final Flight flight;
  final String carrier;
  final bool isRoundTrip;
  final Map<String, dynamic>? returnInfo;
  final String cityFrom;
  final String cityTo;
  final VoidCallback onBook;

  const _FlightCard({
    required this.flight,
    required this.carrier,
    required this.isRoundTrip,
    required this.returnInfo,
    required this.cityFrom,
    required this.cityTo,
    required this.onBook,
  });

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

  Color _airlineColor(String name) {
    const colors = [
      Color(0xFFE53935),
      Color(0xFFF4A900),
      Color(0xFF1565C0),
      Color(0xFF6A1B9A),
      Color(0xFF00695C),
      Color(0xFF283593),
    ];
    return colors[name.hashCode.abs() % colors.length];
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
                  // Airline circle icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _airlineColor(carrier),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        carrier.isNotEmpty
                            ? carrier[0].toUpperCase()
                            : '✈',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                  ),
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
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: formatDzd(flight.price),
                          style: const TextStyle(
                              color: _kBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        const TextSpan(
                          text: '',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12),
                        ),
                      ],
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
  final VoidCallback onSearch;

  const _EditSearchSheet({
    required this.initialFrom,
    required this.initialTo,
    required this.initialDepartureDate,
    this.initialReturnDate,
    required this.initialFlightClass,
    required this.initialPassengers,
    required this.onSearch,
  });

  @override
  State<_EditSearchSheet> createState() => _EditSearchSheetState();
}

class _EditSearchSheetState extends State<_EditSearchSheet> {
  late int      _tripType;
  late String   _fromCode;
  late String   _fromLabel;
  late String   _toCode;
  late String   _toLabel;
  late DateTime _departureDate;
  DateTime?     _returnDate;
  late String   _flightClass;
  late int      _passengers;

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
    final result = await showAirportSearch(
      context,
      current: isFrom ? _fromCode : _toCode,
    );
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
                child: _infoField('Passagers',
                    '$_passengers Siège${_passengers > 1 ? 's' : ''}',
                    Icons.person_outline,
                    onTap: () => setState(() => _passengers = _passengers % 9 + 1)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoField('Classe', _flightClass,
                    Icons.airline_seat_recline_normal_outlined,
                    onTap: () => setState(() {
                      final next = (_classes.indexOf(_flightClass) + 1) % _classes.length;
                      _flightClass = _classes[next];
                    })),
              ),
            ]),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSearch();
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
