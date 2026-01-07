class Room {
  final int? id;
  final String name;
  final String? building;
  final String? floor;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Room({
    this.id,
    required this.name,
    this.building,
    this.floor,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'] as int?,
      name: map['name'] as String,
      building: map['building'] as String?,
      floor: map['floor'] as String?,
      description: map['description'] as String?,
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
      'building': building,
      'floor': floor,
      'description': description,
    };
  }

  Room copyWith({
    int? id,
    String? name,
    String? building,
    String? floor,
    String? description,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Display name with building/floor if available
  String get displayName {
    final parts = <String>[name];
    if (building != null && building!.isNotEmpty) {
      parts.add(building!);
    }
    if (floor != null && floor!.isNotEmpty) {
      parts.add('Lt. $floor');
    }
    return parts.join(' - ');
  }
}
