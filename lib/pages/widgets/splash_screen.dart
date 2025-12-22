import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../pages/login_page.dart' as login;
import '../../pages/home_page.dart' as home;
import '../../pages/npt_entry_page.dart' as npt;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    Timer(const Duration(seconds: 3), () async {
      String route = await getInitialRoute();

      if (!mounted) return;

      switch (route) {
        case '/home':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const home.HomePage()),
          );
          break;

        case '/npt_entry':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const npt.NptEntryPage()),
          );
          break;

        default:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const login.LoginPage()),
          );
      }
    });
  }

  Future<String> getInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lastPage') ?? '/login';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Center(
          child: ScaleTransition(
            scale: _animation,
            child: const Text(
              "TrackAll",
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
