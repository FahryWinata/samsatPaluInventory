import 'package:flutter/foundation.dart';
import 'models/asset_model.dart';
import 'models/inventory_model.dart';
import 'models/user_model.dart';

import 'services/asset_service.dart';
import 'services/inventory_service.dart';
import 'services/user_service.dart';

class TestServices {
  final AssetService assetService = AssetService();
  final InventoryService inventoryService = InventoryService();
  final UserService userService = UserService();

  Future<void> runTests() async {
    if (kDebugMode) {
      debugPrint('Starting System Tests...');
    }

    try {
      // 1. Test Users
      debugPrint('--- Testing Users ---');
      final userId = await userService.createUser(
        User(
          name: 'Test User',
          email: 'test@example.com',
          department: 'IT',
          createdAt: DateTime.now(),
        ),
      );
      debugPrint('User created with ID: $userId');

      // 2. Test Inventory
      debugPrint('--- Testing Inventory ---');
      final itemId = await inventoryService.createItem(
        InventoryItem(
          name: 'Test Item',
          quantity: 10,
          unit: 'pcs',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      debugPrint('Inventory Item created with ID: $itemId');

      // 3. Test Assets
      debugPrint('--- Testing Assets ---');
      final assetId = await assetService.createAsset(
        Asset(
          name: 'Test Laptop',
          identifierValue: 'SN-${DateTime.now().millisecondsSinceEpoch}',
          status: 'available',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      debugPrint('Asset created with ID: $assetId');

      // 4. Test Asset Transfer
      debugPrint('--- Testing Transfer ---');
      final success = await assetService.transferAsset(
        assetId: assetId,
        toUserId: userId,
        notes: 'Test Transfer',
      );
      debugPrint('Asset transfer successful: $success');

      // 5. Test History (Using the new method signature)
      debugPrint('--- Testing History ---');
      final history = await assetService.getTransferHistory(assetId);
      debugPrint('Transfer history records: ${history.length}');

      for (var record in history) {
        debugPrint(
          ' - Transferred to User ID: ${record.toUserId} on ${record.transferDate}',
        );
      }

      debugPrint('All Tests Passed!');
    } catch (e) {
      debugPrint('Test Failed: $e');
    }
  }
}
