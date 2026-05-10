import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/utils/ticket_pdf.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _reservations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _cancelReservation(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la réservation'),
        content: const Text('Voulez-vous vraiment annuler cette réservation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, annuler', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.cancelReservation(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réservation annulée'), backgroundColor: Colors.orange),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final loggedIn = await _api.isLoggedIn;
      if (!loggedIn) {
        if (mounted) setState(() { _reservations = []; _loading = false; });
        return;
      }
      final list = await _api.listReservations();
      if (mounted) setState(() { _reservations = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes voyages'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _reservations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flight_takeoff, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 20),
                          Text('Aucun voyage pour le moment',
                              style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                          const SizedBox(height: 10),
                          Text('Réservez votre premier vol !',
                              style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _reservations.length,
                        itemBuilder: (context, index) {
                          final r = _reservations[index];
                          final ref = r['booking_reference'] as String? ?? r['id']?.toString() ?? 'N/A';
                          final amount = r['total_amount']?.toString() ?? '0';
                          final currency = r['currency'] as String? ?? 'EUR';
                          final createdAt = r['created_at'] as String? ?? '';
                          final status = r['status'] as String? ?? 'confirmed';
                          DateTime? date;
                          try { date = DateTime.parse(createdAt); } catch (_) {}

                          final statusColor = status == 'confirmed'
                              ? Colors.green
                              : status == 'cancelled'
                                  ? Colors.red
                                  : Colors.orange;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.flight, color: Colors.blue),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${r['origin_iata'] ?? '---'} → ${r['destination_iata'] ?? '---'}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            Text('Réf: $ref',
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                            if (date != null)
                                              Text(
                                                'Réservé le ${date.day}/${date.month}/${date.year}',
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('$amount $currency',
                                              style: TextStyle(
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.bold)),
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusColor.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(status,
                                                style: TextStyle(
                                                    color: statusColor.shade700, fontSize: 11)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (status == 'confirmed' || status == 'pending') ...[
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        if (status == 'confirmed')
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => downloadTicketPdf(r),
                                              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                              label: const Text('Billet PDF',
                                                  style: TextStyle(color: Colors.red)),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Colors.red),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10)),
                                              ),
                                            ),
                                          ),
                                        if (status == 'confirmed') const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _cancelReservation(r['id'].toString()),
                                            icon: const Icon(Icons.cancel_outlined, color: Colors.orange),
                                            label: const Text('Annuler',
                                                style: TextStyle(color: Colors.orange)),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: Colors.orange),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
