import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/pothole_report.dart';
import '../services/mock_data.dart';
import '../utils/report_format.dart';
import '../widgets/report_thumbnail.dart';

enum _QueueFilter { all, queued, sent }

/// Riwayat deteksi dan antrean sinkronisasi, mengikuti UI-M02.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<PotholeReport> _reports = [...mockReports];
  var _filter = _QueueFilter.all;
  var _syncing = false;

  int get _queued => _reports.where((report) => report.status == ReportStatus.menungguSinyal).length;

  int get _sent => _reports.length - _queued;

  List<PotholeReport> get _visible {
    switch (_filter) {
      case _QueueFilter.all:
        return _reports;
      case _QueueFilter.queued:
        return _reports.where((report) => report.status == ReportStatus.menungguSinyal).toList();
      case _QueueFilter.sent:
        return _reports.where((report) => report.status != ReportStatus.menungguSinyal).toList();
    }
  }

  Future<void> _sync() async {
    if (_queued == 0 || _syncing) return;
    setState(() => _syncing = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final moved = _queued;
    setState(() {
      _reports = [
        for (final report in _reports)
          if (report.status == ReportStatus.menungguSinyal)
            report.copyWith(status: ReportStatus.terkirim)
          else
            report,
      ];
      _syncing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$moved laporan terkirim ke server.')),
    );
  }

  void _reload() {
    setState(() {
      _reports = [...mockReports];
      _filter = _QueueFilter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return ColoredBox(
      color: const Color(0xFFF4F6FB),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          'ROADSAFE FIELD V2.4',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Riwayat & Antrean',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _reload,
                    tooltip: 'Muat ulang sampel',
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _SyncBanner(queued: _queued, syncing: _syncing, onSync: _sync),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _FilterChip(
                        label: 'Semua (${_reports.length})',
                        selected: _filter == _QueueFilter.all,
                        onTap: () => setState(() => _filter = _QueueFilter.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Antrean\nOffline',
                        count: _queued,
                        selected: _filter == _QueueFilter.queued,
                        onTap: () => setState(() => _filter = _QueueFilter.queued),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Terkirim ($_sent)',
                        selected: _filter == _QueueFilter.sent,
                        onTap: () => setState(() => _filter = _QueueFilter.sent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Tidak ada laporan pada filter ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    )
                  else
                    for (var i = 0; i < visible.length; i++) ...[
                      _ReportCard(report: visible[i], order: i + 1),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 6),
                  const Text(
                    'Penyimpanan lokal: 18.4 MB dari 2.0 GB dialokasikan',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.queued, required this.syncing, required this.onSync});

  final int queued;
  final bool syncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF6D48A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.hardDrive, color: Color(0xFFD97706), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  queued == 0
                      ? 'Semua laporan sudah terkirim'
                      : '$queued Laporan Menunggu Sinkronisasi',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 26),
            child: Text(
              'Tersimpan di antrean lokal saat kendaraan melaju di area tanpa sinyal.',
              style: TextStyle(color: Color(0xFFB45309), fontSize: 12, height: 1.35),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: queued == 0 || syncing ? null : onSync,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFBBF7D0),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.uploadCloud, size: 16),
              label: Text(syncing ? 'Mengirim...' : 'Sinkronkan Sekarang'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? Colors.white : const Color(0xFFE8EDF4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? const Color(0xFFBFDBFE) : Colors.transparent),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: selected ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                    child: Text(
                      '$count',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.order});

  final PotholeReport report;
  final int order;

  @override
  Widget build(BuildContext context) {
    final queued = report.status == ReportStatus.menungguSinyal;
    final tone = _tone(report.category);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: tone, width: 4)),
        boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ReportThumbnail(label: 'Privacy\nBlur'),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Badge(label: report.category.label, color: tone),
                        const Spacer(),
                        Text(
                          'Skor: ${report.score.toStringAsFixed(1)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(report.street, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      formatCoordinate(report.lat, report.lng),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                formatReportWhen(report.timestamp),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
              const SizedBox(width: 12),
              const Icon(LucideIcons.gauge, size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                '${report.speed.toStringAsFixed(0)} km/jam',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: queued ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        queued ? LucideIcons.database : LucideIcons.uploadCloud,
                        size: 13,
                        color: queued ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          queued ? 'Menunggu Sinyal (antrean lokal)' : report.status.label,
                          style: TextStyle(
                            color: queued ? const Color(0xFFB45309) : const Color(0xFF15803D),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                queued ? 'Slot #${order.toString().padLeft(2, '0')}' : 'Batch #${100 + order}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
