import 'package:flutter/material.dart';

class AssetCategory {
  final int? id;
  final String name;
  final String
  identifierType; // 'serial_number', 'vehicle_id', 'room_tag', 'none'
  final bool requiresPerson;
  final bool requiresRoom;
  final String iconName; // Material icon name
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AssetCategory({
    this.id,
    required this.name,
    this.identifierType = 'none',
    this.requiresPerson = true,
    this.requiresRoom = false,
    this.iconName = 'inventory_2',
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
      iconName: map['icon_name'] as String? ?? 'inventory_2',
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
      'icon_name': iconName,
    };
  }

  AssetCategory copyWith({
    int? id,
    String? name,
    String? identifierType,
    bool? requiresPerson,
    bool? requiresRoom,
    String? iconName,
  }) {
    return AssetCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      identifierType: identifierType ?? this.identifierType,
      requiresPerson: requiresPerson ?? this.requiresPerson,
      requiresRoom: requiresRoom ?? this.requiresRoom,
      iconName: iconName ?? this.iconName,
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

  /// Get the Material icon for this category
  IconData get icon => iconMap[iconName] ?? Icons.inventory_2;

  /// Available icons for category selection
  static const Map<String, IconData> iconMap = {
    'inventory_2': Icons.inventory_2,
    'computer': Icons.computer,
    'laptop_mac': Icons.laptop_mac,
    'directions_car': Icons.directions_car,
    'two_wheeler': Icons.two_wheeler,
    'ac_unit': Icons.ac_unit,
    'local_fire_department': Icons.local_fire_department,
    'chair': Icons.chair,
    'desk': Icons.desk,
    'print': Icons.print,
    'router': Icons.router,
    'phone_android': Icons.phone_android,
    'tv': Icons.tv,
    'kitchen': Icons.kitchen,
    'build': Icons.build,
  };

  /// Get display names for icons
  static const Map<String, String> iconDisplayNames = {
    'inventory_2': 'Inventaris',
    'computer': 'Komputer',
    'laptop_mac': 'Laptop',
    'directions_car': 'Mobil',
    'two_wheeler': 'Motor',
    'ac_unit': 'AC',
    'local_fire_department': 'APAR',
    'chair': 'Kursi',
    'desk': 'Meja',
    'print': 'Printer',
    'router': 'Router',
    'phone_android': 'Handphone',
    'tv': 'TV/Monitor',
    'kitchen': 'Dapur',
    'build': 'Peralatan',
  };
}
