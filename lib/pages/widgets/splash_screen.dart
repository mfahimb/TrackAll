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
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<Color?> _color;
  late Animation<Alignment> _align;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _scale = Tween(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _color = ColorTween(
      begin: Colors.black,
      end: const Color(0xFF1A237E),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.9, curve: Curves.easeInOut),
      ),
    );

    // Center → near top (matches login card position)
    _align = AlignmentTween(
      begin: Alignment.center,
      end: const Alignment(0, -0.55),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _controller.forward();

    Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;

      final route = await getInitialRoute();
      Widget next;

      switch (route) {
        case '/home':
          next = const home.HomePage();
          break;
        case '/npt_entry':
          next = const npt.NptEntryPage();
          break;
        default:
          next = const login.LoginPage();
      }

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => next,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  Future<String> getInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (!isLoggedIn) return '/login';
    return prefs.getString('lastPage') ?? '/home';
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
        child: FadeTransition(
          opacity: _fade,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return Align(
                alignment: _align.value,
                child: ScaleTransition(
                  scale: _scale,
                  child: Text(
                    "TrackAll",
                    style: TextStyle(
                      fontSize: 42, // EXACT match
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: _color.value,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
