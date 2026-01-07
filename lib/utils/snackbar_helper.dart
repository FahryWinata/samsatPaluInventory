import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'extensions.dart';

class SnackBarHelper {
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
  }) {
    _showToast(
      context: context,
      type: ToastificationType.success,
      title: title ?? context.t('success_title'),
      message: message,
      iconColor: const Color(0xFF4CAF50), // Green
      iconData: Icons.check,
    );
  }

  static void showError(BuildContext context, String message, {String? title}) {
    _showToast(
      context: context,
      type: ToastificationType.error,
      title: title ?? context.t('error_title'),
      message: message,
      iconColor: const Color(0xFFF44336), // Red
      iconData: Icons.close,
    );
  }

  static void showInfo(BuildContext context, String message, {String? title}) {
    _showToast(
      context: context,
      type: ToastificationType.info,
      title: title ?? context.t('info_title'),
      message: message,
      iconColor: const Color(0xFF2196F3), // Blue
      iconData: Icons.info_outline,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
  }) {
    _showToast(
      context: context,
      type: ToastificationType.warning,
      title: title ?? context.t('warning_title'),
      message: message,
      iconColor: const Color(0xFFFF9800), // Orange
      iconData: Icons.warning_amber_rounded,
    );
  }

  static void _showToast({
    required BuildContext context,
    required ToastificationType type,
    required String title,
    required String message,
    required Color iconColor,
    required IconData iconData,
  }) {
    toastification.show(
      type: type,
      style: ToastificationStyle.simple,
      backgroundColor: _getBackgroundColor(type),
      foregroundColor: Colors.white,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome,
            color: Colors.white70,
            size: 16,
          ), // Sparkle icon
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
      description: Text(
        message,
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
      alignment: Alignment.bottomLeft,
      margin: const EdgeInsets.all(16),
      animationDuration: const Duration(milliseconds: 300),
      animationBuilder: (context, animation, alignment, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      autoCloseDuration: const Duration(seconds: 4),
      borderRadius: BorderRadius.circular(12.0),
      boxShadow: const [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 16,
          offset: Offset(0, 4),
          spreadRadius: 2,
        ),
      ],
      showProgressBar: false,
      closeButton: const ToastCloseButton(),
      closeOnClick: false,
      pauseOnHover: true,
      dragToClose: true,
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors
              .transparent, // Removed background circle to match screenshot better or keep it?
          // Screenshot has a circle outline or filled circle. Let's keep the filled circle but maybe subtle.
          // Actually screenshot shows a ring with the icon inside.
          border: Border.all(color: iconColor, width: 1.5),
          shape: BoxShape.circle,
        ),
        child: Icon(iconData, color: iconColor, size: 16),
      ),
    );
  }

  static Color _getBackgroundColor(ToastificationType type) {
    switch (type) {
      case ToastificationType.success:
        return const Color(0xFF2E7D32); // Green 800
      case ToastificationType.error:
        return const Color(0xFFC62828); // Red 800
      case ToastificationType.info:
        return const Color(0xFF1565C0); // Blue 800
      case ToastificationType.warning:
        return const Color(0xFFEF6C00); // Orange 800
    }
    return Colors.black; // Default fallback
  }
}
