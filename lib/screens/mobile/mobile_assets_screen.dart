import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/asset_service.dart';
import '../../services/user_service.dart';
import '../../models/asset_model.dart';
import '../../widgets/asset_form_dialog.dart';

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

  List<Asset> _allAssets = [];
  bool _isLoading = true;
  late TabController _tabController;
  Map<int, String> _userNames = {}; // Cache user names

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
    setState(() => _isLoading = true);
    try {
      final assets = await assetService.getAllAssets();
      final users = await userService
          .getAllUsers(); // Fetch users to map IDs to Names

      if (mounted) {
        setState(() {
          _allAssets = assets;
          _userNames = {for (var u in users) u.id!: u.name}; // Create Map
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading assets: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

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
        }
        _loadData();
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
        }
        _loadData();
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
        }
        _loadData();
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

  List<Asset> _getFilteredAssets(String status) {
    return _allAssets.where((asset) {
      if (asset.status.toLowerCase() != status.toLowerCase()) return false;
      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        return asset.name.toLowerCase().contains(query) ||
            (asset.identifierValue ?? '').toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  int get _availableCount =>
      _allAssets.where((a) => a.status.toLowerCase() == 'available').length;
  int get _assignedCount =>
      _allAssets.where((a) => a.status.toLowerCase() == 'assigned').length;
  int get _maintenanceCount =>
      _allAssets.where((a) => a.status.toLowerCase() == 'maintenance').length;

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
                _buildAssetList('available'),
                _buildAssetList('assigned'),
                _buildAssetList('maintenance'),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF1976D2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAssetList(String status) {
    final assets = _getFilteredAssets(status);

    if (assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No $status assets found',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        return _buildAssetCard(assets[index]);
      },
    );
  }

  Widget _buildAssetCard(Asset asset) {
    // Determine the subtitle text
    String subtitleText;
    if (asset.status == 'assigned' && asset.currentHolderId != null) {
      final holderName = _userNames[asset.currentHolderId] ?? 'Unknown User';
      subtitleText = 'Holder: $holderName';
    } else if (asset.status == 'maintenance') {
      subtitleText = 'Loc: ${asset.maintenanceLocation ?? 'N/A'}';
    } else {
      subtitleText = (asset.identifierValue?.isNotEmpty ?? false)
          ? 'S/N: ${asset.identifierValue}'
          : 'Available';
    }

    return GestureDetector(
      onTap: () => _showAssetOptions(asset),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                image: asset.imagePath != null
                    ? DecorationImage(
                        image: asset.imagePath!.startsWith('http')
                            ? NetworkImage(asset.imagePath!)
                            : FileImage(File(asset.imagePath!))
                                  as ImageProvider,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: asset.imagePath == null ? _getIconForAsset(asset) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitleText,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_vert, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _getIconForAsset(Asset asset) {
    final name = asset.name.toLowerCase();
    if (name.contains('macbook') || name.contains('laptop')) {
      return const Icon(Icons.laptop, color: Colors.grey);
    }
    if (name.contains('iphone') ||
        name.contains('ipad') ||
        name.contains('tablet')) {
      return const Icon(Icons.tablet_mac, color: Colors.grey);
    }
    if (name.contains('keyboard')) {
      return const Icon(Icons.keyboard, color: Colors.grey);
    }
    if (name.contains('mouse')) {
      return const Icon(Icons.mouse, color: Colors.grey);
    }
    if (name.contains('monitor') || name.contains('display')) {
      return const Icon(Icons.monitor, color: Colors.grey);
    }
    return const Icon(Icons.devices_other, color: Colors.grey);
  }
}
