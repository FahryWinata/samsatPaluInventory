import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/asset_model.dart';
import '../utils/app_colors.dart';

class AssetCard extends StatelessWidget {
  final Asset asset;
  final String? holderName;
  final String? roomName;
  final IconData? categoryIcon;
  final VoidCallback onTap;

  const AssetCard({
    super.key,
    required this.asset,
    this.holderName,
    this.roomName,
    this.categoryIcon,
    required this.onTap,
  });

  /// Returns appropriate ImageProvider based on whether the path is a URL or local file
  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    } else {
      return FileImage(File(path));
    }
  }

  /// Shows a full-screen dialog with the image
  void _showImageDialog(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: Image(
                  image: _getImageProvider(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;

    switch (asset.status) {
      case 'available':
        statusColor = AppColors.available;
        statusText = 'Available';
        break;
      case 'assigned':
        statusColor = AppColors.assigned;
        statusText = 'Assigned';
        break;
      case 'maintenance':
        statusColor = AppColors.maintenance;
        statusText = 'Maintenance';
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusText = 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side: Image
                GestureDetector(
                  onTap: asset.imagePath != null
                      ? () => _showImageDialog(context, asset.imagePath!)
                      : null,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade100),
                      image: asset.imagePath != null
                          ? DecorationImage(
                              image: _getImageProvider(asset.imagePath!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: asset.imagePath == null
                        ? Center(
                            child: Icon(
                              categoryIcon ?? Icons.inventory_2,
                              color: statusColor.withValues(alpha: 0.8),
                              size: 32,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),

                // Right Side: Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Name
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              asset.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.more_horiz,
                            size: 20,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Sub-header: SKU + Status Badge
                      Row(
                        children: [
                          Text(
                            asset.identifierValue ?? 'No SKU',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(statusText, statusColor),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tags - Using Wrap for better layout
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          // Holder Name tag
                          if (holderName != null && asset.status == 'assigned')
                            _buildTag(
                              holderName!,
                              AppColors.assigned.withValues(alpha: 0.1),
                              AppColors.assigned,
                              icon: Icons.person,
                            ),

                          // Room Name tag
                          if (roomName != null)
                            _buildTag(
                              roomName!,
                              Colors.blue.shade50,
                              Colors.blue.shade700,
                              icon: Icons.room,
                            ),

                          // Purchase Date tag
                          if (asset.purchaseDate != null)
                            _buildTag(
                              DateFormat(
                                'MMM yyyy',
                              ).format(asset.purchaseDate!),
                              Colors.grey.shade100,
                              Colors.grey.shade600,
                              icon: Icons.calendar_today,
                            ),
                        ],
                      ),

                      // Description check if needed, but the design didn't really have it.
                      // Keeping it cleaner as requested.
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(
    String text,
    Color bgColor,
    Color textColor, {
    IconData? icon,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
