import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/utils/currency.dart';

class AgentReservationsScreen extends StatefulWidget {
  const AgentReservationsScreen({super.key});

  @override
  State<AgentReservationsScreen> createState() => _AgentReservationsScreenState();
}

class _AgentReservationsScreenState extends State<AgentReservationsScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _reservations = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.listAgentReservations(
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
      setState(() { _reservations = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'confirmed': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'pending':   return Colors.orange;
      default:          return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'confirmed': return 'Confirmée';
      case 'cancelled': return 'Annulée';
      case 'pending':   return 'En attente';
      default:          return s;
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> r, String newStatus) async {
    final action = newStatus == 'confirmed' ? 'confirmer' : 'annuler';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${action[0].toUpperCase()}${action.substring(1)} la réservation'),
        content: Text('Voulez-vous $action la réservation ${r['booking_reference'] ?? r['id'].toString().substring(0, 8)} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'confirmed' ? Colors.green : Colors.red,
            ),
            child: Text(
              newStatus == 'confirmed' ? 'Confirmer' : 'Annuler',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.updateReservationStatus(r['id'].toString(), newStatus);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text('Réservations (${_reservations.length})',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'pending', 'confirmed', 'cancelled'].map((s) {
                      final active = _statusFilter == s;
                      final label = s == 'all' ? 'Tous' : _statusLabel(s);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: active,
                          onSelected: (_) { setState(() => _statusFilter = s); _load(); },
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: active ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _reservations.length,
                itemBuilder: (context, i) {
                  final r = _reservations[i];
                  final statusStr = r['status'] as String? ?? '';
                  final ref = r['booking_reference']?.toString().isNotEmpty == true
                      ? r['booking_reference']
                      : r['id'].toString().substring(0, 8);
                  final route = '${r['origin_iata'] ?? '?'} → ${r['destination_iata'] ?? '?'}';
                  final amount = r['total_amount'] != null
                      ? formatDzdFromString(r['total_amount'].toString()) : '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(ref,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _statusColor(statusStr).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(_statusLabel(statusStr),
                                    style: TextStyle(
                                        color: _statusColor(statusStr),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.flight, size: 14, color: Colors.black45),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(route,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              if (amount.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(amount,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                              ],
                            ],
                          ),
                          if (r['user_email'] != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 14, color: Colors.black45),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(r['user_email'],
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                ),
                              ],
                            ),
                          ],
                          // Action buttons
                          if (statusStr == 'pending') ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _updateStatus(r, 'cancelled'),
                                  icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
                                  label: const Text('Annuler', style: TextStyle(color: Colors.red, fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _updateStatus(r, 'confirmed'),
                                  icon: const Icon(Icons.check_circle_outline, size: 14),
                                  label: const Text('Confirmer', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                  ),
                                ),
                              ],
                            ),
                          ] else if (statusStr == 'confirmed') ...[
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _updateStatus(r, 'cancelled'),
                                icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
                                label: const Text('Annuler', style: TextStyle(color: Colors.red, fontSize: 12)),
                                style: TextButton.styleFrom(
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                ),
                              ),
                            ),
                          ],
                        ],
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
