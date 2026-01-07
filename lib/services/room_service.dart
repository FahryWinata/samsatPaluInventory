import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room_model.dart';

class RoomService {
  final _supabase = Supabase.instance.client;

  /// Get all rooms
  Future<List<Room>> getAllRooms() async {
    final response = await _supabase
        .from('rooms')
        .select()
        .order('name', ascending: true);

    return (response as List).map((json) => Room.fromMap(json)).toList();
  }

  /// Get room by ID
  Future<Room?> getRoomById(int id) async {
    final response = await _supabase
        .from('rooms')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Room.fromMap(response);
  }

  /// Create a new room
  Future<int> createRoom(Room room) async {
    final response = await _supabase
        .from('rooms')
        .insert(room.toMap()..remove('id'))
        .select('id')
        .single();

    return response['id'] as int;
  }

  /// Update an existing room
  Future<void> updateRoom(Room room) async {
    if (room.id == null) throw Exception('Room ID is required for update');

    await _supabase
        .from('rooms')
        .update(room.toMap()..remove('id'))
        .eq('id', room.id!);
  }

  /// Delete a room
  Future<void> deleteRoom(int id) async {
    // First, unassign any assets from this room
    await _supabase
        .from('assets')
        .update({'assigned_to_room_id': null})
        .eq('assigned_to_room_id', id);

    // Then delete the room
    await _supabase.from('rooms').delete().eq('id', id);
  }

  /// Get assets assigned to a room
  Future<List<Map<String, dynamic>>> getAssetsInRoom(int roomId) async {
    final response = await _supabase
        .from('assets')
        .select()
        .eq('assigned_to_room_id', roomId)
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get room count
  Future<int> getRoomCount() async {
    final response = await _supabase.from('rooms').select('id');
    return (response as List).length;
  }

  /// Search rooms by name
  Future<List<Room>> searchRooms(String query) async {
    final response = await _supabase
        .from('rooms')
        .select()
        .ilike('name', '%$query%')
        .order('name', ascending: true);

    return (response as List).map((json) => Room.fromMap(json)).toList();
  }
}
