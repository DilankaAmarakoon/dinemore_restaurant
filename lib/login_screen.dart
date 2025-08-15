import 'package:advertising_screen/provider/handle_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'display_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deviceMacAddress = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _deviceMacAddressFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureDeviceMacAddress = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _deviceMacAddress.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _deviceMacAddressFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();

    final success = await authProvider.login(
      _usernameController.text.trim(),
      _passwordController.text,
        _deviceMacAddress.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, _) => const DisplayScreen(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowDown) {
        if (_usernameFocus.hasFocus) {
          FocusScope.of(context).requestFocus(_passwordFocus);
        } else if (_passwordFocus.hasFocus) {
          FocusScope.of(context).requestFocus(_deviceMacAddressFocus);
        }
      } else if (key == LogicalKeyboardKey.arrowUp) {
        if (_deviceMacAddressFocus.hasFocus) {
          FocusScope.of(context).requestFocus(_passwordFocus);
        } else if (_passwordFocus.hasFocus) {
          FocusScope.of(context).requestFocus(_usernameFocus);
        }
      } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        _handleLogin();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1565C0),
                Color(0xFF1E88E5),
                Color(0xFF42A5F5),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16), // Reduced from 24
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Card(
                      elevation: 12, // Reduced from 16
                      shadowColor: Colors.black.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16), // Reduced from 20
                      ),
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 320, // Reduced from 450
                          minHeight: 380, // Reduced from 500
                        ),
                        padding: const EdgeInsets.all(24), // Reduced from 40
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // App Icon - Smaller
                              Container(
                                width: 60, // Reduced from 100
                                height: 60, // Reduced from 100
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                                  ),
                                  borderRadius: BorderRadius.circular(12), // Reduced from 20
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 10, // Reduced from 15
                                      offset: const Offset(0, 4), // Reduced from (0, 8)
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.restaurant_menu,
                                  size: 32, // Reduced from 50
                                  color: Colors.white,
                                ),
                              ),

                              const SizedBox(height: 16), // Reduced from 24

                              // Title - Smaller
                              Text(
                                'Restaurant Display',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith( // Changed from headlineMedium
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1565C0),
                                ),
                              ),

                              const SizedBox(height: 4), // Reduced from 8

                              // Subtitle - Smaller
                              Text(
                                'Digital Advertising System',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith( // Changed from bodyLarge
                                  color: Colors.grey[600],
                                  fontSize: 12, // Added explicit smaller size
                                ),
                              ),

                              const SizedBox(height: 20), // Reduced from 40

                              // Username Field - Compact
                              TextFormField(
                                controller: _usernameController,
                                focusNode: _usernameFocus,
                                autofocus: true,
                                style: const TextStyle(fontSize: 14), // Smaller text
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  hintText: 'Enter username',
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), // Compact padding
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(6), // Reduced from 8
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E88E5).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6), // Reduced from 8
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Color(0xFF1E88E5),
                                      size: 20, // Smaller icon
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10), // Reduced from 12
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1E88E5),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter username';
                                  }
                                  if (value.trim().length < 3) {
                                    return 'Min 3 characters';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) {
                                  FocusScope.of(context).requestFocus(_passwordFocus);
                                },
                              ),

                              const SizedBox(height: 12), // Reduced from 16

                              // Password Field - Compact
                              TextFormField(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                obscureText: _obscurePassword,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Enter password',
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E88E5).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.lock,
                                      color: Color(0xFF1E88E5),
                                      size: 20,
                                    ),
                                  ),
                                  suffixIcon: IconButton(
                                    iconSize: 20, // Smaller icon
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.grey[600],
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1E88E5),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Enter password';
                                  }
                                  if (value.length < 3) {
                                    return 'Min 3 characters';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) {
                                  FocusScope.of(context).requestFocus(_deviceMacAddressFocus);
                                },
                              ),

                              const SizedBox(height: 12),

                              // Device Mac Address Field - Compact
                              TextFormField(
                                controller: _deviceMacAddress,
                                focusNode: _deviceMacAddressFocus,
                                obscureText: _obscureDeviceMacAddress,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Device Mac Address',
                                  hintText: 'Enter Mac Address',
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E88E5).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.my_location,
                                      color: Color(0xFF1E88E5),
                                      size: 20,
                                    ),
                                  ),
                                  suffixIcon: IconButton(
                                    iconSize: 20,
                                    icon: Icon(
                                      _obscureDeviceMacAddress
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.grey[600],
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureDeviceMacAddress = !_obscureDeviceMacAddress;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1E88E5),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Enter Mac Address';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => _handleLogin(),
                              ),

                              const SizedBox(height: 16), // Reduced from 30

                              // Error Message - Compact
                              Consumer<AuthProvider>(
                                builder: (context, authProvider, child) {
                                  if (authProvider.errorMessage != null) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12), // Reduced from 20
                                      padding: const EdgeInsets.all(12), // Reduced from 16
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        border: Border.all(color: Colors.red.shade200),
                                        borderRadius: BorderRadius.circular(8), // Reduced from 12
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: Colors.red.shade600,
                                            size: 16, // Reduced from 20
                                          ),
                                          const SizedBox(width: 8), // Reduced from 12
                                          Expanded(
                                            child: Text(
                                              authProvider.errorMessage!,
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontSize: 12, // Reduced from 14
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),

                              // Login Button - Compact
                              SizedBox(
                                width: double.infinity,
                                child: Consumer<AuthProvider>(
                                  builder: (context, authProvider, child) {
                                    return ElevatedButton(
                                      onPressed: authProvider.isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E88E5),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10), // Reduced from 12
                                        ),
                                        elevation: 6, // Reduced from 8
                                        shadowColor: Colors.blue.withOpacity(0.4),
                                      ),
                                      child: authProvider.isLoading
                                          ? const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            height: 16, // Reduced from 20
                                            width: 16, // Reduced from 20
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                          SizedBox(width: 2), // Reduced from 12
                                          Text(
                                            'Signing In...',
                                            style: TextStyle(fontSize: 14), // Reduced from 16
                                          ),
                                        ],
                                      )
                                          :  Center(
                                            child: Text(
                                              'Sign In',
                                              style: TextStyle(
                                            fontSize: 16, // Reduced from 18
                                            fontWeight: FontWeight.bold,
                                                                                    ),
                                                                                  ),
                                          ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}