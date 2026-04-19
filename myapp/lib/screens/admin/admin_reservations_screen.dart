import 'package:flutter/material.dart';
import 'package:myapp/api.dart';

class AdminReservationsScreen extends StatefulWidget {
  const AdminReservationsScreen({super.key});

  @override
  State<AdminReservationsScreen> createState() => _AdminReservationsScreenState();
}

class _AdminReservationsScreenState extends State<AdminReservationsScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _reservations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.listReservations();
      setState(() { _reservations = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'pending':   return Colors.orange;
      default:          return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.indigo),
                const SizedBox(width: 10),
                Text('Réservations (${_reservations.length})',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
          else if (_reservations.isEmpty)
            const Expanded(child: Center(child: Text('Aucune réservation.')))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _reservations.length,
                itemBuilder: (context, i) {
                  final r = _reservations[i];
                  final statusStr = r['status'] as String? ?? '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _statusColor(statusStr).withValues(alpha: 0.1),
                        child: Icon(Icons.flight, color: _statusColor(statusStr)),
                      ),
                      title: Text(
                        r['booking_reference']?.toString().isNotEmpty == true
                            ? r['booking_reference']
                            : r['id'].toString().substring(0, 8),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(r['user_email'] ?? ''),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(statusStr).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(statusStr,
                            style: TextStyle(
                                color: _statusColor(statusStr),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
