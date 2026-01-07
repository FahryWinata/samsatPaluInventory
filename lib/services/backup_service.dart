import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

class BackupService {
  // Cloud based system doesn't need manual file backups like SQLite

  Future<String> backupDatabase() async {
    // No-op or throw
    throw Exception('Cloud Database is automatically backed up by provider.');
  }

  Future<bool> restoreDatabase(String backupPath) async {
    throw Exception('Restore must be done via Cloud Console.');
  }

  Future<String> getDatabaseSize() async {
    return 'Cloud Managed';
  }

  Future<void> clearAllData() async {
    try {
      final supabase = SupabaseService.client;
      // Truncate/Delete all
      await supabase.from('asset_transfers').delete().neq('id', 0);
      await supabase.from('assets').delete().neq('id', 0);
      await supabase.from('inventory').delete().neq('id', 0);
      await supabase.from('users').delete().neq('id', 0);
    } catch (e) {
      throw Exception('Failed to clear data: $e');
    }
  }

  Future<void> performAutoBackupIfNeeded() async {
    // No-op
    debugPrint('Auto-backup skipped (Cloud Mode)');
  }
}
