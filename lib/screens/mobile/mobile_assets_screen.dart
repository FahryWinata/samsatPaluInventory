import 'package:flutter/material.dart';
import '../../services/asset_service.dart';
import '../../services/user_service.dart';
import '../../models/asset_model.dart';
import '../../widgets/asset_form_dialog.dart';
import '../../utils/performance_logger.dart';
import 'paginated_asset_list_view.dart';

class MobileAssetsScreen extends StatefulWidget {
  const MobileAssetsScreen({super.key});

  @override
  State<MobileAssetsScreen> createState() => _MobileAssetsScreenState();
}

class _MobileAssetsScreenState extends State<MobileAssetsScreen>
    with SingleTickerProviderStateMixin {
  final assetService = AssetService();
  final userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  final _perf = PerformanceLogger();

  Map<int, String> _userNames = {}; // Cache user names
  bool _isLoading = true;
  late TabController _tabController;

  // Keys to refresh lists
  final GlobalKey<PaginatedAssetListViewState> _availableKey = GlobalKey();
  final GlobalKey<PaginatedAssetListViewState> _assignedKey = GlobalKey();
  final GlobalKey<PaginatedAssetListViewState> _maintenanceKey = GlobalKey();

  // Counts for tabs
  int _availableCount = 0;
  int _assignedCount = 0;
  int _maintenanceCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _perf.startTimer('MobileAssetsScreen._loadData');

    try {
      _perf.startTimer('MobileAssetsScreen.getAssetStatistics');
      final stats = await assetService.getAssetStatistics();
      _perf.stopTimer(
        'MobileAssetsScreen.getAssetStatistics',
        details:
            'available=${stats['available']}, assigned=${stats['assigned']}',
      );

      _perf.startTimer('MobileAssetsScreen.getAllUsers');
      final users = await userService.getAllUsers();
      _perf.stopTimer(
        'MobileAssetsScreen.getAllUsers',
        details: 'users=${users.length}',
      );

      if (mounted) {
        setState(() {
          _availableCount = stats['available'] ?? 0;
          _assignedCount = stats['assigned'] ?? 0;
          _maintenanceCount = stats['maintenance'] ?? 0;

          _userNames = {for (var u in users) u.id!: u.name};
          _isLoading = false;
        });
      }
      _perf.stopTimer('MobileAssetsScreen._loadData', details: 'Success');
    } catch (e) {
      _perf.stopTimer('MobileAssetsScreen._loadData', details: 'ERROR: $e');
      debugPrint("Error loading data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _refreshAll() {
    _loadData(); // Refresh counts
    _availableKey.currentState?.refresh();
    _assignedKey.currentState?.refresh();
    _maintenanceKey.currentState?.refresh();
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aset berhasil ditambahkan'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshAll();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ... (Edit/Move/Delete handlers kept same, but calling _refreshAll)

  Future<void> _showEditDialog(Asset asset) async {
    final result = await showDialog<Asset>(
      context: context,
      builder: (context) => AssetFormDialog(asset: asset),
    );

    if (result != null) {
      try {
        await assetService.updateAsset(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aset berhasil diperbarui'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshAll();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showMoveDialog(Asset asset) async {
    final users = await userService.getAllUsers();
    if (!mounted) return;

    final newStatus = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        String selectedStatus = asset.status;
        int? selectedUser;
        String? maintenanceNote;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Pindahkan Aset'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    items: const [
                      DropdownMenuItem(
                        value: 'available',
                        child: Text('Tersedia'),
                      ),
                      DropdownMenuItem(
                        value: 'assigned',
                        child: Text('Ditetapkan'),
                      ),
                      DropdownMenuItem(
                        value: 'maintenance',
                        child: Text('Perbaikan'),
                      ),
                    ],
                    onChanged: (val) => setState(() => selectedStatus = val!),
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                  if (selectedStatus == 'assigned') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: selectedUser,
                      items: users
                          .map(
                            (u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(u.name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => selectedUser = val),
                      decoration: const InputDecoration(
                        labelText: 'Tetapkan ke Pengguna',
                      ),
                    ),
                  ],
                  if (selectedStatus == 'maintenance') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Catatan Perbaikan',
                      ),
                      onChanged: (val) => maintenanceNote = val,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, {
                      'status': selectedStatus,
                      'userId': selectedUser,
                      'note': maintenanceNote,
                    });
                  },
                  child: const Text('Move'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newStatus != null && mounted) {
      try {
        final finalAsset = Asset(
          id: asset.id,
          name: asset.name,
          identifierValue: asset.identifierValue,
          description: asset.description,
          purchaseDate: asset.purchaseDate,
          status: newStatus['status'],
          currentHolderId: newStatus['status'] == 'assigned'
              ? newStatus['userId']
              : null,
          imagePath: asset.imagePath,
          maintenanceLocation: newStatus['status'] == 'maintenance'
              ? newStatus['note']
              : null,
          createdAt: asset.createdAt,
          updatedAt: DateTime.now(),
        );

        await assetService.updateAsset(finalAsset);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Asset moved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshAll();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showAssetOptions(Asset asset) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit Detail'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showEditDialog(asset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.orange),
              title: const Text('Pindahkan / Ubah Status'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showMoveDialog(asset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Hapus Aset'),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDeleteAsset(asset);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAsset(Asset asset) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Aset'),
        content: const Text('Apakah Anda yakin ingin menghapus aset ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await assetService.deleteAsset(asset.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aset berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshAll();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus aset: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        title: const Text(
          'Asset Status',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1976D2),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1976D2),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: 'Available ($_availableCount)'),
            Tab(text: 'Assigned ($_assignedCount)'),
            Tab(text: 'Maintenance ($_maintenanceCount)'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                PaginatedAssetListView(
                  key: _availableKey,
                  status: 'available',
                  assetService: assetService,
                  onAssetTap: _showAssetOptions,
                  userNames: _userNames,
                ),
                PaginatedAssetListView(
                  key: _assignedKey,
                  status: 'assigned',
                  assetService: assetService,
                  onAssetTap: _showAssetOptions,
                  userNames: _userNames,
                ),
                PaginatedAssetListView(
                  key: _maintenanceKey,
                  status: 'maintenance',
                  assetService: assetService,
                  onAssetTap: _showAssetOptions,
                  userNames: _userNames,
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
}
