import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/utils/currency.dart';

class LivreurBilletsScreen extends StatefulWidget {
  const LivreurBilletsScreen({super.key});

  @override
  State<LivreurBilletsScreen> createState() => _LivreurBilletsScreenState();
}

class _LivreurBilletsScreenState extends State<LivreurBilletsScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _billets = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'all';

  static const _filters = [
    ('all',       'Tous'),
    ('confirmed', 'Confirmée'),
    ('emis',      'Émis'),
    ('cancelled', 'Annulée'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.listMyBillets(
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
      setState(() { _billets = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _statusColor(String s) => switch (s) {
    'confirmed' => Colors.blue,
    'emis'      => Colors.green,
    'cancelled' => Colors.red,
    _           => Colors.grey,
  };

  String _statusLabel(String s) => switch (s) {
    'confirmed' => 'Confirmée',
    'emis'      => 'Émis',
    'cancelled' => 'Annulée',
    _           => s,
  };

  IconData _statusIcon(String s) => switch (s) {
    'confirmed' => Icons.check_circle_outline,
    'emis'      => Icons.confirmation_num,
    'cancelled' => Icons.cancel_outlined,
    _           => Icons.help_outline,
  };

  void _showDetail(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BilletDetailSheet(r: r),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Mes billets'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: _filters.map((f) {
                final (value, label) = f;
                final active = _statusFilter == value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: active,
                    onSelected: (_) {
                      setState(() => _statusFilter = value);
                      _load();
                    },
                    selectedColor: Colors.teal.shade100,
                    checkmarkColor: Colors.teal,
                    labelStyle: TextStyle(
                      color: active ? Colors.teal.shade700 : Colors.grey.shade700,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Body
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.teal)))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                ]),
              ),
            )
          else if (_billets.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.confirmation_num_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('Aucun billet assigné',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                ]),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: Colors.teal,
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _billets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = _billets[i];
                    final status = r['status'] as String? ?? '';
                    final ref = r['booking_reference']?.toString().isNotEmpty == true
                        ? r['booking_reference']
                        : r['id'].toString().substring(0, 8);
                    final route =
                        '${r['origin_iata'] ?? '?'} → ${r['destination_iata'] ?? '?'}';
                    final client = r['user_full_name'] as String? ?? '';
                    final phone  = r['user_phone'] as String? ?? '';
                    final amount = r['total_amount'] != null
                        ? formatDzdFromString(r['total_amount'].toString())
                        : '';

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _showDetail(r),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row
                              Row(children: [
                                Icon(_statusIcon(status),
                                    size: 16,
                                    color: _statusColor(status)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(ref,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: _statusColor(status)
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    _statusLabel(status),
                                    style: TextStyle(
                                        color: _statusColor(status),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              // Route
                              Row(children: [
                                const Icon(Icons.flight, size: 14, color: Colors.black45),
                                const SizedBox(width: 4),
                                Expanded(child: Text(route,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13))),
                                if (amount.isNotEmpty)
                                  Text(amount,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600, fontSize: 13)),
                              ]),
                              // Client
                              if (client.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.person_outline,
                                      size: 13, color: Colors.black45),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(client,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black54))),
                                  if (phone.isNotEmpty)
                                    Row(children: [
                                      const Icon(Icons.phone_outlined,
                                          size: 13, color: Colors.teal),
                                      const SizedBox(width: 4),
                                      Text(phone,
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.teal)),
                                    ]),
                                ]),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('Voir les détails',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500)),
                                  Icon(Icons.chevron_right,
                                      size: 14, color: Colors.grey.shade400),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Detail sheet (read-only for livreur) ─────────────────────────────────────

class _BilletDetailSheet extends StatelessWidget {
  final Map<String, dynamic> r;
  const _BilletDetailSheet({required this.r});

  String _fmt(String iso) {
    if (iso.length < 16) return iso;
    return '${iso.substring(0, 10)}  ${iso.substring(11, 16)}';
  }

  @override
  Widget build(BuildContext context) {
    final ref = r['booking_reference']?.toString().isNotEmpty == true
        ? r['booking_reference']
        : r['id'].toString().substring(0, 8);
    final passengers =
        (r['passengers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final departure = r['departure_at'] as String? ?? '';
    final arrival   = r['arrival_at'] as String? ?? '';
    final carrier   = r['carrier_name'] as String? ?? '';
    final amount    = r['total_amount'] != null
        ? formatDzdFromString(r['total_amount'].toString())
        : '';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            Text('Billet $ref',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (carrier.isNotEmpty)
              Text(carrier,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 20),

            _section('Vol', [
              _row(Icons.flight_takeoff, 'Départ',
                  '${r['origin_iata'] ?? '?'}  ${_fmt(departure)}'),
              _row(Icons.flight_land, 'Arrivée',
                  '${r['destination_iata'] ?? '?'}  ${_fmt(arrival)}'),
              if (amount.isNotEmpty)
                _row(Icons.payments_outlined, 'Montant', amount),
            ]),
            const SizedBox(height: 16),

            _section('Client', [
              _row(Icons.person_outline, 'Nom',
                  r['user_full_name'] as String? ?? ''),
              _row(Icons.email_outlined, 'Email',
                  r['user_email'] as String? ?? ''),
              if ((r['user_phone'] as String? ?? '').isNotEmpty)
                _row(Icons.phone_outlined, 'Téléphone',
                    r['user_phone'] as String? ?? ''),
            ]),

            if (passengers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Passagers (${passengers.length})',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              ...passengers.map((p) {
                final name =
                    '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 8),
        SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        Expanded(
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
