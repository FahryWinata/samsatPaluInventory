import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../utils/app_colors.dart';
import '../services/inventory_service.dart';
import '../services/asset_service.dart';
import '../services/user_service.dart';
import '../services/activity_service.dart';
import '../models/inventory_model.dart';
import '../models/activity_model.dart';
import '../utils/extensions.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/error_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final inventoryService = InventoryService();
  final assetService = AssetService();
  final userService = UserService();
  final activityService = ActivityService();

  // Statistics Data
  int totalInventoryItems = 0;
  int totalAssets = 0;
  int totalUsers = 0;

  // Inventory 3-State Health
  int goodStockCount = 0;
  int lowStockCount = 0;
  int outOfStockCount = 0;

  int availableAssets = 0;
  int assignedAssets = 0;
  int maintenanceAssets = 0;

  // Maintenance Stats
  int overdueMaintenanceCount = 0;
  int upcomingMaintenanceCount = 0;

  // List Data
  List<InventoryItem> stockAlertItems = [];
  List<ActivityLog> recentActivities = [];

  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final items = await inventoryService.getAllItems();
      final assetsList = await assetService.getAllAssets();
      final users = await userService.getAllUsers();
      final assetStats = await assetService.getAssetStatistics();
      final activities = await activityService.getRecentActivities(limit: 20);

      // Calculate 3-State Inventory Health
      int good = 0;
      int low = 0;
      int out = 0;
      List<InventoryItem> alerts = [];

      for (var item in items) {
        if (item.quantity == 0) {
          out++;
          alerts.add(item);
        } else if (item.quantity <= item.minimumStock) {
          low++;
          alerts.add(item);
        } else {
          good++;
        }
      }

      if (mounted) {
        setState(() {
          totalInventoryItems = items.length;
          totalAssets = assetsList.length;
          totalUsers = users.length;

          goodStockCount = good;
          lowStockCount = low;
          outOfStockCount = out;
          stockAlertItems = alerts;

          availableAssets = assetStats['available'] ?? 0;
          assignedAssets = assetStats['assigned'] ?? 0;
          maintenanceAssets = assetStats['maintenance'] ?? 0;
          recentActivities = activities;
          isLoading = false;
        });
      }

      // Load maintenance stats separately (don't block main load)
      final maintenanceStats = await assetService.getMaintenanceStats();
      if (mounted) {
        setState(() {
          overdueMaintenanceCount = maintenanceStats['overdue'] ?? 0;
          upcomingMaintenanceCount = maintenanceStats['upcoming'] ?? 0;
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: isLoading
          ? _buildLoadingSkeleton(isDesktop)
          : hasError
          ? ErrorDisplay(message: errorMessage, onRetry: _loadData)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: isDesktop
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 24),

                        // Row 1: Overviews
                        SizedBox(
                          height: 180,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildAssetOverviewCard(),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 1,
                                child: _buildInventorySummaryCard(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Row 2: Charts
                        SizedBox(
                          height: 320,
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: _buildBarChartCard()),
                              const SizedBox(width: 24),
                              Expanded(flex: 1, child: _buildPieChartCard()),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          height:
                              500, // Fixed height to allow scrolling of the page
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildActivityListCard(isDesktop: true),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  children: [
                                    _buildMaintenanceAlertCard(),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: _buildStockAlertListCard(
                                        isDesktop: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  // Fallback for Mobile
                  : Column(
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 16),
                        _buildAssetOverviewCard(isMobile: true),
                        const SizedBox(height: 16),
                        _buildInventorySummaryCard(isMobile: true),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 300,
                          child: _buildBarChartCard(isMobile: true),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 300,
                          child: _buildPieChartCard(isMobile: true),
                        ),
                        const SizedBox(height: 16),
                        _buildActivityListCard(isDesktop: false),
                        const SizedBox(height: 16),
                        _buildMaintenanceAlertCard(),
                        const SizedBox(height: 16),
                        _buildStockAlertListCard(isDesktop: false),
                      ],
                    ),
            ),
    );
  }

  // --- SKELETON LOADER ---
  Widget _buildLoadingSkeleton(bool isDesktop) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonLoader(width: 150, height: 24),
                  SizedBox(height: 8),
                  SkeletonLoader(width: 100, height: 14),
                ],
              ),
              const SkeletonLoader(width: 40, height: 40),
            ],
          ),
          const SizedBox(height: 16),
          if (isDesktop)
            Row(
              children: [
                Expanded(flex: 2, child: _buildSkeletonCard(height: 180)),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: _buildSkeletonCard(height: 180)),
              ],
            )
          else
            Column(
              children: [
                _buildSkeletonCard(height: 180),
                const SizedBox(height: 16),
                _buildSkeletonCard(height: 180),
              ],
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard({required double height}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('dashboard'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            Text(
              context.t('welcome_back'),
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              tooltip: context.t('refresh'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssetOverviewCard({bool isMobile = false}) {
    return _BentoCard(
      title: context.t('asset_overview'),
      disableExpand: isMobile,
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              label: context.t('total'),
              value: totalAssets.toString(),
              icon: Icons.devices,
              color: Colors.blue,
            ),
          ),
          _divider(),
          Expanded(
            child: _SummaryItem(
              label: context.t('avail'),
              value: availableAssets.toString(),
              icon: Icons.check_circle_outline,
              color: Colors.teal,
            ),
          ),
          _divider(),
          Expanded(
            child: _SummaryItem(
              label: context.t('assigned'),
              value: assignedAssets.toString(),
              icon: Icons.person_outline,
              color: Colors.orange,
            ),
          ),
          _divider(),
          Expanded(
            child: _SummaryItem(
              label: context.t('maint'),
              value: maintenanceAssets.toString(),
              icon: Icons.build_circle_outlined,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventorySummaryCard({bool isMobile = false}) {
    return _BentoCard(
      title: context.t('inventory_summary'),
      disableExpand: isMobile,
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              label: context.t('total'),
              value: totalInventoryItems.toString(),
              icon: Icons.inventory_2_outlined,
              color: Colors.indigo,
            ),
          ),
          _divider(),
          Expanded(
            child: _SummaryItem(
              label: context.t('low'),
              value: lowStockCount.toString(),
              icon: Icons.warning_amber_rounded,
              color: Colors.amber,
            ),
          ),
          _divider(),
          Expanded(
            child: _SummaryItem(
              label: context.t('out'),
              value: outOfStockCount.toString(),
              icon: Icons.highlight_off,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.withValues(alpha: 0.2),
    );
  }

  Widget _buildBarChartCard({bool isMobile = false}) {
    return _BentoCard(
      title: context.t('asset_status_distribution'),
      // disableExpand: false, // Charts always need to fill their container
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (totalAssets > 0 ? totalAssets : 10).toDouble(),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  const style = TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  );
                  String text;
                  switch (value.toInt()) {
                    case 0:
                      text = context.t('available');
                      break;
                    case 1:
                      text = context.t('assigned');
                      break;
                    case 2:
                      text = context.t('maint');
                      break;
                    default:
                      text = '';
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(text, style: style),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            _makeBarGroup(0, availableAssets.toDouble(), AppColors.available),
            _makeBarGroup(1, assignedAssets.toDouble(), AppColors.assigned),
            _makeBarGroup(
              2,
              maintenanceAssets.toDouble(),
              AppColors.maintenance,
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 35,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: (totalAssets > 0 ? totalAssets : 10).toDouble(),
            color: const Color(0xFFF0F0F0),
          ),
        ),
      ],
    );
  }

  Widget _buildPieChartCard({bool isMobile = false}) {
    return _BentoCard(
      title: context.t('inventory_health'),
      // disableExpand: false,
      child: totalInventoryItems == 0
          ? Center(child: Text(context.t('no_data')))
          : Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 40,
                      sections: [
                        if (goodStockCount > 0)
                          PieChartSectionData(
                            color: Colors.green,
                            value: goodStockCount.toDouble(),
                            title: '',
                            radius: 30,
                          ),
                        if (lowStockCount > 0)
                          PieChartSectionData(
                            color: Colors.amber,
                            value: lowStockCount.toDouble(),
                            title: '',
                            radius: 35,
                          ),
                        if (outOfStockCount > 0)
                          PieChartSectionData(
                            color: Colors.red,
                            value: outOfStockCount.toDouble(),
                            title: '',
                            radius: 40,
                          ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendItem(context.t('good'), Colors.green),
                    const SizedBox(height: 8),
                    _legendItem(context.t('low'), Colors.amber),
                    const SizedBox(height: 8),
                    _legendItem(context.t('out'), Colors.red),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _legendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildActivityListCard({required bool isDesktop}) {
    return _BentoCard(
      title: context.t('recent_activity'),
      disableExpand: !isDesktop,
      child: recentActivities.isEmpty
          ? Center(child: Text(context.t('no_activity_logs')))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          context.t('item_header'),
                          style: _headerStyle(),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          context.t('date_header'),
                          style: _headerStyle(),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          context.t('action_header'),
                          style: _headerStyle(),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                isDesktop
                    ? Expanded(child: _buildActivityListView())
                    : _buildActivityListView(shrinkWrap: true),
              ],
            ),
    );
  }

  Widget _buildActivityListView({bool shrinkWrap = false}) {
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      itemCount: recentActivities.length,
      itemBuilder: (context, index) {
        final log = recentActivities[index];
        return _ActivityRow(
          title: log.entityName,
          subtitle: log.details,
          date: _formatDate(log.timestamp),
          status: log.action.toUpperCase(),
          color: _getActionColor(log.action),
        );
      },
    );
  }

  Widget _buildStockAlertListCard({required bool isDesktop}) {
    return _BentoCard(
      title: context.t('stock_alerts'),
      disableExpand: !isDesktop,
      child: stockAlertItems.isEmpty
          ? Center(child: Text(context.t('inventory_healthy')))
          : Column(
              children: [
                isDesktop
                    ? Expanded(child: _buildStockAlertListView())
                    : _buildStockAlertListView(shrinkWrap: true),
              ],
            ),
    );
  }

  Widget _buildStockAlertListView({bool shrinkWrap = false}) {
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      itemCount: stockAlertItems.length,
      separatorBuilder: (ctx, i) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = stockAlertItems[index];
        final isOut = item.quantity == 0;
        final color = isOut ? Colors.red : Colors.amber;
        final text = isOut ? context.t('out') : context.t('low');

        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            "Qty: ${item.quantity} ${item.unit}",
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMaintenanceAlertCard() {
    final hasAlerts =
        overdueMaintenanceCount > 0 || upcomingMaintenanceCount > 0;

    return GestureDetector(
      onTap: () {
        // Navigate to Maintenance screen (index 4)
        context.read<NavigationProvider>().setIndex(4);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: overdueMaintenanceCount > 0
              ? Border.all(color: Colors.red.shade200, width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.build,
                  color: overdueMaintenanceCount > 0
                      ? Colors.red
                      : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  context.t('maintenance_alerts'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasAlerts)
              Text(
                context.t('no_maintenance_scheduled'),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              )
            else
              Row(
                children: [
                  if (overdueMaintenanceCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$overdueMaintenanceCount',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.t('overdue'),
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (upcomingMaintenanceCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$upcomingMaintenanceCount',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.t('upcoming'),
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  TextStyle _headerStyle() => TextStyle(
    color: Colors.grey[500],
    fontSize: 11,
    fontWeight: FontWeight.bold,
  );

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat('HH:mm').format(date);
    }
    return DateFormat('MMM d').format(date);
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
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _BentoCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool disableExpand;

  const _BentoCard({
    required this.title,
    required this.child,
    this.disableExpand = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 16),
          if (disableExpand) child else Expanded(child: child),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;
  final String status;
  final Color color;

  const _ActivityRow({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              date,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
