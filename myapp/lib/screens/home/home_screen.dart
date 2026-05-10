import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/models/flight.dart';
import 'package:myapp/screens/flights/flights_result_screen.dart';
import 'package:myapp/widgets/airport_search_field.dart';

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

  int _adults   = 1;
  int _children = 0;
  List<int> _childrenAges = [];
  String flightClass = 'Economique';

  String get _passengersLabel {
    final parts = <String>[];
    if (_adults   > 0) parts.add('$_adults adulte${_adults > 1 ? 's' : ''}');
    if (_children > 0) parts.add('$_children enfant${_children > 1 ? 's' : ''}');
    return parts.isEmpty ? '1 adulte' : parts.join(', ');
  }
  bool isDirect = false;
  bool hasBaggage = false;
  bool isRefundable = false;

  final ApiClient api = ApiClient();
  List<Map<String, dynamic>> _recommendations = [];

  @override
  void initState() {
    super.initState();
    routes = [{'from': 'ALG', 'to': 'TUN', 'date': _formatDate(DateTime.now())}];
    _loadRecommendations('ALG');
  }

  Future<void> _loadRecommendations(String origin) async {
    if (origin.length != 3) return;
    final dest = routes.isNotEmpty ? (routes[0]['to'] ?? '') : '';
    final results = await api.getRecommendations(origin, destination: dest);
    if (mounted) setState(() => _recommendations = results);
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
        adults: _adults,
        children: _children,
        infants: 0,
        childrenAges: _childrenAges,
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
          passengers: _adults.toString(),
          flightClass: flightClass,
          isDirect: (summary['stops'] ?? 1) == 0,
          hasBaggage: hasBaggage,
          isRefundable: isRefundable,
          price: double.tryParse(summary['total_price']?.toString() ?? '0') ?? 0,
          departureAt: summary['departure_at']?.toString() ?? '',
          arrivalAt: summary['arrival_at']?.toString() ?? '',
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
            passengersCount: _adults + _children,
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
    return Stack(
      children: [
        // World map background
        Positioned.fill(
          child: Image.asset(
            'assets/images/download.jpg',
            fit: BoxFit.cover,
            opacity: const AlwaysStoppedAnimation(0.15),
          ),
        ),
        SingleChildScrollView(
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
          if (_recommendations.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildRecommendations(),
          ],
        ],
      ),
        ),
      ],
    );
  }

  Widget _buildRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.airlines, color: Colors.blue, size: 18),
            const SizedBox(width: 8),
            const Text('Compagnies recommandées',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        ..._recommendations.map((r) {
          final compagnie  = r['compagnie'] as String? ?? '';
          final confidence = (((r['confidence'] as num?) ?? 0) * 100).toStringAsFixed(0);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flight, color: Colors.blue),
              ),
              title: Text(
                compagnie,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              subtitle: Text(
                '$confidence% des voyageurs choisissent cette compagnie',
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$confidence%',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHeader() {
    return const Row(
      children: [
        Icon(Icons.airplanemode_active, color: Colors.blue, size: 35),
        SizedBox(width: 12),
        Text('Recherche de vols',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: ["Aller-Retour", "Aller simple"].asMap().entries.map((entry) {
        final isActive = _flightMode == entry.key;
        return GestureDetector(
          onTap: () => setState(() {
            _flightMode = entry.key;
            routes = [
              {'from': 'ALG', 'to': 'TUN', 'date': _formatDate(DateTime.now())}
            ];
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
          _loadRecommendations(value);
        }),
        const Divider(indent: 50, height: 1),
        _buildListTile(Icons.flight_land, "Où allez-vous ?",
            routes[index]['to'] ?? 'TUN', (value) {
          setState(() => routes[index]['to'] = value);
          // Recharger recommandations avec nouvelle destination
          _loadRecommendations(routes[index]['from'] ?? '');
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
          final iata = await showAirportSearch(context, current: value);
          if (iata != null) onChanged(iata);
        }
      },
    );
  }

  Widget _buildDualField() {
    return Row(
      children: [
        Expanded(
          child: ListTile(
            leading: Icon(Icons.person_outline, color: Colors.grey[400]),
            title: const Text('Passagers', style: TextStyle(fontSize: 11, color: Colors.grey)),
            subtitle: Text(_passengersLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
    int adults   = _adults;
    int children = _children;
    List<int> childrenAges = List.from(_childrenAges);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          void changeChildren(int delta) {
            final next = (children + delta).clamp(0, 8);
            if (next > children) {
              // added a child — ask age
              showDialog<int>(
                context: ctx,
                builder: (_) {
                  int selectedAge = 5;
                  return StatefulBuilder(
                    builder: (ageCtx, setAge) => AlertDialog(
                      title: const Text('Âge de l\'enfant'),
                      content: SizedBox(
                        height: 160,
                        child: Column(
                          children: [
                            const Text('Âge au moment du voyage',
                                style: TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 12),
                            DropdownButton<int>(
                              value: selectedAge,
                              isExpanded: true,
                              items: List.generate(10, (i) => i + 2)
                                  .map((age) => DropdownMenuItem(
                                        value: age,
                                        child: Text('$age ans'),
                                      ))
                                  .toList(),
                              onChanged: (v) => setAge(() => selectedAge = v!),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ageCtx),
                            child: const Text('Annuler')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ageCtx, selectedAge),
                          child: const Text('Confirmer'),
                        ),
                      ],
                    ),
                  );
                },
              ).then((age) {
                if (age != null) {
                  setDlg(() {
                    children = next;
                    childrenAges.add(age);
                  });
                }
              });
            } else {
              setDlg(() {
                children = next;
                if (childrenAges.isNotEmpty) childrenAges.removeLast();
              });
            }
          }

          return AlertDialog(
            title: const Text('Passagers'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _passengerRow('Adultes', '12 ans et +', adults,
                    onMinus: adults > 1 ? () => setDlg(() => adults--) : null,
                    onPlus: adults < 9  ? () => setDlg(() => adults++) : null),
                const Divider(height: 24),
                _passengerRow('Enfants', '2 – 11 ans', children,
                    onMinus: children > 0 ? () => changeChildren(-1) : null,
                    onPlus: children < 8  ? () => changeChildren(1)  : null),
                if (childrenAges.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: childrenAges.asMap().entries.map((e) =>
                      Chip(
                        label: Text('Enfant ${e.key + 1}: ${e.value} ans',
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.blue.shade50,
                      ),
                    ).toList(),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _adults       = adults;
                    _children     = children;
                    _childrenAges = childrenAges;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Confirmer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _passengerRow(String title, String subtitle, int count,
      {VoidCallback? onMinus, VoidCallback? onPlus}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
        IconButton(
          onPressed: onMinus,
          icon: Icon(Icons.remove_circle_outline,
              color: onMinus != null ? Colors.blue : Colors.grey.shade300),
        ),
        SizedBox(
          width: 28,
          child: Text('$count',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        IconButton(
          onPressed: onPlus,
          icon: Icon(Icons.add_circle_outline,
              color: onPlus != null ? Colors.blue : Colors.grey.shade300),
        ),
      ],
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
