import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../models/pothole_report.dart';
import '../services/device_identity.dart';
import '../services/offline_report_queue.dart';
import '../services/road_safe_api_client.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _api = RoadSafeApiClient();
  final _queue = OfflineReportQueue();
  Future<List<PotholeReport>> _reports = Future.value(const []);
  int _queued = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final deviceId = await DeviceIdentity().getOrCreate();
      await _api.registerDevice(
        id: deviceId,
        model: 'Flutter Mobile',
        appVersion: '1.0.0',
      );
      final reports = await _api.getReports(deviceId: deviceId);
      final queued = await _queue.count();
      if (mounted) {
        setState(() {
          _reports = Future.value(reports);
          _queued = queued;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _reports = Future.value(const []);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<PotholeReport>>(
        future: _reports,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data ?? const <PotholeReport>[];
          final auth = AuthProvider.of(context);
          final user = auth.user;

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (user != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x080F172A),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFE7F0FF),
                          child: const Icon(LucideIcons.user, color: Color(0xFF3B6CFF), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.nama,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${user.email} • Peran: ${user.peran}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.logOut, color: Color(0xFFEF4444), size: 20),
                          tooltip: 'Keluar',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Konfirmasi Keluar'),
                                content: const Text('Apakah Anda yakin ingin keluar dari akun RoadSafe?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('Batal'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text('Keluar'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true && context.mounted) {
                              await auth.logout();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const LoginPage()),
                                  (route) => false,
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                if (_queued > 0)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.cloud_upload_outlined),
                      title: Text('$_queued laporan menunggu sinkronisasi'),
                      subtitle: const Text('Tersimpan di antrean lokal'),
                    ),
                  ),
                if (_error != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.error_outline, color: Colors.red),
                      title: const Text('Gagal mengambil riwayat'),
                      subtitle: Text(_error!),
                      trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
                    ),
                  ),
                if (_error == null && reports.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: Text('Belum ada laporan dari perangkat ini.')),
                  ),
                for (final report in reports) _ReportCard(report: report),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final PotholeReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('${report.category.label} - ${report.score.toStringAsFixed(1)}'),
        subtitle: Text(
          '${report.street}\n'
          '${report.lat.toStringAsFixed(5)}, ${report.lng.toStringAsFixed(5)} • '
          '${report.speed.toStringAsFixed(1)} km/jam\n${report.status.label}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
