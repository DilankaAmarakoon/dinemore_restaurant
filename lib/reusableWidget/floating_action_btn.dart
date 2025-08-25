import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Main hover-activated dual FAB widget for TV Remote
class FloatingActionButtons extends StatefulWidget {
  final VoidCallback? onLogout;
  final VoidCallback? onOrientationToggle;
  final double hoverAreaSize;
  final Duration animationDuration;

  const FloatingActionButtons({
    Key? key,
    this.onLogout,
    this.onOrientationToggle,
    this.hoverAreaSize = 140.0, // Larger for TV remote cursor
    this.animationDuration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  State<FloatingActionButtons> createState() => _FloatingActionButtonsState();
}

class _FloatingActionButtonsState extends State<FloatingActionButtons>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });

    // Simple show/hide based only on cursor position
    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  // Default logout dialog
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (widget.onLogout != null) {
                  widget.onLogout!();
                } else {
                  print('User logged out');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Logout', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Default orientation toggle
  void _toggleOrientation() {
    if (widget.onOrientationToggle != null) {
      widget.onOrientationToggle!();
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      print('Orientation toggled');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: Container(
        width: widget.hoverAreaSize * 2.8, // Width for two buttons
        height: widget.hoverAreaSize,
        // Uncomment to visualize hover area during development
        // decoration: BoxDecoration(
        //   border: Border.all(color: _isHovered ? Colors.yellow.withOpacity(0.5) : Colors.red.withOpacity(0.3)),
        //   borderRadius: BorderRadius.circular(8),
        // ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Invisible hover area for cursor detection
            Container(
              width: widget.hoverAreaSize * 2.8,
              height: widget.hoverAreaSize,
              color: Colors.transparent,
            ),
            // Animated buttons - only appear when cursor reaches location
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logout Button - Press OK on TV remote to activate
                        FloatingActionButton.extended(
                          onPressed: _showLogoutDialog,
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                          heroTag: "logout_hover",
                        ),
                        const SizedBox(width: 12), // Spacing between buttons
                        // Orientation Button - Press OK on TV remote to activate
                        FloatingActionButton.extended(
                          onPressed: _toggleOrientation,
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          icon: const Icon(Icons.screen_rotation),
                          label: const Text('Orientation'),
                          heroTag: "orientation_hover",
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Alternative: Always visible version (without hover effects)
class AlwaysVisibleFloatingActionButtons extends StatelessWidget {
  final VoidCallback? onLogout;
  final VoidCallback? onOrientationToggle;

  const AlwaysVisibleFloatingActionButtons({
    Key? key,
    this.onLogout,
    this.onOrientationToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logout Button
        FloatingActionButton.extended(
          onPressed: onLogout ?? () {
            // Default logout action
            _showLogoutDialog(context);
          },
          backgroundColor: Colors.red[600],
          foregroundColor: Colors.white,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          heroTag: "logout_always",
        ),
        const SizedBox(width: 12), // Spacing between buttons
        // Orientation Button
        FloatingActionButton.extended(
          onPressed: onOrientationToggle ?? () {
            // Default orientation toggle action
            _toggleOrientation();
          },
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          icon: const Icon(Icons.screen_rotation),
          label: const Text('Orientation'),
          heroTag: "orientation_always",
        ),
      ],
    );
  }

  // Default logout dialog
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Add your logout logic here
                print('User logged out');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Logout', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Default orientation toggle
  void _toggleOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    print('Orientation toggled');
  }
}

// Compact version with smaller buttons
class CompactFloatingActionButtons extends StatefulWidget {
  final VoidCallback? onLogout;
  final VoidCallback? onOrientationToggle;
  final double hoverAreaSize;

  const CompactFloatingActionButtons({
    Key? key,
    this.onLogout,
    this.onOrientationToggle,
    this.hoverAreaSize = 100.0,
  }) : super(key: key);

  @override
  State<CompactFloatingActionButtons> createState() => _CompactFloatingActionButtonsState();
}

class _CompactFloatingActionButtonsState extends State<CompactFloatingActionButtons>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    isHovered ? _animationController.forward() : _animationController.reverse();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (widget.onLogout != null) {
                  widget.onLogout!();
                } else {
                  print('User logged out');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Logout', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _toggleOrientation() {
    if (widget.onOrientationToggle != null) {
      widget.onOrientationToggle!();
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      print('Orientation toggled');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: Container(
        width: widget.hoverAreaSize * 2.2,
        height: widget.hoverAreaSize,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Compact Logout Button
                    FloatingActionButton(
                      onPressed: _showLogoutDialog,
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      tooltip: 'Logout',
                      heroTag: "logout_compact_hover",
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.logout, size: 20),
                          Text('Logout', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Compact Orientation Button
                    FloatingActionButton(
                      onPressed: _toggleOrientation,
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      tooltip: 'Toggle Orientation',
                      heroTag: "orientation_compact_hover",
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.screen_rotation, size: 20),
                          Text('Orient', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Usage example
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TV Hover FAB Example'),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TV Interface with Hover FAB',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Move mouse cursor to bottom-right corner\nto reveal floating action buttons',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey[900],
      // Main hover-activated FAB for TV Remote - appears when cursor reaches location
      floatingActionButton: FloatingActionButtons(
        hoverAreaSize: 140.0, // Large area for easy TV remote cursor detection
        animationDuration: Duration(milliseconds: 300),
        onLogout: () {
          // Your logout logic here
          print('TV Remote: Logging out...');
        },
        onOrientationToggle: () {
          // Your orientation logic here
          print('TV Remote: Toggling orientation...');
        },
      ),

      // Alternative options (uncomment to use instead):

      // Always visible version:
      // floatingActionButton: AlwaysVisibleFloatingActionButtons(
      //   onLogout: () => print('Logout pressed'),
      //   onOrientationToggle: () => print('Orientation pressed'),
      // ),

      // Compact hover version:
      // floatingActionButton: CompactFloatingActionButtons(
      //   hoverAreaSize: 100.0,
      //   onLogout: () => print('Compact logout'),
      //   onOrientationToggle: () => print('Compact orientation'),
      // ),
    );
  }
}