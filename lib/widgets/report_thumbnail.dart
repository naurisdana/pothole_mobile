import 'package:flutter/material.dart';

/// Gambar bukti pengganti. Foto asli belum disimpan di perangkat.
class ReportThumbnail extends StatelessWidget {
  const ReportThumbnail({
    super.key,
    required this.label,
    this.width = 72,
    this.height = 72,
  });

  final String label;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _AsphaltPainter()),
            DecoratedBox(
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18)),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AsphaltPainter extends CustomPainter {
  const _AsphaltPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF3F4A57),
    );
    final lane = Paint()
      ..color = const Color(0xFFF5C542)
      ..strokeWidth = 2;
    final center = size.width / 2;
    for (var y = 4.0; y < size.height; y += 10) {
      canvas.drawLine(Offset(center, y), Offset(center, y + 5), lane);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.48, size.height * 0.62),
        width: size.width * 0.42,
        height: size.height * 0.28,
      ),
      Paint()..color = const Color(0xFF1C2430),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
