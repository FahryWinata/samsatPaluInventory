import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../models/inventory_model.dart';
import '../services/inventory_service.dart';
import '../widgets/inventory_form_dialog.dart';
import '../widgets/quantity_dialog.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/error_widget.dart';
import '../utils/extensions.dart';
import '../utils/snackbar_helper.dart';

class InventoryScreen extends StatefulWidget {
  final String initialFilter;

  const InventoryScreen({super.key, this.initialFilter = 'all'});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final inventoryService = InventoryService();
  final TextEditingController _searchController = TextEditingController();

  List<InventoryItem> items = [];
  List<InventoryItem> filteredItems = [];
  bool isLoading = true;
  String searchQuery = '';

  late String filterStatus;

  // Stats
  int totalItems = 0;
  int goodStockCount = 0;
  int lowStockCount = 0;
  int outOfStockCount = 0;

  // Pagination Configuration
  int _currentPage = 1;
  final int _itemsPerPage = 8;

  bool hasError = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    filterStatus = widget.initialFilter;
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final loadedItems = await inventoryService.getAllItems();

      // Calculate Stats
      int good = 0;
      int low = 0;
      int out = 0;

      for (var item in loadedItems) {
        if (item.quantity == 0) {
          out++;
        } else if (item.quantity <= item.minimumStock) {
          low++;
        } else {
          good++;
        }
      }

      setState(() {
        items = loadedItems;
        totalItems = items.length;
        goodStockCount = good;
        lowStockCount = low;
        outOfStockCount = out;

        _applyFilters();
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = context.t('failed_load_inventory');
        });
      }
    }
  }

  void _applyFilters() {
    _currentPage = 1;

    filteredItems = items.where((item) {
      final matchesSearch =
          searchQuery.isEmpty ||
          item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (item.description?.toLowerCase().contains(
                searchQuery.toLowerCase(),
              ) ??
              false);

      bool matchesStatus = true;
      if (filterStatus == 'good') {
        matchesStatus = item.quantity > item.minimumStock;
      } else if (filterStatus == 'low') {
        matchesStatus = item.quantity > 0 && item.quantity <= item.minimumStock;
      } else if (filterStatus == 'out') {
        matchesStatus = item.quantity == 0;
      }

      return matchesSearch && matchesStatus;
    }).toList();
  }

  void _onFilterTap(String status) {
    setState(() {
      filterStatus = status;
      _applyFilters();
    });
  }

  // --- CRUD Actions ---
  Future<void> _showAddDialog() async {
    final result = await showDialog<InventoryItem>(
      context: context,
      builder: (context) => const InventoryFormDialog(),
    );
    if (result != null) {
      try {
        await inventoryService.createItem(result);
        _loadItems();
        if (mounted) {
          SnackBarHelper.showSuccess(context, context.t('item_added'));
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            e.toString().replaceAll("Exception: ", ""),
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
        _loadItems();
        // ADDED: Confirmation for Edit
        if (mounted) {
          SnackBarHelper.showSuccess(context, context.t('item_updated'));
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            e.toString().replaceAll("Exception: ", ""),
          );
        }
      }
    }
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('delete')),
        content: Text('${context.t('confirm')} delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t('delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await inventoryService.deleteItem(item.id!);
        _loadItems();
        if (mounted) {
          SnackBarHelper.showSuccess(context, context.t('item_deleted'));
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            "${context.t('failed_delete_item')}: $e",
          );
        }
      }
    }
  }

  Future<void> _adjustQuantity(InventoryItem item, bool isIncrease) async {
    final result = await showDialog<QuantityResult>(
      context: context,
      builder: (context) => QuantityDialog(
        itemName: item.name,
        currentQuantity: item.quantity,
        isIncrease: isIncrease,
      ),
    );

    if (result != null) {
      try {
        if (isIncrease) {
          await inventoryService.increaseQuantity(
            item.id!,
            result.amount,
            notes: result.notes,
          );
          if (mounted) {
            SnackBarHelper.showSuccess(
              context,
              context.t('stock_increased_success'),
            );
          }
        } else {
          await inventoryService.decreaseQuantity(
            item.id!,
            result.amount,
            notes: result.notes,
          );
          if (mounted) {
            SnackBarHelper.showSuccess(
              context,
              context.t('stock_decreased_success'),
            );
          }
        }
        _loadItems();
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            "Error: ${e.toString().replaceAll("Exception: ", "")}",
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: isLoading
          ? _buildLoadingSkeleton(isDesktop)
          : hasError
          ? ErrorDisplay(message: errorMessage, onRetry: _loadItems)
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header
                  Text(
                    context.t('overall_inventory'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Summary Cards
                  _buildSummaryStats(isDesktop),
                  const SizedBox(height: 24),

                  // 3. Products Table Card
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Toolbar
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: isDesktop
                                ? Row(
                                    children: [
                                      Text(
                                        context.t('products_header'),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      _buildActionsToolbar(),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        context.t('products_header'),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildActionsToolbar(),
                                    ],
                                  ),
                          ),
                          const Divider(height: 1),

                          // Table Content
                          Expanded(
                            child: _getCurrentPageItems().isEmpty
                                ? _buildEmptyState()
                                : isDesktop
                                ? _buildDesktopTable()
                                : _buildMobileList(),
                          ),

                          // Pagination
                          _buildPaginationControls(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --- Widgets: Summary Stats ---
  Widget _buildSummaryStats(bool isDesktop) {
    List<Widget> cards = [
      _buildStatCard(
        context.t('total_products'),
        totalItems.toString(),
        Colors.blue,
        'all',
      ),
      _buildStatCard(
        context.t('good_stock'),
        goodStockCount.toString(),
        Colors.green,
        'good',
      ),
      _buildStatCard(
        context.t('low_stock'),
        lowStockCount.toString(),
        Colors.amber,
        'low',
      ),
      _buildStatCard(
        context.t('out_of_stock'),
        outOfStockCount.toString(),
        Colors.red,
        'out',
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards
            .map(
              (c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: c,
                ),
              ),
            )
            .toList(),
      );
    } else {
      // Mobile: 2x2 Grid
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 12),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    String filterKey,
  ) {
    final bool isSelected = filterStatus == filterKey;

    return InkWell(
      onTap: () => _onFilterTap(filterKey),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionsToolbar() {
    return Row(
      children: [
        SizedBox(
          width: 250,
          height: 40,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.t('search_items'),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          searchQuery = '';
                          _applyFilters();
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            onChanged: (val) {
              setState(() {
                searchQuery = val;
                _applyFilters();
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _showAddDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: Text(context.t('add_product')),
        ),
      ],
    );
  }

  Widget _buildPaginationControls() {
    final int totalPages = (filteredItems.isEmpty)
        ? 1
        : (filteredItems.length / _itemsPerPage).ceil();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _currentPage > 1
                ? () => setState(() => _currentPage--)
                : null,
            child: Text(context.t('previous')),
          ),
          const SizedBox(width: 16),
          Text(
            "${context.t('page')} $_currentPage ${context.t('of')} $totalPages",
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: _currentPage < totalPages
                ? () => setState(() => _currentPage++)
                : null,
            child: Text(context.t('next')),
          ),
        ],
      ),
    );
  }

  List<InventoryItem> _getCurrentPageItems() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= filteredItems.length) return [];

    final endIndex = (startIndex + _itemsPerPage < filteredItems.length)
        ? startIndex + _itemsPerPage
        : filteredItems.length;

    return filteredItems.sublist(startIndex, endIndex);
  }

  Widget _buildDesktopTable() {
    final displayItems = _getCurrentPageItems();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Colors.grey[50],
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  context.t('product_name_header'),
                  style: _headerStyle(),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(context.t('unit_header'), style: _headerStyle()),
              ),
              Expanded(
                flex: 1,
                child: Text(context.t('qty_header'), style: _headerStyle()),
              ),
              Expanded(
                flex: 1,
                child: Text(context.t('min_header'), style: _headerStyle()),
              ),
              Expanded(
                flex: 2,
                child: Text(context.t('status_header'), style: _headerStyle()),
              ),
              const SizedBox(width: 180),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: ListView.separated(
            itemCount: displayItems.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = displayItems[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        item.unit ?? '-',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        item.quantity.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        item.minimumStock.toString(),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(flex: 2, child: _buildStatusBadge(item)),
                    SizedBox(
                      width: 180,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildActionButton(
                            Icons.remove_circle_outline,
                            Colors.orange,
                            context.t('decrease'),
                            () => _adjustQuantity(item, false),
                          ),
                          _buildActionButton(
                            Icons.add_circle_outline,
                            Colors.green,
                            context.t('increase'),
                            () => _adjustQuantity(item, true),
                          ),
                          _buildActionButton(
                            Icons.edit,
                            Colors.blue,
                            context.t('edit'),
                            () => _showEditDialog(item),
                          ),
                          _buildActionButton(
                            Icons.delete,
                            Colors.red,
                            context.t('delete'),
                            () => _deleteItem(item),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      tooltip: tooltip,
      splashRadius: 20,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: onPressed,
    );
  }

  TextStyle _headerStyle() => TextStyle(
    color: Colors.grey[600],
    fontWeight: FontWeight.bold,
    fontSize: 12,
  );

  Widget _buildMobileList() {
    final displayItems = _getCurrentPageItems();

    return ListView.separated(
      itemCount: displayItems.length,
      separatorBuilder: (ctx, i) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = displayItems[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          title: Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            "Qty: ${item.quantity} ${item.unit ?? ''} | Min: ${item.minimumStock}",
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusBadge(item, compact: true),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') _showEditDialog(item);
                  if (value == 'delete') _deleteItem(item);
                  if (value == 'add') _adjustQuantity(item, true);
                  if (value == 'remove') _adjustQuantity(item, false);
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'add',
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(context.t('add_stock')),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'remove',
                    child: Row(
                      children: [
                        const Icon(Icons.remove_circle, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(context.t('reduce_stock')),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(context.t('edit')),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(context.t('delete')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(InventoryItem item, {bool compact = false}) {
    Color color;
    String text;

    if (item.quantity == 0) {
      color = Colors.red;
      text = compact ? context.t('out') : context.t('out_of_stock');
    } else if (item.quantity <= item.minimumStock) {
      color = Colors.amber;
      text = compact ? context.t('low') : context.t('low_stock');
    } else {
      color = Colors.green;
      text = compact ? context.t('ok') : context.t('in_stock');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            filterStatus == 'all'
                ? context.t('no_products_found')
                : context.t('no_items_match_filter'),
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoader(width: 150, height: 24),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: SkeletonLoader(width: 80, height: 20),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonLoader(width: 100, height: 20),
                      SkeletonLoader(width: 200, height: 30),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: 8,
                      itemBuilder: (c, i) => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: SkeletonLoader(
                          width: double.infinity,
                          height: 40,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
