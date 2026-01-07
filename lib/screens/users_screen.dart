import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../models/user_model.dart';
import '../models/room_model.dart';
import '../services/user_service.dart';
import '../services/asset_service.dart';
import '../services/room_service.dart';
import '../widgets/user_card.dart';
import '../widgets/user_form_dialog.dart';
import '../widgets/user_detail_dialog.dart';
import '../widgets/room_form_dialog.dart';
import '../widgets/room_detail_dialog.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/error_widget.dart';
import '../utils/extensions.dart';
import '../utils/snackbar_helper.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final userService = UserService();
  final assetService = AssetService();
  final roomService = RoomService();

  // User state
  List<User> users = [];
  Map<int, int> assetCounts = {};
  bool isLoadingUsers = true;
  bool hasUserError = false;

  // Room state
  List<Room> rooms = [];
  Map<int, int> roomAssetCounts = {};
  bool isLoadingRooms = true;
  bool hasRoomError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
    _loadRooms();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      isLoadingUsers = true;
      hasUserError = false;
    });

    try {
      final loadedUsers = await userService.getAllUsers();
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
          isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingUsers = false;
          hasUserError = true;
        });
      }
    }
  }

  Future<void> _loadRooms() async {
    setState(() {
      isLoadingRooms = true;
      hasRoomError = false;
    });

    try {
      final loadedRooms = await roomService.getAllRooms();
      final counts = <int, int>{};
      for (var room in loadedRooms) {
        if (room.id != null) {
          final assets = await roomService.getAssetsInRoom(room.id!);
          counts[room.id!] = assets.length;
        }
      }

      if (mounted) {
        setState(() {
          rooms = loadedRooms;
          roomAssetCounts = counts;
          isLoadingRooms = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingRooms = false;
          hasRoomError = true;
        });
      }
    }
  }

  Future<void> _showAddUserDialog() async {
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

  Future<void> _showAddRoomDialog() async {
    final result = await showDialog<Room>(
      context: context,
      builder: (context) => const RoomFormDialog(),
    );

    if (result != null) {
      try {
        await roomService.createRoom(result);
        _loadRooms();
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Ruangan berhasil ditambahkan');
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, 'Gagal menambahkan ruangan: $e');
        }
      }
    }
  }

  Future<void> _showUserDetailDialog(User user) async {
    await showDialog(
      context: context,
      builder: (context) => UserDetailDialog(user: user, onUpdate: _loadUsers),
    );
  }

  Future<void> _showRoomDetailDialog(Room room) async {
    await showDialog(
      context: context,
      builder: (context) => RoomDetailDialog(room: room, onUpdate: _loadRooms),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.t('users')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadUsers();
              _loadRooms();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pengguna', icon: Icon(Icons.people, size: 20)),
            Tab(text: 'Ruangan', icon: Icon(Icons.meeting_room, size: 20)),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildUserTab(), _buildRoomTab()],
      ),
    );
  }

  Widget _buildUserTab() {
    return Column(
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
                onPressed: _showAddUserDialog,
                icon: const Icon(Icons.add),
                label: Text(context.t('add_user')),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: isLoadingUsers
              ? _buildLoadingSkeleton()
              : hasUserError
              ? ErrorDisplay(
                  message: 'Failed to load users',
                  onRetry: _loadUsers,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return UserCard(
                      user: user,
                      assetCount: assetCounts[user.id] ?? 0,
                      onTap: () => _showUserDetailDialog(user),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRoomTab() {
    return Column(
      children: [
        // Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${rooms.length} Total Ruangan',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddRoomDialog,
                icon: const Icon(Icons.add),
                label: const Text('Tambah Ruangan'),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: isLoadingRooms
              ? _buildLoadingSkeleton()
              : hasRoomError
              ? ErrorDisplay(
                  message: 'Failed to load rooms',
                  onRetry: _loadRooms,
                )
              : rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada ruangan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tambahkan ruangan untuk mengelola lokasi aset',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return _buildRoomCard(room);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRoomCard(Room room) {
    final assetCount = roomAssetCounts[room.id] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showRoomDetailDialog(room),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.meeting_room,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.displayName != room.name
                          ? room.displayName
                          : (room.description ?? 'Tidak ada deskripsi'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Asset count badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: assetCount > 0
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2,
                      size: 16,
                      color: assetCount > 0 ? AppColors.primary : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$assetCount',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: assetCount > 0 ? AppColors.primary : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
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
