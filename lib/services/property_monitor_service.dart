import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/pages/itemDetails.dart';
import 'package:zcanopy/services/gateway_api.dart';

class PropertyMonitorService {
  static final PropertyMonitorService _instance =
      PropertyMonitorService._internal();
  factory PropertyMonitorService() => _instance;
  PropertyMonitorService._internal();

  Timer? _timer;
  static const _defaultLat = 0.3476;
  static const _defaultLng = 32.5825;
  static const _pollInterval = Duration(seconds: 30);
  static GlobalKey<NavigatorState>? navigatorKey;
  static VoidCallback? onCountUpdated;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (!Hive.isBoxOpen('propertyMonitor')) {
      await Hive.openBox('propertyMonitor');
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('taskBar');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _showPersistentNotification(count: 0);
  }

  void startMonitoring() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => _checkNearby());
    _checkNearby();
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkNearby() async {
    try {
      final lat = _getLatitude();
      final lng = _getLongitude();
      final data = await GatewayApi().getNearbyProperties(
        lat: lat,
        long: lng,
        radiusKm: 10,
        limit: 20,
      );
      final properties = _extractProperties(data);
      final count = properties.length;

      final box = Hive.box('propertyMonitor');
      await box.put('nearbyCount', count);
      await box.put('nearbyList', properties);

      if (count > 0) {
        try { FlutterAppBadger.updateBadgeCount(count); } catch (_) {}
      } else {
        try { FlutterAppBadger.removeBadge(); } catch (_) {}
      }

      onCountUpdated?.call();
      await _showPersistentNotification(count: count);
    } catch (e) {
      debugPrint('PropertyMonitor checkNearby error: $e');
    }
  }

  static List<Map<String, dynamic>> _extractProperties(Map<String, dynamic> data) {
    final candidates = data['nearByProperties'] ?? data['properties'] ?? data['results'];
    if (candidates is List) {
      return candidates
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  double _getLatitude() {
    try {
      final loc = Hive.box('myStore').get('location');
      if (loc is Map && loc['latitude'] != null) {
        return (loc['latitude'] as num).toDouble();
      }
    } catch (_) {}
    return _defaultLat;
  }

  double _getLongitude() {
    try {
      final loc = Hive.box('myStore').get('location');
      if (loc is Map && loc['longitude'] != null) {
        return (loc['longitude'] as num).toDouble();
      }
    } catch (_) {}
    return _defaultLng;
  }

  Future<void> _onNotificationTapped(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final itemId = payload;
      if (itemId.isNotEmpty && navigatorKey?.currentState != null) {
        navigatorKey!.currentState!.push(
          MaterialPageRoute(
            builder: (_) => PropertyDetailsPage(
              itemID: itemId,
              revealContact: false,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Notification tap handler error: $e');
    }
  }

  Future<void> _showPersistentNotification({required int count}) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'property_monitor_channel',
      'Property Monitor',
      channelDescription: 'Shows nearby property count',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      icon: 'taskBar',
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    final title = count > 0 ? 'Nearby Properties' : 'Watching for nearby properties';
    final body = count > 0 ? '$count new property${count == 1 ? '' : 'ies'} available nearby' : 'No new properties nearby';

    try {
      await _notificationsPlugin.show(
        5001,
        title,
        body,
        details,
        payload: count > 0 ? 'monitor' : null,
      );
    } catch (_) {}
  }

  Future<int> getStoredCount() async {
    final box = Hive.box('propertyMonitor');
    return (box.get('nearbyCount') as int?) ?? 0;
  }
}
