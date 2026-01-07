import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import 'package:intl/intl.dart'; // Ensure you have intl package for date formatting

class RecentActivityCard extends StatelessWidget {
  final String title;
  final String description;
  final DateTime timestamp;
  final IconData icon;
  final Color iconColor;

  const RecentActivityCard({
    super.key,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    // Format the date (e.g., "Today 10:30 AM" or "Nov 23, 10:30 AM")
    final now = DateTime.now();
    final isToday =
        timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;

    final dateString = isToday
        ? 'Today ${DateFormat('HH:mm').format(timestamp)}'
        : DateFormat('MMM d, HH:mm').format(timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      dateString,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
