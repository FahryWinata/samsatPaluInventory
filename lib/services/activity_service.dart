import '../models/activity_model.dart';
import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityService {
  // Helper to access client
  SupabaseClient get supabase => SupabaseService.client;

  // Log a new activity
  Future<int> logActivity({
    required String action,
    required String entityType,
    required int entityId,
    required String entityName,
    String performedBy = 'Admin', // Default to Admin for now
    String details = '',
  }) async {
    final activity = ActivityLog(
      action: action,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      performedBy: performedBy,
      timestamp: DateTime.now(),
      details: details,
    );

    // Remove ID to let DB generate it
    final data = activity.toMap()..remove('id');

    final response = await supabase
        .from('activities')
        .insert(data)
        .select()
        .single();

    return response['id'] as int;
  }

  // Get recent activities
  Future<List<ActivityLog>> getRecentActivities({int limit = 10}) async {
    final List<dynamic> response = await supabase
        .from('activities')
        .select()
        .order('timestamp', ascending: false)
        .limit(limit);

    return response.map((json) => ActivityLog.fromMap(json)).toList();
  }

  // Clear all logs (Optional utility)
  Future<void> clearLogs() async {
    // Requires a WHERE clause in Supabase.
    // We use a condition that is always true (id > 0) to delete potentially everything.
    // Use with caution.
    await supabase.from('activities').delete().gt('id', 0);
  }
}
