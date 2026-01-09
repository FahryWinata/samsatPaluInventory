import 'package:flutter/foundation.dart';
import '../models/inventory_model.dart';
import '../models/inventory_history_model.dart';
import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'activity_service.dart';
import 'cache_service.dart';

class InventoryService {
  final activityService = ActivityService();
  SupabaseClient get supabase => SupabaseService.client;
  final _cache = CacheService();

  /// Helper to invalidate inventory caches
  void _invalidateInventoryCaches() {
    _cache.invalidate(CacheKeys.allInventoryItems);
    _cache.invalidate(CacheKeys.inventoryStats);
  }

  Future<int> createItem(InventoryItem item) async {
    debugPrint('=== InventoryService.createItem START ===');
    debugPrint('Item name: ${item.name}');
    debugPrint('Item.toMap(): ${item.toMap()}');

    try {
      // Check if name exists
      final List<dynamic> existing = await supabase
          .from('inventory')
          .select()
          .ilike('name', item.name); // Case insensitive check

      debugPrint('Existing items with same name: ${existing.length}');

      if (existing.isNotEmpty) {
        debugPrint('ERROR: Item with this name already exists');
        throw Exception('Item with this name already exists');
      }

      final data = item.toMap()..remove('id');
      debugPrint('Data to insert (after removing id): $data');

      final response = await supabase
          .from('inventory')
          .insert(data)
          .select()
          .single();

      debugPrint('Insert response: $response');
      final id = response['id'] as int;

      await activityService.logActivity(
        action: 'create',
        entityType: 'inventory',
        entityId: id,
        entityName: item.name,
        details: 'Initial stock: ${item.quantity} ${item.unit}',
      );

      // Invalidate cache after creation
      _invalidateInventoryCaches();

      debugPrint('=== InventoryService.createItem SUCCESS, id=$id ===');
      return id;
    } catch (e, stackTrace) {
      debugPrint('=== InventoryService.createItem ERROR ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get all items (with caching - 30 second TTL since inventory changes frequently)
  Future<List<InventoryItem>> getAllItems() async {
    return _cache.getOrFetch(
      CacheKeys.allInventoryItems,
      () async {
        final List<dynamic> response = await supabase
            .from('inventory')
            .select()
            .order('name');
        return response.map((json) => InventoryItem.fromMap(json)).toList();
      },
      ttlSeconds: CacheService.shortTTL, // 30 seconds
    );
  }

  // Paginated Items with Count
  Future<({List<InventoryItem> items, int count})> getItemsPaginated({
    int page = 1,
    int limit = 10,
    String? searchQuery,
    String? filterStatus, // 'good', 'low', 'out'
  }) async {
    // We need a separate query for count because Supabase doesn't return count with select(*) easily in one go
    // without `count: exact` which wraps response.
    // However, `select()` with `count(CountOption.exact)` returns a `PostgrestResponse` which contains `count` and `data`.

    // Let's use the modifiers to build the base filter first.
    // BUT Supabase Flutter v2 chain is strict.
    // We'll use a helper to apply filters to both the data query and the count query?
    // Or just use `select('*, count(*)')` is not standard Postgrest.

    // Better approach: Use `count()` method on a fresh query builder for count, and standard select for data.

    // Helper to apply filters
    PostgrestFilterBuilder applyFilters(PostgrestFilterBuilder q) {
      if (searchQuery != null && searchQuery.isNotEmpty) {
        q = q.or('name.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }
      if (filterStatus == 'out') {
        q = q.eq('quantity', 0);
      }
      return q;
    }

    // 1. Get Count
    // count(CountOption.exact) returns PostgrestFilterBuilder<int>
    var countBuilder = supabase.from('inventory').count(CountOption.exact);
    final countRes = await applyFilters(countBuilder);
    final totalCount = countRes as int;

    // 2. Get Data
    var dataBuilder = supabase.from('inventory').select();
    var dataQuery = applyFilters(dataBuilder);

    final from = (page - 1) * limit;
    final to = from + limit - 1;

    final List<dynamic> response = await dataQuery
        .order('name', ascending: true)
        .range(from, to);

    final items = response.map((json) => InventoryItem.fromMap(json)).toList();

    return (items: items, count: totalCount);
  }

  // Get inventory stats (with caching - 30 second TTL)
  Future<Map<String, int>> getInventoryStats() async {
    return _cache.getOrFetch(CacheKeys.inventoryStats, () async {
      // 1. Total Rows
      final total = await supabase.from('inventory').count(CountOption.exact);

      // 2. Out of Stock
      final out = await supabase
          .from('inventory')
          .count(CountOption.exact)
          .eq('quantity', 0);

      // 3. For Low/Good, we fetch minimal data (id, quantity, minimum_stock)
      final List<dynamic> minimalData = await supabase
          .from('inventory')
          .select('quantity, minimum_stock');

      int low = 0;
      int good = 0;
      for (var item in minimalData) {
        final q = item['quantity'] as int;
        final m = item['minimum_stock'] as int;
        if (q > 0) {
          if (q <= m) {
            low++;
          } else {
            good++;
          }
        }
      }

      return {'total': total, 'out': out, 'low': low, 'good': good};
    }, ttlSeconds: CacheService.shortTTL);
  }

  Future<InventoryItem?> getItemById(int id) async {
    try {
      final response = await supabase
          .from('inventory')
          .select()
          .eq('id', id)
          .single();
      return InventoryItem.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Future<int> updateItem(InventoryItem item) async {
    // Check name uniqueness (excluding self)
    final List<dynamic> existing = await supabase
        .from('inventory')
        .select()
        .ilike('name', item.name)
        .neq('id', item.id as Object);

    if (existing.isNotEmpty) {
      throw Exception('Item with this name already exists');
    }

    await supabase
        .from('inventory')
        .update(item.toMap())
        .eq('id', item.id as Object);

    await activityService.logActivity(
      action: 'update',
      entityType: 'inventory',
      entityId: item.id!,
      entityName: item.name,
      details: 'Updated item details',
    );

    return item.id!;
  }

  Future<int> deleteItem(int id) async {
    final item = await getItemById(id);
    final name = item?.name ?? 'Unknown Item';

    await supabase.from('inventory').delete().eq('id', id);

    await activityService.logActivity(
      action: 'delete',
      entityType: 'inventory',
      entityId: id,
      entityName: name,
      details: 'Item deleted from inventory',
    );

    return id;
  }

  Future<int> increaseQuantity(int id, int amount, {String? notes}) async {
    final item = await getItemById(id);
    if (item == null) return 0;

    final newQuantity = item.quantity + amount;

    // We can just update the quantity field directly
    await supabase
        .from('inventory')
        .update({
          'quantity': newQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);

    // Log detailed history
    await _logHistory(
      inventoryId: id,
      actionType: 'in',
      quantityChange: amount,
      previousQuantity: item.quantity,
      newQuantity: newQuantity,
      notes: notes,
    );

    await activityService.logActivity(
      action: 'update',
      entityType: 'inventory',
      entityId: id,
      entityName: item.name,
      details:
          'Stock increased by $amount (New total: $newQuantity). Notes: $notes',
    );

    return id;
  }

  Future<int> decreaseQuantity(int id, int amount, {String? notes}) async {
    final item = await getItemById(id);
    if (item == null) return 0;

    final newQuantity = item.quantity - amount;
    if (newQuantity < 0) {
      throw Exception('Cannot decrease quantity below 0');
    }

    await supabase
        .from('inventory')
        .update({
          'quantity': newQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);

    // Log detailed history
    await _logHistory(
      inventoryId: id,
      actionType: 'out',
      quantityChange: -amount,
      previousQuantity: item.quantity,
      newQuantity: newQuantity,
      notes: notes,
    );

    await activityService.logActivity(
      action: 'update',
      entityType: 'inventory',
      entityId: id,
      entityName: item.name,
      details:
          'Stock decreased by $amount (New total: $newQuantity). Notes: $notes',
    );

    return id;
  }

  Future<List<InventoryItem>> getLowStockItems() async {
    // Logic: quantity <= minimum_stock. Supabase doesn't support comparing two columns directly in .filter() easily efficiently without RPC
    // But we can filter client side or use a view.
    // Actually, Supabase postgrest-js supports .lte('quantity', 'minimum_stock')? No, second arg is value.
    // We'll fetch all and filter in Dart for now to keep it simple, or write a custom query?
    // Given the expected scale (thousands not millions), filtering in Dart is likely fine for MVP.
    // OR we can use `.select().filter('quantity', 'lte', col('minimum_stock'))` syntax? No.
    // We'll fetch all items.

    final allItems = await getAllItems();
    return allItems
        .where((item) => item.quantity <= item.minimumStock)
        .toList();
  }

  Future<List<InventoryItem>> searchItems(String query) async {
    final List<dynamic> response = await supabase
        .from('inventory')
        .select()
        .or('name.ilike.%$query%,description.ilike.%$query%');
    return response.map((json) => InventoryItem.fromMap(json)).toList();
  }

  Future<int> getTotalItemCount() async {
    // Sum of quantity.
    // Supabase doesn't have a simple aggregate function exposed in the SDK without `rpc`.
    // We'll fetch all `quantity` fields and sum them up client side.
    final List<dynamic> response = await supabase
        .from('inventory')
        .select('quantity');
    return response.fold<int>(
      0,
      (sum, item) => sum + (item['quantity'] as int),
    );
  }

  Future<void> _logHistory({
    required int inventoryId,
    required String actionType,
    required int quantityChange,
    required int previousQuantity,
    required int newQuantity,
    String? notes,
  }) async {
    try {
      final history = InventoryHistory(
        inventoryId: inventoryId,
        actionType: actionType,
        quantityChange: quantityChange,
        previousQuantity: previousQuantity,
        newQuantity: newQuantity,
        notes: notes,
        createdAt: DateTime.now(),
        createdBy: 'Admin', // In real app, get from Auth Service
      );

      await supabase
          .from('inventory_history')
          .insert(history.toMap()..remove('id'));
    } catch (e) {
      debugPrint('Error logging inventory history: $e');
      // Don't throw, just log error so UI doesn't crash on logging failure
    }
  }

  Future<List<InventoryHistory>> getHistoryByMonth(int year, int month) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    final List<dynamic> response = await supabase
        .from('inventory_history')
        .select(
          '*, inventory:inventory_id(name)',
        ) // Join with inventory to get name
        .gte('created_at', startDate.toIso8601String())
        .lte('created_at', endDate.toIso8601String())
        .order('created_at', ascending: true);

    return response.map((json) => InventoryHistory.fromMap(json)).toList();
  }
}
