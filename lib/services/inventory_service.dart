import 'package:flutter/foundation.dart';
import '../models/inventory_model.dart';
import '../models/inventory_history_model.dart';
import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'activity_service.dart';

class InventoryService {
  final activityService = ActivityService();
  SupabaseClient get supabase => SupabaseService.client;

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

  Future<List<InventoryItem>> getAllItems() async {
    final List<dynamic> response = await supabase
        .from('inventory')
        .select()
        .order('name');
    return response.map((json) => InventoryItem.fromMap(json)).toList();
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
