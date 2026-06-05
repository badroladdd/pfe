import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:location/location.dart';
import 'package:myapp/api.dart';

class LivreurNavigationScreen extends StatefulWidget {
  const LivreurNavigationScreen({super.key});

  @override
  State<LivreurNavigationScreen> createState() =>
      _LivreurNavigationScreenState();
}

class _LivreurNavigationScreenState extends State<LivreurNavigationScreen> {
  final ApiClient _api = ApiClient();
  final Location _location = Location();

  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<Map<String, dynamic>> _packages = [];
  bool _loading = true;
  String? _error;
  int _selectedPackageIndex = -1;

  StreamSubscription<LocationData>? _locationSub;

  static const double _defaultZoom = 15.0;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    try {
      await _requestLocationPermission();
      await _getCurrentLocation();
      await _fetchAssignedPackages();
      await _updateLocationOnServer();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    final hasPermission = await _location.hasPermission();
    if (hasPermission == PermissionStatus.denied) {
      await _location.requestPermission();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationData = await _location.getLocation();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(
            locationData.latitude ?? 0.0,
            locationData.longitude ?? 0.0,
          );
        });
      }

      _locationSub = _location.onLocationChanged.listen((LocationData loc) {
        if (!mounted) return;
        setState(() {
          _currentLocation = LatLng(
            loc.latitude ?? 0.0,
            loc.longitude ?? 0.0,
          );
          _updateLocationMarker();
        });
        _updateLocationOnServer();
      });
    } catch (e) {
      _showErrorSnackBar("Failed to get location: $e");
    }
  }

  Future<void> _fetchAssignedPackages() async {
    try {
      final data = await _api.listAssignedPackages();
      final List<dynamic> list = data["results"] ?? [];
      if (!mounted) return;
      setState(() {
        _packages = list.cast<Map<String, dynamic>>();
      });
      _updateMarkersAndPolylines();
    } catch (e) {
      _showErrorSnackBar("Failed to fetch packages: $e");
    }
  }

  Future<void> _updateLocationOnServer() async {
    if (_currentLocation == null) return;
    try {
      await _api.updateLivreurLocation(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
      );
    } catch (e) {
      debugPrint("Failed to update location on server: $e");
    }
  }

  void _updateMarkersAndPolylines() {
    if (_currentLocation == null) return;

    final newMarkers = <Marker>{};

    newMarkers.add(
      Marker(
        markerId: const MarkerId("current_location"),
        position: _currentLocation!,
        infoWindow: const InfoWindow(title: "My Location"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    for (int i = 0; i < _packages.length; i++) {
      final package = _packages[i];
      final lat = double.tryParse(package["latitude"].toString()) ?? 0.0;
      final lng = double.tryParse(package["longitude"].toString()) ?? 0.0;
      final isSelected = i == _selectedPackageIndex;

      newMarkers.add(
        Marker(
          markerId: MarkerId("package_$i"),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: package["recipient_name"] ?? "Package",
            snippet: package["tracking_number"] ?? "",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected
                ? BitmapDescriptor.hueViolet
                : package["status"] == "delivered"
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueOrange,
          ),
          onTap: () => _selectPackage(i),
        ),
      );
    }

    setState(() => _markers = newMarkers);
  }

  void _updateLocationMarker() {
    // Called inside setState — safe to mutate directly here.
    _markers = {
      ..._markers.where((m) => m.markerId.value != "current_location"),
      Marker(
        markerId: const MarkerId("current_location"),
        position: _currentLocation!,
        infoWindow: const InfoWindow(title: "My Location"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    };
  }

  void _selectPackage(int index) {
    setState(() => _selectedPackageIndex = index);
    _updateMarkersAndPolylines();
    _showPackageDetailsBottomSheet(_packages[index]);
  }

  Future<void> _launchGPS(Map<String, dynamic> package) async {
    try {
      final latitude = double.tryParse(package["latitude"].toString()) ?? 0.0;
      final longitude = double.tryParse(package["longitude"].toString()) ?? 0.0;

      final googleMapsUrl =
          "https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving";
      final appleMapsUrl =
          "maps://maps.apple.com/?daddr=$latitude,$longitude&dirflg=d";

      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl),
            mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
        await launchUrl(Uri.parse(appleMapsUrl),
            mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar("Could not launch navigation app");
      }
    } catch (e) {
      _showErrorSnackBar("Error launching GPS: $e");
    }
  }

  Future<void> _updatePackageStatus(
    Map<String, dynamic> package,
    String newStatus,
  ) async {
    try {
      final colisId = package["id"];
      final deliveryNote =
          newStatus == "delivered" ? "Delivered by livreur" : "In transit";

      await _api.updatePackageStatus(
        colisId,
        status: newStatus,
        deliveryNote: deliveryNote,
      );

      if (!mounted) return;
      Navigator.pop(context);
      await _fetchAssignedPackages();
      _showSuccessSnackBar("Package status updated");
    } catch (e) {
      _showErrorSnackBar("Failed to update package status: $e");
    }
  }

  void _showPackageDetailsBottomSheet(Map<String, dynamic> package) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Tracking: ${package["tracking_number"]}",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          package["recipient_name"] ?? "Unknown",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(package["status"]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      package["status"]?.toString().toUpperCase() ?? "UNKNOWN",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildInfoSection("Recipient Information", [
                ("Name", package["recipient_name"] ?? "N/A"),
                ("Phone", package["recipient_phone"] ?? "N/A"),
                ("Email", package["recipient_email"] ?? "N/A"),
              ]),
              const SizedBox(height: 12),

              _buildInfoSection("Delivery Address", [
                ("Address", package["delivery_address"] ?? "N/A"),
              ]),
              const SizedBox(height: 12),

              _buildInfoSection("Package Details", [
                ("Weight", "${package["weight_kg"] ?? 0} kg"),
                ("Dimensions", package["dimensions"] ?? "N/A"),
                ("Priority",
                    package["priority"]?.toString().toUpperCase() ?? "NORMAL"),
                ("Contents", package["contents"] ?? "N/A"),
              ]),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _launchGPS(package),
                      icon: const Icon(Icons.navigation),
                      label: const Text("Launch GPS"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: package["status"] == "delivered"
                          ? null
                          : () {
                              final newStatus =
                                  package["status"] == "assigned"
                                      ? "in_transit"
                                      : "delivered";
                              _updatePackageStatus(package, newStatus);
                            },
                      icon: Icon(
                        package["status"] == "delivered"
                            ? Icons.check_circle
                            : package["status"] == "in_transit"
                                ? Icons.local_shipping
                                : Icons.schedule,
                      ),
                      label: Text(
                        package["status"] == "delivered"
                            ? "Delivered"
                            : package["status"] == "in_transit"
                                ? "Mark Delivered"
                                : "Start Delivery",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<(String, String)> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
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
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case "delivered":  return Colors.green;
      case "in_transit": return Colors.orange;
      case "assigned":   return Colors.blue;
      case "failed":     return Colors.red;
      default:           return Colors.grey;
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Livreur Navigation"),
        backgroundColor: Colors.blue,
        elevation: 0,
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
                      Text(
                        "Error: $_error",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _initializeScreen();
                        },
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : _currentLocation == null
                  ? const Center(
                      child: Text("Unable to determine current location"),
                    )
                  : Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _currentLocation!,
                            zoom: _defaultZoom,
                          ),
                          onMapCreated: (controller) {
                            _mapController = controller;
                          },
                          markers: _markers,
                          polylines: _polylines,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: true,
                        ),

                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              "Packages: ${_packages.length}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),

                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: FloatingActionButton(
                            mini: true,
                            onPressed: () async {
                              setState(() => _loading = true);
                              await _fetchAssignedPackages();
                              if (mounted) setState(() => _loading = false);
                            },
                            backgroundColor: Colors.blue,
                            child: const Icon(Icons.refresh),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
