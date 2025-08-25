
import 'dart:convert';
import 'dart:typed_data';
import 'package:advertising_screen/constant/staticData.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml_rpc/client_c.dart' as xml_rpc;

enum MediaType { image, video }

class ContentItem {
  final String id;
  final String? imageUrl;
  final String? videoUrl;
  final double duration;
  final MediaType type;
  final String title;

  ContentItem({
    required this.id,
    this.imageUrl,
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
    print("pharse 1");
    _isLoading = true;
    _errorMessage = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final password = prefs.getString('password');
      final url = baseUrl;
      final database = dbName;
      final deviceId = prefs.getString('device_id');

      if (userId == null || password == null || url == null ||
          database == null || deviceId == null) {
        throw Exception('Authentication data not found');
      }

      final rawData = await xml_rpc.call(
        Uri.parse('$url/xmlrpc/2/object'),
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
          {
            'fields': [
              'id', 'image', 'file_type', 'duration',
            ],
          },
        ],
      );
      if (rawData is List) {
        _contentItems = await _processContentData(rawData);
        _currentIndex = 0;
      }
      print("yyyyyyyyy");

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
        if (fileType == 'video') {
          mediaType = MediaType.video;
        } else {
          mediaType = MediaType.image;
        }
        if (mediaType == MediaType.image) {
          if (item['image'] != null ) {
            print("eeer");
            items.add(ContentItem(
              id: item['id'].toString(),
              imageUrl: item['image'],
              duration: duration,
              type: MediaType.image,
              title: title,
            ));
          }
        } else if (mediaType == MediaType.video) {
          if (item['image'] != null) {
            items.add(ContentItem(
              id: item['id'].toString(),
              videoUrl: item['image'],
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

