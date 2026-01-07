import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../models/asset_model.dart';
import '../models/user_model.dart';
import '../services/asset_service.dart';
import '../services/user_service.dart';
import '../widgets/asset_card.dart';
import '../widgets/asset_detail_dialog.dart';
import '../widgets/asset_form_dialog.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/error_widget.dart';
import '../utils/extensions.dart';
import '../utils/snackbar_helper.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final assetService = AssetService();
  final userService = UserService();

  // Master list of all assets (loaded once)
  List<Asset> _allAssets = [];

  // Filtered lists for display
  List<Asset> availableAssets = [];
  List<Asset> assignedAssets = [];
  List<Asset> maintenanceAssets = [];

  Map<int, String> holderNames = {};

  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // Search Handling
  String searchQuery = '';
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
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      // 1. Fetch all data once
      final allAssets = await assetService.getAllAssets();
      final users = await userService.getAllUsers();

      // 2. Create holder names map
      final namesMap = <int, String>{};
      for (var user in users) {
        namesMap[user.id!] = user.name;
      }

      if (mounted) {
        setState(() {
          _allAssets = allAssets; // Store master list
          holderNames = namesMap;
          _applyFilters(); // Filter locally
          isLoading = false;
          hasError = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading assets: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = context.t('failed_load_assets');
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

  Future<void> _showDetailDialog(Asset asset) async {
    await showDialog(
      context: context,
      builder: (context) =>
          AssetDetailDialog(asset: asset, onUpdate: _loadAssets),
    );
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
    // final oldStatus = asset.status; // Unused
    // final oldHolderId = asset.currentHolderId; // Unused

    // 2. Optimistic UI Update
    setState(() {
      availableAssets.removeWhere((a) => a.id == asset.id);
      assignedAssets.removeWhere((a) => a.id == asset.id);
      maintenanceAssets.removeWhere((a) => a.id == asset.id);

      final updatedAsset = asset.copyWith(
        status: newStatus,
        currentHolderId: targetUser?.id, // Set if assigning
      );

      if (newStatus == 'available') availableAssets.add(updatedAsset);
      if (newStatus == 'assigned') assignedAssets.add(updatedAsset);
      if (newStatus == 'maintenance') maintenanceAssets.add(updatedAsset);

      // Update master list
      final index = _allAssets.indexWhere((a) => a.id == asset.id);
      if (index != -1) {
        _allAssets[index] = updatedAsset;
      }
    });

    try {
      // 3. Perform Database Update
      bool success = false;
      if (newStatus == 'assigned' && targetUser != null) {
        success = await assetService.transferAsset(
          assetId: asset.id!,
          toUserId: targetUser.id!,
        );
      } else {
        // Release (Available/Maintenance)
        success = await assetService.releaseAsset(
          asset.id!,
          newStatus,
          notes: maintenanceNote,
        );
      }

      if (!success) throw Exception('Failed to update status');

      // 4. Show Feedback (Undo removed as per request)
    } catch (e) {
      _loadAssets(); // Revert on error
      if (mounted) {
        SnackBarHelper.showError(context, 'Error: $e');
      }
    }
  }

  Future<User?> _showUserSelectionDialog() async {
    final users = await userService.getAllUsers();
    if (!mounted) return null;

    return showDialog<User>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 300, // Small and centered
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.t('select_holder'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text(
                            user.name[0],
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(
                          user.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          user.department ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => Navigator.pop(context, user),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        dense: true,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text(context.t('cancel')),
                ),
              ],
            ),
          ),
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
      appBar: AppBar(
        title: Text(context.t('assets_kanban')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAssets,
            tooltip: context.t('refresh'),
          ),
          const SizedBox(width: 8),
        ],
      ),
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
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add),
                  label: Text(context.t('add_asset')),
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
                        // Stack columns vertically on small screens
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
                        // Show columns side by side on larger screens
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
          onTap: () {},
        ),
      ),
      child: AssetCard(
        asset: asset,
        holderName: asset.currentHolderId != null
            ? holderNames[asset.currentHolderId]
            : null,
        onTap: () => _showDetailDialog(asset),
      ),
    );
  }
}
