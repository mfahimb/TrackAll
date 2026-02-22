import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackall_app/pages/widgets/loading_indicator.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool rememberMe = false;
  bool obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();

    _loadSavedCredentials();
    _checkSession();
  }

  @override
  void dispose() {
    _animationController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      usernameController.text = prefs.getString('remembered_user') ?? '';
      passwordController.text = prefs.getString('remembered_pass') ?? '';
      rememberMe = prefs.getBool('remember_me') ?? false;
    });
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final loginTime = prefs.getInt('loginTime');

    if (userId != null && loginTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - loginTime < 3600 * 1000) {
        Navigator.pushReplacementNamed(context, '/company_select');
      }
    }
  }

  Future<void> login() async {
    setState(() => loading = true);
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    try {
      final uri = Uri.parse(
          "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/login_auth");
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: "p_username=$username&p_password=$password",
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userId', username);
          await prefs.setInt(
              'loginTime', DateTime.now().millisecondsSinceEpoch);

          if (rememberMe) {
            await prefs.setString('remembered_user', username);
            await prefs.setString('remembered_pass', password);
            await prefs.setBool('remember_me', true);
          } else {
            await prefs.remove('remembered_user');
            await prefs.remove('remembered_pass');
            await prefs.setBool('remember_me', false);
          }

          if (mounted) {
            Navigator.pushReplacementNamed(context, '/company_select');
          }
        } else {
          showMessage(data['error'] ?? "Invalid credentials");
        }
      }
    } catch (e) {
      showMessage("Network error: $e");
    }

    if (mounted) setState(() => loading = false);
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF1A237E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: _buildBackgroundBlob(
                400, const Color(0xFFB6E0FE).withOpacity(0.5)),
          ),
          Positioned(
            bottom: -50,
            left: -80,
            child: _buildBackgroundBlob(
                350, const Color(0xFFD1E9FF).withOpacity(0.6)),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // LOGO CARD
                      ClipRRect(
                        borderRadius: BorderRadius.circular(35),
                        child: BackdropFilter(
                          filter:
                              ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.symmetric(vertical: 35),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(35),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.7),
                                  width: 1.5),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.radar_rounded,
                                    size: 55,
                                    color: Color(0xFF2196F3)),
                                const SizedBox(height: 12),
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                    colors: [
                                      Color(0xFF1A237E),
                                      Color(0xFF2196F3)
                                    ],
                                  ).createShader(bounds),
                                  child: const Text(
                                    "TrackAll",
                                    style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white),
                                  ),
                                ),
                                const Text(
                                  "SMART TRACKING.BETTER SOLUTION.",
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF5C7C99),
                                      letterSpacing: 2.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 45),

                      _buildAestheticField(
                        controller: usernameController,
                        icon: Icons.person_outline_rounded,
                        hint: "User ID",
                      ),
                      const SizedBox(height: 20),
                      _buildAestheticField(
                        controller: passwordController,
                        icon: Icons.lock_outline_rounded,
                        hint: "Password",
                        isPassword: true,
                      ),

                      const SizedBox(height: 15),

                      // REMEMBER ME ONLY
                      Row(
                        children: [
                          Checkbox(
                            value: rememberMe,
                            activeColor: const Color(0xFF2196F3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            onChanged: (v) =>
                                setState(() => rememberMe = v!),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Keep me signed in",
                            style: TextStyle(
                                color: Color(0xFF5C7C99),
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),

                      const SizedBox(height: 35),

                      loading
                          ? const LoadingIndicator()
                          : GestureDetector(
                              onTap: login,
                              child: Container(
                                width: double.infinity,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2196F3),
                                      Color(0xFF1A237E)
                                    ],
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    "LOGIN",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 1.2),
                                  ),
                                ),
                              ),
                            ),

                      const SizedBox(height: 40),
                      const Text(
                        "© MIS-PRAN-RFL Group",
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAestheticField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8)),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? obscurePassword : false,
        decoration: InputDecoration(
          prefixIcon:
              Icon(icon, color: const Color(0xFF2196F3)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  onPressed: () =>
                      setState(() => obscurePassword = !obscurePassword),
                )
              : null,
          hintText: hint,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        ),
      ),
    );
  }

  Widget _buildBackgroundBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
