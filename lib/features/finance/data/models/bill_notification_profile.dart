import 'dart:convert';
import 'package:flutter/material.dart';

import '../../notifications/finance_notification_contract.dart';

/// Per-bill notification overrides layered on top of Finance defaults.
///
/// Stores WHEN to notify (mini app concern) and WHICH TYPE to use.
/// The Hub manages HOW to notify (sound, channel, priority, etc.).
class BillNotificationProfile {
  final String billId;
  
  // WHEN to notify (mini app concern)
  final int reminderDaysBefore;
  final TimeOfDay? preferredTime;
  
  // WHICH notification type to use (Hub looks up delivery config)
  final String? typeOverride;
  
  // Content template
  final String templateKey;
  
  // Legacy fields (deprecated - Hub manages these now)
  final String? channelKey;
  final String? soundKey;

  const BillNotificationProfile({
    required this.billId,
    this.reminderDaysBefore = 3,
    this.preferredTime,
    this.typeOverride,
    this.templateKey = FinanceNotificationContract.templateBillDue,
    this.channelKey,
    this.soundKey,
  });

  BillNotificationProfile copyWith({
    String? billId,
    int? reminderDaysBefore,
    TimeOfDay? preferredTime,
    String? templateKey,
    String? channelKey,
    String? soundKey,
    String? typeOverride,
    bool clearPreferredTime = false,
    bool clearChannel = false,
    bool clearSound = false,
    bool clearTypeOverride = false,
  }) {
    return BillNotificationProfile(
      billId: billId ?? this.billId,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      preferredTime: clearPreferredTime ? null : (preferredTime ?? this.preferredTime),
      templateKey: templateKey ?? this.templateKey,
      channelKey: clearChannel ? null : (channelKey ?? this.channelKey),
      soundKey: clearSound ? null : (soundKey ?? this.soundKey),
      typeOverride: clearTypeOverride
          ? null
          : (typeOverride ?? this.typeOverride),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'billId': billId,
      'reminderDaysBefore': reminderDaysBefore,
      if (preferredTime != null) 'preferredTimeHour': preferredTime!.hour,
      if (preferredTime != null) 'preferredTimeMinute': preferredTime!.minute,
      'templateKey': templateKey,
      if (typeOverride != null && typeOverride!.isNotEmpty)
        'typeOverride': typeOverride,
      // Legacy fields (deprecated)
      if (channelKey != null && channelKey!.isNotEmpty) 'channelKey': channelKey,
      if (soundKey != null && soundKey!.isNotEmpty) 'soundKey': soundKey,
    };
  }

  factory BillNotificationProfile.fromJson(Map<String, dynamic> json) {
    final billId = (json['billId'] as String?)?.trim() ?? '';
    
    TimeOfDay? preferredTime;
    if (json['preferredTimeHour'] != null && json['preferredTimeMinute'] != null) {
      preferredTime = TimeOfDay(
        hour: json['preferredTimeHour'] as int,
        minute: json['preferredTimeMinute'] as int,
      );
    }
    
    return BillNotificationProfile(
      billId: billId,
      reminderDaysBefore: json['reminderDaysBefore'] as int? ?? 3,
      preferredTime: preferredTime,
      templateKey: (json['templateKey'] as String?)?.trim().isNotEmpty == true
          ? (json['templateKey'] as String).trim()
          : FinanceNotificationContract.templateBillDue,
      channelKey: (json['channelKey'] as String?)?.trim().isNotEmpty == true
          ? (json['channelKey'] as String).trim()
          : null,
      soundKey: (json['soundKey'] as String?)?.trim().isNotEmpty == true
          ? (json['soundKey'] as String).trim()
          : null,
      typeOverride:
          (json['typeOverride'] as String?)?.trim().isNotEmpty == true
          ? (json['typeOverride'] as String).trim()
          : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory BillNotificationProfile.fromJsonString(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is Map<String, dynamic>) {
      return BillNotificationProfile.fromJson(decoded);
    }
    if (decoded is Map) {
      return BillNotificationProfile.fromJson(decoded.cast<String, dynamic>());
    }
    throw const FormatException('Invalid bill profile JSON');
  }
}

