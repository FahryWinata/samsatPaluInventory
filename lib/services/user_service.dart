import '../models/user_model.dart';
import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'activity_service.dart';
import 'cache_service.dart';

class UserService {
  SupabaseClient get supabase => SupabaseService.client;
  final _cache = CacheService();

  // Create a new user
  Future<int> createUser(User user) async {
    final data = user.toMap()..remove('id');
    final response = await supabase
        .from('users')
        .insert(data)
        .select()
        .single();

    // Invalidate cache after creation
    _cache.invalidate(CacheKeys.allUsers);

    return response['id'] as int;
  }

  // Get all users (with caching - 5 minute TTL)
  Future<List<User>> getAllUsers() async {
    return _cache.getOrFetch(
      CacheKeys.allUsers,
      () async {
        final List<dynamic> response = await supabase
            .from('users')
            .select()
            .order('name');
        return response.map((json) => User.fromMap(json)).toList();
      },
      ttlSeconds: CacheService.longTTL, // 5 minutes
    );
  }

  // Get user by ID
  Future<User?> getUserById(int id) async {
    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('id', id)
          .single();
      return User.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  // Update user
  Future<int> updateUser(User user) async {
    await supabase
        .from('users')
        .update(user.toMap())
        .eq('id', user.id as Object);

    // Invalidate cache after update
    _cache.invalidate(CacheKeys.allUsers);

    return user.id!;
  }

  // Delete user
  Future<int> deleteUser(int id) async {
    // Get user info before deletion for logging
    final user = await getUserById(id);
    final userName = user?.name ?? 'Unknown User';

    // First, delete transfer history where this user is involved (from or to)
    await supabase.from('asset_transfers').delete().eq('from_user_id', id);
    await supabase.from('asset_transfers').delete().eq('to_user_id', id);

    // Release all assets assigned to this user (set to available)
    await supabase
        .from('assets')
        .update({
          'status': 'available',
          'current_holder_id': null,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('current_holder_id', id);

    // Delete the user
    await supabase.from('users').delete().eq('id', id);

    // Invalidate caches
    _cache.invalidate(CacheKeys.allUsers);
    _cache.invalidate(CacheKeys.allAssets); // Assets were modified too

    // Log activity
    final activityService = ActivityService();
    await activityService.logActivity(
      action: 'delete',
      entityType: 'user',
      entityId: id,
      entityName: userName,
      details: 'User deleted, assets released to available',
    );

    return id;
  }

  // Search users by name
  Future<List<User>> searchUsers(String query) async {
    final List<dynamic> response = await supabase
        .from('users')
        .select()
        .ilike('name', '%$query%'); // Case insensitive search
    return response.map((json) => User.fromMap(json)).toList();
  }

  // Get users by department
  Future<List<User>> getUsersByDepartment(String department) async {
    final List<dynamic> response = await supabase
        .from('users')
        .select()
        .eq('department', department);
    return response.map((json) => User.fromMap(json)).toList();
  }
}
