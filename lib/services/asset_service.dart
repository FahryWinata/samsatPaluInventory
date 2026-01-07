import '../models/asset_model.dart';
import '../models/asset_transfer_model.dart';
import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'activity_service.dart';
import 'storage_service.dart';

class AssetService {
  final activityService = ActivityService();
  SupabaseClient get supabase => SupabaseService.client;

  // Create new asset
  // Create new asset
  Future<int> createAsset(Asset asset) async {
    final data = asset.toMap()..remove('id');
    try {
      final response = await supabase
          .from('assets')
          .insert(data)
          .select()
          .single();
      final id = response['id'] as int;

      await _logCreateActivity(id, asset);
      return id;
    } on PostgrestException catch (e) {
      // 23505: duplicate key value violates unique constraint
      if (e.code == '23505') {
        return await _createAssetWithManualId(asset);
      }
      rethrow;
    }
  }

  Future<int> _createAssetWithManualId(Asset asset) async {
    // Fetch max ID
    final List<dynamic> maxIdResponse = await supabase
        .from('assets')
        .select('id')
        .order('id', ascending: false)
        .limit(1);

    int nextId = 1;
    if (maxIdResponse.isNotEmpty) {
      nextId = (maxIdResponse.first['id'] as int) + 1;
    }

    final data = asset.toMap();
    data['id'] = nextId;

    final response = await supabase
        .from('assets')
        .insert(data)
        .select()
        .single();
    final id = response['id'] as int;

    await _logCreateActivity(id, asset);
    return id;
  }

  Future<void> _logCreateActivity(int id, Asset asset) async {
    await activityService.logActivity(
      action: 'create',
      entityType: 'asset',
      entityId: id,
      entityName: asset.name,
      details: 'Added new asset: ${asset.identifierValue ?? asset.name}',
    );
  }

  // Get all assets
  Future<List<Asset>> getAllAssets() async {
    final List<dynamic> response = await supabase
        .from('assets')
        .select()
        .order('updated_at', ascending: false);
    return response.map((json) => Asset.fromMap(json)).toList();
  }

  // Get asset by ID
  Future<Asset?> getAssetById(int id) async {
    try {
      final response = await supabase
          .from('assets')
          .select()
          .eq('id', id)
          .single();
      return Asset.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  // Get assets by current holder (Used by Users Screen)
  Future<List<Asset>> getAssetsByHolder(int userId) async {
    final List<dynamic> response = await supabase
        .from('assets')
        .select()
        .eq('current_holder_id', userId);
    return response.map((json) => Asset.fromMap(json)).toList();
  }

  // Update asset (Generic)
  Future<int> updateAsset(Asset asset) async {
    // Explicitly update updated_at if not handled by trigger (but app sets it usually)
    await supabase
        .from('assets')
        .update(asset.toMap())
        .eq('id', asset.id as Object);
    return asset.id!;
  }

  // Update Status specifically
  Future<bool> updateAssetStatus(int assetId, String status) async {
    final asset = await getAssetById(assetId);
    if (asset == null) return false;

    final updatedAsset = asset.copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );

    await updateAsset(updatedAsset);

    await activityService.logActivity(
      action: 'update',
      entityType: 'asset',
      entityId: assetId,
      entityName: asset.name,
      details: 'Status changed to $status',
    );

    return true;
  }

  // Transfer Asset
  Future<bool> transferAsset({
    required int assetId,
    required int toUserId,
    String? notes,
  }) async {
    final asset = await getAssetById(assetId);
    if (asset == null) return false;

    // 1. Create Transfer Record
    final transfer = AssetTransfer(
      assetId: assetId,
      fromUserId: asset.currentHolderId,
      toUserId: toUserId,
      transferDate: DateTime.now(),
      notes: notes,
    );

    // Insert transfer
    await supabase
        .from('asset_transfers')
        .insert(transfer.toMap()..remove('id'));

    // 2. Update Asset
    final updatedAsset = asset.copyWith(
      status: 'assigned',
      currentHolderId: toUserId,
      updatedAt: DateTime.now(),
    );

    await updateAsset(updatedAsset);

    // 3. Log Activity
    // Fetch user name via another query or assume Supabase handles joins via View.
    // We'll just fetch simple name for now.
    final userResponse = await supabase
        .from('users')
        .select('name')
        .eq('id', toUserId)
        .single();
    final userName = userResponse['name'] as String? ?? 'User #$toUserId';

    await activityService.logActivity(
      action: 'transfer',
      entityType: 'asset',
      entityId: assetId,
      entityName: asset.name,
      details: 'Transferred to $userName',
    );

    return true;
  }

  // Release Asset
  Future<bool> releaseAsset(
    int assetId,
    String newStatus, {
    String? notes,
  }) async {
    if (newStatus != 'available' && newStatus != 'maintenance') {
      return false;
    }

    final asset = await getAssetById(assetId);
    if (asset == null) return false;

    final updatedAsset = asset.copyWith(
      status: newStatus,
      currentHolderId: null, // Force null
      maintenanceLocation: newStatus == 'maintenance' ? notes : null,
      updatedAt: DateTime.now(),
    );

    await updateAsset(updatedAsset);

    await activityService.logActivity(
      action: 'update',
      entityType: 'asset',
      entityId: assetId,
      entityName: asset.name,
      details:
          'Asset moved to $newStatus (Holder cleared)${notes != null && notes.isNotEmpty ? '. Note: $notes' : ''}',
    );

    return true;
  }

  // Delete asset
  Future<int> deleteAsset(int id) async {
    final asset = await getAssetById(id);
    final name = asset?.name ?? 'Unknown';

    // Delete image from Supabase storage if exists
    if (asset?.imagePath != null) {
      final storageService = StorageService();
      await storageService.deleteImage(asset!.imagePath);
    }

    // First, delete related transfer history to avoid FK constraint
    await supabase.from('asset_transfers').delete().eq('asset_id', id);

    // Then delete the asset
    await supabase.from('assets').delete().eq('id', id);

    await activityService.logActivity(
      action: 'delete',
      entityType: 'asset',
      entityId: id,
      entityName: name,
      details: 'Asset deleted permanently',
    );
    return id;
  }

  // Statistics
  Future<Map<String, int>> getAssetStatistics() async {
    final available = await supabase
        .from('assets')
        .count(CountOption.exact)
        .eq('status', 'available');

    final assigned = await supabase
        .from('assets')
        .count(CountOption.exact)
        .eq('status', 'assigned');

    final maintenance = await supabase
        .from('assets')
        .count(CountOption.exact)
        .eq('status', 'maintenance');

    return {
      'available': available,
      'assigned': assigned,
      'maintenance': maintenance,
    };
  }

  // Get transfer history for an asset
  Future<List<AssetTransfer>> getTransferHistory(int assetId) async {
    final List<dynamic> response = await supabase
        .from('asset_transfers')
        .select()
        .eq('asset_id', assetId)
        .order('transfer_date', ascending: false);
    return response.map((json) => AssetTransfer.fromMap(json)).toList();
  }

  // Get transfer history with user names
  Future<List<Map<String, dynamic>>> getTransferHistoryWithNames(
    int assetId,
  ) async {
    // Supabase supports joining via select syntax if foreign keys exist
    // select('*, from_user:users!from_user_id(name), to_user:users!to_user_id(name)')
    // But keeping it simple for now, raw query might work via rpc, but simple join select is better.
    // Let's rely on manual joins or separate lookups? No, Supabase join is clean.

    final response = await supabase
        .from('asset_transfers')
        .select(
          '*, u_from:users!from_user_id(name), u_to:users!to_user_id(name)',
        )
        .eq('asset_id', assetId)
        .order('transfer_date', ascending: false);

    // Transform response to match expected flat format for UI
    return (response as List<dynamic>).map((item) {
      final map = item as Map<String, dynamic>;
      return {
        ...map,
        'from_user_name': map['u_from']?['name'],
        'to_user_name': map['u_to']?['name'],
      };
    }).toList();
  }

  // Get ALL transfer history
  Future<List<Map<String, dynamic>>> getAllTransfers({int limit = 50}) async {
    final response = await supabase
        .from('asset_transfers')
        .select('''
          *,
          assets(name, serial_number),
          u_from:users!from_user_id(name),
          u_to:users!to_user_id(name)
        ''')
        .order('transfer_date', ascending: false)
        .limit(limit);

    return (response as List<dynamic>).map((item) {
      final map = item as Map<String, dynamic>;
      final asset = map['assets'] as Map<String, dynamic>?;
      return {
        ...map,
        'asset_name': asset?['name'],
        'asset_serial': asset?['serial_number'],
        'from_user_name': map['u_from']?['name'],
        'to_user_name': map['u_to']?['name'],
      };
    }).toList();
  }

  // ==================== MAINTENANCE METHODS ====================

  /// Mark an asset as maintained - resets the maintenance cycle
  Future<bool> markAsMaintained(int assetId) async {
    final asset = await getAssetById(assetId);
    if (asset == null || !asset.requiresMaintenance) return false;

    final now = DateTime.now();
    DateTime? nextDate;

    if (asset.maintenanceIntervalDays != null) {
      nextDate = now.add(Duration(days: asset.maintenanceIntervalDays!));
    }

    final updatedAsset = asset.copyWith(
      lastMaintenanceDate: now,
      nextMaintenanceDate: nextDate,
      updatedAt: now,
    );

    await updateAsset(updatedAsset);

    await activityService.logActivity(
      action: 'update',
      entityType: 'asset',
      entityId: assetId,
      entityName: asset.name,
      details:
          'Marked as maintained. Next due: ${nextDate?.toIso8601String().split('T')[0] ?? 'N/A'}',
    );

    return true;
  }

  /// Update maintenance settings for an asset
  Future<bool> updateMaintenanceSettings({
    required int assetId,
    required bool requiresMaintenance,
    int? intervalDays,
  }) async {
    final asset = await getAssetById(assetId);
    if (asset == null) return false;

    DateTime? nextDate;
    if (requiresMaintenance && intervalDays != null) {
      // If enabling maintenance and has last date, calculate from last date
      // Otherwise calculate from now
      final baseDate = asset.lastMaintenanceDate ?? DateTime.now();
      nextDate = baseDate.add(Duration(days: intervalDays));
    }

    final updatedAsset = asset.copyWith(
      requiresMaintenance: requiresMaintenance,
      maintenanceIntervalDays: intervalDays,
      nextMaintenanceDate: nextDate,
      updatedAt: DateTime.now(),
    );

    await updateAsset(updatedAsset);
    return true;
  }

  /// Get all assets that require maintenance, sorted by next maintenance date
  Future<List<Asset>> getMaintenanceDueAssets() async {
    final List<dynamic> response = await supabase
        .from('assets')
        .select()
        .eq('requires_maintenance', true)
        .not('next_maintenance_date', 'is', null)
        .order('next_maintenance_date', ascending: true);
    return response.map((json) => Asset.fromMap(json)).toList();
  }

  /// Get count of overdue and upcoming maintenance items
  Future<Map<String, int>> getMaintenanceStats() async {
    final assets = await getMaintenanceDueAssets();
    final now = DateTime.now();

    int overdue = 0;
    int upcoming = 0;

    for (final asset in assets) {
      if (asset.nextMaintenanceDate != null) {
        if (asset.nextMaintenanceDate!.isBefore(now)) {
          overdue++;
        } else if (asset.nextMaintenanceDate!.isBefore(
          now.add(const Duration(days: 30)),
        )) {
          upcoming++;
        }
      }
    }

    return {'overdue': overdue, 'upcoming': upcoming};
  }
}
