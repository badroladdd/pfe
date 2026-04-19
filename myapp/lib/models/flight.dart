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
  });
}
