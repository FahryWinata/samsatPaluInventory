import 'package:flutter/material.dart';
import '../models/inventory_model.dart';
import '../utils/app_colors.dart';

class InventoryListItem extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const InventoryListItem({
    super.key,
    required this.item,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    final isLowStock = item.isLowStock;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isLowStock
                          ? AppColors.warning.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.inventory_2,
                      color: isLowStock ? AppColors.warning : AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title and Description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isLowStock)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'LOW STOCK',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (item.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.description!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Bottom Row - Quantity and Actions
              Row(
                children: [
                  // Quantity Display
                  Expanded(
                    child: Row(
                      children: [
                        const Text(
                          'Quantity:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.quantity}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isLowStock
                                ? AppColors.warning
                                : AppColors.primary,
                          ),
                        ),
                        if (item.unit != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            item.unit!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Quick Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Decrease
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: AppColors.error,
                        iconSize: 28,
                        onPressed: item.quantity > 0 ? onDecrease : null,
                        tooltip: 'Decrease',
                      ),

                      // Increase
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: AppColors.success,
                        iconSize: 28,
                        onPressed: onIncrease,
                        tooltip: 'Increase',
                      ),

                      const SizedBox(width: 8),

                      // Edit
                      IconButton(
                        icon: const Icon(Icons.edit),
                        color: AppColors.primary,
                        onPressed: onEdit,
                        tooltip: 'Edit',
                      ),

                      // Delete
                      IconButton(
                        icon: const Icon(Icons.delete),
                        color: AppColors.error,
                        onPressed: onDelete,
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
