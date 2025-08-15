// import 'package:firebase_analytics/firebase_analytics.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'dart:io';
// import 'app_restart.dart';
//
// class NotificationService {
//   static final NotificationService _instance = NotificationService._internal();
//   factory NotificationService() => _instance;
//   NotificationService._internal();
//
//   final FirebaseMessaging _messaging = FirebaseMessaging.instance;
//   final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
//
//   bool _isInitialized = false;
//   String? _cachedToken;
//   bool _isAndroidTV = false;
//   bool _hasGooglePlayServices = false;
//
//   Future<void> initialize(BuildContext context) async {
//     if (_isInitialized) {
//       debugPrint('🔔 NotificationService already initialized');
//       return;
//     }
//
//     try {
//       debugPrint('🔔 Initializing NotificationService...');
//
//       // First, check device compatibility
//       await _checkDeviceCompatibility();
//
//       // Check if Firebase Messaging is supported
//       bool isSupported = await _messaging.isSupported();
//       if (!isSupported) {
//         debugPrint('❌ Firebase Messaging not supported on this device');
//         await logEvent('fcm_not_supported', parameters: {
//           'is_android_tv': _isAndroidTV,
//           'has_google_play': _hasGooglePlayServices,
//         });
//         return;
//       }
//
//       debugPrint('✅ Firebase Messaging is supported');
//
//       // For Android TV, we need to handle permissions differently
//       if (_isAndroidTV) {
//         await _initializeForAndroidTV(context);
//       } else {
//         await _initializeForMobile(context);
//       }
//
//     } catch (e, stackTrace) {
//       debugPrint('❌ Error initializing notifications: $e');
//       debugPrint('Stack trace: $stackTrace');
//       await _logDetailedError(e, stackTrace);
//       // Don't rethrow - let app continue without notifications
//     }
//   }
//
//   Future<void> _checkDeviceCompatibility() async {
//     try {
//       if (Platform.isAndroid) {
//         try {
//           DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//           AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
//
//           // Check if it's Android TV
//           _isAndroidTV = androidInfo.systemFeatures.contains('android.software.leanback') ||
//               androidInfo.systemFeatures.contains('android.hardware.type.television');
//
//           // For now, assume Google Play Services availability for physical devices
//           _hasGooglePlayServices = androidInfo.isPhysicalDevice;
//
//           debugPrint('🖥️ Device Info:');
//           debugPrint('   - Model: ${androidInfo.model}');
//           debugPrint('   - Android Version: ${androidInfo.version.release}');
//           debugPrint('   - Is Android TV: $_isAndroidTV');
//           debugPrint('   - Has Google Play Services: $_hasGooglePlayServices');
//           debugPrint('   - System Features: ${androidInfo.systemFeatures.take(5).join(', ')}...');
//
//           await logEvent('device_compatibility_check', parameters: {
//             'model': androidInfo.model,
//             'android_version': androidInfo.version.release,
//             'is_android_tv': _isAndroidTV ? 'true' : 'false',
//             'has_google_play': _hasGooglePlayServices ? 'true' : 'false',
//             'sdk_int': androidInfo.version.sdkInt,
//           });
//         } catch (deviceInfoError) {
//           debugPrint('❌ Error getting device info: $deviceInfoError');
//           // Fallback: assume it's Android TV based on common TV box characteristics
//           _isAndroidTV = true; // Since you're testing on H96 Max M1
//           _hasGooglePlayServices = true; // Assume true for now
//
//           debugPrint('🖥️ Using fallback device detection:');
//           debugPrint('   - Assumed Android TV: $_isAndroidTV');
//           debugPrint('   - Assumed Google Play Services: $_hasGooglePlayServices');
//         }
//       }
//     } catch (e) {
//       debugPrint('❌ Error checking device compatibility: $e');
//       // Final fallback
//       _isAndroidTV = true;
//       _hasGooglePlayServices = true;
//     }
//   }
//
//   Future<void> _initializeForAndroidTV(BuildContext context) async {
//     debugPrint('🖥️ Initializing for Android TV...');
//
//     if (!_hasGooglePlayServices) {
//       debugPrint('❌ Google Play Services not available - FCM won\'t work');
//       await logEvent('fcm_gps_not_available');
//       return;
//     }
//
//     // For Android TV, permissions might not work as expected
//     // Try to get token directly with longer timeouts
//     await _initializeTokenWithRetry(maxRetries: 5, baseTimeoutSeconds: 30);
//
//     if (_cachedToken != null) {
//       _setupMessageHandlers(context);
//       _isInitialized = true;
//       debugPrint('✅ NotificationService initialized for Android TV');
//       await logEvent('fcm_android_tv_initialized');
//     } else {
//       debugPrint('❌ Failed to initialize FCM on Android TV');
//       await logEvent('fcm_android_tv_failed');
//     }
//   }
//
//   Future<void> _initializeForMobile(BuildContext context) async {
//     debugPrint('📱 Initializing for Mobile device...');
//
//     // Request permissions first
//     NotificationSettings settings = await _messaging.requestPermission(
//       alert: true,
//       announcement: false,
//       badge: true,
//       carPlay: false,
//       criticalAlert: false,
//       provisional: false,
//       sound: true,
//     );
//
//     debugPrint('🔔 Permission status: ${settings.authorizationStatus}');
//
//     if (settings.authorizationStatus == AuthorizationStatus.authorized ||
//         settings.authorizationStatus == AuthorizationStatus.provisional) {
//
//       await _initializeTokenWithRetry();
//       _setupMessageHandlers(context);
//       _isInitialized = true;
//       debugPrint('✅ NotificationService initialized for Mobile');
//
//       await logEvent('fcm_mobile_initialized', parameters: {
//         'permission_status': settings.authorizationStatus.name,
//       });
//     } else {
//       debugPrint('❌ Notification permission denied');
//       await logEvent('fcm_permission_denied', parameters: {
//         'permission_status': settings.authorizationStatus.name,
//       });
//     }
//   }
//
//   Future<void> _initializeTokenWithRetry({int maxRetries = 3, int baseTimeoutSeconds = 10}) async {
//     for (int attempt = 1; attempt <= maxRetries; attempt++) {
//       try {
//         debugPrint('🔔 Attempting to get FCM token (attempt $attempt/$maxRetries)');
//
//         // Increase timeout for Android TV
//         int timeoutSeconds = baseTimeoutSeconds + (attempt * (_isAndroidTV ? 10 : 5));
//
//         String? token = await _messaging.getToken().timeout(
//           Duration(seconds: timeoutSeconds),
//           onTimeout: () {
//             debugPrint('⏰ Token request timed out after ${timeoutSeconds}s');
//             return null;
//           },
//         );
//
//         if (token != null && token.isNotEmpty) {
//           _cachedToken = token;
//           debugPrint('✅ FCM Token obtained: ${token.substring(0, 20)}...');
//           debugPrint('📄 Full token length: ${token.length} characters');
//
//           await logEvent('fcm_token_retrieved', parameters: {
//             'attempt': attempt.toString(),
//             'success': 'true',
//             'is_android_tv': _isAndroidTV ? 'true' : 'false',
//             'timeout_used': timeoutSeconds.toString(),
//             'token_length': token.length.toString(),
//           });
//           return;
//         } else {
//           debugPrint('❌ FCM token is null or empty (attempt $attempt)');
//         }
//       } catch (e) {
//         debugPrint('❌ Error getting FCM token (attempt $attempt): $e');
//         debugPrint('   Error type: ${e.runtimeType}');
//
//         if (attempt == maxRetries) {
//           await logEvent('fcm_token_failed', parameters: {
//             'attempts': maxRetries.toString(),
//             'error': e.toString(),
//             'error_type': e.runtimeType.toString(),
//             'is_android_tv': _isAndroidTV ? 'true' : 'false',
//           });
//         }
//
//         // Wait before retry (exponential backoff)
//         if (attempt < maxRetries) {
//           int delaySeconds = attempt * (_isAndroidTV ? 5 : 2);
//           debugPrint('⏳ Waiting ${delaySeconds}s before retry...');
//           await Future.delayed(Duration(seconds: delaySeconds));
//         }
//       }
//     }
//
//     debugPrint('❌ Failed to get FCM token after $maxRetries attempts');
//   }
//
//   void _setupMessageHandlers(BuildContext context) {
//     debugPrint('🔧 Setting up message handlers...');
//
//     // Handle messages when app is in foreground
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       debugPrint('📱 Received foreground message: ${message.messageId}');
//       _handleMessage(context, message);
//     });
//
//     // Handle messages when app is opened from notification
//     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//       debugPrint('📱 App opened from notification: ${message.messageId}');
//       _handleMessage(context, message);
//     });
//
//     // Handle token refresh
//     _messaging.onTokenRefresh.listen((String token) {
//       debugPrint('🔄 FCM Token refreshed');
//       _cachedToken = token;
//       logEvent('fcm_token_refreshed', parameters: {
//         'is_android_tv': _isAndroidTV,
//         'new_token_length': token.length,
//       });
//     });
//
//     debugPrint('✅ Message handlers set up successfully');
//   }
//
//   void _handleMessage(BuildContext context, RemoteMessage message) {
//     debugPrint('📨 Handling message: ${message.notification?.title}');
//     debugPrint('   - Message ID: ${message.messageId}');
//     debugPrint('   - Data: ${message.data}');
//
//     // Log message received event
//     logEvent('notification_received', parameters: {
//       'message_id': message.messageId ?? 'unknown',
//       'has_notification': message.notification != null,
//       'has_data': message.data.isNotEmpty,
//       'is_android_tv': _isAndroidTV,
//       'notification_title': message.notification?.title ?? 'no_title',
//     });
//
//     // Check if this is a content refresh notification
//     if (message.data['action'] == 'content_refresh' ||
//         message.data['refresh'] == 'true') {
//       _handleContentRefresh(context);
//     }
//   }
//
//   void _handleContentRefresh(BuildContext context) {
//     debugPrint('🔄 Handling content refresh from notification');
//
//     logEvent('content_refresh_triggered', parameters: {
//       'source': 'notification',
//       'is_android_tv': _isAndroidTV,
//     });
//
//     // Restart the app to refresh content
//     RestartWidget.restartApp(context);
//   }
//
//   Future<void> _logDetailedError(dynamic error, StackTrace stackTrace) async {
//     String errorString = error.toString();
//
//     // Check for specific error patterns
//     Map<String, bool> errorPatterns = {
//       'authentication_failed': errorString.toLowerCase().contains('authentication'),
//       'network_error': errorString.toLowerCase().contains('network') ||
//           errorString.toLowerCase().contains('timeout'),
//       'service_unavailable': errorString.toLowerCase().contains('service') ||
//           errorString.toLowerCase().contains('unavailable'),
//       'permission_denied': errorString.toLowerCase().contains('permission'),
//     };
//
//     await logEvent('fcm_detailed_error', parameters: {
//       'error_message': errorString,
//       'is_android_tv': _isAndroidTV,
//       'has_google_play': _hasGooglePlayServices,
//       ...errorPatterns,
//     });
//
//     // Provide specific troubleshooting hints
//     if (errorString.contains('AUTHENTICATION_FAILED')) {
//       debugPrint('🚨 Firebase authentication failed. Please check:');
//       debugPrint('   - google-services.json is correct');
//       debugPrint('   - Package name matches Firebase project');
//       debugPrint('   - SHA-1 fingerprint is added to Firebase Console');
//     } else if (errorString.toLowerCase().contains('service') && _isAndroidTV) {
//       debugPrint('🚨 Service error on Android TV. This might be due to:');
//       debugPrint('   - Missing Google Play Services');
//       debugPrint('   - Outdated Google Play Services version');
//       debugPrint('   - TV box manufacturer restrictions');
//     }
//   }
//
//   Future<void> logEvent(String eventName, {Map<String, Object>? parameters}) async {
//     try {
//       await _analytics.logEvent(name: eventName, parameters: parameters);
//       debugPrint('📊 Analytics event logged: $eventName');
//     } catch (e) {
//       debugPrint('❌ Error logging analytics event $eventName: $e');
//     }
//   }
//
//   Future<String?> getToken() async {
//     // Return cached token if available
//     if (_cachedToken != null && _cachedToken!.isNotEmpty) {
//       debugPrint('📋 Returning cached token: ${_cachedToken!.substring(0, 20)}...');
//       return _cachedToken;
//     }
//
//     debugPrint('🔄 Getting fresh FCM token...');
//
//     try {
//       // Use longer timeout for Android TV
//       int timeoutSeconds = _isAndroidTV ? 30 : 15;
//
//       String? token = await _messaging.getToken().timeout(
//         Duration(seconds: timeoutSeconds),
//         onTimeout: () {
//           debugPrint('⏰ Get token timed out after ${timeoutSeconds}s');
//           return null;
//         },
//       );
//
//       if (token != null && token.isNotEmpty) {
//         _cachedToken = token;
//         debugPrint('✅ Fresh token obtained: ${token.substring(0, 20)}...');
//       } else {
//         debugPrint('❌ Fresh token is null or empty');
//       }
//
//       return token;
//     } catch (e) {
//       debugPrint('❌ Error getting FCM token: $e');
//       await logEvent('get_token_error', parameters: {
//         'error': e.toString(),
//         'is_android_tv': _isAndroidTV,
//       });
//       return null;
//     }
//   }
//
//   Future<void> deleteToken() async {
//     try {
//       await _messaging.deleteToken();
//       _cachedToken = null;
//       debugPrint('🗑️ FCM token deleted');
//
//       await logEvent('fcm_token_deleted', parameters: {
//         'is_android_tv': _isAndroidTV,
//       });
//     } catch (e) {
//       debugPrint('❌ Error deleting FCM token: $e');
//     }
//   }
//
//   // Diagnostic method to test FCM functionality
//   Future<Map<String, dynamic>> runDiagnostics() async {
//     Map<String, dynamic> diagnostics = {
//       'timestamp': DateTime.now().toIso8601String(),
//       'is_initialized': _isInitialized,
//       'is_android_tv': _isAndroidTV,
//       'has_google_play_services': _hasGooglePlayServices,
//       'has_cached_token': _cachedToken != null,
//       'firebase_messaging_supported': false,
//       'can_get_token': false,
//       'errors': <String>[],
//     };
//
//     try {
//       // Test Firebase Messaging support
//       diagnostics['firebase_messaging_supported'] = await _messaging.isSupported();
//
//       // Test token retrieval
//       String? token = await getToken();
//       diagnostics['can_get_token'] = token != null;
//
//       if (token != null) {
//         diagnostics['token_length'] = token.length;
//         diagnostics['token_preview'] = token.substring(0, 20) + '...';
//       }
//
//     } catch (e) {
//       diagnostics['errors'].add('Diagnostic error: $e');
//     }
//
//     debugPrint('🔍 FCM Diagnostics: $diagnostics');
//
//     await logEvent('fcm_diagnostics_run', parameters: {
//       'diagnostics_json': diagnostics.toString(),
//     });
//
//     return diagnostics;
//   }
//
//   // Method to check if service is properly initialized
//   bool get isInitialized => _isInitialized;
//
//   // Method to get cached token without network call
//   String? get cachedToken => _cachedToken;
//
//   // Device info getters
//   bool get isAndroidTV => _isAndroidTV;
//   bool get hasGooglePlayServices => _hasGooglePlayServices;
//
//   // Method to force reinitialize (useful for debugging)
//   Future<void> reinitialize(BuildContext context) async {
//     debugPrint('🔄 Reinitializing NotificationService...');
//     _isInitialized = false;
//     _cachedToken = null;
//     await initialize(context);
//   }
// }