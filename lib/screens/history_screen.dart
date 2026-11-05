import 'package:flutter/material.dart';

import '../services/mock_data.dart';

/// Kerangka tab riwayat. Daftar antrean menyusul di layar UI-M02.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text(
          'Riwayat & Antrean\n${mockReports.length} laporan sampel',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
