import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../services/inventory_service.dart';
import '../services/asset_service.dart';
import '../services/export_service.dart';
import '../services/activity_service.dart';
import '../services/user_service.dart';
import '../models/inventory_model.dart';
import '../models/asset_model.dart';
import '../models/activity_model.dart';
import '../utils/extensions.dart';
import '../utils/snackbar_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final inventoryService = InventoryService();
  final assetService = AssetService();
  final exportService = ExportService();
  final activityService = ActivityService();
  final userService = UserService();

  bool isLoading = true;
  List<InventoryItem> inventoryItems = [];
  List<Asset> assets = [];
  List<ActivityLog> recentActivities = [];
  List<Map<String, dynamic>> transferHistory = [];
  Map<int, String> holderNames = {};

  // Stats for Charts
  int availableCount = 0;
  int assignedCount = 0;
  int maintenanceCount = 0;
  int lowStockCount = 0;
  int goodStockCount = 0;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final items = await inventoryService.getAllItems();
      final assetList = await assetService.getAllAssets();
      final stats = await assetService.getAssetStatistics();
      final lowStock = await inventoryService.getLowStockItems();
      final activities = await activityService.getRecentActivities(limit: 20);
      final transfers = await assetService.getAllTransfers();
      final users = await userService.getAllUsers();

      // Create holder map
      final namesMap = <int, String>{};
      for (var user in users) {
        namesMap[user.id!] = user.name;
      }

      if (mounted) {
        setState(() {
          inventoryItems = items;
          assets = assetList;
          recentActivities = activities;
          transferHistory = transfers;
          holderNames = namesMap;

          // Asset Stats
          availableCount = stats['available'] ?? 0;
          assignedCount = stats['assigned'] ?? 0;
          maintenanceCount = stats['maintenance'] ?? 0;

          // Inventory Stats
          lowStockCount = lowStock.length;
          goodStockCount = items.length - lowStockCount;

          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading report data: $e");
      if (mounted) {
        setState(() => isLoading = false);
        SnackBarHelper.showError(
          context,
          '${context.t('failed_load_data')}: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.t('reports')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Custom Tab Bar
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildTabButton(0, context.t('overview'), Icons.pie_chart),
                  const SizedBox(width: 12),
                  _buildTabButton(1, context.t('activity_log'), Icons.history),
                  const SizedBox(width: 12),
                  _buildTabButton(2, context.t('transfers'), Icons.swap_horiz),
                ],
              ),
            ),
          ),

          // Tab Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildActivityLogTab(),
                      _buildTransferHistoryTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.animateTo(index);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: OVERVIEW ---

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('data_visualization'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),

          // --- CHARTS ROW ---
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildAssetChart()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildInventoryChart()),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildAssetChart(),
                    const SizedBox(height: 24),
                    _buildInventoryChart(),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 40),
          Text(
            context.t('export_data'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          // --- EXPORT BUTTONS ---
          _buildExportCard(
            context,
            title: context.t('inventory_report'),
            subtitle: context.t('inventory_report_desc'),
            icon: Icons.inventory,
            color: AppColors.primary,
            onTap: () => _showExportDialog(isInventory: true),
          ),
          const SizedBox(height: 16),
          _buildExportCard(
            context,
            title: context.t('asset_status_report'),
            subtitle: context.t('asset_report_desc'),
            icon: Icons.devices,
            color: AppColors.info,
            onTap: () => _showExportDialog(isInventory: false),
          ),
        ],
      ),
    );
  }

  Future<void> _showExportDialog({required bool isInventory}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    // Load saved values or use defaults
    final titleController = TextEditingController(
      text: isInventory
          ? (prefs.getString('export_title_inventory') ?? 'LAPORAN INVENTARIS')
          : (prefs.getString('export_title_asset') ?? 'LAPORAN STATUS ASET'),
    );

    // Approver (Mengetahui) controllers
    final approverNameController = TextEditingController(
      text: prefs.getString('export_approver_name') ?? '',
    );
    final approverRankController = TextEditingController(
      text: prefs.getString('export_approver_rank') ?? 'Pembina (IV/a)',
    );
    final approverNipController = TextEditingController(
      text: prefs.getString('export_approver_nip') ?? '',
    );
    final approverTitleController = TextEditingController(
      text: prefs.getString('export_approver_title') ?? 'Pengurus Barang,',
    );

    // Creator (Pembuat Laporan) controllers
    final creatorNameController = TextEditingController(
      text: prefs.getString('export_creator_name') ?? '',
    );
    final creatorRankController = TextEditingController(
      text: prefs.getString('export_creator_rank') ?? '',
    );
    final creatorNipController = TextEditingController(
      text: prefs.getString('export_creator_nip') ?? '',
    );
    final creatorTitleController = TextEditingController(
      text:
          prefs.getString('export_creator_title') ?? 'Kepala Seksi Tata Usaha,',
    );

    // Third signer (Pengurus Barang) controllers
    final thirdSignerNameController = TextEditingController(
      text: prefs.getString('export_third_signer_name') ?? '',
    );
    final thirdSignerRankController = TextEditingController(
      text: prefs.getString('export_third_signer_rank') ?? '',
    );
    final thirdSignerNipController = TextEditingController(
      text: prefs.getString('export_third_signer_nip') ?? '',
    );
    final thirdSignerTitleController = TextEditingController(
      text:
          prefs.getString('export_third_signer_title') ??
          'KEPALA UNIT PELAKSANA TEKNIS\nPENDAPATAN DAERAH WILAYAH I PALU',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('export_options')),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: context.t('report_title'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // Two column layout for first two signers
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column - Approver (Mengetahui)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Penandatangan 1 (Kiri)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: approverTitleController,
                            decoration: const InputDecoration(
                              labelText: 'Jabatan',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            maxLines: 2,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: approverNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nama',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: approverRankController,
                            decoration: const InputDecoration(
                              labelText: 'Pangkat/Gol',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: approverNipController,
                            decoration: const InputDecoration(
                              labelText: 'NIP',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Right column - Creator (Pembuat Laporan)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Penandatangan 2 (Kanan)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: creatorTitleController,
                            decoration: const InputDecoration(
                              labelText: 'Jabatan',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            maxLines: 2,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: creatorNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nama',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: creatorRankController,
                            decoration: const InputDecoration(
                              labelText: 'Pangkat/Gol',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: creatorNipController,
                            decoration: const InputDecoration(
                              labelText: 'NIP',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),

                // Third signer - centered below
                const Text(
                  'Penandatangan 3 (Tengah Bawah)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                // Jabatan field
                TextField(
                  controller: thirdSignerTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Jabatan',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13),
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: thirdSignerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: thirdSignerRankController,
                        decoration: const InputDecoration(
                          labelText: 'Pangkat/Gol',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: thirdSignerNipController,
                        decoration: const InputDecoration(
                          labelText: 'NIP',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('cancel')),
          ),
          // Reset button to clear saved settings
          TextButton.icon(
            onPressed: () async {
              // Clear all saved export settings
              await prefs.remove('export_approver_title');
              await prefs.remove('export_approver_name');
              await prefs.remove('export_approver_rank');
              await prefs.remove('export_approver_nip');
              await prefs.remove('export_creator_title');
              await prefs.remove('export_creator_name');
              await prefs.remove('export_creator_rank');
              await prefs.remove('export_creator_nip');
              await prefs.remove('export_third_signer_title');
              await prefs.remove('export_third_signer_name');
              await prefs.remove('export_third_signer_rank');
              await prefs.remove('export_third_signer_nip');

              // Reset text controllers to default values
              approverTitleController.text = 'Pengurus Barang,';
              approverNameController.text = '';
              approverRankController.text = 'Pembina (IV/a)';
              approverNipController.text = '';

              creatorTitleController.text = 'Kepala Seksi Tata Usaha,';
              creatorNameController.text = '';
              creatorRankController.text = '';
              creatorNipController.text = '';

              thirdSignerTitleController.text =
                  'KEPALA UNIT PELAKSANA TEKNIS\nPENDAPATAN DAERAH WILAYAH I PALU';
              thirdSignerNameController.text = '';
              thirdSignerRankController.text = '';
              thirdSignerNipController.text = '';

              // Show confirmation
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pengaturan export telah direset'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reset'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              // Save values for next time
              await prefs.setString(
                isInventory ? 'export_title_inventory' : 'export_title_asset',
                titleController.text,
              );
              // Save approver values
              await prefs.setString(
                'export_approver_name',
                approverNameController.text,
              );
              await prefs.setString(
                'export_approver_rank',
                approverRankController.text,
              );
              await prefs.setString(
                'export_approver_nip',
                approverNipController.text,
              );
              await prefs.setString(
                'export_approver_title',
                approverTitleController.text,
              );
              // Save creator values
              await prefs.setString(
                'export_creator_name',
                creatorNameController.text,
              );
              await prefs.setString(
                'export_creator_rank',
                creatorRankController.text,
              );
              await prefs.setString(
                'export_creator_nip',
                creatorNipController.text,
              );
              await prefs.setString(
                'export_creator_title',
                creatorTitleController.text,
              );
              // Save third signer values
              await prefs.setString(
                'export_third_signer_name',
                thirdSignerNameController.text,
              );
              await prefs.setString(
                'export_third_signer_rank',
                thirdSignerRankController.text,
              );
              await prefs.setString(
                'export_third_signer_nip',
                thirdSignerNipController.text,
              );
              await prefs.setString(
                'export_third_signer_title',
                thirdSignerTitleController.text,
              );

              try {
                if (isInventory) {
                  await exportService.generateInventoryReport(
                    inventoryItems,
                    customTitle: titleController.text,
                    approverName: approverNameController.text,
                    approverRank: approverRankController.text,
                    approverNip: approverNipController.text,
                    approverTitle: approverTitleController.text,
                    creatorName: creatorNameController.text,
                    creatorRank: creatorRankController.text,
                    creatorNip: creatorNipController.text,
                    creatorTitle: creatorTitleController.text,
                    thirdSignerName: thirdSignerNameController.text,
                    thirdSignerRank: thirdSignerRankController.text,
                    thirdSignerNip: thirdSignerNipController.text,
                    thirdSignerTitle: thirdSignerTitleController.text,
                  );
                } else {
                  await exportService.generateAssetReport(
                    assets,
                    holderNames,
                    customTitle: titleController.text,
                    approverName: approverNameController.text,
                    approverRank: approverRankController.text,
                    approverNip: approverNipController.text,
                    approverTitle: approverTitleController.text,
                    creatorName: creatorNameController.text,
                    creatorRank: creatorRankController.text,
                    creatorNip: creatorNipController.text,
                    creatorTitle: creatorTitleController.text,
                    thirdSignerName: thirdSignerNameController.text,
                    thirdSignerRank: thirdSignerRankController.text,
                    thirdSignerNip: thirdSignerNipController.text,
                    thirdSignerTitle: thirdSignerTitleController.text,
                  );
                }

                if (mounted) {
                  SnackBarHelper.showSuccess(
                    context,
                    isInventory
                        ? context.t('inventory_report_generated')
                        : context.t('asset_report_generated'),
                  );
                }
              } catch (e) {
                if (mounted) {
                  SnackBarHelper.showError(
                    context,
                    '${context.t('failed_load_data')}: $e',
                  );
                }
              }
            },
            child: Text(context.t('export')),
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('asset_distribution'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      color: AppColors.available,
                      value: availableCount.toDouble(),
                      title: '$availableCount',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: AppColors.assigned,
                      value: assignedCount.toDouble(),
                      title: '$assignedCount',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: AppColors.maintenance,
                      value: maintenanceCount.toDouble(),
                      title: '$maintenanceCount',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildLegendItem(context.t('available'), AppColors.available),
            const SizedBox(height: 8),
            _buildLegendItem(context.t('assigned'), AppColors.assigned),
            const SizedBox(height: 8),
            _buildLegendItem(context.t('maintenance'), AppColors.maintenance),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('inventory_health'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      color: Colors.green,
                      value: goodStockCount.toDouble(),
                      title: '$goodStockCount',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.redAccent,
                      value: lowStockCount.toDouble(),
                      title: '$lowStockCount',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildLegendItem(context.t('good_stock'), Colors.green),
            const SizedBox(height: 8),
            _buildLegendItem(context.t('low_stock'), Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  // --- TAB 2: ACTIVITY LOG ---

  Widget _buildActivityLogTab() {
    if (recentActivities.isEmpty) {
      return Center(child: Text(context.t('no_recent_activities')));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recentActivities.length,
      itemBuilder: (context, index) {
        final activity = recentActivities[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getActivityColor(activity.action),
              child: Icon(
                _getActivityIcon(activity.action),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              activity.details.isEmpty
                  ? activity.action.toUpperCase()
                  : activity.details,
            ),
            subtitle: Text(
              '${activity.entityType.toUpperCase()} • ${activity.performedBy} • ${DateFormat('yyyy-MM-dd HH:mm').format(activity.timestamp)}',
            ),
          ),
        );
      },
    );
  }

  Color _getActivityColor(String action) {
    switch (action) {
      case 'create':
        return Colors.green;
      case 'update':
        return Colors.blue;
      case 'delete':
        return Colors.red;
      case 'transfer':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getActivityIcon(String action) {
    switch (action) {
      case 'create':
        return Icons.add;
      case 'update':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'transfer':
        return Icons.swap_horiz;
      default:
        return Icons.info;
    }
  }

  // --- TAB 3: TRANSFER HISTORY ---

  Widget _buildTransferHistoryTab() {
    if (transferHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              context.t('no_transfer_history'),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transferHistory.length,
      itemBuilder: (context, index) {
        final transfer = transferHistory[index];
        final date = DateTime.parse(transfer['transfer_date']);
        final fromUser = transfer['from_user_name'] ?? 'Storage';
        final toUser = transfer['to_user_name'] ?? 'Unknown';
        final assetName = transfer['asset_name'] ?? 'Unknown Asset';
        final assetSerial = transfer['asset_serial'] ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.assigned.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.swap_horiz,
                    color: AppColors.assigned,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assetName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (assetSerial.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          assetSerial,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              fromUser,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.assigned.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              toUser,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.assigned,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('MMM dd').format(date),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('HH:mm').format(date),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
