import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/screens/auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _profile;
  bool _loggedIn = false;
  bool _loading = true;
  int _bookingsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final loggedIn = await _api.isLoggedIn;
    if (!loggedIn) {
      if (mounted) setState(() { _loggedIn = false; _loading = false; _bookingsCount = 0; });
      return;
    }
    try {
      final results = await Future.wait([_api.getProfile(), _api.listReservations()]);
      final profile = results[0] as Map<String, dynamic>;
      final reservations = results[1] as List<Map<String, dynamic>>;
      if (mounted) setState(() {
        _profile = profile;
        _loggedIn = true;
        _bookingsCount = reservations.length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loggedIn = false; _loading = false; });
    }
  }

  void _showEditProfile() {
    final firstCtrl = TextEditingController(text: _profile!['first_name'] ?? '');
    final lastCtrl  = TextEditingController(text: _profile!['last_name']  ?? '');
    final phoneCtrl = TextEditingController(text: _profile!['phone']      ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier mes informations'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstCtrl,
                decoration: const InputDecoration(labelText: 'Prénom'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lastCtrl,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.updateProfile(
                  firstName: firstCtrl.text.trim(),
                  lastName:  lastCtrl.text.trim(),
                  phone:     phoneCtrl.text.trim(),
                );
                _loadProfile();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Informations mises à jour'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showChangePassword() {
    final oldCtrl  = TextEditingController();
    final newCtrl  = TextEditingController();
    final confCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Ancien mot de passe'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmer le nouveau mot de passe'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (newCtrl.text != confCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Les mots de passe ne correspondent pas'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await _api.changePassword(
                  oldPassword: oldCtrl.text,
                  newPassword: newCtrl.text,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mot de passe modifié avec succès'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    setState(() { _profile = null; _loggedIn = false; _bookingsCount = 0; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          if (_loggedIn && _profile != null) ...[
            Text(
              'Bonjour, ${_profile!['first_name']} !',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.blue[900]),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    _infoRow(Icons.person_outline, 'Nom',
                        '${_profile!['first_name']} ${_profile!['last_name']}'),
                    const Divider(height: 1),
                    _infoRow(Icons.email_outlined, 'Email', _profile!['email'] ?? ''),
                    if ((_profile!['phone'] as String? ?? '').isNotEmpty) ...[
                      const Divider(height: 1),
                      _infoRow(Icons.phone_outlined, 'Téléphone', _profile!['phone']),
                    ],
                    const Divider(height: 1),
                    _infoRow(Icons.badge_outlined, 'Rôle', _profile!['role'] ?? 'client'),
                  ],
                ),
              ),
            ),
          ] else
            Text(
              'Bienvenue !',
              style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.blue[900]),
            ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.flight, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_bookingsCount voyage${_bookingsCount > 1 ? "s" : ""}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'réservé${_bookingsCount > 1 ? "s" : ""}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_loggedIn) ...[
            _buildProfileItem(context, Icons.edit_outlined, 'Modifier mes informations',
                onTap: _showEditProfile),
            _buildProfileItem(context, Icons.lock_outline, 'Changer le mot de passe',
                onTap: _showChangePassword),
            _buildProfileItem(context, Icons.logout, 'Se déconnecter',
                onTap: _logout, color: Colors.red),
          ] else
            _buildProfileItem(context, Icons.login, 'Se connecter', onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()))
                .then((_) => _loadProfile());
            }),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(BuildContext context, IconData icon, String title,
      {VoidCallback? onTap, Color? color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.blueGrey),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: color)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap ?? () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fonctionnalité: $title'),
                duration: const Duration(seconds: 1)),
          );
        },
      ),
    );
  }
}
