import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../models/asset_model.dart';
import '../models/user_model.dart';
import '../models/asset_category_model.dart';
import '../models/room_model.dart';
import '../services/asset_service.dart';
import '../services/category_service.dart';
import '../services/room_service.dart';
import '../services/user_service.dart';
import '../widgets/asset_card.dart';
import '../widgets/asset_detail_dialog.dart';
import '../widgets/asset_form_dialog.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/error_widget.dart';
import '../utils/extensions.dart';
import '../utils/snackbar_helper.dart';
import '../utils/performance_logger.dart';
import '../widgets/custom_filter_dropdown.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final assetService = AssetService();
  final userService = UserService();
  final categoryService = CategoryService();
  final roomService = RoomService();
  final _perf = PerformanceLogger();

  // Master list of all assets (loaded once)
  List<Asset> _allAssets = [];

  // Filtered lists for display
  List<Asset> availableAssets = [];
  List<Asset> assignedAssets = [];
  List<Asset> maintenanceAssets = [];

  Map<int, String> holderNames = {};
  Map<int, IconData> _categoryIcons = {};

  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // Search Handling
  String searchQuery = '';
  // Multi-select state
  List<int> _selectedCategoryIds = [];
  List<int> _selectedRoomIds = [];

  List<({int id, String name})> _categories = [];
  List<({int id, String name})> _rooms = [];
  Map<int, String> _roomNames = {};
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    _perf.startTimer('AssetsScreen._loadAssets');

    setState(() {
      isLoading = true;
      hasError = false;
    });

    // OPTIMIZATION: Parallel Fetch
    _perf.startTimer('AssetsScreen.parallelFetch');
    try {
      final results = await Future.wait([
        assetService.getAllAssets(), // 0
        userService.getAllUsers(), // 1
        categoryService.getAllCategories(), // 2
        roomService.getAllRooms(), // 3
      ]);
      _perf.stopTimer(
        'AssetsScreen.parallelFetch',
        details: 'All 4 calls complete',
      );

      final assets = results[0] as List<Asset>;
      final users = results[1] as List<User>;
      final categories = results[2] as List<AssetCategory>;
      final rooms = results[3] as List<Room>; // Loaded rooms

      // Prepare Lookups
      final userMap = {for (var u in users) u.id!: u.name};
      final catIcons = {
        for (var c in categories) c.id!: c.icon, // Fixed: using c.icon
      };

      // Store categories/rooms for dropdowns
      final categoryList =
          categories.map((c) => (id: c.id ?? 0, name: c.name)).toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      final roomList = rooms.map((r) => (id: r.id ?? 0, name: r.name)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      final roomNameMap = {for (var r in rooms) r.id!: r.name};

      if (mounted) {
        setState(() {
          _allAssets = assets;
          holderNames = userMap;
          _categoryIcons = catIcons;
          _categories = categoryList;
          _rooms = roomList;
          _roomNames = roomNameMap;

          _applyFilters(); // Initial distribution
          isLoading = false;
        });
      }
      _perf.stopTimer(
        'AssetsScreen._loadAssets',
        details: 'Success, total=${assets.length}',
      );
    } catch (e) {
      _perf.stopTimer('AssetsScreen._loadAssets', details: 'ERROR: $e');
      debugPrint("Error loading assets: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = e.toString();
        });
      }
    }
  }

  // Client-side filtering (Instant)
  void _applyFilters() {
    final available = <Asset>[];
    final assigned = <Asset>[];
    final maintenance = <Asset>[];

    for (var asset in _allAssets) {
      // Search Filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final matchesName = asset.name.toLowerCase().contains(query);
        final matchesSerial = (asset.identifierValue ?? '')
            .toLowerCase()
            .contains(query);

        if (!matchesName && !matchesSerial) {
          continue; // Skip this asset if it doesn't match
        }
      }

      // Category Filter (Multi-select)
      if (_selectedCategoryIds.isNotEmpty &&
          !_selectedCategoryIds.contains(asset.categoryId)) {
        continue;
      }

      // Room Filter (Multi-select)
      if (_selectedRoomIds.isNotEmpty &&
          !_selectedRoomIds.contains(asset.assignedToRoomId)) {
        continue;
      }

      // Sort into Columns
      switch (asset.status) {
        case 'available':
          available.add(asset);
          break;
        case 'assigned':
          assigned.add(asset);
          break;
        case 'maintenance':
          maintenance.add(asset);
          break;
      }
    }

    setState(() {
      availableAssets = available;
      assignedAssets = assigned;
      maintenanceAssets = maintenance;
    });
  }

  // Debounced Search Handler
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          searchQuery = query;
          _applyFilters(); // Filter locally without DB call
        });
      }
    });
  }

  Future<void> _showAddDialog() async {
    final result = await showDialog<Asset>(
      context: context,
      builder: (context) => const AssetFormDialog(),
    );

    if (result != null) {
      try {
        await assetService.createAsset(result);
        if (mounted) {
          SnackBarHelper.showSuccess(context, context.t('asset_added'));
        }
        _loadAssets(); // Reload from DB after add
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, '${context.t('error')}: $e');
        }
      }
    }
  }

  Future<void> _moveAsset(
    Asset asset,
    String newStatus, {
    bool isUndo = false,
  }) async {
    // 1. Handle "Assigned" status specifically (Requires User Selection)
    if (newStatus == 'assigned' && !isUndo) {
      final user = await _showUserSelectionDialog();
      if (user == null) return; // Cancelled by user

      // Proceed with Transfer
      await _processMove(asset, newStatus, targetUser: user);
    } else if (newStatus == 'maintenance' && !isUndo) {
      // 2. Handle "Maintenance" status (Requires Note)
      final note = await _showMaintenanceDialog();
      if (note == null) {
        return; // Cancelled by user (null means cancel, empty string is valid note)
      }

      await _processMove(asset, newStatus, maintenanceNote: note);
    } else {
      // Proceed with normal move (Available or Undo)
      await _processMove(asset, newStatus, isUndo: isUndo);
    }
  }

  Future<void> _processMove(
    Asset asset,
    String newStatus, {
    User? targetUser,
    String? maintenanceNote,
    bool isUndo = false,
  }) async {
    // 2. Optimistic UI Update
    setState(() {
      availableAssets.removeWhere((a) => a.id == asset.id);
      assignedAssets.removeWhere((a) => a.id == asset.id);
      maintenanceAssets.removeWhere((a) => a.id == asset.id);

      final updatedAsset = asset.copyWith(
        status: newStatus,
        currentHolderId: targetUser?.id, // Set if assigning
      );

      if (newStatus == 'available') {
        availableAssets.add(updatedAsset);
      }
      if (newStatus == 'assigned') {
        assignedAssets.add(updatedAsset);
      }
      if (newStatus == 'maintenance') {
        maintenanceAssets.add(updatedAsset);
      }

      _applyFilters();
    });

    // 3. API Call
    bool success = false;
    if (newStatus == 'assigned' && targetUser != null) {
      success = await assetService.transferAsset(
        assetId: asset.id!,
        toUserId: targetUser.id!,
        notes: 'Assigned via Drag & Drop',
      );
    } else if (newStatus == 'maintenance') {
      success = await assetService.updateAssetStatus(asset.id!, newStatus);
    } else {
      // Undo or simple status change
      if (newStatus == 'available' && isUndo) {
        success = await assetService.releaseAsset(
          asset.id!,
          'available',
          notes: 'Undo/Drag to Available',
        );
      } else {
        success = await assetService.updateAssetStatus(asset.id!, newStatus);
      }
    }

    // 4. Rollback if Error
    if (!success) {
      if (mounted) {
        SnackBarHelper.showError(context, context.t('error_moving_asset'));
        _loadAssets(); // Revert to server state
      }
    }
  }

  Future<User?> _showUserSelectionDialog() async {
    return await showDialog<User>(
      context: context,
      builder: (context) {
        // Simple search state for dialog
        String userSearch = '';

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(context.t('select_user')),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search User',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) {
                        setState(() {
                          userSearch = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<List<User>>(
                      future: userService
                          .getAllUsers(), // Cached service handles performance
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        final users = snapshot.data!;
                        final filtered = users
                            .where(
                              (u) => u.name.toLowerCase().contains(
                                userSearch.toLowerCase(),
                              ),
                            )
                            .toList();
                        if (filtered.isEmpty) {
                          return const Text('No users found');
                        }

                        return ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final user = filtered[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(user.name[0]),
                                ),
                                title: Text(user.name),
                                subtitle: Text(user.department ?? ''),
                                onTap: () => Navigator.pop(context, user),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.t('cancel')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _showMaintenanceDialog() async {
    final noteController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.t('confirm_maintenance')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.t('enter_maintenance_note')),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  hintText: context.t('maintenance_note_hint'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(context.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, noteController.text),
              child: Text(context.t('confirm')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Search and Add Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.t('search_assets'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 12),

                // Category Filter (Custom Widget)
                SizedBox(
                  width: 200,
                  child: CustomFilterDropdown<({int id, String name})>(
                    label: 'Categories',
                    hint: context.t('select_category'),
                    items: _categories,
                    selectedItems: _categories
                        .where((c) => _selectedCategoryIds.contains(c.id))
                        .toList(),
                    itemLabelBuilder: (item) => item.name,
                    onChanged: (selected) {
                      setState(() {
                        _selectedCategoryIds = selected
                            .map((e) => e.id)
                            .toList();
                        _applyFilters();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Room Filter (Custom Widget)
                SizedBox(
                  width: 200,
                  child: CustomFilterDropdown<({int id, String name})>(
                    label: 'Rooms',
                    hint: context.t('select_room'),
                    items: _rooms,
                    selectedItems: _rooms
                        .where((r) => _selectedRoomIds.contains(r.id))
                        .toList(),
                    itemLabelBuilder: (item) => item.name,
                    onChanged: (selected) {
                      setState(() {
                        _selectedRoomIds = selected.map((e) => e.id).toList();
                        _applyFilters();
                      });
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // Add Asset Button
                ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add),
                  label: Text(context.t('add_asset')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Kanban Board
          Expanded(
            child: isLoading
                ? _buildLoadingSkeleton()
                : hasError
                ? ErrorDisplay(message: errorMessage, onRetry: _loadAssets)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isSmallScreen = constraints.maxWidth < 900;

                      if (isSmallScreen) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildKanbanColumn(
                                context.t('available'),
                                availableAssets,
                                AppColors.available,
                                'available',
                                fullWidth: true,
                              ),
                              const SizedBox(height: 16),
                              _buildKanbanColumn(
                                context.t('assigned'),
                                assignedAssets,
                                AppColors.assigned,
                                'assigned',
                                fullWidth: true,
                              ),
                              const SizedBox(height: 16),
                              _buildKanbanColumn(
                                context.t('maintenance'),
                                maintenanceAssets,
                                AppColors.maintenance,
                                'maintenance',
                                fullWidth: true,
                              ),
                            ],
                          ),
                        );
                      } else {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildKanbanColumn(
                                context.t('available'),
                                availableAssets,
                                AppColors.available,
                                'available',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKanbanColumn(
                                context.t('assigned'),
                                assignedAssets,
                                AppColors.assigned,
                                'assigned',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKanbanColumn(
                                context.t('maintenance'),
                                maintenanceAssets,
                                AppColors.maintenance,
                                'maintenance',
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 900;

        if (isSmallScreen) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSkeletonColumn(),
                const SizedBox(height: 16),
                _buildSkeletonColumn(),
                const SizedBox(height: 16),
                _buildSkeletonColumn(),
              ],
            ),
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSkeletonColumn()),
              const SizedBox(width: 16),
              Expanded(child: _buildSkeletonColumn()),
              const SizedBox(width: 16),
              Expanded(child: _buildSkeletonColumn()),
            ],
          );
        }
      },
    );
  }

  Widget _buildSkeletonColumn() {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SkeletonLoader(
                  width: 12,
                  height: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(width: 12),
                const SkeletonLoader(width: 100, height: 16),
                const SizedBox(width: 8),
                const SkeletonLoader(width: 30, height: 20),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SkeletonLoader(
                                width: 40,
                                height: 40,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SkeletonLoader(
                                      width: double.infinity,
                                      height: 16,
                                    ),
                                    SizedBox(height: 8),
                                    SkeletonLoader(width: 100, height: 12),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetailDialog(Asset asset) async {
    await showDialog(
      context: context,
      builder: (context) => AssetDetailDialog(
        asset: asset,
        onUpdate: _loadAssets,
        onSplit: asset.quantity > 1 ? () => _showSplitAssetDialog(asset) : null,
        onMerge: () => _showMergeAssetDialog(asset),
      ),
    );
  }

  void _showMergeAssetDialog(Asset sourceAsset) {
    showDialog(
      context: context,
      builder: (context) {
        List<Asset> candidates = [];
        bool isLoadingCandidates = true;
        Asset? selectedTarget;

        return StatefulBuilder(
          builder: (context, setState) {
            // Load candidates once
            if (isLoadingCandidates) {
              assetService.getAllAssets().then((allAssets) {
                if (context.mounted) {
                  setState(() {
                    candidates = allAssets
                        .where(
                          (a) =>
                              a.id != sourceAsset.id &&
                              a.name.toLowerCase() ==
                                  sourceAsset.name.toLowerCase(),
                        )
                        .toList();
                    isLoadingCandidates = false;
                  });
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 350,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.merge_type,
                            color: Colors.teal.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Merge Asset',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${sourceAsset.name} (${sourceAsset.quantity} unit)',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Content
                    if (isLoadingCandidates)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (candidates.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'No assets with same name found.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      Text(
                        'Select target:',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: candidates.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final c = candidates[i];
                            final isSelected = selectedTarget?.id == c.id;
                            return InkWell(
                              onTap: () => setState(() => selectedTarget = c),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.teal.shade50
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.teal
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      color: isSelected
                                          ? Colors.teal
                                          : Colors.grey,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${c.name} (${c.quantity} unit)',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            'ID: ${c.id} • ${c.status}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: selectedTarget == null
                              ? null
                              : () async {
                                  final target = selectedTarget!;
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Confirm Merge'),
                                      content: Text(
                                        'Merge into "${target.name}"?\n\n'
                                        'Result: ${target.quantity + sourceAsset.quantity} units\n'
                                        'Source will be deleted.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Confirm'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true && context.mounted) {
                                    Navigator.pop(context);
                                    try {
                                      await assetService.mergeAssets(
                                        sourceAsset,
                                        target,
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          this.context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Assets merged!'),
                                          ),
                                        );
                                      }
                                      _loadAssets();
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          this.context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                          child: const Text('Merge'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSplitAssetDialog(Asset asset) {
    // ... existing _showSplitAssetDialog implementation ...
    showDialog(
      context: context,
      builder: (context) {
        int splitQuantity = 1;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Split ${asset.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current quantity: ${asset.quantity}. How many new assets do you want to create?',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity for new asset(s)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        splitQuantity = int.tryParse(value) ?? 1;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      splitQuantity <= 0 || splitQuantity >= asset.quantity
                      ? null
                      : () async {
                          Navigator.pop(context);
                          try {
                            await assetService.splitAsset(asset, splitQuantity);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Asset split successfully'),
                              ),
                            );
                            _loadAssets();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error splitting asset: $e'),
                              ),
                            );
                          }
                        },
                  child: const Text('Split'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildKanbanColumn(
    String title,
    List<Asset> assets,
    Color color,
    String status, {
    bool fullWidth = false,
  }) {
    return Container(
      margin: fullWidth
          ? EdgeInsets.zero
          : const EdgeInsets.only(top: 16, bottom: 16, right: 16),
      decoration: fullWidth
          ? null
          : BoxDecoration(
              color: Colors.grey.shade50, // Lighter background
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${assets.length}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          // Drop Target
          if (fullWidth)
            _buildDragTarget(assets, color, status, fullWidth)
          else
            Expanded(child: _buildDragTarget(assets, color, status, fullWidth)),
        ],
      ),
    );
  }

  Widget _buildDragTarget(
    List<Asset> assets,
    Color color,
    String status,
    bool fullWidth,
  ) {
    return DragTarget<Asset>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) {
        _moveAsset(details.data, status);
      },
      builder: (context, candidateData, rejectedData) {
        final isDraggingOver = candidateData.isNotEmpty;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDraggingOver
                ? color.withValues(alpha: 0.1)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDraggingOver ? color : Colors.grey.shade200,
              width: isDraggingOver ? 2 : 1,
            ),
          ),
          child: assets.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.t('no_assets'),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        if (isDraggingOver) ...[
                          const SizedBox(height: 8),
                          Text(
                            context.loc.locale.languageCode == 'id'
                                ? 'Letakkan di sini'
                                : 'Drop here',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: fullWidth,
                  physics: fullWidth
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  itemCount: assets.length,
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    return _buildDraggableAssetCard(asset);
                  },
                ),
        );
      },
    );
  }

  Widget _buildDraggableAssetCard(Asset asset) {
    final categoryIcon = asset.categoryId != null
        ? _categoryIcons[asset.categoryId]
        : null;
    final roomName = asset.assignedToRoomId != null
        ? _roomNames[asset.assignedToRoomId]
        : null;

    return LongPressDraggable<Asset>(
      delay: const Duration(milliseconds: 150), // Faster drag
      data: asset,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 280,
          child: Opacity(
            opacity: 0.8,
            child: AssetCard(
              asset: asset,
              holderName: asset.currentHolderId != null
                  ? holderNames[asset.currentHolderId]
                  : null,
              roomName: roomName,
              categoryIcon: categoryIcon,
              onTap: () {},
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: AssetCard(
          asset: asset,
          holderName: asset.currentHolderId != null
              ? holderNames[asset.currentHolderId]
              : null,
          roomName: roomName,
          categoryIcon: categoryIcon,
          onTap: () {},
        ),
      ),
      child: AssetCard(
        asset: asset,
        holderName: asset.currentHolderId != null
            ? holderNames[asset.currentHolderId]
            : null,
        roomName: roomName,
        categoryIcon: categoryIcon,
        onTap: () => _showDetailDialog(asset),
      ),
    );
  }
}
