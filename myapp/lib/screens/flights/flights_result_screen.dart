import 'package:flutter/material.dart';
import 'package:myapp/models/flight.dart';
import 'package:myapp/screens/flights/flight_detail_screen.dart';
import 'package:myapp/utils/currency.dart';

class FlightsResultScreen extends StatefulWidget {
  final List<Flight> flights;
  final List<Map<String, dynamic>> rawOffers;
  final int passengersCount;
  final VoidCallback onBookingCreated;
  final String? forUserId;

  const FlightsResultScreen({
    super.key,
    required this.flights,
    required this.rawOffers,
    required this.passengersCount,
    required this.onBookingCreated,
    this.forUserId,
  });

  @override
  State<FlightsResultScreen> createState() => _FlightsResultScreenState();
}

class _FlightsResultScreenState extends State<FlightsResultScreen> {
  String _sortOrder    = 'asc';   // 'asc' | 'desc'
  String? _filterCarrier;         // null = toutes les compagnies

  // Liste des compagnies disponibles
  List<String> get _carriers {
    final set = <String>{};
    for (final offer in widget.rawOffers) {
      final carrier = (offer['_summary'] as Map<String, dynamic>?)?['carrier']?.toString() ?? '';
      if (carrier.isNotEmpty) set.add(carrier);
    }
    return ['Toutes', ...set.toList()..sort()];
  }

  // Vols filtrés et triés
  List<int> get _filteredIndices {
    List<int> indices = List.generate(widget.flights.length, (i) => i);

    // Filtre par compagnie
    if (_filterCarrier != null && _filterCarrier != 'Toutes') {
      indices = indices.where((i) {
        final carrier = (widget.rawOffers[i]['_summary'] as Map<String, dynamic>?)?['carrier']?.toString() ?? '';
        return carrier == _filterCarrier;
      }).toList();
    }

    // Tri par prix
    indices.sort((a, b) {
      final pa = widget.flights[a].price;
      final pb = widget.flights[b].price;
      return _sortOrder == 'asc' ? pa.compareTo(pb) : pb.compareTo(pa);
    });

    return indices;
  }

  void _showCarrierFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtrer par compagnie',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      setState(() => _filterCarrier = c == 'Toutes' ? null : c);
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

  @override
  Widget build(BuildContext context) {
    final indices = _filteredIndices;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: const Text('Vols disponibles'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Barre de filtres ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Tri par prix
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'asc',
                        icon: Icon(Icons.arrow_upward, size: 14),
                        label: Text('Prix croissant', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: 'desc',
                        icon: Icon(Icons.arrow_downward, size: 14),
                        label: Text('Prix décroissant', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {_sortOrder},
                    onSelectionChanged: (v) => setState(() => _sortOrder = v.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filtre compagnie — bouton
                OutlinedButton.icon(
                  onPressed: () => _showCarrierFilter(),
                  icon: const Icon(Icons.airlines, size: 16),
                  label: Text(
                    _filterCarrier != null && _filterCarrier != 'Toutes'
                        ? _filterCarrier!
                        : 'Compagnie',
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: BorderSide(
                      color: _filterCarrier != null && _filterCarrier != 'Toutes'
                          ? Colors.blue
                          : Colors.grey.shade400,
                    ),
                    foregroundColor: _filterCarrier != null && _filterCarrier != 'Toutes'
                        ? Colors.blue
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Compteur
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${indices.length} vol${indices.length > 1 ? "s" : ""} trouvé${indices.length > 1 ? "s" : ""}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ),
          // ── Liste des vols ────────────────────────────────────────────
          Expanded(
            child: indices.isEmpty
                ? const Center(child: Text('Aucun vol pour ces filtres'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: indices.length,
                    itemBuilder: (context, i) {
                      final idx    = indices[i];
                      final flight = widget.flights[idx];
                      final summary = widget.rawOffers[idx]['_summary'] as Map<String, dynamic>?;
                      final carrier     = summary?['carrier']?.toString() ?? '';
                      final isRoundTrip = summary?['is_round_trip'] == true;
                      final returnInfo  = summary?['return'] as Map<String, dynamic>?;

                      return _FlightCard(
                        flight: flight,
                        carrier: carrier,
                        isRoundTrip: isRoundTrip,
                        returnInfo: returnInfo,
                        onBook: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FlightDetailScreen(
                              rawOffer: widget.rawOffers[idx],
                              flight: flight,
                              onBookingCreated: widget.onBookingCreated,
                              forUserId: widget.forUserId,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FlightCard extends StatelessWidget {
  final Flight flight;
  final String carrier;
  final bool isRoundTrip;
  final Map<String, dynamic>? returnInfo;
  final VoidCallback onBook;

  const _FlightCard({
    required this.flight,
    required this.carrier,
    required this.isRoundTrip,
    required this.returnInfo,
    required this.onBook,
  });

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.length >= 16 ? iso.substring(11, 16) : iso;
    }
  }

  String _formatDateShort(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      const days = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
      const months = ['Jan.', 'Fév.', 'Mar.', 'Avr.', 'Mai', 'Juin', 'Juil.', 'Août', 'Sep.', 'Oct.', 'Nov.', 'Déc.'];
      return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baggage tag
            if (flight.hasBaggage) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text('Bagages', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Outbound leg
            _buildLeg(
              label: isRoundTrip ? 'Aller' : null,
              carrier: carrier,
              origin: flight.from,
              destination: flight.to,
              date: flight.date,
              isDirect: flight.isDirect,
              departureAt: flight.departureAt,
              arrivalAt: flight.arrivalAt,
            ),

            // Return leg
            if (isRoundTrip && returnInfo != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              _buildLeg(
                label: 'Retour',
                carrier: carrier,
                origin: returnInfo!['origin']?.toString() ?? flight.to,
                destination: returnInfo!['destination']?.toString() ?? flight.from,
                date: (returnInfo!['departure_at']?.toString() ?? '').split('T')[0],
                isDirect: flight.isDirect,
                departureAt: returnInfo!['departure_at']?.toString(),
                arrivalAt: returnInfo!['arrival_at']?.toString(),
              ),
            ],

            const SizedBox(height: 14),

            // Price + Book button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  formatDzd(flight.price),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Réserver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildLeg({
    String? label,
    required String carrier,
    required String origin,
    required String destination,
    required String date,
    required bool isDirect,
    String? departureAt,
    String? arrivalAt,
  }) {
    final depTime  = _formatTime(departureAt);
    final arrTime  = _formatTime(arrivalAt);
    final dateStr  = _formatDateShort(departureAt ?? (date.isNotEmpty ? '${date}T00:00:00' : null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Airline name box
            Container(
              constraints: const BoxConstraints(maxWidth: 110, minWidth: 70),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Text(
                carrier.isNotEmpty ? carrier : '✈',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),

            // Departure time + airport
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(depTime != '--:--' ? depTime : date,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(origin, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),

            // Line + Direct/Stops
            Expanded(
              child: Column(
                children: [
                  Text(
                    isDirect ? 'Direct' : 'Escale',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDirect ? Colors.teal : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
                      Icon(Icons.circle, size: 6, color: Colors.grey.shade400),
                    ],
                  ),
                ],
              ),
            ),

            // Arrival time + airport + date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (dateStr.isNotEmpty)
                  Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                Text(arrTime != '--:--' ? arrTime : '',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(destination, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
