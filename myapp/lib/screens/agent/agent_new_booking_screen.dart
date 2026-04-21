import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/models/flight.dart';
import 'package:myapp/screens/flights/flights_result_screen.dart';

class AgentNewBookingScreen extends StatefulWidget {
  final VoidCallback onBookingCreated;
  const AgentNewBookingScreen({super.key, required this.onBookingCreated});

  @override
  State<AgentNewBookingScreen> createState() => _AgentNewBookingScreenState();
}

class _AgentNewBookingScreenState extends State<AgentNewBookingScreen> {
  final _api = ApiClient();

  // Client selection
  List<Map<String, dynamic>> _clients = [];
  Map<String, dynamic>? _selectedClient;
  bool _loadingClients = true;

  // Search fields
  final _originCtrl      = TextEditingController(text: 'ALG');
  final _destCtrl        = TextEditingController(text: 'TUN');
  String _departureDate  = '';
  String _returnDate     = '';
  int _adults            = 1;
  String _cabinClass     = 'Economique';
  int _flightMode        = 0; // 0=aller-retour, 1=aller simple

  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final list = await _api.listAdminUsers();
      setState(() {
        _clients = list.where((u) => u['role'] == 'client').toList();
        _loadingClients = false;
      });
    } catch (_) {
      setState(() => _loadingClients = false);
    }
  }

  String _toTravelClass(String v) {
    switch (v) {
      case 'Affaires': return 'BUSINESS';
      case 'Première': return 'FIRST';
      default:         return 'ECONOMY';
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _toIso(String dd) {
    final p = dd.split('/');
    if (p.length != 3) return '';
    return '${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}';
  }

  Future<void> _pickDate(Function(String) onPicked) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) onPicked(_formatDate(d));
  }

  Future<void> _search() async {
    final origin = _originCtrl.text.trim().toUpperCase();
    final dest   = _destCtrl.text.trim().toUpperCase();

    if (origin.length != 3 || dest.length != 3) {
      _snack('Codes IATA invalides (3 lettres requis).');
      return;
    }
    if (origin == dest) { _snack('Départ et arrivée identiques.'); return; }
    if (_departureDate.isEmpty) { _snack('Sélectionnez une date de départ.'); return; }
    if (_flightMode == 0 && _returnDate.isEmpty) {
      _snack('Sélectionnez une date de retour.');
      return;
    }

    setState(() => _searching = true);
    try {
      final results = await _api.searchFlights(
        origin: origin,
        destination: dest,
        departureDate: _toIso(_departureDate),
        adults: _adults,
        travelClass: _toTravelClass(_cabinClass),
        returnDate: _flightMode == 0 ? _toIso(_returnDate) : null,
      );

      final valid = results.where((o) => o['_summary'] != null).toList();
      if (valid.isEmpty) { _snack('Aucun vol trouvé.'); return; }

      final flights = valid.map((offer) {
        final s = offer['_summary'] as Map<String, dynamic>;
        return Flight(
          from: s['origin']?.toString() ?? '',
          to: s['destination']?.toString() ?? '',
          date: (s['departure_at']?.toString() ?? '').split('T')[0],
          passengers: _adults.toString(),
          flightClass: _cabinClass,
          isDirect: (s['stops'] ?? 1) == 0,
          hasBaggage: false,
          isRefundable: false,
          price: double.tryParse(s['total_price']?.toString() ?? '0') ?? 0,
          departureAt: s['departure_at']?.toString() ?? '',
          arrivalAt: s['arrival_at']?.toString() ?? '',
        );
      }).toList();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _AgentFlightsResultScreen(
            flights: flights,
            rawOffers: valid,
            selectedClient: _selectedClient,
            onBookingCreated: widget.onBookingCreated,
          ),
        ),
      );
    } catch (e) {
      _snack('Erreur: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nouvelle réservation',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // ── Client selector ──────────────────────────────────────
          _sectionTitle('Client'),
          const SizedBox(height: 8),
          _loadingClients
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: _selectedClient,
                  hint: const Text('Sélectionner un client (optionnel)'),
                  decoration: _inputDecoration(),
                  items: _clients.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text('${c['first_name']} ${c['last_name']} — ${c['email']}'),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedClient = v),
                ),

          const SizedBox(height: 20),

          // ── Trip mode ────────────────────────────────────────────
          _sectionTitle('Type de voyage'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Aller-Retour')),
              ButtonSegment(value: 1, label: Text('Aller simple')),
            ],
            selected: {_flightMode},
            onSelectionChanged: (s) => setState(() => _flightMode = s.first),
          ),

          const SizedBox(height: 20),

          // ── Route ────────────────────────────────────────────────
          _sectionTitle('Itinéraire'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextFormField(
                controller: _originCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration(label: 'Départ', icon: Icons.flight_takeoff),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _destCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration(label: 'Arrivée', icon: Icons.flight_land),
              )),
            ],
          ),
          const SizedBox(height: 12),
          _dateTile(
            icon: Icons.calendar_today,
            label: 'Date de départ',
            value: _departureDate,
            onPick: (v) => setState(() => _departureDate = v),
          ),
          if (_flightMode == 0) ...[
            const SizedBox(height: 8),
            _dateTile(
              icon: Icons.calendar_today_outlined,
              label: 'Date de retour',
              value: _returnDate,
              onPick: (v) => setState(() => _returnDate = v),
            ),
          ],

          const SizedBox(height: 20),

          // ── Passengers & Class ───────────────────────────────────
          _sectionTitle('Passagers & Classe'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _adults,
                  decoration: _inputDecoration(label: 'Adultes', icon: Icons.person),
                  items: List.generate(9, (i) => i + 1)
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n adulte${n > 1 ? 's' : ''}')))
                      .toList(),
                  onChanged: (v) => setState(() => _adults = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _cabinClass,
                  decoration: _inputDecoration(label: 'Classe', icon: Icons.airline_seat_recline_normal),
                  items: ['Economique', 'Affaires', 'Première']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _cabinClass = v!),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _searching ? null : _search,
              icon: _searching
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search, color: Colors.white),
              label: Text(_searching ? 'Recherche…' : 'Rechercher des vols',
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54));

  InputDecoration _inputDecoration({String? label, IconData? icon}) => InputDecoration(
    labelText: label,
    prefixIcon: icon != null ? Icon(icon, size: 18) : null,
    filled: true,
    fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Widget _dateTile({required IconData icon, required String label, required String value, required Function(String) onPick}) {
    return GestureDetector(
      onTap: () => _pickDate(onPick),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 10),
            Text(value.isEmpty ? label : value,
                style: TextStyle(
                  color: value.isEmpty ? Colors.grey : Colors.black87,
                  fontSize: 14,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Results screen wrapper that passes the selected client ──────────────────

class _AgentFlightsResultScreen extends StatelessWidget {
  final List<Flight> flights;
  final List<Map<String, dynamic>> rawOffers;
  final Map<String, dynamic>? selectedClient;
  final VoidCallback onBookingCreated;

  const _AgentFlightsResultScreen({
    required this.flights,
    required this.rawOffers,
    required this.selectedClient,
    required this.onBookingCreated,
  });

  @override
  Widget build(BuildContext context) {
    return FlightsResultScreen(
      flights: flights,
      rawOffers: rawOffers,
      passengersCount: int.tryParse(flights.isNotEmpty ? flights.first.passengers : '1') ?? 1,
      onBookingCreated: onBookingCreated,
      forUserId: selectedClient?['id']?.toString(),
    );
  }
}
