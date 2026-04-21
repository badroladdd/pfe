import 'package:flutter/material.dart';
import 'package:myapp/models/flight.dart';
import 'package:myapp/screens/flights/flight_detail_screen.dart';

class FlightsResultScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: const Text('Vols disponibles'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: flights.length,
        itemBuilder: (context, index) {
          final flight = flights[index];
          final summary = rawOffers[index]['_summary'] as Map<String, dynamic>?;
          final carrier = summary?['carrier']?.toString() ?? '';
          final isRoundTrip = summary?['is_round_trip'] == true;
          final returnInfo = summary?['return'] as Map<String, dynamic>?;

          return _FlightCard(
            flight: flight,
            carrier: carrier,
            currency: summary?['currency']?.toString() ?? 'DZD',
            isRoundTrip: isRoundTrip,
            returnInfo: returnInfo,
            onBook: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FlightDetailScreen(
                  rawOffer: rawOffers[index],
                  flight: flight,
                  onBookingCreated: onBookingCreated,
                  forUserId: forUserId,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FlightCard extends StatelessWidget {
  final Flight flight;
  final String carrier;
  final String currency;
  final bool isRoundTrip;
  final Map<String, dynamic>? returnInfo;
  final VoidCallback onBook;

  const _FlightCard({
    required this.flight,
    required this.carrier,
    required this.currency,
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
                  '${_formatPrice(flight.price)} $currency',
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

  String _formatPrice(double price) {
    final p = price.toStringAsFixed(2);
    // Format with space thousands separator
    final parts = p.split('.');
    final intPart = parts[0];
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write('\u202F');
      buffer.write(intPart[i]);
    }
    return '${buffer.toString()},${parts[1]}';
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
              width: 52,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                carrier.isNotEmpty ? carrier.substring(0, carrier.length.clamp(0, 6)) : '✈',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
                textAlign: TextAlign.center,
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
