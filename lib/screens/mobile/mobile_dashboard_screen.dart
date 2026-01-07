import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../services/asset_service.dart';
import '../../services/activity_service.dart';
import '../../models/activity_model.dart';
import 'package:intl/intl.dart';

class MobileDashboardScreen extends StatefulWidget {
  const MobileDashboardScreen({super.key});

  @override
  State<MobileDashboardScreen> createState() => _MobileDashboardScreenState();
}

class _MobileDashboardScreenState extends State<MobileDashboardScreen> {
  final inventoryService = InventoryService();
  final assetService = AssetService();
  final activityService = ActivityService();

  bool isLoading = true;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;
  int _totalAssets = 0;
  int _availableAssets = 0;
  int _totalItems = 0;
  List<ActivityLog> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final items = await inventoryService.getAllItems();
      final assets = await assetService.getAllAssets();
      final activities = await activityService.getRecentActivities(limit: 5);

      if (mounted) {
        setState(() {
          _lowStockCount = items
              .where((i) => i.quantity <= i.minimumStock && i.quantity > 0)
              .length;
          _outOfStockCount = items.where((i) => i.quantity == 0).length;
          _totalItems = items.length;
          _totalAssets = assets.length;
          _availableAssets = assets
              .where((a) => a.status.toLowerCase() == 'available')
              .length;
          _recentActivities = activities;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    String? subtitle,
    bool showTrend = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(Icons.more_horiz, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: showTrend
                    ? (subtitle.contains('↓') ? Colors.red : Colors.green)
                    : Colors.grey,
                fontSize: 12,
                fontWeight: showTrend ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light grey background
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),

                // Statistic Cards
                _buildOverviewCard(
                  title: 'Total Barang',
                  value: '$_totalItems',
                  color: Colors.blue,
                  icon: Icons.inventory_2,
                  subtitle: 'Item Types in Inventory',
                ),
                _buildOverviewCard(
                  title: 'Total Unit',
                  value: '$_totalAssets',
                  color: const Color(0xFF6C63FF), // Purple
                  icon: Icons.devices,
                  subtitle: 'Registered Assets',
                ),
                _buildOverviewCard(
                  title: 'Unit Tersedia',
                  value: '$_availableAssets',
                  color: Colors.green,
                  icon: Icons.check_circle_outline,
                  subtitle: 'Ready to Assign',
                ),
                _buildOverviewCard(
                  title: 'Item Stok Rendah',
                  value: '$_lowStockCount',
                  color: Colors.orange,
                  icon: Icons.warning_amber,
                  subtitle: 'Needs Restocking',
                  showTrend: true,
                ),
                _buildOverviewCard(
                  title: 'Item Habis',
                  value: '$_outOfStockCount',
                  color: Colors.red,
                  icon: Icons.remove_circle_outline,
                  showTrend: true,
                  subtitle: '$_outOfStockCount items Out of Stock',
                ),

                const SizedBox(height: 32),

                // Recent Activity Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Aktivitas Terbaru',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: const [
                          Text('Terbaru', style: TextStyle(fontSize: 12)),
                          SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRecentActivityList(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overview',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat('d MMM, yyyy', 'id_ID').format(DateTime.now()),
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Icon(Icons.notifications_none_rounded, size: 24),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivityList() {
    if (_recentActivities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Belum ada aktivitas',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentActivities.length,
      itemBuilder: (context, index) {
        final activity = _recentActivities[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getActionColor(activity.action).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getActionIcon(activity.action),
                  color: _getActionColor(activity.action),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_translateAction(activity.action)} ${activity.entityName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'oleh ${activity.performedBy} • ${DateFormat('HH:mm').format(activity.timestamp)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'create':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline;
      case 'transfer':
        return Icons.swap_horiz_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'create':
        return Colors.green;
      case 'update':
        return Colors.blue;
      case 'delete':
        return Colors.red;
      case 'transfer':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _translateAction(String action) {
    switch (action.toLowerCase()) {
      case 'create':
        return 'Menambah';
      case 'update':
        return 'Memperbarui';
      case 'delete':
        return 'Menghapus';
      case 'transfer':
        return 'Mentransfer';
      default:
        return action;
    }
  }
}
