import 'package:flutter/material.dart';

import '../../../../core/notifications/notifications.dart';
import '../../../notifications_hub/presentation/screens/hub_module_detail_page.dart';

/// Lightweight entry point to the Notification Hub's Finance module screen.
class FinanceNotificationHubLink extends StatelessWidget {
  final bool compact;
  final String? subtitle;

  const FinanceNotificationHubLink({
    super.key,
    this.compact = false,
    this.subtitle,
  });

  void _openHub(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const HubModuleDetailPage(moduleId: NotificationHubModuleIds.finance),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (compact) {
      return InkWell(
        onTap: () => _openHub(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.notifications_active_rounded,
            size: 18,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _openHub(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFCDAF56).withOpacity(0.12),
              const Color(0xFFCDAF56).withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCDAF56).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFCDAF56).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.tune_rounded,
                size: 18,
                color: Color(0xFFCDAF56),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage in Notification Hub',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFCDAF56),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle ??
                        'Sound, channel, vibration, and delivery settings',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color(0xFFCDAF56),
            ),
          ],
        ),
      ),
    );
  }
}
