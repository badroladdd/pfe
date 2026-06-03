import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/utils/currency.dart';

// ─── Public entry point ───────────────────────────────────────────────────────

Future<void> showReservationDetail(
  BuildContext context,
  Map<String, dynamic> reservation, {
  bool isAgent = false,
  VoidCallback? onStatusChanged,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => ReservationDetailSheet(
      reservation: reservation,
      isAgent: isAgent,
      onStatusChanged: onStatusChanged,
    ),
  );
}

class ReservationDetailSheet extends StatefulWidget {
  final Map<String, dynamic> reservation;
  final bool isAgent;
  final VoidCallback? onStatusChanged;

  const ReservationDetailSheet({
    super.key,
    required this.reservation,
    this.isAgent = false,
    this.onStatusChanged,
  });

  @override
  State<ReservationDetailSheet> createState() => _ReservationDetailSheetState();
}

class _ReservationDetailSheetState extends State<ReservationDetailSheet> {
  final _api = ApiClient();
  late Map<String, dynamic> _r;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _r = Map.from(widget.reservation);
  }

  String get _status => _r['status'] as String? ?? '';
  String get _ref =>
      _r['booking_reference']?.toString().isNotEmpty == true
          ? _r['booking_reference']
          : (_r['id']?.toString() ?? '').substring(0, 8);

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

  Future<void> _doAction(String newStatus, {String? livreurId}) async {
    setState(() => _saving = true);
    try {
      Map<String, dynamic> updated;
      if (newStatus == 'assign_livreur' && livreurId != null) {
        updated = await _api.assignLivreurToReservation(_r['id'].toString(), livreurId);
      } else {
        updated = await _api.updateReservationStatus(_r['id'].toString(), newStatus);
      }
      setState(() => _r = updated);
      widget.onStatusChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndAssignLivreur() async {
    List<Map<String, dynamic>> livreurs = [];
    try {
      livreurs = await _api.adminListLivreurs(status: 'active');
    } catch (_) {}

    if (!mounted) return;

    String? selectedId = _r['livreur_id'] as String?;

    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Assigner un livreur'),
          content: livreurs.isEmpty
              ? const Text('Aucun livreur actif disponible.')
              : DropdownButtonFormField<String>(
                  initialValue: selectedId,
                  decoration: const InputDecoration(
                    labelText: 'Livreur',
                    border: OutlineInputBorder(),
                  ),
                  items: livreurs.map((l) {
                    final user = l['user'] as Map<String, dynamic>? ?? {};
                    final name =
                        '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
                    final sector = l['sector_name'] as String? ?? '';
                    return DropdownMenuItem<String>(
                      value: l['id']?.toString(),
                      child: Text('$name — $sector',
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setDlg(() => selectedId = v),
                ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: selectedId == null ? null : () => Navigator.pop(ctx, selectedId),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              child: const Text('Assigner'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != null) {
      await _doAction('assign_livreur', livreurId: confirmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final passengers =
        (_r['passengers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final amount = _r['total_amount'] != null
        ? formatDzdFromString(_r['total_amount'].toString())
        : '';
    final departure = _r['departure_at'] as String? ?? '';
    final arrival = _r['arrival_at'] as String? ?? '';
    final carrier = _r['carrier_name'] as String? ?? '';
    final livreurName = _r['livreur_name'] as String?;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
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

            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Billet $_ref',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      if (carrier.isNotEmpty)
                        Text(carrier,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor(_status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _statusColor(_status).withValues(alpha: 0.4)),
                  ),
                  child: Text(_statusLabel(_status),
                      style: TextStyle(
                          color: _statusColor(_status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Flight info
            _Section('Vol', [
              _Row(Icons.flight_takeoff, 'Départ',
                  '${_r['origin_iata'] ?? '?'}  ${_fmt(departure)}'),
              _Row(Icons.flight_land, 'Arrivée',
                  '${_r['destination_iata'] ?? '?'}  ${_fmt(arrival)}'),
              if (amount.isNotEmpty)
                _Row(Icons.attach_money, 'Montant', amount),
            ]),
            const SizedBox(height: 16),

            // Client
            _Section('Client', [
              _Row(Icons.person_outline, 'Nom',
                  _r['user_full_name'] as String? ?? ''),
              _Row(Icons.email_outlined, 'Email',
                  _r['user_email'] as String? ?? ''),
              if ((_r['user_phone'] as String? ?? '').isNotEmpty)
                _Row(Icons.phone_outlined, 'Téléphone',
                    _r['user_phone'] as String? ?? ''),
            ]),
            const SizedBox(height: 16),

            // Passengers
            if (passengers.isNotEmpty) ...[
              _SectionTitle('Passagers (${passengers.length})'),
              ...passengers.map((p) => _PassengerTile(p)),
              const SizedBox(height: 16),
            ],

            // Livreur — only assignable for confirmed/emis
            if (_status == 'confirmed' || _status == 'emis') ...[
              _SectionTitle('Livreur assigné'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.delivery_dining,
                      size: 18,
                      color: livreurName != null
                          ? Colors.teal
                          : Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      livreurName ?? 'Non assigné',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: livreurName != null
                              ? Colors.teal.shade700
                              : Colors.grey),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _pickAndAssignLivreur,
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: Text(
                        livreurName != null ? 'Changer' : 'Assigner',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),

            // Action buttons (agent only)
            if (widget.isAgent) ...[
              const Divider(),
              const SizedBox(height: 8),
              _ActionButtons(
                status: _status,
                saving: _saving,
                onAction: _doAction,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(String iso) {
    if (iso.length < 16) return iso;
    final d = iso.substring(0, 10);
    final t = iso.substring(11, 16);
    return '$d  $t';
  }
}

// ─── Action buttons ───────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final String status;
  final bool saving;
  final Future<void> Function(String) onAction;

  const _ActionButtons(
      {required this.status, required this.saving, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (status == 'pending' || status == 'confirmed')
          Expanded(
            child: OutlinedButton.icon(
              onPressed: saving ? null : () => _confirm(context, 'cancelled'),
              icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 16),
              label: const Text('Annuler',
                  style: TextStyle(color: Colors.red, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
        if (status == 'pending') ...[
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: saving ? null : () => _confirm(context, 'confirmed'),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Confirmer', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
        ],
        if (status == 'confirmed') ...[
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: saving ? null : () => _confirm(context, 'emis'),
              icon: const Icon(Icons.send_outlined, size: 16),
              label: const Text('Émettre', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirm(BuildContext context, String newStatus) async {
    final labels = {
      'confirmed': ('Confirmer', Colors.blue),
      'emis': ('Émettre', Colors.green),
      'cancelled': ('Annuler', Colors.red),
    };
    final (label, color) = labels[newStatus]!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label le billet'),
        content: Text('Confirmer l\'action "$label" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white),
            child: Text(label),
          ),
        ],
      ),
    );
    if (ok == true) await onAction(newStatus);
  }
}

// ─── Small helpers ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _Section(this.title, this.rows);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey));
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          SizedBox(
              width: 70,
              child: Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _PassengerTile extends StatelessWidget {
  final Map<String, dynamic> p;
  const _PassengerTile(this.p);

  @override
  Widget build(BuildContext context) {
    final name = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
    final type = (p['type'] as String? ?? 'adult');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(type,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
