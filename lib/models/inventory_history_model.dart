class InventoryHistory {
  final int? id;
  final int inventoryId;
  final String actionType; // 'in' or 'out'
  final int quantityChange;
  final int previousQuantity;
  final int newQuantity;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;

  // Optional: associated item details for reporting (joined)
  final String? itemName;

  InventoryHistory({
    this.id,
    required this.inventoryId,
    required this.actionType,
    required this.quantityChange,
    required this.previousQuantity,
    required this.newQuantity,
    this.notes,
    this.createdBy,
    required this.createdAt,
    this.itemName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inventory_id': inventoryId,
      'action_type': actionType,
      'quantity_change': quantityChange,
      'previous_quantity': previousQuantity,
      'new_quantity': newQuantity,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory InventoryHistory.fromMap(Map<String, dynamic> map) {
    return InventoryHistory(
      id: map['id'],
      inventoryId: map['inventory_id'],
      actionType: map['action_type'],
      quantityChange: map['quantity_change'],
      previousQuantity: map['previous_quantity'],
      newQuantity: map['new_quantity'],
      notes: map['notes'],
      createdBy: map['created_by'],
      createdAt: DateTime.parse(map['created_at']),
      // Handle joined data if present (depends on query)
      itemName: map['inventory'] != null ? map['inventory']['name'] : null,
    );
  }
}
