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
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.listAdminUsers();
      setState(() { _users = list; _filtered = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _users.where((u) {
        final name = '${u['first_name']} ${u['last_name']}'.toLowerCase();
        final email = (u['email'] ?? '').toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    });
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return Colors.indigo;
      case 'agent': return Colors.blue;
      default:      return Colors.teal;
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    String selectedRole = user['role'] ?? 'client';
    bool isActive = user['is_active'] ?? true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('${user['first_name']} ${user['last_name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rôle', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'client', label: Text('Client')),
                  ButtonSegment(value: 'agent',  label: Text('Agent')),
                  ButtonSegment(value: 'admin',  label: Text('Admin')),
                ],
                selected: {selectedRole},
                onSelectionChanged: (s) => setS(() => selectedRole = s.first),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Compte actif', style: TextStyle(fontWeight: FontWeight.bold)),
                  Switch(
                    value: isActive,
                    onChanged: (v) => setS(() => isActive = v),
                    activeThumbColor: Colors.indigo,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              child: const Text('Sauvegarder', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    try {
      await _api.updateAdminUser(user['id'].toString(), {
        'role': selectedRole,
        'is_active': isActive,
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _createUser() async {
    final firstCtrl = TextEditingController();
    final lastCtrl  = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    String role = 'agent';
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Créer un utilisateur'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: firstCtrl,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                      validator: (v) => v!.isEmpty ? 'Requis' : null,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(
                      controller: lastCtrl,
                      decoration: const InputDecoration(labelText: 'Nom'),
                      validator: (v) => v!.isEmpty ? 'Requis' : null,
                    )),
                  ]),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passCtrl,
                    decoration: const InputDecoration(labelText: 'Mot de passe'),
                    obscureText: true,
                    validator: (v) => (v?.length ?? 0) < 8 ? '8 caractères min.' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Téléphone (optionnel)'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Rôle', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'agent',  label: Text('Agent')),
                      ButtonSegment(value: 'admin',  label: Text('Admin')),
                      ButtonSegment(value: 'client', label: Text('Client')),
                    ],
                    selected: {role},
                    onSelectionChanged: (s) => setS(() => role = s.first),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              child: const Text('Créer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    try {
      await _api.createAdminUser(
        email:     emailCtrl.text.trim(),
        password:  passCtrl.text,
        firstName: firstCtrl.text.trim(),
        lastName:  lastCtrl.text.trim(),
        role:      role,
        phone:     phoneCtrl.text.trim(),
      );
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utilisateur créé avec succès.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur'),
        content: Text('Supprimer ${user['first_name']} ${user['last_name']} ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteAdminUser(user['id'].toString());
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createUser,
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Nouvel utilisateur', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
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
                    const Icon(Icons.people, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Text('Utilisateurs (${_filtered.length})',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom ou email…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
          else if (_filtered.isEmpty)
            const Expanded(child: Center(child: Text('Aucun utilisateur.')))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final u = _filtered[i];
                  final role = u['role'] as String? ?? 'client';
                  final isActive = u['is_active'] as bool? ?? true;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _roleColor(role).withValues(alpha: 0.12),
                        child: Text(
                          ((u['first_name'] as String? ?? '?').isNotEmpty
                              ? (u['first_name'] as String)[0] : '?').toUpperCase(),
                          style: TextStyle(color: _roleColor(role), fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text('${u['first_name']} ${u['last_name']}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (!isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Bloqué',
                                  style: TextStyle(fontSize: 10, color: Colors.red)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(u['email'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _roleColor(role).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(role,
                                style: TextStyle(color: _roleColor(role),
                                    fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit')   _editUser(u);
                              if (v == 'delete') _deleteUser(u);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit',   child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Modifier')])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: Colors.red))])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
    );
  }
}
