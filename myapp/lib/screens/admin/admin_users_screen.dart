import 'package:flutter/material.dart';
import 'package:myapp/api.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _users = [];
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
      final list = await _api.listAdminUsers();
      setState(() { _users = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return Colors.indigo;
      case 'agent': return Colors.blue;
      default:      return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.indigo),
                const SizedBox(width: 10),
                Text('Utilisateurs (${_users.length})',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
          else if (_users.isEmpty)
            const Expanded(child: Center(child: Text('Aucun utilisateur.')))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                itemBuilder: (context, i) {
                  final u = _users[i];
                  final role = u['role'] as String? ?? 'client';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _roleColor(role).withValues(alpha: 0.1),
                        child: Text(
                          ((u['first_name'] as String? ?? '?').isNotEmpty
                                  ? (u['first_name'] as String)[0]
                                  : '?')
                              .toUpperCase(),
                          style: TextStyle(color: _roleColor(role), fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text('${u['first_name']} ${u['last_name']}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(u['email'] ?? ''),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _roleColor(role).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(role,
                            style: TextStyle(
                                color: _roleColor(role),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
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
