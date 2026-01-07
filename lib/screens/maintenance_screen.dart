import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/asset_model.dart';
import '../services/asset_service.dart';
import '../utils/app_colors.dart';
import '../utils/extensions.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/error_widget.dart';
import '../widgets/asset_detail_dialog.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final assetService = AssetService();

  // Master list
  List<Asset> _allAssets = [];

  // Filtered lists
  List<Asset> overdueAssets = [];
  List<Asset> upcomingAssets = [];
  List<Asset> futureAssets = [];

  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // Search
  String searchQuery = '';
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      // Fetch only assets that require maintenance
      final assets = await assetService.getMaintenanceDueAssets();

      if (mounted) {
        setState(() {
          _allAssets = assets;
          _applyFilters();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = context.t('failed_load_data');
        });
      }
    }
  }

  void _applyFilters() {
    final overdue = <Asset>[];
    final upcoming = <Asset>[];
    final future = <Asset>[];
    final now = DateTime.now();
    final thirtyDaysLater = now.add(const Duration(days: 30));

    for (var asset in _allAssets) {
      // Search Filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final matchesName = asset.name.toLowerCase().contains(query);
        final matchesSerial = (asset.identifierValue ?? '')
            .toLowerCase()
            .contains(query);

        if (!matchesName && !matchesSerial) {
          continue;
        }
      }

      // Sort into Columns based on Date
      if (asset.nextMaintenanceDate == null) {
        future.add(asset); // Or handling for not scheduled
      } else if (asset.nextMaintenanceDate!.isBefore(now)) {
        overdue.add(asset);
      } else if (asset.nextMaintenanceDate!.isBefore(thirtyDaysLater)) {
        upcoming.add(asset);
      } else {
        future.add(asset);
      }
    }

    setState(() {
      overdueAssets = overdue;
      upcomingAssets = upcoming;
      futureAssets = future;
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          searchQuery = query;
          _applyFilters();
        });
      }
    });
  }

  Future<void> _markAsMaintained(Asset asset) async {
    // Optimistic Update
    final originalAsset = asset;
    final now = DateTime.now();
    DateTime? nextDate;
    if (asset.maintenanceIntervalDays != null) {
      nextDate = now.add(Duration(days: asset.maintenanceIntervalDays!));
    }

    final updatedAsset = asset.copyWith(
      lastMaintenanceDate: now,
      nextMaintenanceDate: nextDate,
    );

    setState(() {
      // Remove from old list
      if (overdueAssets.remove(asset)) {
      } else if (upcomingAssets.remove(asset)) {
      } else if (futureAssets.remove(asset)) {}

      // Add to Future list (since it's just maintained)
      // Note: In real logic, it might still be upcoming if interval is very short,
      // but usually it goes to future/upcoming.
      // Re-running filters handles placement correctly if we update master list.
      final index = _allAssets.indexOf(asset);
      if (index != -1) {
        _allAssets[index] = updatedAsset;
      }
      _applyFilters();
    });

    // Show success snackbar immediately
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('maintenance_updated')),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final success = await assetService.markAsMaintained(asset.id!);
      if (!success) throw Exception('Failed to update');
    } catch (e) {
      // Revert on error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() {
          final index = _allAssets.indexWhere((a) => a.id == asset.id);
          if (index != -1) _allAssets[index] = originalAsset;
          _applyFilters();
        });
      }
    }
  }

  Future<void> _showDetailDialog(Asset asset) async {
    await showDialog(
      context: context,
      builder: (context) => AssetDetailDialog(
        asset: asset,
        onUpdate: _loadData,
        maintenanceMode: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.t('maintenance_reminder')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: context.t('refresh'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
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

          // Kanban Board
          Expanded(
            child: isLoading
                ? _buildLoadingSkeleton()
                : hasError
                ? ErrorDisplay(message: errorMessage, onRetry: _loadData)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isSmallScreen = constraints.maxWidth < 900;

                      if (isSmallScreen) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildKanbanColumn(
                                context.t('overdue'),
                                overdueAssets,
                                Colors.red,
                                isOverdue: true,
                                fullWidth: true,
                              ),
                              const SizedBox(height: 16),
                              _buildKanbanColumn(
                                context.t('upcoming'),
                                upcomingAssets,
                                Colors.orange,
                                fullWidth: true,
                              ),
                              const SizedBox(height: 16),
                              _buildKanbanColumn(
                                context.t(
                                  'future_maintenance',
                                ), // Need to add key/use localized
                                futureAssets,
                                Colors.blue,
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
                                context.t('overdue'),
                                overdueAssets,
                                Colors.red,
                                isOverdue: true,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKanbanColumn(
                                context.t('upcoming'),
                                upcomingAssets,
                                Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKanbanColumn(
                                context.t('future_maintenance'),
                                futureAssets,
                                Colors.blue,
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
              children: List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildSkeletonColumn(),
                ),
              ),
            ),
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              3,
              (index) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: index == 0 ? 0 : 16),
                  child: _buildSkeletonColumn(),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildSkeletonColumn() {
    return Container(
      padding: const EdgeInsets.all(16),
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
            child: SkeletonLoader(width: double.infinity, height: 100),
          ),
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(
    String title,
    List<Asset> assets,
    Color color, {
    bool isOverdue = false,
    bool fullWidth = false,
  }) {
    return Container(
      margin: fullWidth
          ? EdgeInsets.zero
          : const EdgeInsets.only(top: 16, bottom: 16, right: 16),
      decoration: fullWidth
          ? null
          : BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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

          // List
          if (assets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.grey.shade300,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t('no_assets'),
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            )
          else
            fullWidth
                ? ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: assets.length,
                    itemBuilder: (context, index) => _MaintenanceCard(
                      asset: assets[index],
                      onMarkMaintained: () => _markAsMaintained(assets[index]),
                      onTap: () => _showDetailDialog(assets[index]),
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: assets.length,
                      itemBuilder: (context, index) => _MaintenanceCard(
                        asset: assets[index],
                        onMarkMaintained: () =>
                            _markAsMaintained(assets[index]),
                        onTap: () => _showDetailDialog(assets[index]),
                      ),
                    ),
                  ),
        ],
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  final Asset asset;
  final VoidCallback onMarkMaintained;
  final VoidCallback onTap;

  const _MaintenanceCard({
    required this.asset,
    required this.onMarkMaintained,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = asset.isMaintenanceOverdue;
    final daysUntil = asset.daysUntilMaintenance;
    final dateFormat = DateFormat('dd MMM yyyy');

    Color statusColor;
    String statusText;

    if (isOverdue) {
      statusColor = Colors.red;
      statusText =
          '${daysUntil?.abs() ?? 0} ${context.t('days')} ${context.t('overdue')}';
    } else if (daysUntil != null && daysUntil <= 30) {
      statusColor = Colors.orange;
      statusText = '${context.t('due_in')} $daysUntil ${context.t('days')}';
    } else {
      statusColor = Colors.blue;
      statusText = context.t('scheduled');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.build, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          asset.identifierValue ?? '-',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('next_due'),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      Text(
                        asset.nextMaintenanceDate != null
                            ? dateFormat.format(asset.nextMaintenanceDate!)
                            : '-',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: isOverdue ? Colors.red : null,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: onMarkMaintained,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      foregroundColor: Colors.green,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      context.t('done'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
