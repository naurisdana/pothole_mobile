import 'package:flutter/material.dart';

import '../services/mock_data.dart';

/// Kerangka tab peta. Marker sebaran menyusul di layar UI-M03.
class DistributionMapScreen extends StatelessWidget {
  const DistributionMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text(
          'Peta Sebaran\n${mockReports.length} titik sampel',
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
