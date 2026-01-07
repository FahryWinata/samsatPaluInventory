class Asset {
  final int? id;
  final String name;
  final String? identifierValue; // Was serialNumber, now optional
  final String? description;
  final DateTime? purchaseDate;
  final String status;
  final int? currentHolderId;
  final int? categoryId;
  final int? assignedToRoomId;
  final String? imagePath;
  final String? maintenanceLocation;
  // Maintenance reminder fields
  final bool requiresMaintenance;
  final int? maintenanceIntervalDays;
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Asset({
    this.id,
    required this.name,
    this.identifierValue,
    this.description,
    this.purchaseDate,
    this.status = 'available',
    this.currentHolderId,
    this.categoryId,
    this.assignedToRoomId,
    this.imagePath,
    this.maintenanceLocation,
    this.requiresMaintenance = false,
    this.maintenanceIntervalDays,
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Asset copyWith({
    int? id,
    String? name,
    String? identifierValue,
    String? description,
    DateTime? purchaseDate,
    String? status,
    int? currentHolderId,
    int? categoryId,
    int? assignedToRoomId,
    String? imagePath,
    String? maintenanceLocation,
    bool? requiresMaintenance,
    int? maintenanceIntervalDays,
    DateTime? lastMaintenanceDate,
    DateTime? nextMaintenanceDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Asset(
      id: id ?? this.id,
      name: name ?? this.name,
      identifierValue: identifierValue ?? this.identifierValue,
      description: description ?? this.description,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      status: status ?? this.status,
      currentHolderId: currentHolderId ?? this.currentHolderId,
      categoryId: categoryId ?? this.categoryId,
      assignedToRoomId: assignedToRoomId ?? this.assignedToRoomId,
      imagePath: imagePath ?? this.imagePath,
      maintenanceLocation: maintenanceLocation ?? this.maintenanceLocation,
      requiresMaintenance: requiresMaintenance ?? this.requiresMaintenance,
      maintenanceIntervalDays:
          maintenanceIntervalDays ?? this.maintenanceIntervalDays,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      nextMaintenanceDate: nextMaintenanceDate ?? this.nextMaintenanceDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'identifier_value': identifierValue,
      'description': description,
      'purchase_date': purchaseDate?.toIso8601String(),
      'status': status,
      'current_holder_id': currentHolderId,
      'category_id': categoryId,
      'assigned_to_room_id': assignedToRoomId,
      'image_path': imagePath,
      'maintenance_location': maintenanceLocation,
      'requires_maintenance': requiresMaintenance,
      'maintenance_interval_days': maintenanceIntervalDays,
      'last_maintenance_date': lastMaintenanceDate?.toIso8601String(),
      'next_maintenance_date': nextMaintenanceDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'],
      name: map['name'],
      identifierValue:
          map['identifier_value'] ?? map['serial_number'], // Backward compat
      description: map['description'],
      purchaseDate: map['purchase_date'] != null
          ? DateTime.parse(map['purchase_date'])
          : null,
      status: map['status'],
      currentHolderId: map['current_holder_id'],
      categoryId: map['category_id'],
      assignedToRoomId: map['assigned_to_room_id'],
      imagePath: map['image_path'],
      maintenanceLocation: map['maintenance_location'],
      requiresMaintenance: map['requires_maintenance'] ?? false,
      maintenanceIntervalDays: map['maintenance_interval_days'],
      lastMaintenanceDate: map['last_maintenance_date'] != null
          ? DateTime.parse(map['last_maintenance_date'])
          : null,
      nextMaintenanceDate: map['next_maintenance_date'] != null
          ? DateTime.parse(map['next_maintenance_date'])
          : null,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  /// Helper to check if maintenance is overdue
  bool get isMaintenanceOverdue {
    if (!requiresMaintenance || nextMaintenanceDate == null) return false;
    return nextMaintenanceDate!.isBefore(DateTime.now());
  }

  /// Helper to get days until next maintenance (negative if overdue)
  int? get daysUntilMaintenance {
    if (!requiresMaintenance || nextMaintenanceDate == null) return null;
    return nextMaintenanceDate!.difference(DateTime.now()).inDays;
  }
}
