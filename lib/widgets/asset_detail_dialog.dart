import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'package:intl/intl.dart';
import '../models/asset_model.dart';
import '../models/user_model.dart';
import '../models/asset_category_model.dart';
import '../models/room_model.dart';
import '../services/asset_service.dart';
import '../services/user_service.dart';
import '../services/category_service.dart';
import '../services/room_service.dart';
import '../utils/app_colors.dart';

import '../utils/snackbar_helper.dart';
import 'asset_form_dialog.dart';

class AssetDetailDialog extends StatefulWidget {
  final Asset asset;
  final VoidCallback onUpdate;
  final bool maintenanceMode;

  const AssetDetailDialog({
    super.key,
    required this.asset,
    required this.onUpdate,
    this.maintenanceMode = false,
  });

  @override
  State<AssetDetailDialog> createState() => _AssetDetailDialogState();
}

class _AssetDetailDialogState extends State<AssetDetailDialog> {
  final AssetService assetService = AssetService();
  final UserService userService = UserService();
  final CategoryService categoryService = CategoryService();
  final RoomService roomService = RoomService();

  late Asset _asset;
  bool isLoading = true;
  User? currentHolder;
  AssetCategory? assetCategory;
  Room? assignedRoom;
  List<Map<String, dynamic>> transferHistory = [];

  @override
  void initState() {
    super.initState();
    _asset = widget.asset;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      // 1. Fetch fresh asset data
      final freshAsset = await assetService.getAssetById(_asset.id!);
      if (freshAsset != null) {
        _asset = freshAsset;
      }

      // 2. Fetch current holder
      if (_asset.currentHolderId != null) {
        currentHolder = await userService.getUserById(_asset.currentHolderId!);
      } else {
        currentHolder = null;
      }

      // 3. Fetch category
      if (_asset.categoryId != null) {
        assetCategory = await categoryService.getCategoryById(
          _asset.categoryId!,
        );
      } else {
        assetCategory = null;
      }

      // 4. Fetch assigned room
      if (_asset.assignedToRoomId != null) {
        assignedRoom = await roomService.getRoomById(_asset.assignedToRoomId!);
      } else {
        assignedRoom = null;
      }

      // 5. Fetch history
      final history = await assetService.getTransferHistoryWithNames(
        _asset.id!,
      );

      if (mounted) {
        setState(() {
          transferHistory = history;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _showAssignDialog() async {
    final users = await userService.getAllUsers();
    if (!mounted) return;

    // Filter out the current holder
    final availableUsers = users
        .where((u) => u.id != _asset.currentHolderId)
        .toList();

    final User? selectedUser = await showDialog<User>(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredUsers = availableUsers
                .where(
                  (u) =>
                      u.name.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ) ||
                      (u.department?.toLowerCase().contains(
                            searchQuery.toLowerCase(),
                          ) ??
                          false),
                )
                .toList();

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 350, // Slightly wider for search bar
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t('select_holder'), // Used key 'select_holder'
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    // Search Bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: context.t('search_users'),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (filteredUsers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          searchQuery.isEmpty
                              ? context.t('no_other_users_available')
                              : context.t('no_users_found'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              title: Text(
                                user.name,
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                user.department ?? '-',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () => Navigator.pop(context, user),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              dense: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hoverColor: Colors.grey.shade100,
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
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
      },
    );

    if (selectedUser != null) {
      await assetService.transferAsset(
        assetId: _asset.id!,
        toUserId: selectedUser.id!,
      );
      widget.onUpdate(); // Notify parent to refresh
      _loadData(); // Refresh local data (will fetch new holder)
    }
  }

  Future<void> _showEditDialog() async {
    final updatedAsset = await showDialog<Asset>(
      context: context,
      builder: (context) => AssetFormDialog(asset: _asset),
    );

    if (updatedAsset != null) {
      try {
        await assetService.updateAsset(updatedAsset);
        widget.onUpdate();
        _loadData();
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Asset updated successfully');
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, 'Failed to update asset: $e');
        }
      }
    }
  }

  Future<void> _deleteAsset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('delete_asset_title')),
        content: Text(
          'Are you sure you want to delete "${_asset.name}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.t('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await assetService.deleteAsset(_asset.id!);
      widget.onUpdate();
      if (mounted) {
        Navigator.pop(context);
        SnackBarHelper.showSuccess(context, 'Asset deleted successfully');
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return AppColors.available;
      case 'assigned':
        return AppColors.assigned;
      case 'maintenance':
        return AppColors.maintenance;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _asset.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _asset.identifierValue ?? '-',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Edit Button
                  if (!widget.maintenanceMode)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: _showEditDialog,
                      tooltip: 'Edit Asset',
                    ),
                  if (!widget.maintenanceMode)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: _deleteAsset,
                      tooltip: 'Delete Asset',
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fixed Content: Status & Details
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: Column(
                            children: [
                              // Status & Holder
                              _buildInfoSection(
                                context,
                                title: 'Current Status',
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          _asset.status,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _asset.status.toUpperCase(),
                                        style: TextStyle(
                                          color: _getStatusColor(_asset.status),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (currentHolder != null) ...[
                                      const SizedBox(width: 12),
                                      const Icon(
                                        Icons.arrow_right_alt,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 12),
                                      const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        currentHolder!.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    // Assign Button
                                    if (!widget.maintenanceMode)
                                      ElevatedButton.icon(
                                        onPressed: _showAssignDialog,
                                        icon: const Icon(
                                          Icons.person_add,
                                          size: 16,
                                        ),
                                        label: Text(context.t('assign')),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.orange.shade600,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Details
                              _buildInfoSection(
                                context,
                                title: 'Details',
                                child: Column(
                                  children: [
                                    _buildDetailRow(
                                      'Kategori',
                                      assetCategory?.name ??
                                          'Tidak Berkategori',
                                    ),
                                    _buildDetailRow(
                                      'Ruangan',
                                      assignedRoom?.displayName ?? 'Tidak Ada',
                                    ),
                                    _buildDetailRow(
                                      'Description',
                                      _asset.description ?? '-',
                                    ),
                                    _buildDetailRow(
                                      'Purchase Date',
                                      _asset.purchaseDate != null
                                          ? DateFormat(
                                              'dd MMM yyyy',
                                            ).format(_asset.purchaseDate!)
                                          : '-',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Maintenance Settings Section
                              _buildInfoSection(
                                context,
                                title: context.t('maintenance_settings'),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Toggle Row
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.build,
                                            size: 20,
                                            color: _asset.requiresMaintenance
                                                ? Colors.orange
                                                : Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            context.t('requires_maintenance'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Spacer(),
                                          Switch(
                                            value: _asset.requiresMaintenance,
                                            onChanged: (value) async {
                                              // Optimistic local update
                                              final newInterval = value
                                                  ? 90
                                                  : null;
                                              DateTime? nextDate;
                                              if (value &&
                                                  newInterval != null) {
                                                final baseDate =
                                                    _asset
                                                        .lastMaintenanceDate ??
                                                    DateTime.now();
                                                nextDate = baseDate.add(
                                                  Duration(days: newInterval),
                                                );
                                              }
                                              setState(() {
                                                _asset = _asset.copyWith(
                                                  requiresMaintenance: value,
                                                  maintenanceIntervalDays:
                                                      newInterval,
                                                  nextMaintenanceDate: nextDate,
                                                );
                                              });
                                              // Save to backend
                                              await assetService
                                                  .updateMaintenanceSettings(
                                                    assetId: _asset.id!,
                                                    requiresMaintenance: value,
                                                    intervalDays: newInterval,
                                                  );
                                              widget.onUpdate();
                                            },
                                            activeTrackColor:
                                                Colors.orange.shade200,
                                            activeThumbColor: Colors.orange,
                                          ),
                                        ],
                                      ),
                                      if (_asset.requiresMaintenance) ...[
                                        const Divider(),
                                        // Interval Dropdown
                                        Row(
                                          children: [
                                            Text(
                                              context.t('maintenance_interval'),
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const Spacer(),
                                            DropdownButton<int>(
                                              value:
                                                  _asset
                                                      .maintenanceIntervalDays ??
                                                  90,
                                              items: [30, 60, 90, 120, 180, 365]
                                                  .map(
                                                    (days) => DropdownMenuItem(
                                                      value: days,
                                                      child: Text(
                                                        '$days ${context.t('days')}',
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (value) async {
                                                if (value != null) {
                                                  // Optimistic local update
                                                  final baseDate =
                                                      _asset
                                                          .lastMaintenanceDate ??
                                                      DateTime.now();
                                                  final nextDate = baseDate.add(
                                                    Duration(days: value),
                                                  );
                                                  setState(() {
                                                    _asset = _asset.copyWith(
                                                      maintenanceIntervalDays:
                                                          value,
                                                      nextMaintenanceDate:
                                                          nextDate,
                                                    );
                                                  });
                                                  // Save to backend
                                                  await assetService
                                                      .updateMaintenanceSettings(
                                                        assetId: _asset.id!,
                                                        requiresMaintenance:
                                                            true,
                                                        intervalDays: value,
                                                      );
                                                  widget.onUpdate();
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Last Maintained & Next Due
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    context.t(
                                                      'last_maintained',
                                                    ),
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  Text(
                                                    _asset.lastMaintenanceDate !=
                                                            null
                                                        ? DateFormat(
                                                            'dd MMM yyyy',
                                                          ).format(
                                                            _asset
                                                                .lastMaintenanceDate!,
                                                          )
                                                        : context.t('never'),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    context.t(
                                                      'next_maintenance',
                                                    ),
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  Text(
                                                    _asset.nextMaintenanceDate !=
                                                            null
                                                        ? DateFormat(
                                                            'dd MMM yyyy',
                                                          ).format(
                                                            _asset
                                                                .nextMaintenanceDate!,
                                                          )
                                                        : context.t('not_set'),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          _asset
                                                              .isMaintenanceOverdue
                                                          ? Colors.red
                                                          : null,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Mark as Maintained Button
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              // Optimistic local update
                                              final now = DateTime.now();
                                              DateTime? nextDate;
                                              if (_asset
                                                      .maintenanceIntervalDays !=
                                                  null) {
                                                nextDate = now.add(
                                                  Duration(
                                                    days: _asset
                                                        .maintenanceIntervalDays!,
                                                  ),
                                                );
                                              }
                                              setState(() {
                                                _asset = _asset.copyWith(
                                                  lastMaintenanceDate: now,
                                                  nextMaintenanceDate: nextDate,
                                                );
                                              });
                                              // Save to backend
                                              final success = await assetService
                                                  .markAsMaintained(_asset.id!);
                                              if (!context.mounted) return;
                                              if (success) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      context.t(
                                                        'maintenance_updated',
                                                      ),
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                                widget.onUpdate();
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.check,
                                              size: 18,
                                            ),
                                            label: Text(
                                              context.t('mark_as_maintained'),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 32),

                              // History Header
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  'Transfer History',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),

                        // Scrollable History
                        Expanded(
                          child: transferHistory.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    'No transfer history available',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    0,
                                    24,
                                    24,
                                  ),
                                  itemCount: transferHistory.length,
                                  itemBuilder: (context, index) {
                                    final log = transferHistory[index];
                                    final date = DateTime.parse(
                                      log['transfer_date'],
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Column(
                                            children: [
                                              const CircleAvatar(
                                                radius: 4,
                                                backgroundColor:
                                                    AppColors.textSecondary,
                                              ),
                                              if (index !=
                                                  transferHistory.length - 1)
                                                Container(
                                                  width: 1,
                                                  height: 40,
                                                  color: Colors.grey.shade300,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Transferred to ${log['to_user_name'] ?? 'Unknown'}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  DateFormat(
                                                    'MMM dd, HH:mm',
                                                  ).format(date),
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                if (log['notes'] != null &&
                                                    log['notes']
                                                        .toString()
                                                        .isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: Text(
                                                      log['notes'],
                                                      style: const TextStyle(
                                                        fontStyle:
                                                            FontStyle.italic,
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
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
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
