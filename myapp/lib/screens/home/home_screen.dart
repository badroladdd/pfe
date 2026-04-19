import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/models/flight.dart';
import 'package:myapp/screens/flights/flights_result_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onBookingCreated;

  const HomeScreen({super.key, required this.onBookingCreated});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _flightMode = 0;
  List<Map<String, String>> routes = [];
  String _returnDate = '';

  String passengers = '1 Passager';
  String flightClass = 'Economique';
  bool isDirect = false;
  bool hasBaggage = false;
  bool isRefundable = false;

  final ApiClient api = ApiClient();

  @override
  void initState() {
    super.initState();
    routes = [];
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  bool _isIataCode(String value) {
    return RegExp(r'^[A-Za-z]{3}$').hasMatch(value.trim());
  }

  String _toTravelClass(String value) {
    switch (value) {
      case 'Affaires': return 'BUSINESS';
      case 'Première': return 'FIRST';
      default:         return 'ECONOMY';
    }
  }

  void _addRoute() {
    if (routes.length < 4) {
      setState(() {
        routes.add({'from': '', 'to': '', 'date': _formatDate(DateTime.now())});
      });
    }
  }

  Future<void> _searchFlights() async {
    final origin      = routes[0]['from']?.trim().toUpperCase() ?? '';
    final destination = routes[0]['to']?.trim().toUpperCase() ?? '';
    final rawDate     = routes[0]['date']?.trim() ?? '';

    if (!_isIataCode(origin) || !_isIataCode(destination)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir des codes IATA valides à 3 lettres.')),
      );
      return;
    }

    if (origin == destination) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L\'aéroport de départ et d\'arrivée doit être différent.')),
      );
      return;
    }

    if (rawDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une date de départ.')),
      );
      return;
    }

    final dateParts = rawDate.split('/');
    if (dateParts.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date invalide. Utilisez le format JJ/MM/AAAA.')),
      );
      return;
    }

    final formattedDate =
        '${dateParts[2]}-${dateParts[1].padLeft(2, '0')}-${dateParts[0].padLeft(2, '0')}';

    String? formattedReturnDate;
    if (_flightMode == 0) {
      if (_returnDate.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez sélectionner une date de retour.')),
        );
        return;
      }
      final rParts = _returnDate.split('/');
      if (rParts.length == 3) {
        formattedReturnDate =
            '${rParts[2]}-${rParts[1].padLeft(2, '0')}-${rParts[0].padLeft(2, '0')}';
      }
    }

    try {
      final results = await api.searchFlights(
        origin: origin,
        destination: destination,
        departureDate: formattedDate,
        adults: int.parse(passengers.split(' ')[0]),
        travelClass: _toTravelClass(flightClass),
        nonStop: isDirect,
        returnDate: formattedReturnDate,
      );

      final validOffers = results.where((offer) => offer['_summary'] != null).toList();

      final foundFlights = validOffers.map((offer) {
        final summary = offer['_summary'] as Map<String, dynamic>;
        return Flight(
          from: summary['origin']?.toString() ?? '',
          to: summary['destination']?.toString() ?? '',
          date: (summary['departure_at']?.toString() ?? '').split('T')[0],
          passengers: passengers.split(' ')[0],
          flightClass: flightClass,
          isDirect: (summary['stops'] ?? 1) == 0,
          hasBaggage: hasBaggage,
          isRefundable: isRefundable,
          price: double.tryParse(summary['total_price']?.toString() ?? '0') ?? 0,
        );
      }).toList();

      if (foundFlights.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun vol trouvé pour ces critères.')),
        );
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FlightsResultScreen(
            flights: foundFlights,
            rawOffers: validOffers,
            passengersCount: int.parse(passengers.split(' ')[0]),
            onBookingCreated: widget.onBookingCreated,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de recherche: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildTabSelector(),
          const SizedBox(height: 20),
          _buildSearchCard(),
          const SizedBox(height: 15),
          _buildOptionsRow(),
          const SizedBox(height: 25),
          _buildSearchButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Icon(Icons.airplanemode_active, color: Colors.blue, size: 35),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            children: [
              const Icon(Icons.phone, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              const Text("0560 99 90 09",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const CircleAvatar(
            backgroundColor: Colors.white,
            radius: 18,
            child: Text("🇫🇷", style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: ["Aller-Retour", "Aller simple", "Multi"].asMap().entries.map((entry) {
        final isActive = _flightMode == entry.key;
        return GestureDetector(
          onTap: () => setState(() {
            _flightMode = entry.key;
            if (_flightMode != 2) {
              routes = [
                {'from': 'ALG', 'to': 'TUN', 'date': _formatDate(DateTime.now())}
              ];
            }
          }),
          child: Column(
            children: [
              Text(entry.value,
                  style: TextStyle(
                      color: isActive ? Colors.blue : Colors.grey,
                      fontWeight: FontWeight.bold)),
              if (isActive)
                Container(
                    margin: const EdgeInsets.only(top: 5),
                    height: 3,
                    width: 40,
                    color: Colors.blue),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          ...routes.asMap().entries.map((e) => _buildRouteItem(e.key)),
          if (_flightMode == 0) ...[
            const Divider(indent: 50, height: 1),
            _buildListTile(
              Icons.calendar_today,
              "Date de retour",
              _returnDate.isEmpty ? 'Sélectionnez une date' : _returnDate,
              (value) => setState(() => _returnDate = value),
              isDate: true,
            ),
          ],
          if (_flightMode == 2)
            TextButton.icon(
              onPressed: _addRoute,
              icon: const Icon(Icons.add),
              label: const Text("Ajouter un vol"),
            ),
          const Divider(height: 1),
          _buildDualField(),
        ],
      ),
    );
  }

  Widget _buildRouteItem(int index) {
    return Column(
      children: [
        if (index > 0) const Divider(thickness: 1),
        _buildListTile(Icons.flight_takeoff, "D'où partez-vous ?",
            routes[index]['from'] ?? 'ALG', (value) {
          setState(() => routes[index]['from'] = value);
        }),
        const Divider(indent: 50, height: 1),
        _buildListTile(Icons.flight_land, "Où allez-vous ?",
            routes[index]['to'] ?? 'TUN', (value) {
          setState(() => routes[index]['to'] = value);
        }),
        const Divider(indent: 50, height: 1),
        _buildListTile(Icons.calendar_today, "Date",
            routes[index]['date'] ?? 'Sélectionnez une date', (value) {
          setState(() => routes[index]['date'] = value);
        }, isDate: true),
      ],
    );
  }

  Widget _buildListTile(IconData icon, String label, String value,
      Function(String) onChanged, {bool isDate = false}) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[400]),
      title: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      onTap: () async {
        if (isDate) {
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (pickedDate != null) {
            onChanged("${pickedDate.day}/${pickedDate.month}/${pickedDate.year}");
          }
        } else {
          _showEditDialog(label, value, onChanged);
        }
      },
    );
  }

  void _showEditDialog(String label, String currentValue, Function(String) onChanged) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier $label'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Entrez $label'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              onChanged(controller.text);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildDualField() {
    return Row(
      children: [
        Expanded(
          child: ListTile(
            leading: Icon(Icons.person_outline, color: Colors.grey[400]),
            title: const Text('Passagers', style: TextStyle(fontSize: 11, color: Colors.grey)),
            subtitle: Text(passengers, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            onTap: _showPassengerDialog,
          ),
        ),
        Container(width: 1, height: 40, color: Colors.grey[200]),
        Expanded(
          child: ListTile(
            leading: Icon(Icons.confirmation_number_outlined, color: Colors.grey[400]),
            title: const Text('Classe', style: TextStyle(fontSize: 11, color: Colors.grey)),
            subtitle: Text(flightClass, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            onTap: _showClassDialog,
          ),
        ),
      ],
    );
  }

  void _showPassengerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nombre de passagers'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['1 Passager', '2 Passagers', '3 Passagers', '4 Passagers']
              .map((v) => ListTile(
                    title: Text(v),
                    onTap: () {
                      setState(() => passengers = v);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showClassDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Classe de voyage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Economique', 'Affaires', 'Première']
              .map((v) => ListTile(
                    title: Text(v),
                    onTap: () {
                      setState(() => flightClass = v);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildOptionsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildOption("Direct", isDirect, (v) => setState(() => isDirect = v!)),
        _buildOption("Bagages", hasBaggage, (v) => setState(() => hasBaggage = v!)),
        _buildOption("Remboursable", isRefundable, (v) => setState(() => isRefundable = v!)),
      ],
    );
  }

  Widget _buildOption(String title, bool value, Function(bool?) onChanged) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        Text(title, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildSearchButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: _searchFlights,
        icon: const Icon(Icons.search, color: Colors.white),
        label: const Text("Rechercher",
            style: TextStyle(color: Colors.white, fontSize: 18)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }
}
