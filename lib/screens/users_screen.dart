import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/asset_service.dart'; // Import Asset Service
import '../widgets/user_card.dart';
import '../widgets/user_form_dialog.dart';
import '../widgets/user_detail_dialog.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/error_widget.dart';
import '../utils/extensions.dart';
import '../utils/snackbar_helper.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final userService = UserService();
  final assetService = AssetService(); // Initialize Asset Service

  List<User> users = [];
  Map<int, int> assetCounts = {}; // Store asset counts per user
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final loadedUsers = await userService.getAllUsers();

      // Calculate asset counts for each user
      final counts = <int, int>{};
      for (var user in loadedUsers) {
        if (user.id != null) {
          final assets = await assetService.getAssetsByHolder(user.id!);
          counts[user.id!] = assets.length;
        }
      }

      if (mounted) {
        setState(() {
          users = loadedUsers;
          assetCounts = counts;
          isLoading = false;
          hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Failed to load users';
        });
      }
    }
  }

  Future<void> _showAddDialog() async {
    final result = await showDialog<User>(
      context: context,
      builder: (context) => const UserFormDialog(),
    );

    if (result != null) {
      try {
        await userService.createUser(result);
        _loadUsers();
        if (mounted) {
          SnackBarHelper.showSuccess(context, context.t('user_added'));
        }
      } catch (e) {
        // Handle error
      }
    }
  }

  Future<void> _showDetailDialog(User user) async {
    await showDialog(
      context: context,
      builder: (context) => UserDetailDialog(
        user: user,
        onUpdate: _loadUsers, // Reload list when dialog closes
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.t('users')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${users.length} ${context.t('total_users')}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add),
                  label: Text(context.t('add_user')),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: isLoading
                ? _buildLoadingSkeleton()
                : hasError
                ? ErrorDisplay(message: errorMessage, onRetry: _loadUsers)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return UserCard(
                        user: user,
                        assetCount: assetCounts[user.id] ?? 0,
                        onTap: () => _showDetailDialog(user),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => const SkeletonListItem(),
    );
  }
}
