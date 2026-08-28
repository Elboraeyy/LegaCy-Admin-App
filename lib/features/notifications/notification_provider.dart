import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/core/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// A single notification item
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String category; // order, inventory, review, message, restock, finance, system
  final String? referenceId;
  final String? referenceType;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.referenceId,
    this.referenceType,
    required this.createdAt,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      category: json['category'] ?? 'system',
      referenceId: json['referenceId'],
      referenceType: json['referenceType'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      isRead: json['isRead'] == true,
    );
  }

  NotifCategory get notifCategory {
    switch (category) {
      case 'order': return NotifCategory.order;
      case 'inventory': return NotifCategory.inventory;
      case 'review': return NotifCategory.review;
      case 'message': return NotifCategory.message;
      case 'restock': return NotifCategory.restock;
      case 'finance': return NotifCategory.finance;
      default: return NotifCategory.system;
    }
  }

  IconData get icon {
    switch (category) {
      case 'order': return Icons.shopping_bag_rounded;
      case 'inventory': return Icons.warning_amber_rounded;
      case 'review': return Icons.star_rounded;
      case 'message': return Icons.mail_rounded;
      case 'restock': return Icons.notifications_active_rounded;
      case 'finance': return Icons.attach_money_rounded;
      default: return Icons.shield_rounded;
    }
  }

  Color get color {
    switch (category) {
      case 'order': return const Color(0xFF3B82F6);
      case 'inventory': return const Color(0xFFF59E0B);
      case 'review': return const Color(0xFFF59E0B);
      case 'message': return const Color(0xFF6366F1);
      case 'restock': return const Color(0xFF0EA5E9);
      case 'finance': return const Color(0xFF10B981);
      default: return const Color(0xFF0F766E);
    }
  }
}

/// Central provider for notification state & polling
class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  Timer? _pollTimer;
  String? _token;

  // Settings (persisted to SharedPreferences)
  Map<String, bool> _pushEnabled = {
    'order': true,
    'inventory': true,
    'review': true,
    'message': true,
    'restock': true,
    'finance': false,
    'system': false,
  };
  Map<String, bool> _soundEnabled = {
    'order': true,
    'inventory': true,
    'review': true,
    'message': true,
    'restock': true,
    'finance': false,
    'system': false,
  };
  Map<String, bool> _popupEnabled = {
    'order': true,
    'inventory': true,
    'review': true,
    'message': true,
    'restock': false,
    'finance': false,
    'system': false,
  };
  bool _globalEnabled = true;

  // Getters
  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;
  bool get globalEnabled => _globalEnabled;
  Map<String, bool> get pushEnabled => _pushEnabled;
  Map<String, bool> get soundEnabled => _soundEnabled;
  Map<String, bool> get popupEnabled => _popupEnabled;

  // Grouped notifications
  List<AppNotification> get todayNotifications {
    final now = DateTime.now();
    return _notifications.where((n) =>
      n.createdAt.year == now.year &&
      n.createdAt.month == now.month &&
      n.createdAt.day == now.day
    ).toList();
  }

  List<AppNotification> get yesterdayNotifications {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _notifications.where((n) =>
      n.createdAt.year == yesterday.year &&
      n.createdAt.month == yesterday.month &&
      n.createdAt.day == yesterday.day
    ).toList();
  }

  List<AppNotification> get earlierNotifications {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _notifications.where((n) =>
      n.createdAt.isBefore(DateTime(yesterday.year, yesterday.month, yesterday.day))
    ).toList();
  }

  Future<void> init(String? token) async {
    _token = token;
    await _loadSettings();
    if (token != null) {
      await fetchNotifications();
      _startPolling();

      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          final client = ApiClient(token: _token);
          await client.put('/api/admin/auth/fcm-token', body: {'fcmToken': fcmToken});
        }
      } catch (e) {
        // Ignore token error
      }

      FirebaseMessaging.onMessage.listen((message) {
        if (!_globalEnabled) return;

        // This only fires when app is in FOREGROUND.
        // Android does NOT auto-show notifications in foreground,
        // so WE must show it via local notifications.
        String catStr = message.data['category'] ?? 'system';

        NotifCategory category = NotifCategory.values.firstWhere(
          (e) => e.name == catStr,
          orElse: () => NotifCategory.system,
        );

        if (_pushEnabled[catStr] == true) {
          NotificationService.instance.show(
            id: message.hashCode,
            title: message.notification?.title ?? message.data['title'] ?? 'Notification',
            body: message.notification?.body ?? message.data['body'] ?? '',
            category: category,
            payload: message.data.toString(),
            silent: _soundEnabled[catStr] != true,
          );
        }
        
        // Refresh notifications list in UI
        fetchNotifications();
      });
    }
  }

  /// Fetch notifications from API
  Future<void> fetchNotifications() async {
    if (_token == null) return;
    _isLoading = _notifications.isEmpty;
    if (_isLoading) notifyListeners();

    try {
      final client = ApiClient(token: _token);
      final data = await client.get('/api/admin/auth/notifications');
      final list = (data['notifications'] as List?) ?? [];

      _notifications = list.map((j) => AppNotification.fromJson(j)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      // Silent fail - notifications are non-critical
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notifId) async {
    final idx = _notifications.indexWhere((n) => n.id == notifId);
    if (idx == -1) return;
    _notifications[idx].isRead = true;
    notifyListeners();

    if (_token != null) {
      try {
        final client = ApiClient(token: _token);
        await client.put('/api/admin/auth/notifications/$notifId', body: {'isRead': true});
      } catch (_) {}
    }
  }

  /// Mark all as read
  Future<void> markAllAsRead() async {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();

    if (_token != null) {
      try {
        final client = ApiClient(token: _token);
        await client.put('/api/admin/auth/notifications/read-all', body: {});
      } catch (_) {}
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notifId) async {
    _notifications.removeWhere((n) => n.id == notifId);
    notifyListeners();

    if (_token != null) {
      try {
        final client = ApiClient(token: _token);
        await client.delete('/api/admin/auth/notifications/$notifId');
      } catch (_) {}
    }
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    _notifications.clear();
    notifyListeners();

    if (_token != null) {
      try {
        final client = ApiClient(token: _token);
        await client.delete('/api/admin/auth/notifications/clear');
      } catch (_) {}
    }
  }

  // Settings management
  void setGlobalEnabled(bool value) {
    _globalEnabled = value;
    _saveSettings();
    notifyListeners();
  }

  void setPushEnabled(String category, bool value) {
    _pushEnabled[category] = value;
    _saveSettings();
    notifyListeners();
  }

  void setSoundEnabled(String category, bool value) {
    _soundEnabled[category] = value;
    _saveSettings();
    notifyListeners();
  }

  void setPopupEnabled(String category, bool value) {
    _popupEnabled[category] = value;
    _saveSettings();
    notifyListeners();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchNotifications();
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _globalEnabled = prefs.getBool('notif_global') ?? true;

      for (final cat in ['order', 'inventory', 'review', 'message', 'restock', 'finance', 'system']) {
        _pushEnabled[cat] = prefs.getBool('notif_push_$cat') ?? _pushEnabled[cat]!;
        _soundEnabled[cat] = prefs.getBool('notif_sound_$cat') ?? _soundEnabled[cat]!;
        _popupEnabled[cat] = prefs.getBool('notif_popup_$cat') ?? _popupEnabled[cat]!;
      }
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_global', _globalEnabled);

      for (final cat in ['order', 'inventory', 'review', 'message', 'restock', 'finance', 'system']) {
        await prefs.setBool('notif_push_$cat', _pushEnabled[cat]!);
        await prefs.setBool('notif_sound_$cat', _soundEnabled[cat]!);
        await prefs.setBool('notif_popup_$cat', _popupEnabled[cat]!);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
