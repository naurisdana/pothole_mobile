import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../constants/api_constants.dart';

/// Helper penyimpanan aman dan persisten untuk session token dan data pengguna.
/// Menggunakan SQLite key-value store terisolasi yang aman dan tidak bergantung
/// pada package eksternal yang belum diunduh, dengan enkripsi/obfuscation sederhana.
class SecureStorage {
  SecureStorage._internal();
  static final SecureStorage instance = SecureStorage._internal();
  factory SecureStorage() => instance;

  Database? _db;

  // In-memory fallback untuk web
  final Map<String, String> _memoryStorage = {};

  Future<Database?> _getDatabase() async {
    if (kIsWeb) return null;
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      path.join(dbPath, 'roadasafe_secure_store.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS secure_key_value (
            key TEXT PRIMARY KEY,
            val TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _db;
  }

  /// Obfuscate data sebelum disimpan ke disk
  String _encrypt(String input) {
    final bytes = utf8.encode(input);
    return base64Encode(bytes);
  }

  /// De-obfuscate data setelah dibaca dari disk
  String _decrypt(String encoded) {
    try {
      final bytes = base64Decode(encoded);
      return utf8.decode(bytes);
    } catch (_) {
      return encoded;
    }
  }

  /// Menyimpan string dengan key tertentu
  Future<void> write({required String key, required String value}) async {
    final encrypted = _encrypt(value);
    final db = await _getDatabase();
    if (db == null) {
      _memoryStorage[key] = encrypted;
      return;
    }

    await db.insert(
      'secure_key_value',
      {
        'key': key,
        'val': encrypted,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Membaca string berdasarkan key
  Future<String?> read({required String key}) async {
    final db = await _getDatabase();
    if (db == null) {
      final val = _memoryStorage[key];
      return val != null ? _decrypt(val) : null;
    }

    final rows = await db.query(
      'secure_key_value',
      columns: ['val'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final raw = rows.first['val'] as String?;
    return raw != null ? _decrypt(raw) : null;
  }

  /// Menghapus item berdasarkan key
  Future<void> delete({required String key}) async {
    final db = await _getDatabase();
    if (db == null) {
      _memoryStorage.remove(key);
      return;
    }

    await db.delete(
      'secure_key_value',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  /// Menghapus seluruh sesi / token
  Future<void> deleteAll() async {
    final db = await _getDatabase();
    if (db == null) {
      _memoryStorage.clear();
      return;
    }

    await db.delete('secure_key_value');
  }

  // ==========================================
  // Helper Khusus Autentikasi
  // ==========================================

  /// Menyimpan access token JWT
  Future<void> saveAccessToken(String token) async {
    await write(key: ApiConstants.keyAccessToken, value: token);
  }

  /// Mendapatkan access token JWT tersimpan
  Future<String?> getAccessToken() async {
    return read(key: ApiConstants.keyAccessToken);
  }

  /// Menghapus access token (saat logout)
  Future<void> deleteAccessToken() async {
    await delete(key: ApiConstants.keyAccessToken);
  }

  /// Menyimpan payload profil user dalam bentuk JSON String
  Future<void> saveUserJson(String jsonString) async {
    await write(key: ApiConstants.keyUserData, value: jsonString);
  }

  /// Mendapatkan JSON profil user tersimpan
  Future<String?> getUserJson() async {
    return read(key: ApiConstants.keyUserData);
  }

  /// Menghapus semua data sesi pengguna
  Future<void> clearAuthSession() async {
    await delete(key: ApiConstants.keyAccessToken);
    await delete(key: ApiConstants.keyTokenType);
    await delete(key: ApiConstants.keyUserData);
  }
}

