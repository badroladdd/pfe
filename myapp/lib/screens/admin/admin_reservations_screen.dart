import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/utils/currency.dart';
import 'package:myapp/widgets/reservation_detail_sheet.dart';

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
  String _statusFilter = 'all';

  static const _filters = [
    ('all',       'Tous'),
    ('pending',   'En attente'),
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
      final list = await _api.listAdminReservations(
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
      setState(() { _reservations = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  _StatusMeta _meta(String s) => switch (s) {
    'pending'   => _StatusMeta('En attente', Colors.orange, Icons.hourglass_empty),
    'confirmed' => _StatusMeta('Confirmée',  Colors.blue,   Icons.check_circle_outline),
    'emis'      => _StatusMeta('Émis',       Colors.green,  Icons.confirmation_num),
    'cancelled' => _StatusMeta('Annulée',    Colors.red,    Icons.cancel_outlined),
    _           => _StatusMeta(s,            Colors.grey,   Icons.help_outline),
  };

  void _openDetail(Map<String, dynamic> r) {
    showReservationDetail(
      context, r,
      isAgent: false,
      onStatusChanged: _load,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.confirmation_num, color: Colors.indigo),
                const SizedBox(width: 8),
                Text('Billets (${_reservations.length})',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _filters.map((f) {
                final (value, label) = f;
                final active = _statusFilter == value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: active,
                    onSelected: (_) { setState(() => _statusFilter = value); _load(); },
                    selectedColor: Colors.indigo,
                    labelStyle: TextStyle(
                      color: active ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
          else if (_reservations.isEmpty)
            const Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.confirmation_num_outlined, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Aucun billet.', style: TextStyle(color: Colors.grey)),
                ]),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: _reservations.length,
                itemBuilder: (_, i) {
                  final r = _reservations[i];
                  return _BilletCard(
                    r: r,
                    meta: _meta(r['status'] as String? ?? ''),
                    onTap: () => _openDetail(r),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _BilletCard extends StatelessWidget {
  final Map<String, dynamic> r;
  final _StatusMeta meta;
  final VoidCallback onTap;

  const _BilletCard({required this.r, required this.meta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ref = r['booking_reference']?.toString().isNotEmpty == true
        ? r['booking_reference'] : r['id'].toString().substring(0, 8);
    final route = '${r['origin_iata'] ?? '?'} → ${r['destination_iata'] ?? '?'}';
    final amount = r['total_amount'] != null
        ? formatDzdFromString(r['total_amount'].toString()) : '';
    final livreurName = r['livreur_name'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(meta.icon, size: 16, color: meta.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(ref, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  _StatusBadge(meta: meta),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.flight, size: 14, color: Colors.black45),
                  const SizedBox(width: 4),
                  Expanded(child: Text(route, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13))),
                  if (amount.isNotEmpty)
                    Text(amount, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              if (r['user_email'] != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.person_outline, size: 13, color: Colors.black45),
                  const SizedBox(width: 4),
                  Expanded(child: Text(r['user_email'].toString(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black54))),
                ]),
              ],
              if (livreurName != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.delivery_dining, size: 13, color: Colors.teal),
                  const SizedBox(width: 4),
                  Text(livreurName,
                      style: const TextStyle(fontSize: 12, color: Colors.teal)),
                ]),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Voir les détails',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _StatusMeta meta;
  const _StatusBadge({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: meta.color.withValues(alpha: 0.3)),
      ),
      child: Text(meta.label,
          style: TextStyle(color: meta.color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

class _StatusMeta {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusMeta(this.label, this.color, this.icon);
}
