import 'package:flutter/material.dart';
import 'package:myapp/api.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _stats;
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
      final stats = await _api.getAdminStats();
      setState(() { _stats = stats; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.indigo, size: 32),
                const SizedBox(width: 12),
                const Text('Tableau de bord',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
            else ...[
              _statCard('Utilisateurs', _stats!['total_users'].toString(), Icons.people, Colors.blue),
              _statCard('Réservations totales', _stats!['total_reservations'].toString(), Icons.receipt_long, Colors.indigo),
              Row(children: [
                Expanded(child: _statCard('Confirmées', _stats!['confirmed_reservations'].toString(), Icons.check_circle, Colors.green, small: true)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Annulées', _stats!['cancelled_reservations'].toString(), Icons.cancel, Colors.red, small: true)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('En attente', _stats!['pending_reservations'].toString(), Icons.hourglass_empty, Colors.orange, small: true)),
              ]),
              _statCard('Revenus confirmés', '${_stats!['total_revenue']} EUR', Icons.euro, Colors.teal),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, {bool small = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(small ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(small ? 8 : 12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: small ? 20 : 28),
          ),
          SizedBox(width: small ? 10 : 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: small ? 11 : 13)),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: small ? 18 : 26)),
            ],
          ),
        ],
      ),
    );
  }
}
