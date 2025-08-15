import 'package:advertising_screen/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLoggedIn = false; // renamed for clarity

  @override
  void initState() {
    super.initState();
    _checkUserAlreadyLoggedOrNot();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoggedIn ? SplashScreen() : LoginScreen(),
    );
  }
  void _checkUserAlreadyLoggedOrNot() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    int? id = pref.getInt("user_Id");
    print("ioo.>>$id");
    if (id != null && id > 0) {
      setState(() {
        isLoggedIn = true;
      });
    } else {
      setState(() {
        isLoggedIn = false;
      });
    }
  }
}
