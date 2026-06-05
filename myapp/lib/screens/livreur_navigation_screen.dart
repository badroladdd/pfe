import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myapp/api.dart';

class LivreurNavigationScreen extends StatefulWidget {
  const LivreurNavigationScreen({super.key});

  @override
  State<LivreurNavigationScreen> createState() =>
      _LivreurNavigationScreenState();
}

class _LivreurNavigationScreenState extends State<LivreurNavigationScreen> {
  final ApiClient _api = ApiClient();

  List<Map<String, dynamic>> _packages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAssignedPackages();
  }

  Future<void> _fetchAssignedPackages() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.listAssignedPackages();
      final List<dynamic> list = data["results"] ?? [];
      if (!mounted) return;
      setState(() {
        _packages = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _launchGPS(Map<String, dynamic> package) async {
    try {
      final lat = double.tryParse(package["latitude"].toString()) ?? 0.0;
      final lng = double.tryParse(package["longitude"].toString()) ?? 0.0;

      final googleMapsUrl =
          "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving";
      final appleMapsUrl =
          "maps://maps.apple.com/?daddr=$lat,$lng&dirflg=d";

      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl),
            mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
        await launchUrl(Uri.parse(appleMapsUrl),
            mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar("Impossible de lancer l'application GPS");
      }
    } catch (e) {
      _showErrorSnackBar("Erreur GPS : $e");
    }
  }

  Future<void> _updatePackageStatus(
    Map<String, dynamic> package,
    String newStatus,
  ) async {
    try {
      final deliveryNote =
          newStatus == "delivered" ? "Delivered by livreur" : "In transit";
      await _api.updatePackageStatus(
        package["id"],
        status: newStatus,
        deliveryNote: deliveryNote,
      );
      if (!mounted) return;
      Navigator.pop(context);
      await _fetchAssignedPackages();
      _showSuccessSnackBar("Statut mis à jour");
    } catch (e) {
      _showErrorSnackBar("Échec de la mise à jour : $e");
    }
  }

  void _showPackageDetailsBottomSheet(Map<String, dynamic> package) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Poignée
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // En-tête
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Tracking: ${package["tracking_number"] ?? 'N/A'}",
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          package["recipient_name"] ?? "Inconnu",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(package["status"]),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              _infoSection("Destinataire", [
                ("Nom",       package["recipient_name"]  ?? "N/A"),
                ("Téléphone", package["recipient_phone"] ?? "N/A"),
                ("Email",     package["recipient_email"] ?? "N/A"),
              ]),
              const SizedBox(height: 12),

              _infoSection("Adresse de livraison", [
                ("Adresse", package["delivery_address"] ?? "N/A"),
              ]),
              const SizedBox(height: 12),

              _infoSection("Détails du colis", [
                ("Poids",      "${package["weight_kg"] ?? 0} kg"),
                ("Dimensions", package["dimensions"] ?? "N/A"),
                ("Priorité",   package["priority"]?.toString().toUpperCase() ?? "NORMAL"),
                ("Contenu",    package["contents"] ?? "N/A"),
              ]),
              const SizedBox(height: 20),

              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _launchGPS(package),
                      icon: const Icon(Icons.navigation),
                      label: const Text("GPS"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: package["status"] == "delivered"
                          ? null
                          : () {
                              final next = package["status"] == "assigned"
                                  ? "in_transit"
                                  : "delivered";
                              _updatePackageStatus(package, next);
                            },
                      icon: Icon(_statusNextIcon(package["status"])),
                      label: Text(_statusNextLabel(package["status"])),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers UI ──────────────────────────────────────────────────────────────

  Widget _statusBadge(String? status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status?.toUpperCase() ?? "UNKNOWN",
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoSection(String title, List<(String, String)> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.$1,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.grey)),
                  Expanded(
                    child: Text(
                      item.$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case "delivered":  return Colors.green;
      case "in_transit": return Colors.orange;
      case "assigned":   return Colors.blue;
      case "failed":     return Colors.red;
      default:           return Colors.grey;
    }
  }

  IconData _statusNextIcon(String? status) {
    if (status == "delivered")  return Icons.check_circle;
    if (status == "in_transit") return Icons.local_shipping;
    return Icons.schedule;
  }

  String _statusNextLabel(String? status) {
    if (status == "delivered")  return "Livré";
    if (status == "in_transit") return "Marquer livré";
    return "Démarrer";
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Mes livraisons"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAssignedPackages,
            tooltip: "Actualiser",
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text("Erreur : $_error",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchAssignedPackages,
                        child: const Text("Réessayer"),
                      ),
                    ],
                  ),
                )
              : _packages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text("Aucun colis assigné",
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Compteur
                        Container(
                          width: double.infinity,
                          color: Colors.blue,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            "${_packages.length} colis assigné${_packages.length > 1 ? 's' : ''}",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ),
                        // Liste
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _packages.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) =>
                                _packageCard(_packages[i]),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _packageCard(Map<String, dynamic> package) {
    final status = package["status"] as String?;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPackageDetailsBottomSheet(package),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icône statut
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  status == "delivered"
                      ? Icons.check_circle
                      : status == "in_transit"
                          ? Icons.local_shipping
                          : Icons.inventory_2,
                  color: _statusColor(status),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package["recipient_name"] ?? "Inconnu",
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      package["delivery_address"] ?? "",
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "# ${package["tracking_number"] ?? ''}",
                      style: const TextStyle(
                          fontSize: 11, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              // Badge statut
              _statusBadge(status),
            ],
          ),
        ),
      ),
    );
  }
}
