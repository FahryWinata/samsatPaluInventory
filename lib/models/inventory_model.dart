class InventoryItem {
  final int? id;
  final String name;
  final String? description;
  final int quantity;
  final String? unit;
  final int minimumStock;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  InventoryItem({
    this.id,
    required this.name,
    this.description,
    required this.quantity,
    this.unit,
    this.minimumStock = 0,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => quantity <= minimumStock;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'minimum_stock': minimumStock,
      'image_path': imagePath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    // Only include 'id' if it's not null (for updates, not inserts)
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      quantity: map['quantity'],
      unit: map['unit'],
      minimumStock: map['minimum_stock'] ?? 0,
      imagePath: map['image_path'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}
