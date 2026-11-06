import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Menyimpan apakah pengemudi sudah melewati layar izin pertama.
class OnboardingStore {
  const OnboardingStore({this.overrideCompleted});

  /// Jika diisi, penyimpanan berkas dilewati. Dipakai tes widget.
  final bool? overrideCompleted;

  Future<bool> isCompleted() async {
    final override = overrideCompleted;
    if (override != null) return override;
    try {
      return (await _file()).exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> markCompleted() async {
    if (overrideCompleted != null) return;
    try {
      final file = await _file();
      await file.writeAsString('ok');
    } catch (_) {}
  }

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/roadsafe_onboarding.done');
  }
}
