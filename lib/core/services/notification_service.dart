import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification categories matching the admin dashboard
enum NotifCategory {
  order,
  inventory,
  review,
  message,
  restock,
  finance,
  system,
}

/// Service that manages local push notifications with custom channels and sounds
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Stream controller for notification taps
  final StreamController<String?> onNotificationTap = StreamController<String?>.broadcast();

  bool _initialized = false;

  /// Channel definitions per category
  static const Map<NotifCategory, _ChannelDef> _channels = {
    NotifCategory.order: _ChannelDef(
      id: 'legacy_orders',
      name: 'Orders',
      description: 'New order alerts and status updates',
      importance: Importance.high,
      sound: 'order_sound',
    ),
    NotifCategory.inventory: _ChannelDef(
      id: 'legacy_inventory',
      name: 'Inventory Alerts',
      description: 'Low stock and out-of-stock warnings',
      importance: Importance.high,
      sound: 'alert_sound',
    ),
    NotifCategory.review: _ChannelDef(
      id: 'legacy_reviews',
      name: 'Reviews',
      description: 'New product reviews',
      importance: Importance.defaultImportance,
      sound: 'chime_sound',
    ),
    NotifCategory.message: _ChannelDef(
      id: 'legacy_messages',
      name: 'Messages',
      description: 'Contact form messages',
      importance: Importance.high,
      sound: 'message_sound',
    ),
    NotifCategory.restock: _ChannelDef(
      id: 'legacy_restock',
      name: 'Restock Requests',
      description: 'Back-in-stock waitlist requests',
      importance: Importance.defaultImportance,
      sound: 'bell_sound',
    ),
    NotifCategory.finance: _ChannelDef(
      id: 'legacy_finance',
      name: 'Finance',
      description: 'Payment and financial alerts',
      importance: Importance.defaultImportance,
      sound: 'coin_sound',
    ),
    NotifCategory.system: _ChannelDef(
      id: 'legacy_system',
      name: 'System',
      description: 'System and security alerts',
      importance: Importance.low,
    ),
  };

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          onNotificationTap.add(response.payload);
        },
      );

      // Create all notification channels on Android
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // Request notification permission (Android 13+)
        await androidPlugin.requestNotificationsPermission();

        for (final entry in _channels.entries) {
          final def = entry.value;
          await androidPlugin.createNotificationChannel(
            AndroidNotificationChannel(
              def.id,
              def.name,
              description: def.description,
              importance: def.importance,
              enableVibration: true,
              playSound: true,
              showBadge: true,
              enableLights: true,
              ledColor: const Color(0xFF12403C),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('NotificationService initialization warning: $e');
    }

    _initialized = true;
  }

  /// Show a notification
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required NotifCategory category,
    String? payload,
    bool silent = false,
  }) async {
    if (!_initialized) await initialize();

    final channelDef = _channels[category]!;

    final androidDetails = AndroidNotificationDetails(
      channelDef.id,
      channelDef.name,
      channelDescription: channelDef.description,
      importance: silent ? Importance.low : channelDef.importance,
      priority: silent ? Priority.low : Priority.high,
      showWhen: true,
      enableVibration: !silent,
      playSound: !silent,
      visibility: NotificationVisibility.public,
      category: _getAndroidCategory(category),
      styleInformation: BigTextStyleInformation(body),
      color: const Color(0xFF12403C),
      ledColor: const Color(0xFFD4AF37),
      ledOnMs: 1000,
      ledOffMs: 500,
      ticker: title,
      autoCancel: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
      payload: payload,
    );
  }

  /// Cancel a specific notification
  Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  AndroidNotificationCategory? _getAndroidCategory(NotifCategory cat) {
    switch (cat) {
      case NotifCategory.order:
        return AndroidNotificationCategory.status;
      case NotifCategory.message:
        return AndroidNotificationCategory.message;
      case NotifCategory.system:
        return AndroidNotificationCategory.system;
      default:
        return AndroidNotificationCategory.event;
    }
  }

  void dispose() {
    onNotificationTap.close();
  }
}

class _ChannelDef {
  final String id;
  final String name;
  final String description;
  final Importance importance;
  final String? sound;

  const _ChannelDef({
    required this.id,
    required this.name,
    required this.description,
    required this.importance,
    this.sound,
  });
}
