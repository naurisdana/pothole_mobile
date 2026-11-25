import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'report_payload.dart';

class OfflineQueueItem {
  const OfflineQueueItem({required this.id, required this.payload});
  final int id;
  final ReportPayload payload;
}

class OfflineReportQueue {
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final databasePath = await getDatabasesPath();
    _database = await openDatabase(
      path.join(databasePath, 'roadasafe_queue.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE report_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payload TEXT NOT NULL,
            image_path TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  Future<int> enqueue(ReportPayload payload) async {
    if (!await payload.imageFile.exists()) {
      throw ArgumentError('File gambar antrean tidak ditemukan.');
    }
    final directory = await getApplicationDocumentsDirectory();
    final queueDirectory = Directory(path.join(directory.path, 'report_queue'));
    await queueDirectory.create(recursive: true);
    final storedImage = File(path.join(
      queueDirectory.path,
      '${DateTime.now().microsecondsSinceEpoch}${path.extension(payload.imagePath)}',
    ));
    await payload.imageFile.copy(storedImage.path);
    final storedPayload = _replaceImagePath(payload, storedImage.path);
    return (await _db).insert('report_queue', {
      'payload': jsonEncode(_toJson(storedPayload)),
      'image_path': storedImage.path,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<OfflineQueueItem>> pending() async {
    final rows = await (await _db).query('report_queue', orderBy: 'id ASC');
    return rows.map((row) {
      final json = jsonDecode(row['payload']! as String) as Map<String, dynamic>;
      return OfflineQueueItem(id: row['id']! as int, payload: _fromJson(json));
    }).toList();
  }

  Future<void> remove(OfflineQueueItem item) async {
    await (await _db).delete('report_queue', where: 'id = ?', whereArgs: [item.id]);
    final file = File(item.payload.imagePath);
    if (await file.exists()) await file.delete();
  }

  Future<int> count() async {
    final result = await (await _db).rawQuery('SELECT COUNT(*) AS count FROM report_queue');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  ReportPayload _replaceImagePath(ReportPayload payload, String imagePath) => ReportPayload(
        imagePath: imagePath,
        deviceId: payload.deviceId,
        latitude: payload.latitude,
        longitude: payload.longitude,
        gpsAccuracy: payload.gpsAccuracy,
        confidence: payload.confidence,
        l: payload.l,
        k: payload.k,
        p: payload.p,
        t: payload.t,
        street: payload.street,
        speed: payload.speed,
        heading: payload.heading,
        damageType: payload.damageType,
        modelVersion: payload.modelVersion,
        timestamp: payload.timestamp,
      );

  Map<String, dynamic> _toJson(ReportPayload payload) => {
        'imagePath': payload.imagePath,
        'deviceId': payload.deviceId,
        'latitude': payload.latitude,
        'longitude': payload.longitude,
        'gpsAccuracy': payload.gpsAccuracy,
        'confidence': payload.confidence,
        'l': payload.l,
        'k': payload.k,
        'p': payload.p,
        't': payload.t,
        'street': payload.street,
        'speed': payload.speed,
        'heading': payload.heading,
        'damageType': payload.damageType,
        'modelVersion': payload.modelVersion,
        'timestamp': payload.timestamp?.toIso8601String(),
      };

  ReportPayload _fromJson(Map<String, dynamic> json) => ReportPayload(
        imagePath: json['imagePath'] as String,
        deviceId: json['deviceId'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        gpsAccuracy: (json['gpsAccuracy'] as num).toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
        l: (json['l'] as num).toDouble(),
        k: (json['k'] as num).toDouble(),
        p: (json['p'] as num).toDouble(),
        t: (json['t'] as num).toDouble(),
        street: json['street'] as String?,
        speed: (json['speed'] as num?)?.toDouble(),
        heading: (json['heading'] as num?)?.toDouble(),
        damageType: json['damageType'] as String,
        modelVersion: json['modelVersion'] as String,
        timestamp: json['timestamp'] == null ? null : DateTime.parse(json['timestamp'] as String),
      );
}
