import 'package:flutter/material.dart';
import 'package:myapp/data/airports.dart';
import 'package:myapp/widgets/airline_logo.dart';
import 'package:myapp/models/flight.dart';
import 'package:myapp/screens/flights/passenger_form_screen.dart';
import 'package:myapp/utils/currency.dart';

class FlightDetailScreen extends StatelessWidget {
  final Map<String, dynamic> rawOffer;
  final Flight flight;
  final VoidCallback onBookingCreated;
  final String? forUserId;

  const FlightDetailScreen({
    super.key,
    required this.rawOffer,
    required this.flight,
    required this.onBookingCreated,
    this.forUserId,
  });

  // ── Dictionaries lookup ──────────────────────────────────────────────────

  Map<String, dynamic> get _dicts =>
      (rawOffer['dictionaries'] as Map<String, dynamic>?) ?? {};

  String _carrierName(String code) {
    final carriers = _dicts['carriers'] as Map<String, dynamic>? ?? {};
    return carriers[code]?.toString() ?? code;
  }

  String _aircraftName(String code) {
    final aircraft = _dicts['aircraft'] as Map<String, dynamic>? ?? {};
    return aircraft[code]?.toString() ?? code;
  }

  String _cityCountry(String iata) {
    if (iata.isEmpty) return '';
    try {
      final a = kAirports.firstWhere((a) => a.iata == iata.toUpperCase());
      final parts = [a.city, a.country].where((s) => s.isNotEmpty).toList();
      return parts.join(', ');
    } catch (_) {
      return '';
    }
  }

  // ── Segment cabin & bags from travelerPricings ───────────────────────────

  Map<String, dynamic> _fareForSegment(String segmentId) {
    final tps = (rawOffer['travelerPricings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (tps.isEmpty) return {};
    final tp = tps.first;
    final fares = (tp['fareDetailsBySegment'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    for (final f in fares) {
      if (f['segmentId']?.toString() == segmentId) return f;
    }
    return fares.isNotEmpty ? fares.first : {};
  }

  // ── Formatters ───────────────────────────────────────────────────────────

  String _time(String? iso) {
    if (iso == null || iso.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.length >= 16 ? iso.substring(11, 16) : iso;
    }
  }

  String _dateLabel(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      const months = ['Janvier','Février','Mars','Avril','Mai','Juin',
                      'Juillet','Août','Septembre','Octobre','Novembre','Décembre'];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) { return ''; }
  }

  String _dateShort(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      const days   = ['Lun.','Mar.','Mer.','Jeu.','Ven.','Sam.','Dim.'];
      const months = ['Jan.','Fév.','Mar.','Avr.','Mai','Juin',
                      'Juil.','Août','Sep.','Oct.','Nov.','Déc.'];
      return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]}';
    } catch (_) { return ''; }
  }

  String _layoverDuration(String? arrIso, String? depIso) {
    if (arrIso == null || depIso == null) return '';
    try {
      final diff = DateTime.parse(depIso).difference(DateTime.parse(arrIso));
      if (diff.isNegative) return '';
      final h = diff.inHours;
      final m = diff.inMinutes.remainder(60);
      return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
    } catch (_) { return ''; }
  }

  String _duration(String? dur) {
    if (dur == null || dur.isEmpty) return '';
    try {
      final h = RegExp(r'(\d+)H').firstMatch(dur)?.group(1) ?? '0';
      final m = RegExp(r'(\d+)M').firstMatch(dur)?.group(1) ?? '0';
      return '${h}h ${m}m';
    } catch (_) { return dur; }
  }

  String _cabinLabel(String? cabin) {
    switch ((cabin ?? '').toUpperCase()) {
      case 'BUSINESS':        return 'Affaires';
      case 'FIRST':           return 'Première';
      case 'PREMIUM_ECONOMY': return 'Premium Éco.';
      default:                return 'Économique';
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final itineraries = (rawOffer['itineraries'] as List?)
            ?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: const Text('Détails du vol'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (int i = 0; i < itineraries.length; i++)
                  _buildItineraryCard(itineraries[i], i, itineraries.length > 1),
              ],
            ),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildItineraryCard(
      Map<String, dynamic> itinerary, int index, bool isRoundTrip) {
    final segments = (itinerary['segments'] as List?)
            ?.cast<Map<String, dynamic>>() ?? [];
    final firstSeg = segments.isNotEmpty ? segments.first : <String, dynamic>{};
    final lastSeg  = segments.isNotEmpty ? segments.last  : <String, dynamic>{};

    final depAt = (firstSeg['departure'] as Map?)?['at']?.toString() ?? '';
    final arrAt = (lastSeg['arrival']   as Map?)?['at']?.toString() ?? '';
    final originIata = (firstSeg['departure'] as Map?)?['iataCode']?.toString() ?? '';
    final destIata   = (lastSeg['arrival']    as Map?)?['iataCode']?.toString() ?? '';

    final label = !isRoundTrip ? 'Vol' : (index == 0 ? 'Aller' : 'Retour');

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                Text(_dateShort(depAt),
                    style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 12),

            // ── Times + airports ─────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_time(depAt),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  Text(originIata,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (_cityCountry(originIata).isNotEmpty)
                    Text(_cityCountry(originIata),
                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ]),
                Column(children: [
                  Text(
                    segments.length == 1 ? 'Direct' : '${segments.length - 1} escale(s)',
                    style: TextStyle(
                      color: segments.length == 1 ? Colors.teal : Colors.orange,
                      fontWeight: FontWeight.w500, fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(width: 50, height: 1, color: Colors.grey.shade300),
                    Icon(Icons.flight, size: 16, color: Colors.grey.shade400),
                    Container(width: 50, height: 1, color: Colors.grey.shade300),
                  ]),
                  Text(_duration(itinerary['duration']?.toString()),
                      style: const TextStyle(fontSize: 11, color: Colors.teal)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_time(arrAt),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  Text(destIata,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (_cityCountry(destIata).isNotEmpty)
                    Text(_cityCountry(destIata),
                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ]),
              ],
            ),

            // ── Seats ──────────────────────────────────────────────
            Builder(builder: (_) {
              final summary = rawOffer['_summary'] as Map<String, dynamic>?;
              final seats   = summary?['seats_available'];
              final seatsInt = seats is int ? seats : int.tryParse(seats?.toString() ?? '');
              final color = seatsInt == null ? Colors.grey
                  : seatsInt <= 5  ? Colors.red
                  : seatsInt <= 10 ? Colors.orange
                  : Colors.green;
              final txt = seatsInt == null
                  ? 'Places : non communiqué'
                  : seatsInt == 0 ? 'Complet'
                  : '$seatsInt place${seatsInt > 1 ? 's' : ''} disponible${seatsInt > 1 ? 's' : ''}';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Icon(Icons.event_seat, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(txt,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                ]),
              );
            }),

            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Segments ──────────────────────────────────────────
            for (int s = 0; s < segments.length; s++) ...[
              _buildSegmentDetail(segments[s]),
              if (s < segments.length - 1) ...[
                Builder(builder: (_) {
                  final arrIso = (segments[s]['arrival']       as Map?)?['at']?.toString();
                  final depIso = (segments[s+1]['departure']   as Map?)?['at']?.toString();
                  final arrIata = (segments[s]['arrival']      as Map?)?['iataCode']?.toString() ?? '';
                  final dur = _layoverDuration(arrIso, depIso);
                  final airport = kAirports.firstWhere(
                    (a) => a.iata == arrIata,
                    orElse: () => Airport(iata: arrIata, name: '', city: '', country: ''),
                  );
                  final location = [airport.city, airport.country]
                      .where((s) => s.isNotEmpty).join(', ');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.access_time, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            'Escale à $arrIata${dur.isNotEmpty ? ' · $dur' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          if (location.isNotEmpty)
                            Text(
                              location,
                              style: TextStyle(fontSize: 12, color: Colors.orange.shade600),
                            ),
                        ]),
                      ),
                    ]),
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentDetail(Map<String, dynamic> seg) {
    final segId       = seg['id']?.toString() ?? '';
    final carrierCode = seg['carrierCode']?.toString() ?? '';
    final flightNum   = carrierCode + (seg['number']?.toString() ?? '');
    final carrierName = _carrierName(carrierCode);
    final aircraftCode= (seg['aircraft'] as Map?)?['code']?.toString() ?? '';
    final aircraftName= aircraftCode.isNotEmpty ? _aircraftName(aircraftCode) : '';

    final depAt = (seg['departure'] as Map?)?['at']?.toString() ?? '';
    final arrAt = (seg['arrival']   as Map?)?['at']?.toString() ?? '';
    final depIata = (seg['departure'] as Map?)?['iataCode']?.toString() ?? '';
    final arrIata = (seg['arrival']   as Map?)?['iataCode']?.toString() ?? '';
    final depTerminal = (seg['departure'] as Map?)?['terminal']?.toString() ?? '';
    final arrTerminal = (seg['arrival']   as Map?)?['terminal']?.toString() ?? '';
    final dur = _duration(seg['duration']?.toString());

    final fare   = _fareForSegment(segId);
    final cabin  = _cabinLabel(fare['cabin']?.toString());
    final fareBasis = fare['fareBasis']?.toString() ?? '';
    final bags   = fare['includedCheckedBags'] as Map<String, dynamic>?;
    final bagQty = bags?['quantity'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Airline header
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AirlineLogo(code: carrierCode, size: 48),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(carrierName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('Vol $flightNum',
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
            if (aircraftName.isNotEmpty)
              Text(aircraftName,
                  style: const TextStyle(fontSize: 12, color: Colors.black45)),
            Text('Classe : $cabin',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (fareBasis.isNotEmpty)
              Text('Base tarifaire : $fareBasis',
                  style: const TextStyle(fontSize: 12, color: Colors.black45)),
            if (dur.isNotEmpty)
              Text('Durée : $dur',
                  style: const TextStyle(fontSize: 12, color: Colors.teal)),
          ]),
        ]),
        const SizedBox(height: 16),

        // Timeline
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Column(children: [
              Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              ),
              Expanded(child: Container(width: 2, color: Colors.blue.shade100)),
              Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildStop(
                  time: _time(depAt),
                  dateLabel: _dateLabel(depAt),
                  iata: depIata,
                  terminal: depTerminal,
                ),
                const SizedBox(height: 20),
                _buildStop(
                  time: _time(arrAt),
                  dateLabel: _dateLabel(arrAt),
                  iata: arrIata,
                  terminal: arrTerminal,
                ),
              ]),
            ),
          ]),
        ),

        // Baggage
        if (bagQty > 0) ...[
          const SizedBox(height: 12),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.luggage_outlined, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Bagage en soute inclus',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('$bagQty PC',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ]),
        ] else ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.luggage_outlined, size: 18, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text('Pas de bagage en soute inclus',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ],
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStop({
    required String time,
    required String dateLabel,
    required String iata,
    required String terminal,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(time,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        if (dateLabel.isNotEmpty) ...[
          const Text(' · ', style: TextStyle(color: Colors.black38)),
          Text(dateLabel, style: const TextStyle(fontSize: 13, color: Colors.blue)),
        ],
      ]),
      const SizedBox(height: 2),
      Text(iata, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      if (_cityCountry(iata).isNotEmpty)
        Text(_cityCountry(iata),
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      if (terminal.isNotEmpty)
        Text('Terminal $terminal',
            style: const TextStyle(fontSize: 12, color: Colors.black45)),
    ]);
  }

  Widget _buildBottomBar(BuildContext context) {
    final summary  = rawOffer['_summary'] as Map<String, dynamic>?;
    final price    = summary?['total_price']?.toString()
        ?? (rawOffer['price'] as Map?)?['grandTotal']?.toString()
        ?? '0';
    final priceVal = double.tryParse(price) ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Prix total',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              Text(formatDzd(priceVal),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PassengerFormScreen(
                  rawOffer: rawOffer,
                  flight: flight,
                  onBookingCreated: onBookingCreated,
                  forUserId: forUserId,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
            child: const Text('Continuer',
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
