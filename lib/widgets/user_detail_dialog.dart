import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/asset_model.dart';
import '../services/asset_service.dart';
import '../services/user_service.dart';
import '../utils/app_colors.dart';
import '../utils/snackbar_helper.dart';
import 'user_form_dialog.dart';

class UserDetailDialog extends StatefulWidget {
  final User user;
  final VoidCallback onUpdate;

  const UserDetailDialog({
    super.key,
    required this.user,
    required this.onUpdate,
  });

  @override
  State<UserDetailDialog> createState() => _UserDetailDialogState();
}

class _UserDetailDialogState extends State<UserDetailDialog> {
  final assetService = AssetService();
  final userService = UserService();
  late User _user;
  List<Asset> assignedAssets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadAssignedAssets();
  }

  Future<void> _loadAssignedAssets() async {
    setState(() => isLoading = true);

    try {
      final assets = await assetService.getAssetsByHolder(_user.id!);
      setState(() {
        assignedAssets = assets;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading assets: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _editUser() async {
    final updatedUser = await showDialog<User>(
      context: context,
      builder: (context) => UserFormDialog(user: _user),
    );

    if (updatedUser != null && mounted) {
      try {
        await userService.updateUser(updatedUser);
        setState(() {
          _user = updatedUser;
        });
        widget.onUpdate();
        if (mounted) {
          SnackBarHelper.showSuccess(context, context.t('user_updated'));
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, e.toString());
        }
      }
    }
  }

  Future<void> _deleteUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('delete_user_title')),
        content: Text(
          'Are you sure you want to delete "${_user.name}"?\n\n'
          '${assignedAssets.length} assigned asset(s) will be released to available status.',
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
      await userService.deleteUser(_user.id!);
      widget.onUpdate();
      if (mounted) {
        Navigator.pop(context);
        SnackBarHelper.showSuccess(context, 'User deleted successfully');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      _user.name.isNotEmpty ? _user.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _user.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_user.department != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _user.department!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blueAccent),
                    onPressed: _editUser,
                    tooltip: 'Edit User',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: _deleteUser,
                    tooltip: 'Delete User',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Contact Info
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_user.department != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.business,
                        'Department',
                        _user.department!,
                      ),
                    ],

                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.calendar_today,
                      'Member Since',
                      DateFormat('MMMM d, yyyy').format(_user.createdAt),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // Assigned Assets
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Assigned Assets',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${assignedAssets.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (assignedAssets.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No assets assigned',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...assignedAssets.map((asset) => _buildAssetItem(asset)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssetItem(Asset asset) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.laptop_mac,
                color: AppColors.info,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    asset.identifierValue ?? '-',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.assigned.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Assigned',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.assigned,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
