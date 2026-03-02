import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackall_app/pages/widgets/loading_indicator.dart';

// ── Design tokens ─────────────────────────────────────
const _accent     = Color(0xFF3B82F6);
const _accentGlow = Color(0xFF60A5FA);
const _cyan       = Color(0xFF06B6D4);
const _navy       = Color(0xFF0F172A);

const _bgTop      = Color(0xFFEFF6FF);
const _bgBottom   = Color(0xFFF8FAFC);
const _cardBg     = Colors.white;
const _borderL    = Color(0xFFBFDBFE);
const _textPri    = Color(0xFF0F172A);
const _textSec    = Color(0xFF64748B);
const _inputBg    = Color(0xFFF1F5F9);

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
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
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
        debugPrint("🔑 LOGIN RESPONSE: ${response.body}");

        if (data['Success'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userId', username);
          await prefs.setInt('loginTime', DateTime.now().millisecondsSinceEpoch);

          final success = data['Success'];
          final staffCode = _extractStaffCode(success, username);
          await prefs.setString('staffCode', staffCode);
          debugPrint("🔑 SAVED staffCode=$staffCode");

          if (rememberMe) {
            await prefs.setString('remembered_user', username);
            await prefs.setString('remembered_pass', password);
            await prefs.setBool('remember_me', true);
          } else {
            await prefs.remove('remembered_user');
            await prefs.remove('remembered_pass');
            await prefs.setBool('remember_me', false);
          }

          if (mounted) Navigator.pushReplacementNamed(context, '/company_select');
        } else {
          showMessage(data['error'] ?? "Invalid credentials");
        }
      }
    } catch (e) {
      showMessage("Network error: $e");
    }

    if (mounted) setState(() => loading = false);
  }

  String _extractStaffCode(dynamic success, String fallback) {
    if (success == null) return fallback;
    if (success is Map) {
      final candidates = [
        'STAFF_CODE', 'STAFF_ID', 'EMP_CODE', 'EMP_ID',
        'USER_CODE', 'APP_USER', 'CREATED_BY', 'LOGIN_ID',
        'STAFF_NO', 'USER_ID', 'USER_NAME',
      ];
      for (final key in candidates) {
        final val = success[key]?.toString().trim() ?? '';
        if (val.isNotEmpty) return val;
      }
    }
    if (success is List && success.isNotEmpty)
      return _extractStaffCode(success.first, fallback);
    if (success is String && success.isNotEmpty) return success;
    return fallback;
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: _navy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Gradient background ────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_bgTop, _bgBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // ── Subtle grid overlay ────────────────────────────────────
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // ════════════════════════════════════════════════════════════
          // TWO BUBBLE CIRCLES — peeking in from corners
          // ════════════════════════════════════════════════════════════

          // TOP-RIGHT bubble — large blue circle, half-hidden off-screen
          Positioned(
            top: -110,
            right: -110,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accent.withOpacity(0.55),
                    _accentGlow.withOpacity(0.25),
                  ],
                  stops: const [0.0, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.20),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),

          // BOTTOM-LEFT bubble — large cyan circle, half-hidden off-screen
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _cyan.withOpacity(0.50),
                    const Color(0xFF67E8F9).withOpacity(0.20),
                  ],
                  stops: const [0.0, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _cyan.withOpacity(0.18),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),

          // ── Main content (unchanged from doc 5) ───────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      // ── LOGO ──────────────────────────────────────
                      Column(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_accent, _cyan],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withOpacity(0.28),
                                  blurRadius: 22,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: _cyan.withOpacity(0.12),
                                  blurRadius: 40,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.track_changes_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 16),

                          RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: "Track",
                                  style: TextStyle(
                                    color: _textPri,
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                TextSpan(
                                  text: "All",
                                  style: TextStyle(
                                    color: _accent,
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "SMART TRACKING.  BETTER SOLUTION.",
                            style: TextStyle(
                              color: _textSec,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 44),

                      // ── Login card ─────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _borderL, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withOpacity(0.08),
                              blurRadius: 32,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Welcome back 👋",
                              style: TextStyle(
                                color: _textPri,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Sign in to your account to continue",
                              style: TextStyle(color: _textSec, fontSize: 12),
                            ),
                            const SizedBox(height: 24),

                            _buildField(
                              controller: usernameController,
                              icon: Icons.person_outline_rounded,
                              hint: "User ID",
                            ),
                            const SizedBox(height: 14),
                            _buildField(
                              controller: passwordController,
                              icon: Icons.lock_outline_rounded,
                              hint: "Password",
                              isPassword: true,
                            ),

                            const SizedBox(height: 14),

                            Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: rememberMe,
                                    activeColor: _accent,
                                    checkColor: Colors.white,
                                    side: const BorderSide(
                                        color: _borderL, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4)),
                                    onChanged: (v) =>
                                        setState(() => rememberMe = v!),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  "Keep me signed in",
                                  style: TextStyle(
                                    color: _textSec,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 26),

                            loading
                                ? const Center(child: LoadingIndicator())
                                : GestureDetector(
                                    onTap: login,
                                    child: Container(
                                      width: double.infinity,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        gradient: const LinearGradient(
                                          colors: [
                                            _accent,
                                            Color(0xFF1D4ED8),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _accent.withOpacity(0.32),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "LOGIN",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 1.6,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),
                      const Text(
                        "© MIS-PRAN-RFL Group",
                        style: TextStyle(
                          color: _textSec,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
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

  Widget _buildField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderL, width: 1),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? obscurePassword : false,
        style: const TextStyle(color: _textPri, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: _accent, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: _textSec,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => obscurePassword = !obscurePassword),
                )
              : null,
          hintText: hint,
          hintStyle: const TextStyle(color: _textSec, fontSize: 13),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        ),
      ),
    );
  }
}

// ── Subtle light grid painter ─────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6).withOpacity(0.045)
      ..strokeWidth = 0.6;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}