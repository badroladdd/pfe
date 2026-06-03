import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myapp/api.dart';

class LivreurNavigationScreen extends StatefulWidget {
  const LivreurNavigationScreen({super.key});

  @override
  State<LivreurNavigationScreen> createState() => _LivreurNavigationScreenState();
}

class _LivreurNavigationScreenState extends State<LivreurNavigationScreen> {
  final ApiClient _api = ApiClient();

  List<Map<String, dynamic>> _packages = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'all';

  static const _statusFilters = ['all', 'assigned', 'in_transit', 'delivered', 'failed'];

  @override
  void initState() {
    super.initState();
    _fetchPackages();
  }

  Future<void> _fetchPackages() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.listAssignedPackages(
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
      final list = data['results'] as List<dynamic>? ?? [];
      setState(() { _packages = list.cast<Map<String, dynamic>>(); });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _launchNavigation(Map<String, dynamic> package) async {
    final lat = package['latitude'];
    final lng = package['longitude'];
    final address = Uri.encodeComponent(package['delivery_address'] ?? '');

    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    } else {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$address');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir la navigation')),
        );
      }
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> package, String newStatus) async {
    try {
      final id = package['id'].toString();
      final note = newStatus == 'delivered' ? 'Livré par le livreur' : 'En cours de livraison';
      await _api.updatePackageStatus(id, status: newStatus, deliveryNote: note);
      if (mounted) Navigator.pop(context);
      await _fetchPackages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Statut mis à jour'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDetails(Map<String, dynamic> package) {
    final status = package['status'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package['tracking_number'] ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          package['recipient_name'] ?? 'Inconnu',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 20),
              _InfoSection('Destinataire', [
                ('Nom', package['recipient_name'] ?? 'N/A'),
                ('Téléphone', package['recipient_phone'] ?? 'N/A'),
                ('Email', package['recipient_email'] ?? 'N/A'),
              ]),
              const SizedBox(height: 14),
              _InfoSection('Adresse de livraison', [
                ('Adresse', package['delivery_address'] ?? 'N/A'),
              ]),
              const SizedBox(height: 14),
              _InfoSection('Détails du colis', [
                ('Poids', '${package['weight_kg'] ?? 0} kg'),
                ('Dimensions', package['dimensions'] ?? 'N/A'),
                ('Contenu', package['contents'] ?? 'N/A'),
                ('Priorité', (package['priority'] ?? 'normal').toString().toUpperCase()),
              ]),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _launchNavigation(package),
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('Naviguer'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.blue),
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ),
                  if (status != 'delivered' && status != 'cancelled' && status != 'failed') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final next = status == 'assigned' ? 'in_transit' : 'delivered';
                          _updateStatus(package, next);
                        },
                        icon: Icon(status == 'assigned'
                            ? Icons.local_shipping
                            : Icons.check_circle_outline),
                        label: Text(status == 'assigned' ? 'Démarrer' : 'Livré'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Livraisons'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPackages,
          ),
        ],
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
              label: Text(_filterLabel(s)),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _statusFilter = s);
                _fetchPackages();
              },
              selectedColor: Colors.blue.shade100,
              checkmarkColor: Colors.blue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _filterLabel(String status) {
    switch (status) {
      case 'all':        return 'Tous';
      case 'assigned':   return 'Assignés';
      case 'in_transit': return 'En transit';
      case 'delivered':  return 'Livrés';
      case 'failed':     return 'Échoués';
      default:           return status;
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
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchPackages, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    if (_packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Aucun colis trouvé',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPackages,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _packages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _PackageCard(
          package: _packages[i],
          onTap: () => _showDetails(_packages[i]),
          onNavigate: () => _launchNavigation(_packages[i]),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> package;
  final VoidCallback onTap;
  final VoidCallback onNavigate;

  const _PackageCard({required this.package, required this.onTap, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final status = package['status'] as String? ?? '';
    final priority = package['priority'] as String? ?? 'normal';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _PriorityIndicator(priority: priority),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package['recipient_name'] ?? 'Inconnu',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      package['delivery_address'] ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      package['tracking_number'] ?? '',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusChip(status: status),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onNavigate,
                    child: const Icon(Icons.navigation, color: Colors.blue, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityIndicator extends StatelessWidget {
  final String priority;
  const _PriorityIndicator({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = priority == 'urgent'
        ? Colors.red
        : priority == 'express'
            ? Colors.orange
            : Colors.blue;

    return Container(
      width: 4,
      height: 52,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
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
      case 'delivered':
        color = Colors.green; label = 'Livré';
      case 'in_transit':
        color = Colors.orange; label = 'En transit';
      case 'assigned':
        color = Colors.blue; label = 'Assigné';
      case 'failed':
        color = Colors.red; label = 'Échoué';
      case 'cancelled':
        color = Colors.grey; label = 'Annulé';
      default:
        color = Colors.grey; label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<(String, String)> items;
  const _InfoSection(this.title, this.items);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child: Text(item.$1, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ),
              Expanded(
                child: Text(
                  item.$2,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
