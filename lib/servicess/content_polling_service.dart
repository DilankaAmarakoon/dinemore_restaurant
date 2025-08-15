import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/content_provider.dart';

class ContentPollingService {
  static const int _defaultPollingInterval = 10; // 2 minutes
  Timer? _pollingTimer;
  bool _isPolling = false;
  BuildContext? _context;
  int _pollingIntervalSeconds;
  DateTime? _lastContentCheck;
  List<String> _lastContentIds = [];

  ContentPollingService({int pollingIntervalSeconds = _defaultPollingInterval})
      : _pollingIntervalSeconds = pollingIntervalSeconds;

  // Start polling for new content
  void startPolling(BuildContext context) {
    if (_isPolling) return;

    _context = context;
    _isPolling = true;
    _lastContentCheck = DateTime.now();

    debugPrint('🔄 Starting content polling every $_pollingIntervalSeconds seconds');

    // Get initial content IDs
    _updateLastContentIds();

    _pollingTimer = Timer.periodic(
      Duration(seconds: _pollingIntervalSeconds),
          (timer) => _checkForNewContent(),
    );
  }

  // Stop polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    _context = null;
    debugPrint('⏹️ Content polling stopped');
  }

  // Check for new content
  Future<void> _checkForNewContent() async {
    if (!_isPolling || _context == null) return;

    try {
      debugPrint('🔍 Checking for new content...');

      final contentProvider = Provider.of<ContentProvider>(_context!, listen: false);

      // Get current content IDs before refresh
      final oldContentIds = List<String>.from(_lastContentIds);

      // Reload content from Odoo
      await contentProvider.loadContent();

      // Get new content IDs
      _updateLastContentIds();

      // Check if content has changed
      if (_hasContentChanged(oldContentIds, _lastContentIds)) {
        debugPrint('✨ New content detected! Refreshing display...');
        _handleContentRefresh();
      } else {
        debugPrint('✅ No new content found');
      }

    } catch (e) {
      debugPrint('❌ Error checking for new content: $e');
    }
  }

  // Update the list of current content IDs
  void _updateLastContentIds() {
    if (_context == null) return;

    final contentProvider = Provider.of<ContentProvider>(_context!, listen: false);
    _lastContentIds = contentProvider.contentItems.map((item) => item.id).toList();
  }

  // Check if content has changed
  bool _hasContentChanged(List<String> oldIds, List<String> newIds) {
    if (oldIds.length != newIds.length) return true;

    // Check if any IDs are different
    for (int i = 0; i < oldIds.length; i++) {
      if (oldIds[i] != newIds[i]) return true;
    }

    return false;
  }

  // Handle content refresh
  void _handleContentRefresh() {
    if (_context == null) return;

    debugPrint('🔄 Content refresh triggered by polling');

    // Trigger UI refresh by notifying listeners
    final contentProvider = Provider.of<ContentProvider>(_context!, listen: false);
    contentProvider.notifyListeners();
  }

  // Update polling interval
  void updatePollingInterval(int seconds) {
    _pollingIntervalSeconds = seconds;
    if (_isPolling) {
      stopPolling();
      if (_context != null) {
        startPolling(_context!);
      }
    }
  }

  // Get current polling status
  bool get isPolling => _isPolling;
  int get pollingInterval => _pollingIntervalSeconds;
}