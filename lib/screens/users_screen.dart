import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../models/user_model.dart';
import '../models/room_model.dart';
import '../models/asset_model.dart';
import '../services/user_service.dart';
import '../services/asset_service.dart';
import '../services/room_service.dart';
import '../widgets/user_form_dialog.dart';
import '../widgets/user_detail_dialog.dart';
import '../widgets/room_form_dialog.dart';
import '../widgets/room_detail_dialog.dart';
import '../widgets/custom_table.dart';
import '../utils/extensions.dart';
import '../utils/snackbar_helper.dart';
import '../utils/performance_logger.dart';

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
  final _perf = PerformanceLogger();

  // User state
  List<User> users = [];
  List<User> filteredUsers = [];
  Map<int, int> assetCounts = {};
  bool isLoadingUsers = true;
  bool hasUserError = false;

  // Room state
  List<Room> rooms = [];
  List<Room> filteredRooms = [];
  Map<int, int> roomAssetCounts = {};
  bool isLoadingRooms = true;
  bool hasRoomError = false;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadUsers();
    _loadRooms();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    // Clear search when switching tabs? Or keep it? keeping it is simpler but might filter incorrectly if logic differs.
    // We'll keep query but re-filter.
    _applySearch();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    setState(() {
      if (_searchQuery.isEmpty) {
        filteredUsers = users;
        filteredRooms = rooms;
      } else {
        final query = _searchQuery.toLowerCase();
        filteredUsers = users
            .where((u) => u.name.toLowerCase().contains(query))
            .toList();
        filteredRooms = rooms
            .where((r) => r.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _loadUsers() async {
    _perf.startTimer('UsersScreen._loadUsers');

    setState(() {
      isLoadingUsers = true;
      hasUserError = false;
    });

    try {
      // OPTIMIZATION: Parallel fetch users AND all assets (eliminates N+1 query)
      final results = await Future.wait([
        userService.getAllUsers(),
        assetService.getAllAssets(),
      ]);

      final loadedUsers = results[0] as List<User>;
      final allAssets = results[1] as List<Asset>;

      _perf.logStep(
        'UsersScreen._loadUsers',
        'Parallel fetch: ${loadedUsers.length} users, ${allAssets.length} assets',
      );

      // Count assets per user client-side (instant vs 24 API calls)
      final counts = <int, int>{};
      for (var asset in allAssets) {
        if (asset.currentHolderId != null) {
          counts[asset.currentHolderId!] =
              (counts[asset.currentHolderId!] ?? 0) + 1;
        }
      }
      _perf.logStep('UsersScreen._loadUsers', 'Client-side counting complete');

      if (mounted) {
        setState(() {
          users = loadedUsers;
          assetCounts = counts;
          isLoadingUsers = false;
        });
        _applySearch();
      }
      _perf.stopTimer(
        'UsersScreen._loadUsers',
        details: 'Success, users=${loadedUsers.length}',
      );
    } catch (e) {
      _perf.stopTimer('UsersScreen._loadUsers', details: 'ERROR: $e');
      if (mounted) {
        setState(() {
          isLoadingUsers = false;
          hasUserError = true;
        });
      }
    }
  }

  Future<void> _loadRooms() async {
    _perf.startTimer('UsersScreen._loadRooms');

    setState(() {
      isLoadingRooms = true;
      hasRoomError = false;
    });

    try {
      // OPTIMIZATION: Parallel fetch rooms AND all assets (eliminates N+1 query)
      final results = await Future.wait([
        roomService.getAllRooms(),
        assetService.getAllAssets(),
      ]);

      final loadedRooms = results[0] as List<Room>;
      final allAssets = results[1] as List<Asset>;

      _perf.logStep(
        'UsersScreen._loadRooms',
        'Parallel fetch: ${loadedRooms.length} rooms, ${allAssets.length} assets',
      );

      // Count assets per room client-side (instant vs N API calls)
      final counts = <int, int>{};
      for (var asset in allAssets) {
        if (asset.assignedToRoomId != null) {
          counts[asset.assignedToRoomId!] =
              (counts[asset.assignedToRoomId!] ?? 0) + 1;
        }
      }
      _perf.logStep('UsersScreen._loadRooms', 'Client-side counting complete');

      if (mounted) {
        setState(() {
          rooms = loadedRooms;
          roomAssetCounts = counts;
          isLoadingRooms = false;
        });
        _applySearch();
      }
      _perf.stopTimer(
        'UsersScreen._loadRooms',
        details: 'Success, rooms=${loadedRooms.length}',
      );
    } catch (e) {
      _perf.stopTimer('UsersScreen._loadRooms', details: 'ERROR: $e');
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
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Header / Top Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    // Tab Buttons
                    Expanded(
                      child: Row(
                        children: [
                          _buildTabButton(0, 'People', users.length),
                          const SizedBox(width: 24),
                          _buildTabButton(1, 'Rooms', rooms.length),
                        ],
                      ),
                    ),

                    // Search Bar
                    SizedBox(
                      width: 300,
                      height: 40,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          _searchQuery = value;
                          _applySearch();
                        },
                        decoration: InputDecoration(
                          hintText: 'Search Name...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Action Button
                    ElevatedButton.icon(
                      onPressed: _tabController.index == 0
                          ? _showAddUserDialog
                          : _showAddRoomDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        _tabController.index == 0
                            ? 'Add New People'
                            : 'Add New Room',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [_buildUserTable(), _buildRoomTable()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, int count) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final selected = _tabController.index == index;
        return InkWell(
          onTap: () => _tabController.animateTo(index),
          child: Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: selected ? AppColors.primary : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: selected ? AppColors.primary : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserTable() {
    return CustomTable<User>(
      isLoading: isLoadingUsers,
      headers: const ['Name', 'Department', 'Role', 'Status', ''],
      data: filteredUsers,
      rowBuilder: (context, user, index) {
        final holdingCount = assetCounts[user.id] ?? 0;
        return Row(
          children: [
            // Name with Avatar
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getAvatarColor(user.name),
                    radius: 18,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Department (Room)
            Expanded(
              flex: 3,
              child: Text(
                user.department ?? '-',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            // Role (Placeholder or Asset Count)
            Expanded(
              flex: 2,
              child: Text(
                '$holdingCount Assets',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            // Status
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            // Actions
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                    onPressed: () => _showUserDetailDialog(user),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoomTable() {
    return CustomTable<Room>(
      isLoading: isLoadingRooms,
      headers: const ['Room Name', 'Location', 'Assets', 'Status', ''],
      data: filteredRooms,
      rowBuilder: (context, room, index) {
        final holdingCount = roomAssetCounts[room.id] ?? 0;
        return Row(
          children: [
            // Name
            Expanded(
              flex: 3,
              child: Text(
                room.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Location
            Expanded(
              flex: 3,
              child: Text(
                room.displayName.contains(' - ')
                    ? room.displayName.split(' - ').last.trim()
                    : '-',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            // Assets Count
            Expanded(
              flex: 2,
              child: Text(
                '$holdingCount items',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            // Status/Tag
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: holdingCount > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Occupied',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Empty',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
            // Action
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                    onPressed: () => _showRoomDetailDialog(room),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getAvatarColor(String name) {
    if (name.isEmpty) return Colors.grey;
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }
}
