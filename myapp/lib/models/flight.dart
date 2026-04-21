class Flight {
  final String from;
  final String to;
  final String date;
  final String passengers;
  final String flightClass;
  final bool isDirect;
  final bool hasBaggage;
  final bool isRefundable;
  final double price;
  final String departureAt; // ISO datetime, e.g. "2025-04-30T21:25:00"
  final String arrivalAt;   // ISO datetime

  Flight({
    required this.from,
    required this.to,
    required this.date,
    required this.passengers,
    required this.flightClass,
    required this.isDirect,
    required this.hasBaggage,
    required this.isRefundable,
    required this.price,
    this.departureAt = '',
    this.arrivalAt = '',
  });
}
