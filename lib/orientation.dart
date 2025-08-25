import 'package:advertising_screen/provider/handle_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_restart.dart';

class VisualTVOrientationScreen extends StatefulWidget {
  const VisualTVOrientationScreen({super.key});

  @override
  State<VisualTVOrientationScreen> createState() => _VisualTVOrientationScreenState();
}

class _VisualTVOrientationScreenState extends State<VisualTVOrientationScreen>
    with SingleTickerProviderStateMixin {

  int _selectedIndex = 0; // 0 for Portrait, 1 for Landscape
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    _selectedIndex = Provider.of<AuthProvider>(context, listen: false).orientationMode == "landscape" ? 1 :0 ;
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
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

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowLeft && _selectedIndex > 0) {
        setState(() => _selectedIndex = 0);
        _animateSelection();
      } else if (key == LogicalKeyboardKey.arrowRight && _selectedIndex < 1) {
        setState(() => _selectedIndex = 1);
        _animateSelection();
      } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        _selectOrientation();
      }
    }
  }

  void _animateSelection() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  void _selectOrientation() async {
    if (_selectedIndex == 0) {
      Provider.of<AuthProvider>(context, listen: false).setOrientationMode(
          "portrait");
    } else {
      Provider.of<AuthProvider>(context, listen: false).setOrientationMode(
          "landscape");
    }
    // Visual feedback with haptics (if available)
    // RestartWidget.restartApp(context);
  }
  Widget _buildVisualOrientationButton({
    required bool isSelected,
    required VoidCallback onTap,
    required bool isPortrait,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isSelected ? _scaleAnimation.value : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[600] : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.blue[800]! : Colors.grey[400]!,
                  width: isSelected ? 4 : 2,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Large TV/Screen visual representation
                  Container(
                    width: isPortrait ? 80 : 120,
                    height: isPortrait ? 120 : 80,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.blue[200]! : Colors.grey[600]!,
                        width: 3,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Screen content representation (dots pattern)
                        Container(
                          width: isPortrait ? 60 : 100,
                          height: isPortrait ? 100 : 60,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue[100] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(8),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isPortrait ? 3 : 5,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                            itemCount: isPortrait ? 15 : 15,
                            itemBuilder: (context, index) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.blue[400] : Colors.grey[500],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Selection indicator
                  if (isSelected)
                    Positioned(
                      top: 15,
                      right: 15,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.green[600],
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Portrait Button - Visual Only
              _buildVisualOrientationButton(
                isSelected: _selectedIndex == 0,
                isPortrait: true,
                onTap: () {
                  setState(() => _selectedIndex = 0);
                  _selectOrientation();
                },
              ),

              const SizedBox(width: 80),

              // Landscape Button - Visual Only
              _buildVisualOrientationButton(
                isSelected: _selectedIndex == 1,
                isPortrait: false,
                onTap: () {
                  setState(() => _selectedIndex = 1);
                  _selectOrientation();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}