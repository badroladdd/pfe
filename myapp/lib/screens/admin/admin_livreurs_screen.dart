import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/screens/admin/livreur_billets_screen.dart';

class AdminLivreursScreen extends StatefulWidget {
  const AdminLivreursScreen({super.key});

  @override
  State<AdminLivreursScreen> createState() => _AdminLivreursScreenState();
}

class _AdminLivreursScreenState extends State<AdminLivreursScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _livreurs = [];
  List<Map<String, dynamic>> _sectors = [];
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
      final results = await Future.wait([
        _api.adminListLivreurs(),
        _api.listSectors(),
      ]);
      setState(() {
        _livreurs = results[0] as List<Map<String, dynamic>>;
        final sectorsData = results[1] as Map<String, dynamic>;
        _sectors = (sectorsData['results'] as List? ?? []).cast<Map<String, dynamic>>();
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
      builder: (_) => _CreateLivreurDialog(
        sectors: _sectors,
        api: _api,
        onCreated: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Livreurs'),
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
        icon: const Icon(Icons.person_add),
        label: const Text('Nouveau livreur'),
      ),
      body: _buildBody(),
    );
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
    if (_livreurs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Aucun livreur', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Créer un livreur'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _livreurs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _LivreurCard(livreur: _livreurs[i]),
      ),
    );
  }
}

class _LivreurCard extends StatelessWidget {
  final Map<String, dynamic> livreur;
  const _LivreurCard({required this.livreur});

  @override
  Widget build(BuildContext context) {
    final user = livreur['user'] as Map<String, dynamic>? ?? {};
    final status = livreur['status'] as String? ?? 'active';
    final vehicle = livreur['vehicle_type'] as String? ?? '';

    final livreurId = livreur['id']?.toString() ?? '';
    final livreurName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LivreurBilletsScreen(
              livreurId: livreurId,
              livreurName: livreurName,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.indigo.shade100,
                child: Text(
                  (user['first_name'] as String? ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(livreurName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(user['email'] as String? ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Row(children: [
                      _chip(livreur['sector_name'] as String? ?? 'N/A', Colors.blue),
                      const SizedBox(width: 6),
                      _chip(vehicle, Colors.orange),
                    ]),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statusBadge(status),
                  const SizedBox(height: 4),
                  Text(
                    '${livreur['current_packages_count'] ?? 0}/${livreur['max_packages_per_day'] ?? 50}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ],
              ),
            ],
          ),
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

  Widget _statusBadge(String status) {
    final color = status == 'active'
        ? Colors.green
        : status == 'on_leave'
            ? Colors.orange
            : Colors.grey;
    final label = status == 'active'
        ? 'Actif'
        : status == 'on_leave'
            ? 'Congé'
            : 'Inactif';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _CreateLivreurDialog extends StatefulWidget {
  final List<Map<String, dynamic>> sectors;
  final ApiClient api;
  final VoidCallback onCreated;

  const _CreateLivreurDialog({
    required this.sectors,
    required this.api,
    required this.onCreated,
  });

  @override
  State<_CreateLivreurDialog> createState() => _CreateLivreurDialogState();
}

class _CreateLivreurDialogState extends State<_CreateLivreurDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _plate = TextEditingController();

  String? _selectedSectorId;
  String _vehicleType = 'motorcycle';
  int _maxPackages = 50;
  bool _saving = false;
  bool _obscure = true;

  static const _vehicles = ['motorcycle', 'car', 'van', 'truck'];
  static const _vehicleLabels = {'motorcycle': 'Moto', 'car': 'Voiture', 'van': 'Fourgon', 'truck': 'Camion'};

  @override
  void dispose() {
    for (final c in [_email, _password, _firstName, _lastName, _phone, _plate]) {
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
      await widget.api.adminCreateLivreur(
        email: _email.text.trim(),
        password: _password.text,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        phone: _phone.text.trim(),
        sectorId: _selectedSectorId!,
        vehicleType: _vehicleType,
        vehiclePlate: _plate.text.trim(),
        maxPackagesPerDay: _maxPackages,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Livreur créé avec succès'), backgroundColor: Colors.green),
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
              const Text('Nouveau livreur',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _field(_firstName, 'Prénom', required: true)),
                const SizedBox(width: 8),
                Expanded(child: _field(_lastName, 'Nom', required: true)),
              ]),
              const SizedBox(height: 10),
              _field(_email, 'Email', keyboardType: TextInputType.emailAddress, required: true),
              const SizedBox(height: 10),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.length < 8)
                    ? 'Minimum 8 caractères'
                    : null,
              ),
              const SizedBox(height: 10),
              _field(_phone, 'Téléphone', keyboardType: TextInputType.phone),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedSectorId,
                decoration: const InputDecoration(
                  labelText: 'Secteur *',
                  border: OutlineInputBorder(),
                ),
                items: widget.sectors
                    .map((s) => DropdownMenuItem<String>(
                          value: s['id']?.toString(),
                          child: Text(s['name'] as String? ?? ''),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSectorId = v),
                validator: (v) => v == null ? 'Secteur requis' : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _vehicleType,
                decoration: const InputDecoration(
                  labelText: 'Véhicule',
                  border: OutlineInputBorder(),
                ),
                items: _vehicles
                    .map((v) => DropdownMenuItem<String>(
                          value: v,
                          child: Text(_vehicleLabels[v] ?? v),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _vehicleType = v!),
              ),
              const SizedBox(height: 10),
              _field(_plate, 'Plaque d\'immatriculation'),
              const SizedBox(height: 10),
              Row(children: [
                const Text('Max colis/jour:'),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _maxPackages.toDouble(),
                    min: 10,
                    max: 100,
                    divisions: 9,
                    label: '$_maxPackages',
                    onChanged: (v) => setState(() => _maxPackages = v.round()),
                  ),
                ),
                Text('$_maxPackages', style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
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
      decoration: InputDecoration(labelText: required ? '$label *' : label, border: const OutlineInputBorder()),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? '$label requis' : null : null,
    );
  }
}
