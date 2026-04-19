import 'package:flutter/material.dart';
import 'package:myapp/models/flight.dart';
import 'package:myapp/screens/flights/passenger_form_screen.dart';

class FlightsResultScreen extends StatelessWidget {
  final List<Flight> flights;
  final List<Map<String, dynamic>> rawOffers;
  final int passengersCount;
  final VoidCallback onBookingCreated;

  const FlightsResultScreen({
    super.key,
    required this.flights,
    required this.rawOffers,
    required this.passengersCount,
    required this.onBookingCreated,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vols disponibles'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: flights.length,
        itemBuilder: (context, index) {
          final flight = flights[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${flight.from} → ${flight.to}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${flight.price.toStringAsFixed(0)} €',
                          style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Date: ${flight.date}'),
                  Text('${flight.passengers} · ${flight.flightClass}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (flight.isDirect)
                        Chip(label: const Text('Direct'), backgroundColor: Colors.blue.shade50),
                      if (flight.hasBaggage)
                        Chip(label: const Text('Bagages'), backgroundColor: Colors.orange.shade50),
                      if (flight.isRefundable)
                        Chip(label: const Text('Remboursable'), backgroundColor: Colors.green.shade50),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PassengerFormScreen(
                              rawOffer: rawOffers[index],
                              flight: flight,
                              onBookingCreated: onBookingCreated,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Réserver', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
