import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MigrationService {
  SupabaseClient get supabase => SupabaseService.client;

  Future<void> migrateFromSQLite(String dbPath) async {
    // 1. Open SQLite Database
    sqfliteFfiInit();
    final databaseFactory = databaseFactoryFfi;
    final db = await databaseFactory.openDatabase(dbPath);

    try {
      // 2. Migrate Users (Parent table)
      await _migrateTable(db, 'users', (row) async {
        final data = Map<String, dynamic>.from(row);
        await supabase.from('users').upsert(data);
      });

      // 3. Migrate Inventory (Independent)
      await _migrateTable(db, 'inventory', (row) async {
        final data = Map<String, dynamic>.from(row);
        await supabase.from('inventory').upsert(data);
      });

      // 4. Migrate Assets (Depends on Users for holder_id)
      await _migrateTable(db, 'assets', (row) async {
        final data = Map<String, dynamic>.from(row);
        await supabase.from('assets').upsert(data);
      });

      // 5. Migrate Transfer History
      await _migrateTable(db, 'asset_transfers', (row) async {
        final data = Map<String, dynamic>.from(row);
        await supabase.from('asset_transfers').upsert(data);
      });

      // 6. Migrate Activities
      await _migrateTable(db, 'activities', (row) async {
        final data = Map<String, dynamic>.from(row);
        await supabase.from('activities').upsert(data);
      });
    } finally {
      await db.close();
    }
  }

  Future<void> _migrateTable(
    Database db,
    String tableName,
    Future<void> Function(Map<String, dynamic> row) inserter,
  ) async {
    try {
      final rows = await db.query(tableName);
      for (final row in rows) {
        await inserter(row);
      }
    } catch (e) {
      // Table might not exist in older versions, skip
      debugPrint('Skipping table $tableName: $e');
    }
  }
}
