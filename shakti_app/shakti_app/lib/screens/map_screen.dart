import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/safe_zone.dart';
import '../services/location_service.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Circle> _riskZones = {};
  final Set<Marker> _markers = {};
  MapType _mapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _loadRiskZones();
  }

  Future<void> _loadCurrentLocation() async {
    final pos = await LocationService.getCurrentPosition();
    setState(() => _currentPosition = pos);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(pos.latitude, pos.longitude), 14,
      ),
    );
  }

  // ─── Load Bengaluru Risk Zones from bundled JSON ─────────────────────────
  // (Pre-seeded from bengaluru_women_issues_by_area.csv)

  Future<void> _loadRiskZones() async {
    final String data =
        await rootBundle.loadString('assets/bengaluru_risk_zones.json');
    final List zones = json.decode(data);

    final circles = <Circle>{};
    final markers = <Marker>{};

    for (final z in zones) {
      final zone = SafeZone.fromMap(Map<String, dynamic>.from(z));
      final color = zone.isSafe
          ? Colors.green.withOpacity(0.25)
          : Colors.red.withOpacity(0.25);
      final strokeColor = zone.isSafe ? Colors.green : Colors.red;

      circles.add(Circle(
        circleId: CircleId(zone.id),
        center: LatLng(zone.latitude, zone.longitude),
        radius: zone.radiusMeters,
        fillColor: color,
        strokeColor: strokeColor,
        strokeWidth: 2,
      ));

      markers.add(Marker(
        markerId: MarkerId(zone.id),
        position: LatLng(zone.latitude, zone.longitude),
        icon: await _zoneIcon(zone),
        infoWindow: InfoWindow(
          title: zone.name,
          snippet: '${zone.issueType} · ${zone.riskLevel}',
        ),
      ));
    }

    setState(() {
      _riskZones.addAll(circles);
      _markers.addAll(markers);
    });
  }

  Future<BitmapDescriptor> _zoneIcon(SafeZone zone) async {
    return zone.isSafe
        ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
        : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  // ─── User Report a Zone ───────────────────────────────────────────────────

  Future<void> _reportZone(LatLng tapped) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report This Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.shield, color: Colors.green),
              title: const Text('Mark as Safe'),
              onTap: () {
                Navigator.pop(ctx);
                _addUserZone(tapped, safe: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: const Text('Mark as Unsafe'),
              onTap: () {
                Navigator.pop(ctx);
                _addUserZone(tapped, safe: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addUserZone(LatLng pos, {required bool safe}) {
    final id = 'user_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _riskZones.add(Circle(
        circleId: CircleId(id),
        center: pos,
        radius: 150,
        fillColor:
            (safe ? Colors.green : Colors.red).withOpacity(0.3),
        strokeColor: safe ? Colors.green : Colors.red,
        strokeWidth: 2,
      ));
    });
    // TODO: push to Firestore for crowd data aggregation
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: () => setState(() {
              _mapType = _mapType == MapType.normal
                  ? MapType.satellite
                  : MapType.normal;
            }),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _loadCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(12.9716, 77.5946), // Bengaluru default
              zoom: 13,
            ),
            mapType: _mapType,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            circles: _riskZones,
            markers: _markers,
            onMapCreated: (ctrl) => _mapController = ctrl,
            onLongPress: _reportZone,
          ),
          // Legend
          Positioned(
            bottom: 16,
            left: 16,
            child: _buildLegend(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendRow(Colors.green, 'Safe Zone'),
          const SizedBox(height: 6),
          _legendRow(Colors.red, 'Risk Zone'),
          const SizedBox(height: 6),
          const Text('Long-press to report',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
