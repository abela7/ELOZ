import 'package:flutter/material.dart';

/// App-wide themed snackbar helper
/// Uses consistent styling matching the app's dark theme with gold accents
class AppSnackbar {
  static const Color _accentColor = Color(0xFFCDAF56);
  static const Color _darkSurface = Color(0xFF2D3139);
  static const Color _successColor = Color(0xFF4CAF50);
  static const Color _errorColor = Color(0xFFFF6B6B);
  static const Color _warningColor = Color(0xFFFFB347);

  /// Show a success snackbar (e.g., "Task created!")
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: _successColor,
      borderColor: _successColor,
    );
  }

  /// Show an error snackbar
  static void showError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.error_rounded,
      iconColor: _errorColor,
      borderColor: _errorColor,
    );
  }

  /// Show a warning snackbar
  static void showWarning(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.warning_rounded,
      iconColor: _warningColor,
      borderColor: _warningColor,
    );
  }

  /// Show an info snackbar with accent color
  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.info_rounded,
      iconColor: _accentColor,
      borderColor: _accentColor,
    );
  }

  /// Show a points earned/lost snackbar
  static void showPoints(BuildContext context, String message, int points) {
    final isPositive = points >= 0;
    _show(
      context,
      message: message,
      icon: isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
      iconColor: isPositive ? _successColor : _errorColor,
      borderColor: isPositive ? _successColor : _errorColor,
      suffix: Text(
        '${isPositive ? '+' : ''}$points pts',
        style: TextStyle(
          color: isPositive ? _successColor : _errorColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Internal method to show the snackbar
  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    Widget? suffix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (suffix != null) ...[
              const SizedBox(width: 8),
              suffix,
            ],
          ],
        ),
        backgroundColor: isDark ? _darkSurface : const Color(0xFF3D4251),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor.withOpacity(0.5), width: 1),
        ),
        elevation: 8,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

