import '../notification_hub.dart';
import '../notifications.dart';
import '../models/universal_notification.dart';

/// Resolves variable placeholders in a notification's title/body for display.
///
/// Uses the module's adapter to fetch current entity values and replace
/// placeholders like {billName}, {daysLeft} with real data.
Future<String> resolveUniversalNotificationDisplayTitle(
  UniversalNotification n,
) async {
  try {
    await NotificationHub().initialize();
    final adapter = NotificationHub().adapterFor(n.moduleId);
    if (adapter == null) return _fallbackTitle(n.titleTemplate);
    final vars =
        await adapter.resolveVariablesForEntity(n.entityId, n.section);
    var result = n.titleTemplate;
    for (final e in vars.entries) {
      result = result.replaceAll(e.key, e.value);
    }
    result = _stripUnresolvedPlaceholders(result);
    return result.isEmpty ? _fallbackTitle(n.titleTemplate) : result;
  } catch (_) {
    return _fallbackTitle(n.titleTemplate);
  }
}

/// Resolves variable placeholders in a notification's body for display.
Future<String> resolveUniversalNotificationDisplayBody(
  UniversalNotification n,
) async {
  try {
    await NotificationHub().initialize();
    final adapter = NotificationHub().adapterFor(n.moduleId);
    if (adapter == null) return _fallbackTitle(n.bodyTemplate);
    final vars =
        await adapter.resolveVariablesForEntity(n.entityId, n.section);
    var result = n.bodyTemplate;
    for (final e in vars.entries) {
      result = result.replaceAll(e.key, e.value);
    }
    result = _stripUnresolvedPlaceholders(result);
    return result.isEmpty ? _fallbackTitle(n.bodyTemplate) : result;
  } catch (_) {
    return _fallbackTitle(n.bodyTemplate);
  }
}

/// Strips unresolved {variable} placeholders to avoid showing raw templates.
String _stripUnresolvedPlaceholders(String s) {
  return s.replaceAll(RegExp(r'\{[^}]*\}'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _fallbackTitle(String template) {
  if (template.isEmpty) return 'Reminder';
  return _stripUnresolvedPlaceholders(template);
}
