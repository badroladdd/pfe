import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/utils/currency.dart';
import 'package:myapp/utils/ticket_pdf.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  List<Map<String, dynamic>> _reservations = [];
  bool _loading = true;
  String? _error;
  late TabController _tabCtrl;

  static const _tabs = [
    ('confirmed', 'Confirmé',  Colors.green),
    ('pending',   'En attente', Colors.orange),
    ('cancelled', 'Annulé',    Colors.red),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
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

  List<Map<String, dynamic>> _filtered(String status) =>
      _reservations.where((r) => (r['status'] as String? ?? 'pending') == status).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes voyages'),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF3B82F6),
          indicatorWeight: 2.5,
          tabs: _tabs.map((t) {
            final count = _reservations
                .where((r) => (r['status'] as String? ?? 'pending') == t.$1)
                .length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.$2),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: t.$3.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(fontSize: 11, color: t.$3, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : TabBarView(
                  controller: _tabCtrl,
                  children: _tabs.map((t) {
                    final list = _filtered(t.$1);
                    if (list.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.flight_takeoff, size: 70, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun voyage ${t.$2.toLowerCase()}',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        itemBuilder: (context, index) => _buildCard(list[index], t.$3),
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  Widget _buildCard(Map<String, dynamic> r, Color statusColor) {
    final ref = r['booking_reference'] as String? ?? r['id']?.toString() ?? 'N/A';
    final amount = r['total_amount']?.toString() ?? '0';
    final createdAt = r['created_at'] as String? ?? '';
    final status = r['status'] as String? ?? 'pending';
    DateTime? date;
    try { date = DateTime.parse(createdAt); } catch (_) {}

    final statusLabel = status == 'confirmed'
        ? 'Confirmé'
        : status == 'cancelled'
            ? 'Annulé'
            : 'En attente';

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
                    Text(formatDzdFromString(amount),
                        style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold)),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(
                              color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
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
  }
}
