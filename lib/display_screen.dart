import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:advertising_screen/constant/staticData.dart';
import 'package:advertising_screen/provider/content_provider.dart';
import 'package:advertising_screen/provider/handle_provider.dart';
import 'package:advertising_screen/reusableWidget/floating_action_btn.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'odoo_polling.dart';
import 'orientation.dart';

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
        _initializeOdooPolling();
        // Add this line
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
      final url = baseUrl;
      final database = dbName;
      final password = prefs.getString('password');
      final deviceId = prefs.getString('device_id'); // ✅ FIX: Get deviceId from SharedPreferences

      // Try to get username from different possible keys
      String? username = prefs.getString('username') ??
          prefs.getString('user_name') ??
          prefs.getString('login') ??
          'admin'; // fallback

      debugPrint('📋 Odoo credentials check:');
      debugPrint('   - Base URL: $url');
      debugPrint('   - Database: $database');
      debugPrint('   - Username: $username');
      debugPrint('   - Device ID: $deviceId');
      debugPrint('   - Password: ${password != null ? '***' : 'null'}');

      if (url != null && database != null && password != null) {
        // Clean URL for polling service
        String cleanUrl = url.replaceAll('https://', '').replaceAll('http://', '');
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
    print("errr");
    // Refresh content using existing method
    _refreshContent();
    print("ttttttrr");

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

  Future<void> _initializeVideo(String videoUrl) async {
    print("eeerrr,,,,,,<$videoUrl");
    // Extract Google Drive file ID dynamically
    final fileId = _extractFileId(videoUrl);
    if (fileId == null) {
      if (mounted) setState(() => _isVideoInitialized = false);
      return;
    }
    if (_isDisposed) return;

    // Clean up previous controller
    _videoController?.removeListener(_videoListener);
    await _videoController?.dispose();
    _videoController = null;

    if (mounted) setState(() => _isVideoInitialized = false);

    try {
      final directVideoUrl = "https://drive.google.com/uc?export=download&id=$fileId";

      _videoController = VideoPlayerController.network(
        directVideoUrl,
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: false,
          mixWithOthers: false,
        ),
      );

      // Initialize with timeout
      await _videoController!.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Video initialization timeout'),
      );

      if (_isDisposed || !mounted) {
        await _videoController?.dispose();
        return;
      }

      final duration = _videoController!.value.duration;
      final size = _videoController!.value.size;

      debugPrint('✅ Video properties: Duration=$duration, Size=${size.width}x${size.height}, AspectRatio=${_videoController!.value.aspectRatio}');

      if (duration == Duration.zero) {
        throw Exception('Video has zero duration - may be corrupted');
      }

      // Add listener BEFORE setting state for Mali GPU fixes
      _videoController!.addListener(_videoListener);

      // Post-frame callback to ensure proper rendering
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_videoController != null && !_isDisposed && mounted) {
          setState(() => _isVideoInitialized = true);

          await Future.delayed(const Duration(milliseconds: 500)); // small delay for GPU

          try {
            await _videoController!.setVolume(1.0);
            await _videoController!.play();
            _videoController!.setLooping(false);
            debugPrint('✅ Video started playing on Android TV');

            // Force a rebuild to refresh Mali GPU rendering after 2s
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && _videoController != null) {
                setState(() {});
                debugPrint('🔄 Forced video widget rebuild for Mali GPU');
              }
            });
          } catch (e) {
            debugPrint('❌ Error starting playback: $e');
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Video initialization error: $e (${e.runtimeType})');

      await _videoController?.dispose();
      _videoController = null;

      if (!_isDisposed && mounted) {
        setState(() => _isVideoInitialized = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );

        _skipToNextContent();
      }
    }
  }

  String? _extractFileId(String url) {
    final regex = RegExp(r'/d/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  void _skipToNextContent() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!_isDisposed && mounted) {
        debugPrint('⏭️ Skipping to next content');
        _nextContent();
      }
    });
  }
  void _videoListener() {
    if (_isDisposed || _videoController == null || !mounted) return;

    final controller = _videoController!;

    // Handle video errors first
    if (controller.value.hasError) {
      debugPrint('❌ Video playback error: ${controller.value.errorDescription}');

      // ANDROID TV FIX: Log more details about the error
      debugPrint('❌ Error details:');
      debugPrint('   - Error: ${controller.value.errorDescription}');
      debugPrint('   - Position: ${controller.value.position}');
      debugPrint('   - Duration: ${controller.value.duration}');
      debugPrint('   - Is initialized: ${controller.value.isInitialized}');

      controller.removeListener(_videoListener);

      // Show error message before moving to next content
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video playback failed: ${controller.value.errorDescription}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      _nextContent();
      return;
    }

    // ANDROID TV FIX: More robust completion detection
    if (controller.value.isInitialized &&
        controller.value.duration > Duration.zero) {

      final position = controller.value.position;
      final duration = controller.value.duration;
      final remaining = duration - position;

      // Consider video finished if less than 500ms remaining
      if (remaining.inMilliseconds < 500) {
        debugPrint('✅ Video finished playing (${remaining.inMilliseconds}ms remaining)');
        controller.removeListener(_videoListener);
        _nextContent();
        return;
      }

      // ANDROID TV FIX: Check if video is stuck
      Duration? lastPosition;
      int stuckCount = 0;

      if (lastPosition == position && position != Duration.zero) {
        stuckCount++;
        if (stuckCount > 10) { // If stuck for 10 listener calls
          debugPrint('⚠️ Video appears stuck at position: $position');
          debugPrint('⚠️ Attempting to restart playback...');
          controller.play(); // Try to restart
          stuckCount = 0;
        }
      } else {
        stuckCount = 0;
      }
      lastPosition = position;
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
  Future<void> _setOrientation() async {
    try {
      // Stop Odoo polling before logout
      _odooPollingService.stopPolling();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const VisualTVOrientationScreen()),
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
    final orientationMode = Provider.of<AuthProvider>(context,listen: false).orientationMode;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(orientationMode == "landscape" ? 'assets/Dinemore-LandscapeLogo.png' : 'assets/Dinemore-Potraite_Logo.png' ),
          fit: BoxFit.contain,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 5,
              height: 5,
              child: CircularProgressIndicator(
                color: Colors.transparent,
                backgroundColor: Colors.transparent,
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

  // Widget _buildVideoContent() {
  //   if (_videoController != null && _isVideoInitialized) {
  //     return SizedBox.expand(
  //       child: FittedBox(
  //         fit: BoxFit.cover,
  //         child: SizedBox(
  //           width: _videoController!.value.size.width,
  //           height: _videoController!.value.size.height,
  //           child: VideoPlayer(_videoController!),
  //         ),
  //       ),
  //     );
  //   } else {
  //     return _buildLoadingScreen();
  //   }
  // }

  Widget _buildVideoContent() {
    if (_videoController != null && _isVideoInitialized) {
      return ClipRect(
        child: SizedBox.expand(
          child: OverflowBox(
            minWidth: 0.0,
            minHeight: 0.0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),
        ),
        // child: FittedBox(
        //   fit: BoxFit.cover,
        //   child: SizedBox(
        //     width: _videoController!.value.size.width,
        //     height: _videoController!.value.size.height,
        //     child: VideoPlayer(_videoController!),
        //   ),
        // ),
      );
    } else {
      final orientationMode = Provider.of<AuthProvider>(context,listen: false).orientationMode;
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(orientationMode == "landscape" ? 'assets/Dinemore-LandscapeLogo.png' : 'assets/Dinemore-Potraite_Logo.png' ),
            fit: BoxFit.contain,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 5,
                height: 5,
                child: CircularProgressIndicator(
                  color: Colors.transparent,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildImageContent(String url) {
    // Convert Google Drive share URL to direct image URL
    print("url...$url");
    String directUrl = _convertGoogleDriveUrl(url);

    return SizedBox.expand(
      child: Image.network(
        directUrl,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: child,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.white,
              ),
            ),
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

// Helper function to convert Google Drive URLs
  String _convertGoogleDriveUrl(String url) {
    if (url.contains('drive.google.com/file/d/')) {
      // Extract file ID from sharing URL
      final fileId = url.split('/d/')[1].split('/')[0];
      return 'https://drive.google.com/uc?export=view&id=$fileId';
    } else if (url.contains('drive.google.com/open?id=')) {
      // Extract file ID from open URL
      final fileId = url.split('id=')[1];
      return 'https://drive.google.com/uc?export=view&id=$fileId';
    }
    // Return original URL if it's already in direct format or different service
    return url;
  }

  Widget _buildMainContent() {
    return Consumer<ContentProvider>(
      builder: (context, contentProvider, child) {
        if (contentProvider.isLoading) {
          print("yes1");
          return _buildLoadingScreen();
        }

        if (contentProvider.errorMessage != null) {
          return _buildErrorScreen(contentProvider.errorMessage!);
        }

        if (contentProvider.contentItems.isEmpty) {
          return _buildLoadingScreen();
        }

        final currentItem = contentProvider.currentItem;
        if (currentItem == null) {
          print("yes3");
          return _buildLoadingScreen();
        }

        if (currentItem.type == MediaType.video) {
          return _buildVideoContent();
        } else {
          print("ppppppppppppp${currentItem.imageUrl}");
          return _buildImageContent(currentItem.imageUrl!);
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
      floatingActionButton:FloatingActionButtons(
        hoverAreaSize: 150.0,
        animationDuration: Duration(milliseconds: 250), // Faster animation
        onLogout: () => _logout(),
        onOrientationToggle: () => _setOrientation(),
      )

    );
  }
}
