import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/asset_service.dart';
import '../../models/asset_model.dart';
import '../../utils/performance_logger.dart';

class PaginatedAssetListView extends StatefulWidget {
  final String status;
  final AssetService assetService;
  final Function(Asset) onAssetTap;
  final Map<int, String> userNames;

  const PaginatedAssetListView({
    super.key,
    required this.status,
    required this.assetService,
    required this.onAssetTap,
    this.userNames = const {},
  });

  @override
  State<PaginatedAssetListView> createState() => PaginatedAssetListViewState();
}

class PaginatedAssetListViewState extends State<PaginatedAssetListView>
    with AutomaticKeepAliveClientMixin {
  final List<Asset> _assets = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _limit = 15;
  final ScrollController _scrollController = ScrollController();
  final _perf = PerformanceLogger();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom && !_isLoading && _hasMore) {
      _loadMore();
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  Future<void> refresh() async {
    setState(() {
      _assets.clear();
      _page = 1;
      _hasMore = true;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;

    final timerName =
        'PaginatedAssetListView._loadMore(status=${widget.status}, page=$_page)';
    _perf.startTimer(timerName);

    setState(() => _isLoading = true);

    try {
      final newAssets = await widget.assetService.getAssetsPaginated(
        page: _page,
        limit: _limit,
        status: widget.status,
      );

      if (mounted) {
        setState(() {
          _assets.addAll(newAssets);
          _isLoading = false;
          if (newAssets.length < _limit) {
            _hasMore = false;
          } else {
            _page++;
          }
        });
      }
      _perf.stopTimer(
        timerName,
        details: 'Loaded ${newAssets.length} items, total=${_assets.length}',
      );
    } catch (e) {
      _perf.stopTimer(timerName, details: 'ERROR: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // valid for AutomaticKeepAliveClientMixin

    if (_assets.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No ${widget.status} assets found',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _assets.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _assets.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final asset = _assets[index];
          return _buildAssetCard(asset);
        },
      ),
    );
  }

  Widget _buildAssetCard(Asset asset) {
    // Determine the subtitle text
    String subtitleText;
    if (asset.status == 'assigned' && asset.currentHolderId != null) {
      final holderName =
          widget.userNames[asset.currentHolderId] ?? 'Unknown User';
      subtitleText = 'Holder: $holderName';
    } else if (asset.status == 'maintenance') {
      subtitleText = 'Loc: ${asset.maintenanceLocation ?? 'N/A'}';
    } else {
      subtitleText = (asset.identifierValue?.isNotEmpty ?? false)
          ? 'S/N: ${asset.identifierValue}'
          : 'Available';
    }

    return GestureDetector(
      onTap: () => widget.onAssetTap(asset),
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
