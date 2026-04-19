import 'package:myapp/models/flight.dart';

class Booking {
  final String reference;
  final List<Flight> flights;
  final DateTime bookingDate;
  final double totalPrice;

  Booking({
    required this.reference,
    required this.flights,
    required this.bookingDate,
    required this.totalPrice,
  });
}
