import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/pothole_report.dart';
import '../services/mock_data.dart';
import '../utils/report_format.dart';
import '../widgets/report_thumbnail.dart';

/// Peta sebaran deteksi pengemudi, mengikuti UI-M03.
class DistributionMapScreen extends StatefulWidget {
  const DistributionMapScreen({super.key});

  @override
  State<DistributionMapScreen> createState() => _DistributionMapScreenState();
}

class _DistributionMapScreenState extends State<DistributionMapScreen> {
  final MapController _mapController = MapController();
  ReportCategory? _filter;
  PotholeReport? _selected = mockReports.first;
  var _satellite = false;
  var _mapReady = false;

  List<PotholeReport> get _visible {
    final filter = _filter;
    if (filter == null) return mockReports;
    return mockReports.where((report) => report.category == filter).toList();
  }

  int _count(ReportCategory category) {
    return mockReports.where((report) => report.category == category).length;
  }

  void _choose(ReportCategory? category) {
    final next = _visibleFor(category);
    setState(() {
      _filter = category;
      if (_selected == null || !next.contains(_selected)) {
        _selected = next.isEmpty ? null : next.first;
      }
    });
    final selected = _selected;
    if (selected != null) _moveTo(selected);
  }

  List<PotholeReport> _visibleFor(ReportCategory? category) {
    if (category == null) return mockReports;
    return mockReports.where((report) => report.category == category).toList();
  }

  void _moveTo(PotholeReport report) {
    if (!_mapReady) return;
    _mapController.move(LatLng(report.lat, report.lng), 15);
  }

  void _zoom(double delta) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + delta).clamp(3, 18));
  }

  void _openRoute() {
    final selected = _selected;
    if (selected == null) return;
    _moveTo(selected);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Rute menuju ${selected.street} (${formatCoordinate(selected.lat, selected.lng)}).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final selected = _selected;
    return ColoredBox(
      color: const Color(0xFFF4F6FB),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.signal, size: 16, color: Color(0xFF0F172A)),
                      SizedBox(width: 6),
                      Text('ROADSAFE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                      Spacer(),
                      Icon(LucideIcons.shield, size: 18, color: Color(0xFF64748B)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _MapFilter(
                          label: 'Semua',
                          count: mockReports.length,
                          selected: _filter == null,
                          color: const Color(0xFF3B6CFF),
                          onTap: () => _choose(null),
                        ),
                        _MapFilter(
                          label: 'Tinggi',
                          count: _count(ReportCategory.high),
                          selected: _filter == ReportCategory.high,
                          color: const Color(0xFFEF4444),
                          onTap: () => _choose(ReportCategory.high),
                        ),
                        _MapFilter(
                          label: 'Sedang',
                          count: _count(ReportCategory.medium),
                          selected: _filter == ReportCategory.medium,
                          color: const Color(0xFFF59E0B),
                          onTap: () => _choose(ReportCategory.medium),
                        ),
                        _MapFilter(
                          label: 'Rendah',
                          count: _count(ReportCategory.low),
                          selected: _filter == ReportCategory.low,
                          color: const Color(0xFF22C55E),
                          onTap: () => _choose(ReportCategory.low),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(mockReports.first.lat, mockReports.first.lng),
                    initialZoom: 14,
                    onMapReady: () => _mapReady = true,
                    onTap: (_, _) => setState(() => _selected = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _satellite
                          ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'pothole_mobile',
                    ),
                    MarkerLayer(
                      markers: [
                        for (final report in visible)
                          Marker(
                            point: LatLng(report.lat, report.lng),
                            width: selected?.id == report.id ? 36 : 22,
                            height: selected?.id == report.id ? 36 : 22,
                            child: GestureDetector(
                              onTap: () => setState(() => _selected = report),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _tone(report.category),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x33000000), blurRadius: 4),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      _MapButton(
                        icon: LucideIcons.locateFixed,
                        onTap: () {
                          final target = _selected ?? mockReports.first;
                          _moveTo(target);
                        },
                      ),
                      const SizedBox(height: 8),
                      _MapButton(
                        icon: LucideIcons.layers,
                        onTap: () => setState(() => _satellite = !_satellite),
                      ),
                      const SizedBox(height: 8),
                      _MapButton(icon: LucideIcons.plus, onTap: () => _zoom(1)),
                      const SizedBox(height: 8),
                      _MapButton(icon: LucideIcons.minus, onTap: () => _zoom(-1)),
                    ],
                  ),
                ),
                if (selected != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _DetailCard(
                      report: selected,
                      onClose: () => setState(() => _selected = null),
                      onRoute: _openRoute,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _tone(ReportCategory category) {
    switch (category) {
      case ReportCategory.high:
        return const Color(0xFFEF4444);
      case ReportCategory.medium:
        return const Color(0xFFF59E0B);
      case ReportCategory.low:
        return const Color(0xFF22C55E);
    }
  }
}

class _MapFilter extends StatelessWidget {
  const _MapFilter({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? color : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                if (!selected) ...[
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                ],
                Text(
                  '$label ($count)',
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF334155),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 16)),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.report, required this.onClose, required this.onRoute});

  final PotholeReport report;
  final VoidCallback onClose;
  final VoidCallback onRoute;

  @override
  Widget build(BuildContext context) {
    final tone = switch (report.category) {
      ReportCategory.high => const Color(0xFFEF4444),
      ReportCategory.medium => const Color(0xFFF59E0B),
      ReportCategory.low => const Color(0xFF22C55E),
    };
    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    report.category.label,
                    style: TextStyle(color: tone, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  'Skor ${report.score.toStringAsFixed(1)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                Text(
                  formatReportWhen(report.timestamp),
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${report.street}, Bogor',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'GPS: ${formatCoordinate(report.lat, report.lng)} (±${report.gpsAccuracy.toStringAsFixed(1)}m)',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const ReportThumbnail(label: 'AI\nDetection', width: 84, height: 64),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      _Fact(label: 'Tipe', value: 'Lubang Dalam (Pothole)'),
                      _Fact(label: 'Luas', value: '${report.parameters.l.round()}%'),
                      _Fact(label: 'Posisi', value: laneLabel(report.parameters.p)),
                      _Fact(label: 'Kelas Jalan', value: roadClassLabel(report.parameters.t)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                report.status.label,
                style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onRoute,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3B6CFF),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(LucideIcons.navigation, size: 16),
                    label: const Text('Buka Navigasi Rute'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onClose,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(LucideIcons.x, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
