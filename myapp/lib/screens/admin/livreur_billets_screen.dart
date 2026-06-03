import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/utils/currency.dart';
import 'package:myapp/widgets/reservation_detail_sheet.dart';

class LivreurBilletsScreen extends StatefulWidget {
  final String livreurId;
  final String livreurName;

  const LivreurBilletsScreen({
    super.key,
    required this.livreurId,
    required this.livreurName,
  });

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
      final list = await _api.listLivreurBillets(
        widget.livreurId,
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
      setState(() { _billets = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _statusColor(String s) => switch (s) {
    'pending'   => Colors.orange,
    'confirmed' => Colors.blue,
    'emis'      => Colors.green,
    'cancelled' => Colors.red,
    _           => Colors.grey,
  };

  String _statusLabel(String s) => switch (s) {
    'pending'   => 'En attente',
    'confirmed' => 'Confirmée',
    'emis'      => 'Émis',
    'cancelled' => 'Annulée',
    _           => s,
  };

  void _openDetail(Map<String, dynamic> r) {
    showReservationDetail(context, r, isAgent: true, onStatusChanged: _load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Billets assignés', style: TextStyle(fontSize: 16)),
            Text(widget.livreurName,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
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
                    onSelected: (_) { setState(() => _statusFilter = value); _load(); },
                    selectedColor: Colors.indigo.shade100,
                    checkmarkColor: Colors.indigo,
                    labelStyle: TextStyle(
                      color: active ? Colors.indigo : Colors.grey.shade700,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
              ],
            )))
          else if (_billets.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.confirmation_num_outlined,
                      size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('Aucun billet assigné à ${widget.livreurName}.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500)),
                ]),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
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
                    final amount = r['total_amount'] != null
                        ? formatDzdFromString(r['total_amount'].toString())
                        : '';

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openDetail(r),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
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
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(children: [
                                const Icon(Icons.flight,
                                    size: 13, color: Colors.black45),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: Text(route,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13))),
                                if (amount.isNotEmpty)
                                  Text(amount,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                              ]),
                              if (r['user_full_name'] != null) ...[
                                const SizedBox(height: 3),
                                Row(children: [
                                  const Icon(Icons.person_outline,
                                      size: 13, color: Colors.black45),
                                  const SizedBox(width: 4),
                                  Expanded(
                                      child: Text(
                                          r['user_full_name'].toString(),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54))),
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
