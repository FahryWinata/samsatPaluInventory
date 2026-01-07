import 'dart:math';
import 'package:flutter/material.dart';
import '../models/inventory_model.dart';
import '../models/asset_model.dart';
import '../services/inventory_service.dart';
import '../services/asset_service.dart';
import '../utils/snackbar_helper.dart';

class DataSeeder {
  static final _random = Random();
  static final _inventoryService = InventoryService();
  static final _assetService = AssetService();

  static const _itemNames = [
    'Laptop',
    'Mouse',
    'Keyboard',
    'Monitor',
    'Printer',
    'Scanner',
    'Projector',
    'Desk',
    'Chair',
    'Cabinet',
    'Whiteboard',
    'Marker',
    'Paper',
    'Stapler',
    'Pen',
    'Notebook',
    'Tablet',
    'Phone',
    'Router',
    'Switch',
    'Cable',
    'Adapter',
    'Headset',
    'Microphone',
    'Speaker',
    'Camera',
    'Tripod',
    'Server',
    'Hard Drive',
    'SSD',
    'RAM',
    'GPU',
    'CPU',
    'Fan',
    'Case',
    'Power Supply',
    'Battery',
    'Charger',
    'Dock',
    'Hub',
  ];

  static const _units = ['pcs', 'box', 'unit', 'set', 'pack', 'roll'];

  static Future<void> seedData(BuildContext context) async {
    try {
      // Seed Inventory Items
      for (int i = 0; i < 50; i++) {
        final name =
            '${_itemNames[_random.nextInt(_itemNames.length)]} ${_random.nextInt(1000)}';
        final quantity = _random.nextInt(100) + 1;
        final minStock = _random.nextInt(20) + 1;

        final item = InventoryItem(
          name: name,
          description: 'Auto-generated test item #$i',
          quantity: quantity,
          unit: _units[_random.nextInt(_units.length)],
          minimumStock: minStock,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        try {
          await _inventoryService.createItem(item);
        } catch (e) {
          debugPrint('Skipping duplicate item: $name');
        }
      }

      // Seed Assets
      for (int i = 0; i < 50; i++) {
        final name =
            '${_itemNames[_random.nextInt(_itemNames.length)]} Pro ${_random.nextInt(1000)}';
        final serial =
            'SN-${_random.nextInt(1000000)}-${_random.nextInt(1000)}';

        final asset = Asset(
          name: name,
          identifierValue: serial,
          description: 'Auto-generated test asset #$i',
          purchaseDate: DateTime.now().subtract(
            Duration(days: _random.nextInt(365 * 2)),
          ),
          status: 'available',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        try {
          await _assetService.createAsset(asset);
        } catch (e) {
          debugPrint('Skipping duplicate asset: $name');
        }
      }

      if (context.mounted) {
        SnackBarHelper.showSuccess(
          context,
          'Successfully added 100 test items/assets!',
        );
      }
    } catch (e) {
      debugPrint('Error seeding data: $e');
      if (context.mounted) {
        SnackBarHelper.showError(context, 'Error seeding data: $e');
      }
    }
  }
}
