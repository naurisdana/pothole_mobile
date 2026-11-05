String formatClock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute WIB';
}

String formatReportWhen(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final clock = formatClock(time);
  final delta = today.difference(day).inDays;
  if (delta == 0) return 'Hari ini, $clock';
  if (delta == 1) return 'Kemarin, $clock';
  return '${time.day}/${time.month}, $clock';
}

String formatCoordinate(double lat, double lng) {
  return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
}

String laneLabel(double position) {
  if (position >= 75) return 'Tengah Lajur';
  if (position >= 55) return 'Tepi Lajur';
  return 'Bahu Jalan';
}

String roadClassLabel(double density) {
  if (density >= 75) return 'Arteri Primer';
  if (density >= 55) return 'Kolektor';
  return 'Jalan Lokal';
}
