import 'dart:math' as math;
import 'package:advertising_screen/home_page.dart';
import 'package:advertising_screen/provider/content_provider.dart';
import 'package:advertising_screen/provider/handle_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app_restart.dart';
import 'constant/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  // Hide system UI for fullscreen experience
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(RestartWidget(child: const MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}
class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Create providers first, then access them inside
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ContentProvider()),
      ],
      // Use builder to get access to the providers
      builder: (context, child) {
        return Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            // Now we can safely access the AuthProvider
            final isLandscape = authProvider.orientationMode;
            print("isLandscape,,,$isLandscape  ");

            if (isLandscape == "landscape") {
              // Landscape mode - normal app layout
              return MaterialApp(
                title: 'Restaurant Display',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                home: HomePage(),
              );
            } else {
              // Portrait mode - rotated layout
              return Directionality(
                textDirection: TextDirection.ltr,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = constraints.maxWidth;
                    final screenHeight = constraints.maxHeight;
                    return ClipRect(
                      child: SizedBox(
                        width: screenWidth,
                        height: screenHeight,
                        child: OverflowBox(
                          minWidth: screenHeight,
                          maxWidth: screenHeight,
                          minHeight: screenWidth,
                          maxHeight: screenWidth,
                          child: Transform.rotate(
                            angle: math.pi / 2,
                            child: SizedBox(
                              width: screenHeight,
                              height: screenWidth,
                              child: MaterialApp(
                                title: 'Restaurant Display',
                                debugShowCheckedModeBanner: false,
                                theme: AppTheme.lightTheme,
                                home: HomePage(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }
          },
        );
      },
    );
  }
}