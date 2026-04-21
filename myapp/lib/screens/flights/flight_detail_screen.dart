import 'package:flutter/material.dart';
import 'package:myapp/models/flight.dart';
import 'package:myapp/screens/flights/passenger_form_screen.dart';

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

  // ── helpers ──────────────────────────────────────────────────────────

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
      const months = [
        'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
        'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }

  String _dateShort(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      const days = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
      const months = ['Jan.', 'Fév.', 'Mar.', 'Avr.', 'Mai', 'Juin',
                      'Juil.', 'Août', 'Sep.', 'Oct.', 'Nov.', 'Déc.'];
      return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }

  String _duration(String? dur) {
    if (dur == null || dur.isEmpty) return '';
    // Duffel format: PT1H10M
    try {
      final h = RegExp(r'(\d+)H').firstMatch(dur)?.group(1) ?? '0';
      final m = RegExp(r'(\d+)M').firstMatch(dur)?.group(1) ?? '0';
      return '${h}h ${m}m';
    } catch (_) {
      return dur;
    }
  }

  String _cabinLabel(String? cabin) {
    switch ((cabin ?? '').toLowerCase()) {
      case 'business':        return 'Affaires';
      case 'first':           return 'Première';
      case 'premium_economy': return 'Premium Eco.';
      default:                return 'Economique';
    }
  }

  // ── build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final slices = (rawOffer['slices'] as List?)?.cast<Map<String, dynamic>>() ?? [];

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
                for (final slice in slices) _buildSliceCard(slice, slices.length > 1),
              ],
            ),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildSliceCard(Map<String, dynamic> slice, bool isRoundTrip) {
    final segments = (slice['segments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final firstSeg = segments.isNotEmpty ? segments.first : <String, dynamic>{};
    final lastSeg  = segments.isNotEmpty ? segments.last  : <String, dynamic>{};

    final origin      = (slice['origin']      as Map?)?.cast<String, dynamic>() ?? {};
    final destination = (slice['destination'] as Map?)?.cast<String, dynamic>() ?? {};

    final depAt = firstSeg['departing_at']?.toString() ?? '';
    final arrAt = lastSeg['arriving_at']?.toString()   ?? '';

    final isOutbound = slice == (rawOffer['slices'] as List?)?.first;
    final sliceLabel = !isRoundTrip ? null : (isOutbound ? 'Aller' : 'Retour');

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: label + date ────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sliceLabel ?? 'Vol',
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue,
                  ),
                ),
                Text(
                  _dateShort(depAt),
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Times row ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_time(depAt),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    Text(
                      '${origin['city_name'] ?? ''} (${origin['iata_code'] ?? ''})',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      segments.length == 1 ? 'Direct' : '${segments.length - 1} escale(s)',
                      style: TextStyle(
                        color: segments.length == 1 ? Colors.teal : Colors.orange,
                        fontWeight: FontWeight.w500, fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(width: 50, height: 1, color: Colors.grey.shade300),
                        Icon(Icons.flight, size: 16, color: Colors.grey.shade400),
                        Container(width: 50, height: 1, color: Colors.grey.shade300),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_time(arrAt),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    Text(
                      '${destination['city_name'] ?? ''} (${destination['iata_code'] ?? ''})',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),

            const Divider(height: 24),

            // ── Segments detail ────────────────────────────────────
            for (final seg in segments) _buildSegmentDetail(seg),

            // ── Baggage ────────────────────────────────────────────
            _buildBaggageSection(firstSeg),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentDetail(Map<String, dynamic> seg) {
    final carrier    = (seg['marketing_carrier'] as Map?)?.cast<String, dynamic>() ?? {};
    final aircraft   = (seg['aircraft']          as Map?)?.cast<String, dynamic>() ?? {};
    final origin     = (seg['origin']            as Map?)?.cast<String, dynamic>() ?? {};
    final destination= (seg['destination']       as Map?)?.cast<String, dynamic>() ?? {};
    final depAt      = seg['departing_at']?.toString() ?? '';
    final arrAt      = seg['arriving_at']?.toString()  ?? '';
    final duration   = _duration(seg['duration']?.toString());

    // Cabin class & fare basis from first passenger slice
    final paxList  = (seg['passengers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final firstPax = paxList.isNotEmpty ? paxList.first : <String, dynamic>{};
    final cabin    = _cabinLabel(firstPax['cabin_class']?.toString());
    final fareCode = firstPax['fare_basis_code']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Airline + flight info
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Airline box
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                carrier['iata_code']?.toString() ?? '✈',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(carrier['name']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  '${carrier['iata_code'] ?? ''}-${seg['marketing_carrier_flight_number'] ?? ''}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                if (aircraft['name'] != null)
                  Text(aircraft['name'].toString(),
                      style: const TextStyle(fontSize: 12, color: Colors.black45)),
                Text('Classe: $cabin',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                if (fareCode.isNotEmpty)
                  Text('Classe de la réservation: $fareCode',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                if (duration.isNotEmpty)
                  Text('Durée: $duration',
                      style: const TextStyle(fontSize: 12, color: Colors.teal)),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Timeline
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vertical line + dots
              Column(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: Colors.blue, shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                  ),
                  Expanded(child: Container(width: 2, color: Colors.blue.shade100)),
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: Colors.blue, shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Stop info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStop(
                      time: _time(depAt),
                      dateLabel: _dateLabel(depAt),
                      airportName: origin['name']?.toString() ?? '',
                      iata: origin['iata_code']?.toString() ?? '',
                      city: origin['city_name']?.toString() ?? '',
                    ),
                    const SizedBox(height: 20),
                    _buildStop(
                      time: _time(arrAt),
                      dateLabel: _dateLabel(arrAt),
                      airportName: destination['name']?.toString() ?? '',
                      iata: destination['iata_code']?.toString() ?? '',
                      city: destination['city_name']?.toString() ?? '',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStop({
    required String time,
    required String dateLabel,
    required String airportName,
    required String iata,
    required String city,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (dateLabel.isNotEmpty) ...[
              const Text(' - ', style: TextStyle(color: Colors.black38)),
              Text(dateLabel, style: const TextStyle(fontSize: 13, color: Colors.blue)),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          airportName.isNotEmpty ? '$airportName ($iata)' : iata,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        if (city.isNotEmpty)
          Text(city, style: const TextStyle(fontSize: 12, color: Colors.black45)),
      ],
    );
  }

  Widget _buildBaggageSection(Map<String, dynamic> seg) {
    final paxList = (seg['passengers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (paxList.isEmpty) return const SizedBox.shrink();

    final baggages = (paxList.first['baggages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (baggages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        const Text('Bagages',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        for (final bag in baggages) _buildBaggageRow(bag),
      ],
    );
  }

  Widget _buildBaggageRow(Map<String, dynamic> bag) {
    final type     = bag['type']?.toString() ?? '';
    final quantity = bag['quantity']?.toString() ?? '0';

    final bool isCabin = type == 'carry_on';
    final label = isCabin ? 'Bagage en cabine inclus' : 'Bagage en soute inclus';
    final icon  = isCabin ? Icons.backpack_outlined : Icons.luggage_outlined;

    // quantity detail
    String detail = '$quantity PC';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(detail, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final summary  = rawOffer['_summary'] as Map<String, dynamic>?;
    final price    = summary?['total_price']?.toString() ?? rawOffer['total_amount']?.toString() ?? '0';
    final currency = summary?['currency']?.toString()    ?? rawOffer['total_currency']?.toString() ?? '';
    final priceVal = double.tryParse(price) ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Prix total', style: TextStyle(fontSize: 12, color: Colors.black54)),
              Text(
                '${_fmtPrice(priceVal)} $currency',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
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
            child: const Text('Continuer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _fmtPrice(double price) {
    final parts   = price.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final buf     = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('\u202F');
      buf.write(intPart[i]);
    }
    return '${buf.toString()},${parts[1]}';
  }
}
