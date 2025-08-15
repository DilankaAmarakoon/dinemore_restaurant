/*
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml_rpc/client_c.dart' as xml_rpc;

enum MediaType { image, video }

class ContentItem {
  final String id;
  final Uint8List? imageData;
  final String? videoUrl;
  final double duration;
  final MediaType type;
  final String title;

  ContentItem({
    required this.id,
    this.imageData,
    this.videoUrl,
    required this.duration,
    required this.type,
    required this.title,
  });
}

class ContentProvider with ChangeNotifier {
  List<ContentItem> _contentItems = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentIndex = 0;

  List<ContentItem> get contentItems => _contentItems;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentIndex => _currentIndex;
  ContentItem? get currentItem =>
      _contentItems.isNotEmpty ? _contentItems[_currentIndex] : null;

  Future<void> loadContent() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final password = prefs.getString('password');
      final baseUrl = prefs.getString('base_url');
      final database = prefs.getString('database');
      final deviceId = prefs.getString('device_id');

      if (userId == null || password == null || baseUrl == null ||
          database == null || deviceId == null) {
        throw Exception('Authentication data not found');
      }

      final rawData = await xml_rpc.call(
        Uri.parse('https://$baseUrl/xmlrpc/2/object'),
        'execute_kw',
        [
          database,
          userId,
          password,
          'restaurant.display.line',
          'search_read',
          [
            [['device_ip', '=', deviceId]]
          ],
        ],
      );

      if (rawData is List) {
        _contentItems = await _processContentData(rawData);
        _currentIndex = 0;
      }
    } catch (e) {
      _errorMessage = 'Failed to load content: ${e.toString()}';
      debugPrint('Content loading error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<ContentItem>> _processContentData(List<dynamic> rawData) async {
    final List<ContentItem> items = [];

    for (final item in rawData) {
      try {
        final fileType = item['file_type'] as String?;
        final duration = (item['duration'] as num?)?.toDouble() ?? 5.0;
        final title = item['name'] as String? ?? 'Untitled';

        if (fileType == 'image') {
          final imageData = item['image'] as String?;
          if (imageData != null && imageData.isNotEmpty) {
            final bytes = base64Decode(imageData);
            items.add(ContentItem(
              id: item['id'].toString(),
              imageData: bytes,
              duration: duration,
              type: MediaType.image,
              title: title,
            ));
          }
        } else if (fileType == 'video') {
          final videoData = item['video'] as String?;
          if (videoData != null && videoData.isNotEmpty) {
            final videoUrl = _convertGoogleDriveUrl(videoData);
            items.add(ContentItem(
              id: item['id'].toString(),
              videoUrl: videoUrl,
              duration: duration,
              type: MediaType.video,
              title: title,
            ));
          }
        }
      } catch (e) {
        debugPrint('Error processing content item: $e');
      }
    }

    return items;
  }

  String _convertGoogleDriveUrl(String originalUrl) {
    final regex = RegExp(r'd/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(originalUrl);

    if (match != null && match.groupCount >= 1) {
      final fileId = match.group(1)!;
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }

    return originalUrl;
  }

  void nextContent() {
    if (_contentItems.isNotEmpty) {
      _currentIndex = (_currentIndex + 1) % _contentItems.length;
      notifyListeners();
    }
  }

  void previousContent() {
    if (_contentItems.isNotEmpty) {
      _currentIndex = (_currentIndex - 1 + _contentItems.length) % _contentItems.length;
      notifyListeners();
    }
  }

  void setCurrentIndex(int index) {
    if (index >= 0 && index < _contentItems.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  Future<void> refreshContent() async {
    await loadContent();
  }
}


*/


import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml_rpc/client_c.dart' as xml_rpc;

enum MediaType { image, video }

class ContentItem {
  final String id;
  final Uint8List? imageData;
  final String? videoUrl;
  final double duration;
  final MediaType type;
  final String title;

  ContentItem({
    required this.id,
    this.imageData,
    this.videoUrl,
    required this.duration,
    required this.type,
    required this.title,
  });
}

class ContentProvider with ChangeNotifier {
  List<ContentItem> _contentItems = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentIndex = 0;

  List<ContentItem> get contentItems => _contentItems;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentIndex => _currentIndex;
  ContentItem? get currentItem =>
      _contentItems.isNotEmpty ? _contentItems[_currentIndex] : null;

  Future<void> loadContent() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final password = prefs.getString('password');
      final baseUrl = prefs.getString('base_url');
      final database = prefs.getString('database');
      final deviceId = prefs.getString('device_id');

      if (userId == null || password == null || baseUrl == null ||
          database == null || deviceId == null) {
        throw Exception('Authentication data not found');
      }

      final rawData = await xml_rpc.call(
        Uri.parse('https://$baseUrl/xmlrpc/2/object'),
        'execute_kw',
        [
          database,
          userId,
          password,
          'restaurant.display.line',
          'search_read',
          [
            [['device_ip', '=', deviceId]]
          ],
        ],
      );

      if (rawData is List) {
        _contentItems = await _processContentData(rawData);
        _currentIndex = 0;
      }
    } catch (e) {
      _errorMessage = 'Failed to load content: ${e.toString()}';
      debugPrint('Content loading error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<ContentItem>> _processContentData(List<dynamic> rawData) async {
    final List<ContentItem> items = [];

    for (final item in rawData) {
      try {
        final fileType = item['file_type'] as String?;
        final duration = (item['duration'] as num?)?.toDouble() ?? 0.0;
        final title = item['name'] as String? ?? 'Untitled';

        // Determine media type based on file_type or duration
        MediaType mediaType;
        if (fileType == 'video' || duration == 0.0) {
          mediaType = MediaType.video;
        } else {
          mediaType = MediaType.image;
        }
        print("uiiioo..>${item['image']}");
        if (mediaType == MediaType.image) {
          final imageData = item['image'] as String?;
          if (imageData != null && imageData.isNotEmpty) {
            print("eeer");
            final bytes = base64Decode(imageData);
            items.add(ContentItem(
              id: item['id'].toString(),
              imageData: bytes,
              duration: duration > 0 ? duration : 5.0, // Default 5s for images
              type: MediaType.image,
              title: title,
            ));
          }
        } else if (mediaType == MediaType.video) {
          // Try video field first, then image field as fallback
          print("uiiii..>${item['image']}");
          final videoData =  item['image'];
          if (videoData != null && videoData.isNotEmpty) {
            items.add(ContentItem(
              id: item['id'].toString(),
              videoUrl: videoData,
              duration: duration,
              type: MediaType.video,
              title: title,
            ));
          }
        }
      } catch (e) {
        debugPrint('Error processing content item: $e');
      }
    }

    return items;
  }

  String _convertGoogleDriveUrl(String originalUrl) {
    final regex = RegExp(r'd/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(originalUrl);

    if (match != null && match.groupCount >= 1) {
      final fileId = match.group(1)!;
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }

    return originalUrl;
  }

  void nextContent() {
    if (_contentItems.isNotEmpty) {
      _currentIndex = (_currentIndex + 1) % _contentItems.length;
      notifyListeners();
    }
  }

  void previousContent() {
    if (_contentItems.isNotEmpty) {
      _currentIndex = (_currentIndex - 1 + _contentItems.length) % _contentItems.length;
      notifyListeners();
    }
  }

  void setCurrentIndex(int index) {
    if (index >= 0 && index < _contentItems.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  Future<void> refreshContent() async {
    await loadContent();
  }
}

