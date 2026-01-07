import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../models/inventory_model.dart';
import '../../widgets/inventory_form_dialog.dart';

class MobileInventoryScreen extends StatefulWidget {
  const MobileInventoryScreen({super.key});

  @override
  State<MobileInventoryScreen> createState() => _MobileInventoryScreenState();
}

class _MobileInventoryScreenState extends State<MobileInventoryScreen> {
  final inventoryService = InventoryService();
  final TextEditingController _searchController = TextEditingController();

  List<InventoryItem> _allItems = [];
  List<InventoryItem> _filteredItems = [];
  bool _isLoading = true;
  String _selectedFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await inventoryService.getAllItems();
      if (mounted) {
        setState(() {
          _allItems = items;
          _filterItems();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading inventory: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _allItems.where((item) {
        final matchesQuery =
            item.name.toLowerCase().contains(query) ||
            (item.description?.toLowerCase().contains(query) ?? false);
        if (!matchesQuery) return false;

        switch (_selectedFilter) {
          case 'Aman':
            return item.quantity > item.minimumStock;
          case 'Rendah':
            return item.quantity <= item.minimumStock && item.quantity > 0;
          case 'Habis':
            return item.quantity == 0;
          default:
            return true;
        }
      }).toList();
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _filterItems();
  }

  Future<void> _showAddDialog() async {
    final result = await showDialog<InventoryItem>(
      context: context,
      builder: (context) => const InventoryFormDialog(),
    );

    if (result != null) {
      try {
        await inventoryService.createItem(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item berhasil ditambahkan'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showEditDialog(InventoryItem item) async {
    final result = await showDialog<InventoryItem>(
      context: context,
      builder: (context) => InventoryFormDialog(item: item),
    );

    if (result != null) {
      try {
        await inventoryService.updateItem(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  int get _totalCount => _allItems.length;
  int get _safeStockCount =>
      _allItems.where((i) => i.quantity > i.minimumStock).length;
  int get _lowStockCount => _allItems
      .where((i) => i.quantity <= i.minimumStock && i.quantity > 0)
      .length;
  int get _outOfStockCount => _allItems.where((i) => i.quantity == 0).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        title: const Text(
          'Inventaris',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari berdasarkan nama atau SKU',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('Semua'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Aman'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Rendah'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Habis'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Total',
                              _totalCount.toString(),
                              Colors.black,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Stok Aman',
                              _safeStockCount.toString(),
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Stok Rendah',
                              _lowStockCount.toString(),
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Stok Habis',
                              _outOfStockCount.toString(),
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      return _buildInventoryItem(_filteredItems[index]);
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF1976D2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => _onFilterChanged(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1976D2) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryItem(InventoryItem item) {
    Color statusColor;
    String statusText;

    if (item.quantity == 0) {
      statusColor = Colors.red;
      statusText = 'Habis';
    } else if (item.quantity <= item.minimumStock) {
      statusColor = Colors.orange;
      statusText = 'Rendah';
    } else {
      statusColor = Colors.green;
      statusText = 'Aman';
    }

    return GestureDetector(
      onTap: () => _showEditDialog(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                image: item.imagePath != null
                    ? DecorationImage(
                        image: item.imagePath!.startsWith('http')
                            ? NetworkImage(item.imagePath!)
                            : FileImage(File(item.imagePath!)) as ImageProvider,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: item.imagePath == null
                  ? const Icon(Icons.image, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'SKU: INV-${item.id}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.quantity} ${item.unit ?? 'tersedia'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
