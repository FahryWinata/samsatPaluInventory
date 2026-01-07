import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  String _inventoryFilter = 'all';

  int get currentIndex => _currentIndex;
  String get inventoryFilter => _inventoryFilter;

  // Called when clicking the Sidebar
  void setIndex(int index) {
    _currentIndex = index;
    // Reset filters if navigating via sidebar to avoid confusion
    if (index == 1) _inventoryFilter = 'all';
    notifyListeners();
  }

  // Called from Dashboard to jump to Inventory with a filter
  void navigateToInventory({String filter = 'all'}) {
    _currentIndex = 1; // 1 is the Inventory Tab index
    _inventoryFilter = filter;
    notifyListeners();
  }

  // Called from Dashboard to jump to Assets
  void navigateToAssets() {
    _currentIndex = 2; // 2 is the Assets Tab index
    notifyListeners();
  }

  // Called from Dashboard to jump to Users
  void navigateToUsers() {
    _currentIndex = 4; // 4 is the Users Tab index
    notifyListeners();
  }
}
