import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/screens/auth/login_screen.dart';

class LivreurProfileScreen extends StatefulWidget {
  const LivreurProfileScreen({super.key});

  @override
  State<LivreurProfileScreen> createState() => _LivreurProfileScreenState();
}

class _LivreurProfileScreenState extends State<LivreurProfileScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _livreur;
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
      final data = await _api.getLivreurProfile();
      setState(() { _livreur = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vous déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Mon profil'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                ]))
              : _buildProfile(),
    );
  }

  Widget _buildProfile() {
    final l = _livreur!;
    final user = l['user'] as Map<String, dynamic>? ?? {};
    final fullName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    final email = user['email'] as String? ?? '';
    final phone = user['phone'] as String? ?? '';
    final sector = l['sector_name'] as String? ?? '';
    final vehicle = l['vehicle_type'] as String? ?? '';
    final plate = l['vehicle_plate'] as String? ?? '';
    final status = l['status'] as String? ?? 'active';
    final current = l['current_packages_count'] ?? 0;
    final maxPkg = l['max_packages_per_day'] ?? 50;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 44,
            backgroundColor: Colors.teal.shade100,
            child: Text(
              fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
              style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700),
            ),
          ),
          const SizedBox(height: 14),
          Text(fullName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          _statusBadge(status),
          const SizedBox(height: 28),

          // Info card
          _card([
            _infoRow(Icons.email_outlined,       'Email',      email),
            if (phone.isNotEmpty)
              _infoRow(Icons.phone_outlined,     'Téléphone',  phone),
            _infoRow(Icons.location_on_outlined, 'Secteur',    sector),
          ]),
          const SizedBox(height: 16),

          // Vehicle card
          _card([
            _infoRow(_vehicleIcon(vehicle), 'Véhicule',
                _vehicleLabel(vehicle)),
            if (plate.isNotEmpty)
              _infoRow(Icons.pin_outlined, 'Immatriculation', plate),
          ]),
          const SizedBox(height: 16),

          // Stats card
          _card([
            _infoRow(Icons.inventory_2_outlined, 'Billets aujourd\'hui',
                '$current / $maxPkg'),
          ]),
          const SizedBox(height: 32),

          // Logout button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Déconnexion',
                  style: TextStyle(color: Colors.red, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> rows) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: rows),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Icon(icon, size: 20, color: Colors.teal),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
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
            ? 'En congé'
            : 'Inactif';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  IconData _vehicleIcon(String v) => switch (v) {
    'motorcycle' => Icons.two_wheeler,
    'car'        => Icons.directions_car_outlined,
    'van'        => Icons.airport_shuttle_outlined,
    'truck'      => Icons.local_shipping_outlined,
    _            => Icons.directions_car_outlined,
  };

  String _vehicleLabel(String v) => switch (v) {
    'motorcycle' => 'Moto',
    'car'        => 'Voiture',
    'van'        => 'Fourgon',
    'truck'      => 'Camion',
    _            => v,
  };
}
