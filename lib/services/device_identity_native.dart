import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DeviceIdentity {
  Future<String> getOrCreate() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/roadasafe-device-id');
    if (await file.exists()) {
      final value = (await file.readAsString()).trim();
      if (_isUuid(value)) return value;
    }
    final id = _uuidV4();
    await file.writeAsString(id, flush: true);
    return id;
  }

  bool _isUuid(String value) => RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(value);

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = base16Encode(bytes);
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  String base16Encode(List<int> bytes) {
    const digits = '0123456789abcdef';
    return bytes.map((byte) => digits[(byte >> 4) & 0x0f] + digits[byte & 0x0f]).join();
  }
}
