import 'package:flutter/material.dart';
import 'package:myapp/api.dart';

class AdminColisScreen extends StatefulWidget {
  const AdminColisScreen({super.key});

  @override
  State<AdminColisScreen> createState() => _AdminColisScreenState();
}

class _AdminColisScreenState extends State<AdminColisScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _colis = [];
  List<Map<String, dynamic>> _sectors = [];
  List<Map<String, dynamic>> _livreurs = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'all';

  static const _statusFilters = ['all', 'pending', 'assigned', 'in_transit', 'delivered', 'failed'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.adminListColis(status: _statusFilter == 'all' ? null : _statusFilter),
        _api.listSectors(),
        _api.adminListLivreurs(),
      ]);
      setState(() {
        _colis = results[0] as List<Map<String, dynamic>>;
        final sectorsData = results[1] as Map<String, dynamic>;
        _sectors = (sectorsData['results'] as List? ?? []).cast<Map<String, dynamic>>();
        _livreurs = results[2] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => _CreateColisDialog(
        sectors: _sectors,
        api: _api,
        onCreated: _load,
      ),
    );
  }

  void _showAssignDialog(Map<String, dynamic> colis) {
    showDialog(
      context: context,
      builder: (_) => _AssignColisDialog(
        colis: colis,
        livreurs: _livreurs,
        api: _api,
        onAssigned: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Colis'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_box),
        label: const Text('Nouveau colis'),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 48,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: _statusFilters.map((s) {
          final isSelected = _statusFilter == s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_label(s)),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _statusFilter = s);
                _load();
              },
              selectedColor: Colors.indigo.shade100,
              checkmarkColor: Colors.indigo,
              labelStyle: TextStyle(
                color: isSelected ? Colors.indigo : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(String s) {
    switch (s) {
      case 'all':        return 'Tous';
      case 'pending':    return 'En attente';
      case 'assigned':   return 'Assignés';
      case 'in_transit': return 'En transit';
      case 'delivered':  return 'Livrés';
      case 'failed':     return 'Échoués';
      default:           return s;
    }
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_colis.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Aucun colis', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add_box),
              label: const Text('Créer un colis'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: _colis.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _ColisCard(
          colis: _colis[i],
          onAssign: () => _showAssignDialog(_colis[i]),
        ),
      ),
    );
  }
}

class _ColisCard extends StatelessWidget {
  final Map<String, dynamic> colis;
  final VoidCallback onAssign;

  const _ColisCard({required this.colis, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    final status = colis['status'] as String? ?? '';
    final priority = colis['priority'] as String? ?? 'normal';
    final livreurName = colis['livreur_name'] as String?;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        colis['recipient_name'] as String? ?? 'Inconnu',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        colis['tracking_number'] as String? ?? '',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              colis['delivery_address'] as String? ?? '',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(colis['sector_name'] as String? ?? 'N/A', Colors.blue),
                const SizedBox(width: 6),
                _priorityChip(priority),
                const Spacer(),
                if (livreurName != null)
                  _chip(livreurName, Colors.teal)
                else
                  const Text('Non assigné', style: TextStyle(fontSize: 11, color: Colors.orange)),
                const SizedBox(width: 8),
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    onPressed: onAssign,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: const Text('Assigner'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _priorityChip(String priority) {
    final color = priority == 'urgent'
        ? Colors.red
        : priority == 'express'
            ? Colors.orange
            : Colors.grey;
    final label = priority == 'urgent' ? 'URGENT' : priority == 'express' ? 'EXPRESS' : 'NORMAL';
    return _chip(label, color);
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'delivered':  color = Colors.green;  label = 'Livré';
      case 'in_transit': color = Colors.orange; label = 'En transit';
      case 'assigned':   color = Colors.blue;   label = 'Assigné';
      case 'pending':    color = Colors.purple; label = 'En attente';
      case 'failed':     color = Colors.red;    label = 'Échoué';
      case 'cancelled':  color = Colors.grey;   label = 'Annulé';
      default:           color = Colors.grey;   label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Create Colis Dialog ───────────────────────────────────────────────────────

class _CreateColisDialog extends StatefulWidget {
  final List<Map<String, dynamic>> sectors;
  final ApiClient api;
  final VoidCallback onCreated;

  const _CreateColisDialog({required this.sectors, required this.api, required this.onCreated});

  @override
  State<_CreateColisDialog> createState() => _CreateColisDialogState();
}

class _CreateColisDialogState extends State<_CreateColisDialog> {
  final _formKey = GlobalKey<FormState>();
  final _recipientName  = TextEditingController();
  final _recipientPhone = TextEditingController();
  final _recipientEmail = TextEditingController();
  final _address        = TextEditingController();
  final _weight         = TextEditingController();
  final _dimensions     = TextEditingController();
  final _contents       = TextEditingController();
  final _lat            = TextEditingController();
  final _lng            = TextEditingController();

  String? _selectedSectorId;
  String _priority = 'normal';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_recipientName, _recipientPhone, _recipientEmail, _address,
                     _weight, _dimensions, _contents, _lat, _lng]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSectorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un secteur')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.adminCreateColis({
        'recipient_name':  _recipientName.text.trim(),
        'recipient_phone': _recipientPhone.text.trim(),
        'recipient_email': _recipientEmail.text.trim(),
        'delivery_address': _address.text.trim(),
        'latitude':  double.tryParse(_lat.text.trim()) ?? 0.0,
        'longitude': double.tryParse(_lng.text.trim()) ?? 0.0,
        'weight_kg': double.tryParse(_weight.text.trim()) ?? 0.0,
        'dimensions': _dimensions.text.trim(),
        'contents':  _contents.text.trim(),
        'priority':  _priority,
        'sector':    _selectedSectorId,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Colis créé et assigné automatiquement'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nouveau colis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const _SectionLabel('Destinataire'),
              _field(_recipientName, 'Nom du destinataire', required: true),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_recipientPhone, 'Téléphone', keyboardType: TextInputType.phone, required: true)),
                const SizedBox(width: 8),
                Expanded(child: _field(_recipientEmail, 'Email', keyboardType: TextInputType.emailAddress)),
              ]),
              const SizedBox(height: 14),
              const _SectionLabel('Livraison'),
              _field(_address, 'Adresse de livraison', required: true),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_lat, 'Latitude', keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _field(_lng, 'Longitude', keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedSectorId,
                decoration: const InputDecoration(labelText: 'Secteur *', border: OutlineInputBorder()),
                items: widget.sectors
                    .map((s) => DropdownMenuItem<String>(
                          value: s['id']?.toString(),
                          child: Text(s['name'] as String? ?? ''),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSectorId = v),
                validator: (v) => v == null ? 'Secteur requis' : null,
              ),
              const SizedBox(height: 14),
              const _SectionLabel('Détails'),
              Row(children: [
                Expanded(child: _field(_weight, 'Poids (kg)', keyboardType: TextInputType.number, required: true)),
                const SizedBox(width: 8),
                Expanded(child: _field(_dimensions, 'Dimensions')),
              ]),
              const SizedBox(height: 10),
              _field(_contents, 'Contenu', required: true),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priorité', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'normal',  child: Text('Normal')),
                  DropdownMenuItem(value: 'express', child: Text('Express')),
                  DropdownMenuItem(value: 'urgent',  child: Text('Urgent')),
                ],
                onChanged: (v) => setState(() => _priority = v!),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Créer'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
      ),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? '$label requis' : null : null,
    );
  }
}

// ─── Assign Colis Dialog ──────────────────────────────────────────────────────

class _AssignColisDialog extends StatefulWidget {
  final Map<String, dynamic> colis;
  final List<Map<String, dynamic>> livreurs;
  final ApiClient api;
  final VoidCallback onAssigned;

  const _AssignColisDialog({
    required this.colis,
    required this.livreurs,
    required this.api,
    required this.onAssigned,
  });

  @override
  State<_AssignColisDialog> createState() => _AssignColisDialogState();
}

class _AssignColisDialogState extends State<_AssignColisDialog> {
  String? _selectedLivreurId;
  bool _saving = false;

  Future<void> _assign() async {
    if (_selectedLivreurId == null) return;
    setState(() => _saving = true);
    try {
      await widget.api.adminAssignColis(
        colisId: widget.colis['id'].toString(),
        livreurId: _selectedLivreurId!,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onAssigned();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Colis assigné avec succès'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeLivreurs = widget.livreurs
        .where((l) => l['status'] == 'active')
        .toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Assigner le colis'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.colis['tracking_number'] as String? ?? '',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            widget.colis['recipient_name'] as String? ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 16),
          if (activeLivreurs.isEmpty)
            const Text('Aucun livreur actif disponible.',
                style: TextStyle(color: Colors.orange))
          else
            DropdownButtonFormField<String>(
              initialValue: _selectedLivreurId,
              decoration: const InputDecoration(
                labelText: 'Choisir un livreur',
                border: OutlineInputBorder(),
              ),
              items: activeLivreurs.map((l) {
                final user = l['user'] as Map<String, dynamic>? ?? {};
                final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
                final sector = l['sector_name'] as String? ?? '';
                final count = l['current_packages_count'] ?? 0;
                final max = l['max_packages_per_day'] ?? 50;
                return DropdownMenuItem<String>(
                  value: l['id']?.toString(),
                  child: Text('$name — $sector ($count/$max)', overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedLivreurId = v),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: (_saving || _selectedLivreurId == null) ? null : _assign,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Assigner'),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }
}
