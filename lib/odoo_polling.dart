import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OdooPollingService {
  static final OdooPollingService _instance = OdooPollingService._internal();
  factory OdooPollingService() => _instance;
  OdooPollingService._internal();

  Timer? _pollingTimer;
  String? _odooBaseUrl;
  String? _database;
  String? _username;
  String? _password;
  int? _uid;
  String? _sessionId;

  bool _isInitialized = false;
  int _pollingIntervalSeconds = 120;
  String _deviceId = "";
  DateTime? _lastCheckTime;
  Function()? _onImageUpdateCallback;

  // Track record count to detect deletions/additions
  int _lastRecordCount = 0;

  // Model and fields to monitor for your restaurant display
  String _modelToMonitor = 'restaurant.display.line';
  List<String> _fieldsToMonitor = ['image', 'video', 'duration', 'file_type'];

  /// Initialize the Odoo polling service
  Future<void> initialize({
    required String odooUrl,
    required String database,
    required String username,
    required String password,
    String modelToMonitor = 'restaurant.display.line',
    List<String> fieldsToMonitor = const ['image', 'video', 'duration', 'file_type'],
    int pollingIntervalSeconds = 120,
    Function()? onImageUpdate,
    String? deviceId,
  }) async {
    if (_isInitialized) {
      debugPrint('🔐 OdooPollingService already initialized');
      return;
    }

    _odooBaseUrl = odooUrl.endsWith('/') ? odooUrl : '$odooUrl/';
    _database = database;
    _username = username;
    _password = password;
    _modelToMonitor = modelToMonitor;
    _fieldsToMonitor = fieldsToMonitor;
    _pollingIntervalSeconds = pollingIntervalSeconds;
    _onImageUpdateCallback = onImageUpdate;
    _deviceId = deviceId ?? "";

    debugPrint('🔐 Initializing OdooPollingService...');
    debugPrint('   - Odoo URL: $_odooBaseUrl');
    debugPrint('   - Database: $_database');
    debugPrint('   - Username: $_username');
    debugPrint('   - Model: $_modelToMonitor');
    debugPrint('   - Fields: $_fieldsToMonitor');
    debugPrint('   - Device ID: $_deviceId');
    debugPrint('   - Polling interval: ${_pollingIntervalSeconds}s');
    try {
      // Authenticate with Odoo
      bool authenticated = await _authenticateWithOdoo();

      if (authenticated) {
        // Load last check time and record count
        await _loadLastCheckTime();

        // Get initial record count
        await _loadInitialRecordCount();

        // Start polling
        _startPolling();

        _isInitialized = true;
        debugPrint('✅ OdooPollingService initialized successfully');
      } else {
        debugPrint('❌ Failed to authenticate with Odoo');
        throw Exception('Odoo authentication failed');
      }
    } catch (e) {
      debugPrint('❌ Error initializing OdooPollingService: $e');
      rethrow;
    }
  }

  Future<bool> _authenticateWithOdoo() async {
    try {
      debugPrint('🔑 Authenticating with Odoo...');

      final response = await http.post(
        Uri.parse('${_odooBaseUrl}web/session/authenticate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'db': _database,
            'login': _username,
            'password': _password,
          },
        }),
      ).timeout(Duration(seconds: 30));

      debugPrint('🔑 Auth response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['result'] != null && responseData['result']['uid'] != null) {
          _uid = responseData['result']['uid'];

          // Extract session ID from cookies
          String? cookie = response.headers['set-cookie'];
          if (cookie != null) {
            RegExp sessionRegex = RegExp(r'session_id=([^;]+)');
            Match? match = sessionRegex.firstMatch(cookie);
            if (match != null) {
              _sessionId = match.group(1);
            }
          }

          debugPrint('✅ Authenticated with Odoo successfully');
          debugPrint('   - UID: $_uid');
          return true;
        } else {
          debugPrint('❌ Authentication failed: ${responseData['error'] ?? 'Invalid credentials'}');
          return false;
        }
      } else {
        debugPrint('❌ Authentication request failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error during Odoo authentication: $e');
      return false;
    }
  }

  Future<void> _loadLastCheckTime() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? lastCheckTimestamp = prefs.getInt('odoo_last_check');

      if (lastCheckTimestamp != null) {
        _lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheckTimestamp);
        debugPrint('📅 Last check time loaded: $_lastCheckTime');
      } else {
        _lastCheckTime = DateTime.now().subtract(Duration(hours: 1));
        await _saveLastCheckTime();
        debugPrint('📅 First run - checking last hour');
      }

      // Load last known record count
      int? lastCount = prefs.getInt('odoo_last_record_count');
      if (lastCount != null) {
        _lastRecordCount = lastCount;
        debugPrint('📊 Loaded last known record count: $_lastRecordCount');
      }
    } catch (e) {
      debugPrint('❌ Error loading last check time: $e');
      _lastCheckTime = DateTime.now().subtract(Duration(hours: 1));
      _lastRecordCount = 0;
    }
  }

  Future<void> _saveLastCheckTime() async {
    try {
      if (_lastCheckTime != null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt('odoo_last_check', _lastCheckTime!.millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('❌ Error saving last check time: $e');
    }
  }

  Future<void> _loadInitialRecordCount() async {
    try {
      debugPrint('📊 Loading initial record count...');

      final currentCount = await _getCurrentRecordCount();
      _lastRecordCount = currentCount;

      debugPrint('📊 Initial record count: $_lastRecordCount');

      // Save to SharedPreferences
      await _saveLastRecordCount();

    } catch (e) {
      debugPrint('❌ Error loading initial record count: $e');
      _lastRecordCount = 0;
    }
  }

  Future<int> _getCurrentRecordCount() async {
    if (_uid == null || _sessionId == null) {
      throw Exception('Not authenticated');
    }

    List<dynamic> domain = [];
    if (_deviceId.isNotEmpty) {
      domain = [['device_ip', '=', _deviceId]];
    }

    final response = await http.post(
      Uri.parse('${_odooBaseUrl}web/dataset/call_kw'),
      headers: {
        'Content-Type': 'application/json',
        'Cookie': 'session_id=$_sessionId',
      },
      body: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'model': _modelToMonitor,
          'method': 'search_count',
          'args': [domain],
          'kwargs': {},
        },
      }),
    ).timeout(Duration(seconds: 120));

    debugPrint('📊 Record count response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      if (responseData['result'] != null && responseData['error'] == null) {
        return responseData['result'] as int;
      } else {
        debugPrint('❌ Error in record count response: ${responseData['error']}');
        throw Exception('Failed to get record count: ${responseData['error']}');
      }
    }

    throw Exception('Failed to get record count - HTTP ${response.statusCode}');
  }

  Future<void> _saveLastRecordCount() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('odoo_last_record_count', _lastRecordCount);
    } catch (e) {
      debugPrint('❌ Error saving last record count: $e');
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(Duration(seconds: _pollingIntervalSeconds), (timer) async {
      await _checkForImageUpdates();
    });

    debugPrint('🔄 Started polling Odoo every ${_pollingIntervalSeconds}s');

    // Do an immediate check
    _checkForImageUpdates();
  }

  Future<void> _checkForImageUpdates() async {
    try {
      debugPrint('🔍 Checking for content changes in Odoo...');

      if (_uid == null || _sessionId == null) {
        debugPrint('❌ Not authenticated with Odoo, trying to re-authenticate...');
        bool reauth = await _authenticateWithOdoo();
        if (!reauth) {
          debugPrint('❌ Re-authentication failed');
          return;
        }
      }

      bool hasChanges = false;

      // Check for additions/deletions by comparing record counts
      try {
        int currentCount = await _getCurrentRecordCount();
        debugPrint('📊 Current record count: $currentCount');
        debugPrint('📊 Last known record count: $_lastRecordCount');

        if (currentCount != _lastRecordCount) {
          debugPrint('📊 Record count changed: $_lastRecordCount → $currentCount');
          hasChanges = true;

          if (currentCount > _lastRecordCount) {
            debugPrint('➕ New records added');
          } else {
            debugPrint('🗑️ Records deleted');
          }

          // Update the count
          _lastRecordCount = currentCount;
          await _saveLastRecordCount();
        }
      } catch (e) {
        debugPrint('⚠️ Error checking record count: $e');
      }

      // Also check for updates using write_date (existing logic)
      DateTime currentTime = DateTime.now();
      String lastCheckTimeStr = _lastCheckTime!.toUtc().toIso8601String();

      debugPrint('🔍 Searching for records modified since: $lastCheckTimeStr');

      // Build domain for filtering
      List<dynamic> domain = [['write_date', '>', lastCheckTimeStr]];
      if (_deviceId.isNotEmpty) {
        domain.add(['device_ip', '=', _deviceId]);
      }

      List<String> fieldsToFetch = ['id', 'device_ip', 'write_date'] + _fieldsToMonitor;

      final searchResponse = await http.post(
        Uri.parse('${_odooBaseUrl}web/dataset/call_kw'),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$_sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'model': _modelToMonitor,
            'method': 'search_read',
            'args': [
              domain,
              fieldsToFetch,
            ],
            'kwargs': {
              'limit': 100,
            },
          },
        }),
      ).timeout(Duration(seconds: 120));

      debugPrint('🔍 Search response status: ${searchResponse.statusCode}');

      if (searchResponse.statusCode == 200) {
        final responseData = jsonDecode(searchResponse.body);

        if (responseData['result'] != null) {
          List<dynamic> updatedRecords = responseData['result'];
          debugPrint('🔍 Found ${updatedRecords.length} updated records');

          if (updatedRecords.isNotEmpty) {
            debugPrint('📝 Records updated since last check');
            hasChanges = true;

            for (var record in updatedRecords) {
              debugPrint('   - Record ${record['id']}: device_ip ${record['device_ip']} updated');
            }
          }
        } else {
          debugPrint('❌ Error in Odoo response: ${responseData['error']}');
          if (responseData['error']?.toString().contains('session') == true) {
            debugPrint('🔑 Session expired, re-authenticating...');
            await _authenticateWithOdoo();
          }
        }
      } else {
        debugPrint('❌ Failed to search Odoo records: ${searchResponse.statusCode}');
      }

      // If any changes detected, trigger refresh
      if (hasChanges) {
        debugPrint('🔄 Content changes detected - triggering refresh');
        await _triggerAppRefresh([]);
      } else {
        debugPrint('✅ No content changes detected');
      }

      // Update last check time
      _lastCheckTime = currentTime;
      await _saveLastCheckTime();

    } catch (e) {
      debugPrint('❌ Error checking for image updates: $e');
      // Don't rethrow - just log and continue polling
    }
  }
  Future<void> _triggerAppRefresh(List<Map<String, dynamic>> updatedRecords) async {
    try {
      debugPrint('🔄 Triggering app refresh due to content changes');

      // Call the callback function if provided
      if (_onImageUpdateCallback != null) {
        debugPrint('📱 Calling image update callback');
        _onImageUpdateCallback!();
      } else {
        debugPrint('📱 No callback provided - add onImageUpdate parameter to initialize()');
      }

    } catch (e) {
      debugPrint('❌ Error triggering app refresh: $e');
    }
  }

  /// Test connection to Odoo
  Future<bool> testConnection() async {
    try {
      debugPrint('🧪 Testing Odoo connection...');

      bool authenticated = await _authenticateWithOdoo();
      if (!authenticated) {
        return false;
      }

      // Try to get record count
      final count = await _getCurrentRecordCount();
      debugPrint('🧪 Test successful - found $count records');
      return true;
    } catch (e) {
      debugPrint('❌ Error testing Odoo connection: $e');
      return false;
    }
  }

  /// Force check for updates now
  Future<void> checkNow() async {
    if (_isInitialized) {
      debugPrint('🔄 Manual check triggered');
      await _checkForImageUpdates();
    } else {
      debugPrint('❌ Service not initialized');
    }
  }

  /// Get service status
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'authenticated': _uid != null,
      'polling_active': _pollingTimer != null,
      'last_check': _lastCheckTime?.toIso8601String(),
      'polling_interval_seconds': _pollingIntervalSeconds,
      'model_monitored': _modelToMonitor,
      'fields_monitored': _fieldsToMonitor,
      'device_id': _deviceId,
      'last_record_count': _lastRecordCount,
      'odoo_url': _odooBaseUrl,
      'database': _database,
      'username': _username,
    };
  }

  /// Update polling interval
  void updatePollingInterval(int seconds) {
    _pollingIntervalSeconds = seconds;
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _startPolling();
      debugPrint('🔄 Polling interval updated to ${seconds}s');
    }
  }

  /// Stop polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    debugPrint('ℹ️ Odoo polling stopped');
  }

  /// Start polling (if stopped)
  void startPolling() {
    if (_isInitialized && _pollingTimer == null) {
      _startPolling();
    }
  }

  /// Dispose resources
  void dispose() {
    stopPolling();
    _isInitialized = false;
    _uid = null;
    _sessionId = null;
    _onImageUpdateCallback = null;
    _lastRecordCount = 0;
    debugPrint('🗑️ OdooPollingService disposed');
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _uid != null;
  bool get isPolling => _pollingTimer != null;
  DateTime? get lastCheckTime => _lastCheckTime;
  int get pollingIntervalSeconds => _pollingIntervalSeconds;
}