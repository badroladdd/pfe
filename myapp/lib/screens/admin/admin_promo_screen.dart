import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/utils/currency.dart';

class AdminPromoScreen extends StatefulWidget {
  const AdminPromoScreen({super.key});

  @override
  State<AdminPromoScreen> createState() => _AdminPromoScreenState();
}

class _AdminPromoScreenState extends State<AdminPromoScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _promos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.listPromoCodes();
      setState(() => _promos = data);
    } catch (e) {
      _snack('Erreur: $e', Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> promo) async {
    try {
      await _api.togglePromoCode(promo['id'] as int, !(promo['is_active'] as bool));
      _load();
    } catch (e) {
      _snack('Erreur: $e', Colors.red);
    }
  }

  Future<void> _delete(Map<String, dynamic> promo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le code'),
        content: Text('Supprimer "${promo['code']}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deletePromoCode(promo['id'] as int);
      _load();
    } catch (e) {
      _snack('Erreur: $e', Colors.red);
    }
  }

  void _showCreateDialog() {
    final codeCtrl     = TextEditingController();
    final valueCtrl    = TextEditingController();
    final maxUsesCtrl  = TextEditingController(text: '100');
    String discountType = 'percent';
    DateTime? expiresAt;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Nouveau code promo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Code (ex: ETE2025)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: discountType,
                  decoration: const InputDecoration(labelText: 'Type de réduction'),
                  items: const [
                    DropdownMenuItem(value: 'percent', child: Text('Pourcentage (%)')),
                    DropdownMenuItem(value: 'fixed',   child: Text('Montant fixe (DZD)')),
                  ],
                  onChanged: (v) => setDlg(() => discountType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: discountType == 'percent' ? 'Valeur (%)' : 'Valeur (DZD)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxUsesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Nombre max d\'utilisations'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(expiresAt == null
                      ? 'Date d\'expiration *'
                      : 'Expire le ${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year}'),
                  trailing: const Icon(Icons.calendar_today, color: Colors.blue),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                    );
                    if (picked != null) setDlg(() => expiresAt = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (codeCtrl.text.isEmpty || valueCtrl.text.isEmpty || expiresAt == null) {
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _api.createPromoCode({
                    'code':           codeCtrl.text.toUpperCase(),
                    'discount_type':  discountType,
                    'discount_value': double.parse(valueCtrl.text),
                    'max_uses':       int.parse(maxUsesCtrl.text),
                    'expires_at':     expiresAt!.toIso8601String(),
                  });
                  _snack('Code créé avec succès', Colors.green);
                  _load();
                } catch (e) {
                  _snack('Erreur: $e', Colors.red);
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau code'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _promos.isEmpty
                  ? const Center(child: Text('Aucun code promo'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _promos.length,
                      itemBuilder: (_, i) => _PromoCard(
                        promo: _promos[i],
                        onToggle: () => _toggle(_promos[i]),
                        onDelete: () => _delete(_promos[i]),
                      ),
                    ),
            ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final Map<String, dynamic> promo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _PromoCard({required this.promo, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isActive  = promo['is_active'] as bool;
    final isValid   = promo['is_valid']  as bool;
    final type      = promo['discount_type'] as String;
    final value     = promo['discount_value'] as String;
    final used      = promo['used_count'] as int;
    final maxUses   = promo['max_uses'] as int;
    final expiresAt = DateTime.tryParse(promo['expires_at'] as String? ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isValid ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isValid ? Colors.green : Colors.grey),
                  ),
                  child: Text(
                    promo['code'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isValid ? Colors.green.shade700 : Colors.grey,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const Spacer(),
                Switch(value: isActive, onChanged: (_) => onToggle(), activeThumbColor: Colors.indigo),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: onDelete),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _chip(
                  type == 'percent' ? '-$value%' : '-${formatDzdFromString(value)} remise',
                  Icons.local_offer_outlined,
                  Colors.blue,
                ),
                _chip('$used / $maxUses utilisations', Icons.people_outline, Colors.orange),
                if (expiresAt != null)
                  _chip(
                    'Expire ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}',
                    Icons.schedule,
                    expiresAt.isBefore(DateTime.now()) ? Colors.red : Colors.grey,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
