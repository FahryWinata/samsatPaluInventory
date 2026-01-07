import 'package:flutter/material.dart';
import 'app_colors.dart'; // Ensure this import points to your colors file

class DialogUtils {
  // Generic Delete Confirmation
  static Future<bool> showDeleteConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Delete',
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error, // Your red color
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false; // Default to false if dismissed
  }
}
