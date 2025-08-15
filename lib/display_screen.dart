import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:advertising_screen/provider/content_provider.dart';
import 'package:advertising_screen/provider/handle_provider.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_overlay.dart';
import 'login_screen.dart';
import 'odoo_polling.dart';

class DisplayScreen extends StatefulWidget {
  const DisplayScreen({super.key});

  @override
  State<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends State<DisplayScreen>
    with WidgetsBindingObserver {
  Timer? _rotationTimer;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _showAdminOverlay = false;
  bool _isDisposed = false;
  bool _isInitialized = false;

  // Add Odoo polling service
  final OdooPollingService _odooPollingService = OdooPollingService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ✅ FIX: Schedule initialization after build phase completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        _initializeContent();
        _initializeOdooPolling(); // Add this line
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _odooPollingService.dispose(); // Add this line
    WidgetsBinding.instance.removeObserver(this);
    _rotationTimer?.cancel();
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_isDisposed) return;

    switch (state) {
      case AppLifecycleState.resumed:
      // App resumed, restart content rotation and polling
        if (_isInitialized) {
          _startContentRotation();
          _odooPollingService.startPolling(); // Add this line
        }
        break;
      case AppLifecycleState.paused:
      // App paused, pause video and polling
        _videoController?.pause();
        _odooPollingService.stopPolling(); // Add this line
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      // Pause video for inactive states
        _videoController?.pause();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  // Add this new method for Odoo polling initialization
  Future<void> _initializeOdooPolling() async {
    try {
      debugPrint('🔄 Initializing Odoo polling service...');

      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('base_url');
      final database = prefs.getString('database');
      final password = prefs.getString('password');
      final deviceId = prefs.getString('device_id'); // ✅ FIX: Get deviceId from SharedPreferences

      // Try to get username from different possible keys
      String? username = prefs.getString('username') ??
          prefs.getString('user_name') ??
          prefs.getString('login') ??
          'admin'; // fallback

      debugPrint('📋 Odoo credentials check:');
      debugPrint('   - Base URL: $baseUrl');
      debugPrint('   - Database: $database');
      debugPrint('   - Username: $username');
      debugPrint('   - Device ID: $deviceId');
      debugPrint('   - Password: ${password != null ? '***' : 'null'}');

      if (baseUrl != null && database != null && password != null) {
        // Clean URL for polling service
        String cleanUrl = baseUrl.replaceAll('https://', '').replaceAll('http://', '');
        if (!cleanUrl.startsWith('https://')) {
          cleanUrl = 'https://$cleanUrl';
        }

        debugPrint('🔗 Cleaned URL for polling: $cleanUrl');

        await _odooPollingService.initialize(
          odooUrl: cleanUrl,
          database: database,
          username: username,
          password: password,
          modelToMonitor: 'restaurant.display.line',
          fieldsToMonitor: ['image', 'video', 'duration', 'file_type'], // Monitor these fields
          pollingIntervalSeconds: 10, // Check every 2 minutes
          onImageUpdate: _handleOdooContentUpdate,
          deviceId: deviceId, // ✅ FIX: Now properly defined
        );

        debugPrint('✅ Odoo polling initialized successfully');
      } else {
        debugPrint('⚠️ Missing credentials for Odoo polling initialization');
        debugPrint('   - Please ensure all credentials are saved during login');
      }
    } catch (e) {
      debugPrint('❌ Error initializing Odoo polling: $e');
      // Don't throw error - polling is optional, app should still work
    }
  }

  // Add this callback method for handling Odoo updates
  void _handleOdooContentUpdate() {
    if (_isDisposed || !mounted) return;

    debugPrint('🔄 Odoo content update detected! Refreshing display...');

    // Show a brief notification to user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Content updated automatically'),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );

    // Refresh content using existing method
    _refreshContent();
  }

  Future<void> _initializeContent() async {
    if (_isDisposed || _isInitialized) return;

    try {
      debugPrint('🚀 Initializing content...');
      final contentProvider = Provider.of<ContentProvider>(context, listen: false);
      await contentProvider.loadContent();

      if (!_isDisposed && mounted) {
        _isInitialized = true;
        _startContentRotation();
        debugPrint('✅ Content initialization complete');
      }
    } catch (e) {
      debugPrint('❌ Content initialization error: $e');
      if (!_isDisposed && mounted) {
        // Show error state will be handled by Consumer
      }
    }
  }

  void _startContentRotation() {
    if (_isDisposed || !_isInitialized) return;

    final contentProvider = Provider.of<ContentProvider>(context, listen: false);

    if (contentProvider.contentItems.isEmpty) {
      debugPrint('⚠️ No content items available for rotation');
      return;
    }

    // Cancel existing timer
    _rotationTimer?.cancel();

    final currentItem = contentProvider.currentItem;
    if (currentItem == null) return;

    debugPrint('🔄 Starting content rotation - Current: ${currentItem.title} (${currentItem.type.name})');

    if (currentItem.type == MediaType.video) {
      _initializeVideo(currentItem.videoUrl!);
    } else {
      _scheduleNextContent(currentItem.duration);
    }
  }

  // Future<void> _initializeVideo(String videoUrl) async {
  //   if (_isDisposed) return;
  //
  //   debugPrint('🎥 Initializing video: $videoUrl');
  //
  //   // Clean up previous video controller
  //   _videoController?.removeListener(_videoListener);
  //   _videoController?.dispose();
  //   _videoController = null;
  //
  //   if (mounted) {
  //     setState(() {
  //       _isVideoInitialized = false;
  //     });
  //   }
  //
  //   try {
  //     _videoController = VideoPlayerController.networkUrl(
  //       Uri.parse(videoUrl),
  //       videoPlayerOptions: VideoPlayerOptions(
  //         allowBackgroundPlayback: false,
  //         mixWithOthers: false,
  //       ),
  //     );
  //
  //     await _videoController!.initialize();
  //
  //     if (_isDisposed || !mounted) {
  //       _videoController?.dispose();
  //       return;
  //     }
  //
  //     // Set up video completion listener before playing
  //     _videoController!.addListener(_videoListener);
  //
  //     setState(() {
  //       _isVideoInitialized = true;
  //     });
  //
  //     // Start playing
  //     await _videoController!.play();
  //     _videoController!.setLooping(false);
  //
  //     debugPrint('✅ Video initialized and playing');
  //
  //   } catch (e) {
  //     debugPrint('❌ Video initialization error: $e');
  //     _videoController?.dispose();
  //     _videoController = null;
  //
  //     if (!_isDisposed && mounted) {
  //       setState(() {
  //         _isVideoInitialized = false;
  //       });
  //       // Skip to next content after a delay
  //       Future.delayed(const Duration(seconds: 1), () {
  //         if (!_isDisposed && mounted) {
  //           debugPrint('⏭️ Skipping to next content due to video error');
  //           _nextContent();
  //         }
  //       });
  //     }
  //   }
  // }

  Future<void> _initializeVideo(String base64OrUrl) async {

    print("wweee....>${base64OrUrl}");
    if (_isDisposed) return;

    debugPrint('🎥 Initializing video...');

    // Clean up previous video controller
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _videoController = null;

    if (mounted) {
      setState(() {
        _isVideoInitialized = false;
      });
    }

    try {
      if (_isBase64(base64OrUrl)) {
        // Decode Base64 to bytes
        final bytes = base64Decode(base64OrUrl);

        // Write bytes to temporary file
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp_video.mp4');
        await tempFile.writeAsBytes(bytes, flush: true);

        debugPrint('📂 Playing video from temp file: ${tempFile.path}');

        _videoController = VideoPlayerController.file(
          tempFile,
          videoPlayerOptions: VideoPlayerOptions(
            allowBackgroundPlayback: false,
            mixWithOthers: false,
          ),
        );
      } else {
        // Play from URL
        debugPrint('🌐 Playing video from URL: $base64OrUrl');
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(base64OrUrl),
          videoPlayerOptions: VideoPlayerOptions(
            allowBackgroundPlayback: false,
            mixWithOthers: false,
          ),
        );
      }

      await _videoController!.initialize();

      if (_isDisposed || !mounted) {
        _videoController?.dispose();
        return;
      }

      // Set up listener
      _videoController!.addListener(_videoListener);

      setState(() {
        _isVideoInitialized = true;
      });

      // Play video
      await _videoController!.play();
      _videoController!.setLooping(false);

      debugPrint('✅ Video initialized and playing');
    } catch (e) {
      debugPrint('❌ Video initialization error: $e');
      _videoController?.dispose();
      _videoController = null;

      if (!_isDisposed && mounted) {
        setState(() {
          _isVideoInitialized = false;
        });
        Future.delayed(const Duration(seconds: 1), () {
          if (!_isDisposed && mounted) {
            debugPrint('⏭️ Skipping to next content due to video error');
            _nextContent();
          }
        });
      }
    }
  }

// Simple check if string looks like Base64
  bool _isBase64(String str) {
    final base64RegExp = RegExp(r'^[A-Za-z0-9+/=]+$');
    return base64RegExp.hasMatch(str) && str.length % 4 == 0;
  }


  void _videoListener() {
    if (_isDisposed || _videoController == null || !mounted) return;

    final controller = _videoController!;

    // Handle video errors first
    if (controller.value.hasError) {
      debugPrint('❌ Video playback error: ${controller.value.errorDescription}');
      controller.removeListener(_videoListener);
      _nextContent();
      return;
    }

    // Check if video has finished playing
    if (controller.value.isInitialized &&
        controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero) {
      debugPrint('✅ Video finished playing, moving to next content');
      controller.removeListener(_videoListener);
      _nextContent();
    }
  }

  void _scheduleNextContent(double duration) {
    if (_isDisposed) return;

    final durationInSeconds = duration.toInt().clamp(1, 300); // Min 1s, Max 5min

    debugPrint('⏰ Scheduling next content in ${durationInSeconds}s');

    _rotationTimer?.cancel();
    _rotationTimer = Timer(Duration(seconds: durationInSeconds), () {
      if (!_isDisposed && mounted) {
        debugPrint('⏭️ Timer triggered, moving to next content');
        _nextContent();
      }
    });
  }

  void _nextContent() {
    if (_isDisposed) return;

    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    contentProvider.nextContent();

    if (mounted) {
      setState(() {
        _isVideoInitialized = false;
      });
    }

    _startContentRotation();
  }

  Future<void> _refreshContent() async {
    if (_isDisposed) return;

    try {
      debugPrint('🔄 Refreshing content from server...');
      final contentProvider = Provider.of<ContentProvider>(context, listen: false);
      await contentProvider.refreshContent();

      if (!_isDisposed && mounted) {
        debugPrint('✅ Content refresh complete, restarting rotation');
        _startContentRotation();
      }
    } catch (e) {
      debugPrint('❌ Content refresh error: $e');
      // Error will be shown by Consumer
    }
  }

  // Add method to manually trigger Odoo polling check
  Future<void> _manualOdooCheck() async {
    try {
      debugPrint('🔍 Manual Odoo check triggered');
      await _odooPollingService.checkNow();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checking for updates from Odoo...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Manual Odoo check error: $e');
    }
  }

  // Add method to get Odoo polling status
  Map<String, dynamic> getOdooPollingStatus() {
    return _odooPollingService.getStatus();
  }

  void _showLogoutDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.orange),
            SizedBox(width: 12),
            Text('Logout Confirmation'),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?\n\nThis will stop the display and return to the login screen.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      // Stop Odoo polling before logout
      _odooPollingService.stopPolling();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Loading content...',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white70,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 24),
              const Text(
                'Content Error',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _refreshContent,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _showLogoutDialog,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoContentScreen() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 24),
              const Text(
                'No Content Available',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please add content for this device in the admin panel',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 16,
                children: [
                  ElevatedButton.icon(
                    onPressed: _refreshContent,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Check for Content'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _manualOdooCheck,
                    icon: const Icon(Icons.sync),
                    label: const Text('Check Odoo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_videoController != null && _isVideoInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    } else {
      return _buildLoadingScreen();
    }
  }

  Widget _buildImageContent(ContentItem item) {
    return SizedBox.expand(
      child: Image.memory(
        item.imageData!,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: child,
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ Image display error: $error');
          return Container(
            color: Colors.black,
            child: const Center(
              child: Icon(
                Icons.broken_image,
                size: 80,
                color: Colors.white54,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return Consumer<ContentProvider>(
      builder: (context, contentProvider, child) {
        if (contentProvider.isLoading) {
          return _buildLoadingScreen();
        }

        if (contentProvider.errorMessage != null) {
          return _buildErrorScreen(contentProvider.errorMessage!);
        }

        if (contentProvider.contentItems.isEmpty) {
          return _buildNoContentScreen();
        }

        final currentItem = contentProvider.currentItem;
        if (currentItem == null) {
          return _buildLoadingScreen();
        }

        if (currentItem.type == MediaType.video) {
          return _buildVideoContent();
        } else {
          return _buildImageContent(currentItem);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content display
          _buildMainContent(),

          // Admin overlay
          if (_showAdminOverlay)
            AdminOverlay(
              onClose: () {
                if (mounted) {
                  setState(() => _showAdminOverlay = false);
                }
              },
              onRefresh: () {
                if (mounted) {
                  setState(() => _showAdminOverlay = false);
                  _refreshContent();
                }
              },
              onLogout: () {
                if (mounted) {
                  setState(() => _showAdminOverlay = false);
                  _showLogoutDialog();
                }
              },
              // Pass Odoo status method to admin overlay
              getOdooStatus: getOdooPollingStatus,
              onManualOdooCheck: _manualOdooCheck,
            ),

          // Hidden admin access area (top-right corner)
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onLongPress: () {
                if (mounted) {
                  setState(() => _showAdminOverlay = true);
                }
              },
              child: Container(
                width: 80,
                height: 80,
                color: Colors.transparent,
              ),
            ),
          ),

          // Loading indicator overlay
          Consumer<ContentProvider>(
            builder: (context, contentProvider, child) {
              if (contentProvider.isLoading) {
                return Positioned(
                  top: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Updating...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
