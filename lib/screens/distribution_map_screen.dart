import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/road_safe_api_client.dart';

class DistributionMapScreen extends StatefulWidget {
  const DistributionMapScreen({super.key});

  @override
  State<DistributionMapScreen> createState() => _DistributionMapScreenState();
}

class _DistributionMapScreenState extends State<DistributionMapScreen> {
  final _api = RoadSafeApiClient();
  late Future<List<Map<String, dynamic>>> _points;

  @override
  void initState() {
    super.initState();
    _points = _api.getMapReports();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _points,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal mengambil data peta dari API.'),
                  TextButton(
                    onPressed: () => setState(() => _points = _api.getMapReports()),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            );
          }
          final points = snapshot.data ?? const [];
          final markers = points.map(_marker).toList();
          return FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(-6.597, 106.806),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.roadsafe.pothole_mobile',
              ),
              MarkerLayer(markers: markers),
              Positioned(
                top: 12,
                left: 12,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('${points.length} titik dari API'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Marker _marker(Map<String, dynamic> point) {
    final lat = _number(point['latitude']);
    final lng = _number(point['longitude']);
    final score = _number(point['skor']);
    final category = '${point['kategori'] ?? ''}'.toLowerCase();
    final color = category.contains('high') || category.contains('tinggi')
        ? Colors.red
        : category.contains('medium') || category.contains('sedang')
            ? Colors.amber
            : Colors.green;
    return Marker(
      point: LatLng(lat, lng),
      width: 44,
      height: 64,
      child: GestureDetector(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          builder: (_) => ListTile(
            title: Text('${point['lokasi_jalan'] ?? 'Lokasi laporan'}'),
            subtitle: Text('${point['kategori'] ?? 'Unknown'} - Skor ${score.toStringAsFixed(1)}'),
          ),
        ),
        child: Icon(Icons.location_on, size: 42, color: color),
      ),
    );
  }

  double _number(dynamic value) {
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }
}
