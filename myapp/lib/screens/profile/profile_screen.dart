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
          if (_loggedIn)
            _buildProfileItem(context, Icons.logout, 'Se déconnecter',
                onTap: _logout, color: Colors.red)
          else
            _buildProfileItem(context, Icons.login, 'Se connecter', onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()))
                .then((_) => _loadProfile());
            }),
          _buildProfileItem(context, Icons.help_outline, 'Modifier ou rembourser votre billet'),
          _buildProfileItem(context, Icons.phone_outlined, 'Appelez-nous'),
          _buildProfileItem(context, Icons.settings_outlined, 'Préférences'),
          _buildProfileItem(context, Icons.description_outlined, "Conditions d'utilisation"),
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
