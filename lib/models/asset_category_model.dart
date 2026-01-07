class AssetCategory {
  final int? id;
  final String name;
  final String
  identifierType; // 'serial_number', 'vehicle_id', 'room_tag', 'none'
  final bool requiresPerson;
  final bool requiresRoom;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AssetCategory({
    this.id,
    required this.name,
    this.identifierType = 'none',
    this.requiresPerson = true,
    this.requiresRoom = false,
    this.createdAt,
    this.updatedAt,
  });

  factory AssetCategory.fromMap(Map<String, dynamic> map) {
    return AssetCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      identifierType: map['identifier_type'] as String? ?? 'none',
      requiresPerson: map['requires_person'] as bool? ?? true,
      requiresRoom: map['requires_room'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'identifier_type': identifierType,
      'requires_person': requiresPerson,
      'requires_room': requiresRoom,
    };
  }

  AssetCategory copyWith({
    int? id,
    String? name,
    String? identifierType,
    bool? requiresPerson,
    bool? requiresRoom,
  }) {
    return AssetCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      identifierType: identifierType ?? this.identifierType,
      requiresPerson: requiresPerson ?? this.requiresPerson,
      requiresRoom: requiresRoom ?? this.requiresRoom,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Get localized label for identifier type
  String get identifierLabel {
    switch (identifierType) {
      case 'serial_number':
        return 'Serial Number';
      case 'vehicle_id':
        return 'Nomor Kendaraan';
      case 'room_tag':
        return 'Kode Ruangan';
      default:
        return 'Identifier';
    }
  }

  /// Check if this category requires an identifier
  bool get requiresIdentifier => identifierType != 'none';
}
