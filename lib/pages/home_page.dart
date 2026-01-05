import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/top_menu_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _saveLastPage();
    _checkSession();
  }

  Future<void> _saveLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastPage', '/home');
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final loginTime = prefs.getInt('loginTime');

    if (userId == null || loginTime == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - loginTime > 3600 * 1000) {
      await prefs.clear();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// 🔹 Background image
          Positioned.fill(
            child: Image.asset(
              'assets/icon/1691480144736.jpg',
              fit: BoxFit.cover,
            ),
          ),

          /// 🔹 Cooler modern overlay (not flat white)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFEFF4FF).withOpacity(0.75),
                    const Color(0xFFF8FAFC).withOpacity(0.90),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          /// 🔹 Main content (STRUCTURE INTACT)
          Column(
            children: [
              const TopMenuBar(),

              Expanded(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.65),
                              Colors.white.withOpacity(0.45),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: const Color(0xFF4F8CFF).withOpacity(0.25),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 30,
                              offset: Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              "Welcome to",
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "TrackAll Dashboard",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(height: 10),
                            SizedBox(
                              width: 42,
                              height: 4,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(10)),
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF4F8CFF),
                                      Color(0xFF38BDF8),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
