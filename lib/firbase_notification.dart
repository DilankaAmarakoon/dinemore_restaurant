import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_restart.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  bool _isInitialized = false;
  String? _cachedToken;
  bool _isAndroidTV = false;
  bool _hasGooglePlayServices = false;
  bool _fcmAvailable = false;

  // Fallback notification system
  Timer? _pollingTimer;
  String? _deviceId;
  String? _fallbackServerUrl;
  int _pollingIntervalSeconds = 30;
  int _lastNotificationCheck = 0;

  /// Initialize the notification service with optional fallback server
  ///
  /// [context] - BuildContext for UI operations
  /// [fallbackServerUrl] - Optional server URL for polling-based notifications
  /// [pollingInterval] - How often to check for notifications (default: 30 seconds)
  Future<void> initialize(BuildContext context, {
    String? fallbackServerUrl,
    int pollingInterval = 30,
  }) async {
    if (_isInitialized) {
      debugPrint('🔔 NotificationService already initialized');
      return;
    }

    _fallbackServerUrl = fallbackServerUrl;
    _pollingIntervalSeconds = pollingInterval;

    try {
      debugPrint('🔔 Initializing NotificationService...');
      debugPrint('   - Fallback Server: ${_fallbackServerUrl ?? "None"}');
      debugPrint('   - Polling Interval: ${_pollingIntervalSeconds}s');

      // Generate or retrieve device ID
      _deviceId = await _getOrCreateDeviceId();
      debugPrint('📱 Device ID: $_deviceId');

      // Check device compatibility
      await _checkDeviceCompatibility();

      // Try FCM first (will likely fail on Android TV)
      bool fcmSuccess = await _tryInitializeFCM(context);

      if (!fcmSuccess) {
        debugPrint('🔄 FCM failed, setting up fallback notification system...');
        await _initializeFallbackSystem(context);
      }

      _isInitialized = true;
      debugPrint('✅ NotificationService initialized');
      debugPrint('   - FCM Available: $_fcmAvailable');
      debugPrint('   - Fallback Active: ${_pollingTimer != null}');

    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing notifications: $e');
      debugPrint('Stack trace: $stackTrace');
      await _logDetailedError(e, stackTrace);
      // Don't rethrow - let app continue
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? existingId = prefs.getString('device_id');

      if (existingId != null && existingId.isNotEmpty) {
        return existingId;
      }

      // Generate new device ID
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String platform = Platform.operatingSystem;
      String deviceId = '${platform}_tv_$timestamp';

      await prefs.setString('device_id', deviceId);
      debugPrint('📱 Generated new device ID: $deviceId');

      return deviceId;
    } catch (e) {
      debugPrint('❌ Error with device ID: $e');
      // Fallback to timestamp-based ID
      return 'android_tv_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<bool> _tryInitializeFCM(BuildContext context) async {
    try {
      // Check if Firebase Messaging is supported
      bool isSupported = await _messaging.isSupported();
      if (!isSupported) {
        debugPrint('❌ Firebase Messaging not supported');
        return false;
      }

      debugPrint('✅ Firebase Messaging is supported, testing token...');

      // Try to get FCM token with a single quick attempt
      String? token = await _tryGetTokenWithTimeout(timeoutSeconds: 15);
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        _fcmAvailable = true;
        _setupMessageHandlers(context);
        debugPrint('✅ FCM working! Token: ${token.substring(0, 20)}...');
        await logEvent('fcm_success');
        return true;
      } else {
        debugPrint('❌ FCM token failed - will use fallback');
        await logEvent('fcm_failed_using_fallback');
        return false;
      }

    } catch (e) {
      debugPrint('❌ FCM initialization failed: $e');
      await logEvent('fcm_initialization_failed', parameters: {
        'error': e.toString(),
        'is_android_tv': _isAndroidTV ? 'true' : 'false',
      });
      return false;
    }
  }

  Future<String?> _tryGetTokenWithTimeout({int timeoutSeconds = 15}) async {
    try {
      debugPrint('🔑 Trying FCM token with ${timeoutSeconds}s timeout...');

      String? token = await _messaging.getToken().timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          debugPrint('⏰ FCM token request timed out');
          return null;
        },
      );

      return token;
    } catch (e) {
      debugPrint('❌ FCM token error: $e');
      return null;
    }
  }

  Future<void> _initializeFallbackSystem(BuildContext context) async {
    try {
      debugPrint('🔧 Setting up fallback notification system...');

      if (_fallbackServerUrl == null) {
        debugPrint('⚠️ No fallback server URL provided - notifications disabled');
        return;
      }

      if (_deviceId == null) {
        debugPrint('❌ No device ID available for fallback system');
        return;
      }

      // Register device with fallback server
      bool registered = await _registerDeviceWithFallbackServer();

      if (registered) {
        // Start polling for notifications
        _startPollingForNotifications(context);
        debugPrint('✅ Fallback notification system initialized');
        await logEvent('fallback_notification_initialized');
      } else {
        debugPrint('❌ Failed to register with fallback server');
      }

    } catch (e) {
      debugPrint('❌ Error setting up fallback system: $e');
    }
  }

  Future<bool> _registerDeviceWithFallbackServer() async {
    try {
      debugPrint('📡 Registering device with fallback server...');

      final response = await http.post(
        Uri.parse('$_fallbackServerUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': _deviceId,
          'device_type': 'android_tv',
          'device_model': 'H96_Max_M1', // You can make this dynamic
          'app_version': '1.0.0',
          'platform': Platform.operatingSystem,
          'registration_time': DateTime.now().toIso8601String(),
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('✅ Device registered with fallback server');
        return true;
      } else {
        debugPrint('⚠️ Failed to register device: ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error registering device: $e');
      return false;
    }
  }

  void _startPollingForNotifications(BuildContext context) {
    _lastNotificationCheck = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    _pollingTimer = Timer.periodic(Duration(seconds: _pollingIntervalSeconds), (timer) async {
      await _checkForNewNotifications(context);
    });

    debugPrint('🔄 Started polling for notifications every ${_pollingIntervalSeconds}s');
  }

  Future<void> _checkForNewNotifications(BuildContext context) async {
    try {
      int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final response = await http.get(
        Uri.parse('$_fallbackServerUrl/notifications/$_deviceId?since=$_lastNotificationCheck'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final notifications = data['notifications'] as List?;

        if (notifications != null && notifications.isNotEmpty) {
          debugPrint('📬 Found ${notifications.length} new notifications');

          for (var notification in notifications) {
            await _handleFallbackNotification(context, notification);
          }

          // Mark notifications as read
          await _markNotificationsAsRead(notifications);
        }

        _lastNotificationCheck = currentTime;
      } else if (response.statusCode != 404) {
        // 404 is fine (no new notifications), other errors are concerning
        debugPrint('⚠️ Notification check failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error checking for notifications: $e');
      // Don't spam logs for network errors
    }
  }

  Future<void> _handleFallbackNotification(BuildContext context, Map<String, dynamic> notification) async {
    debugPrint('📨 Handling fallback notification: ${notification['title']}');
    debugPrint('   - ID: ${notification['id']}');
    debugPrint('   - Action: ${notification['action']}');

    await logEvent('fallback_notification_received', parameters: {
      'notification_id': notification['id']?.toString() ?? 'unknown',
      'title': notification['title']?.toString() ?? 'no_title',
      'action': notification['action']?.toString() ?? 'no_action',
    });

    // Handle different notification types
    String? action = notification['action'];
    Map<String, dynamic>? data = notification['data'];

    if (action == 'content_refresh' ||
        data?['refresh'] == 'true' ||
        data?['action'] == 'content_refresh') {
      _handleContentRefresh(context);
    } else if (action == 'app_restart') {
      _handleAppRestart(context);
    } else if (action == 'custom') {
      _handleCustomAction(context, data);
    }
  }

  Future<void> _markNotificationsAsRead(List notifications) async {
    try {
      final notificationIds = notifications.map((n) => n['id']).toList();

      await http.post(
        Uri.parse('$_fallbackServerUrl/notifications/mark-read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': _deviceId,
          'notification_ids': notificationIds,
        }),
      ).timeout(Duration(seconds: 5));

    } catch (e) {
      debugPrint('❌ Error marking notifications as read: $e');
    }
  }

  Future<void> _checkDeviceCompatibility() async {
    try {
      if (Platform.isAndroid) {
        try {
          DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
          AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

          _isAndroidTV = androidInfo.systemFeatures.contains('android.software.leanback') ||
              androidInfo.systemFeatures.contains('android.hardware.type.television');
          _hasGooglePlayServices = androidInfo.isPhysicalDevice;

          debugPrint('🖥️ Device Info:');
          debugPrint('   - Model: ${androidInfo.model}');
          debugPrint('   - Android Version: ${androidInfo.version.release}');
          debugPrint('   - Is Android TV: $_isAndroidTV');
          debugPrint('   - Has Google Play Services: $_hasGooglePlayServices');

          await logEvent('device_compatibility_check', parameters: {
            'model': androidInfo.model,
            'android_version': androidInfo.version.release,
            'is_android_tv': _isAndroidTV ? 'true' : 'false',
            'has_google_play': _hasGooglePlayServices ? 'true' : 'false',
            'sdk_int': androidInfo.version.sdkInt.toString(),
          });
        } catch (deviceInfoError) {
          debugPrint('❌ Error getting device info: $deviceInfoError');
          _isAndroidTV = true;
          _hasGooglePlayServices = true;
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking device compatibility: $e');
      _isAndroidTV = true;
      _hasGooglePlayServices = true;
    }
  }

  void _setupMessageHandlers(BuildContext context) {
    if (!_fcmAvailable) return;

    debugPrint('🔧 Setting up FCM message handlers...');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📱 Received FCM foreground message: ${message.messageId}');
      _handleFCMMessage(context, message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 App opened from FCM notification: ${message.messageId}');
      _handleFCMMessage(context, message);
    });

    _messaging.onTokenRefresh.listen((String token) {
      debugPrint('🔄 FCM Token refreshed');
      _cachedToken = token;
      logEvent('fcm_token_refreshed');
    });
  }

  void _handleFCMMessage(BuildContext context, RemoteMessage message) {
    debugPrint('📨 Handling FCM message: ${message.notification?.title}');

    logEvent('fcm_notification_received', parameters: {
      'message_id': message.messageId ?? 'unknown',
      'has_notification': (message.notification != null).toString(),
      'has_data': message.data.isNotEmpty.toString(),
    });

    if (message.data['action'] == 'content_refresh' ||
        message.data['refresh'] == 'true') {
      _handleContentRefresh(context);
    }
  }

  void _handleContentRefresh(BuildContext context) {
    debugPrint('🔄 Handling content refresh from notification');

    logEvent('content_refresh_triggered', parameters: {
      'source': _fcmAvailable ? 'fcm' : 'fallback',
    });

    RestartWidget.restartApp(context);
  }

  void _handleAppRestart(BuildContext context) {
    debugPrint('🔄 Handling app restart from notification');

    logEvent('app_restart_triggered', parameters: {
      'source': _fcmAvailable ? 'fcm' : 'fallback',
    });

    RestartWidget.restartApp(context);
  }

  void _handleCustomAction(BuildContext context, Map<String, dynamic>? data) {
    debugPrint('🎯 Handling custom action: $data');

    logEvent('custom_action_triggered', parameters: {
      'source': _fcmAvailable ? 'fcm' : 'fallback',
      'action_data': data?.toString() ?? 'empty',
    });

    // You can add custom logic here based on the action data
    // For example:
    // - Navigate to specific screens
    // - Update app settings
    // - Trigger specific functions
  }

  Future<void> _logDetailedError(dynamic error, StackTrace stackTrace) async {
    String errorString = error.toString();

    await logEvent('notification_service_error', parameters: {
      'error_message': errorString,
      'is_android_tv': _isAndroidTV ? 'true' : 'false',
      'has_google_play': _hasGooglePlayServices ? 'true' : 'false',
      'fcm_available': _fcmAvailable ? 'true' : 'false',
    });
  }

  Future<void> logEvent(String eventName, {Map<String, Object>? parameters}) async {
    try {
      await _analytics.logEvent(name: eventName, parameters: parameters);
      debugPrint('📊 Analytics event logged: $eventName');
    } catch (e) {
      debugPrint('❌ Error logging analytics event $eventName: $e');
    }
  }

  /// Get notification token (FCM token or device ID for fallback)
  Future<String?> getToken() async {
    if (_fcmAvailable && _cachedToken != null) {
      return _cachedToken;
    } else if (_deviceId != null) {
      return _deviceId;
    }
    return null;
  }

  /// Get current notification method
  String getNotificationMethod() {
    if (_fcmAvailable) return 'FCM';
    if (_pollingTimer != null) return 'Fallback Polling';
    return 'None';
  }

  /// Test notification connectivity
  Future<Map<String, dynamic>> testConnectivity() async {
    Map<String, dynamic> results = {
      'timestamp': DateTime.now().toIso8601String(),
      'fcm_available': _fcmAvailable,
      'fallback_active': _pollingTimer != null,
      'device_id': _deviceId,
      'tests': <String, dynamic>{},
    };

    // Test FCM if available
    if (_fcmAvailable) {
      try {
        String? token = await _tryGetTokenWithTimeout(timeoutSeconds: 5);
        results['tests']['fcm_token'] = token != null;
      } catch (e) {
        results['tests']['fcm_token'] = false;
      }
    }

    // Test fallback server if configured
    if (_fallbackServerUrl != null) {
      try {
        final response = await http.get(
          Uri.parse('$_fallbackServerUrl/health'),
        ).timeout(Duration(seconds: 5));
        results['tests']['fallback_server'] = response.statusCode == 200;
      } catch (e) {
        results['tests']['fallback_server'] = false;
      }
    }

    debugPrint('🔍 Connectivity test results: $results');
    return results;
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isFCMAvailable => _fcmAvailable;
  bool get isAndroidTV => _isAndroidTV;
  String? get deviceId => _deviceId;
  String? get cachedToken => _cachedToken;

  /// Dispose resources
  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Reinitialize the service
  Future<void> reinitialize(BuildContext context, {
    String? fallbackServerUrl,
    int pollingInterval = 30,
  }) async {
    dispose();
    _isInitialized = false;
    _fcmAvailable = false;
    _cachedToken = null;
    await initialize(context,
      fallbackServerUrl: fallbackServerUrl,
      pollingInterval: pollingInterval,
    );
  }
}