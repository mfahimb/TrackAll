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

// ── Session TTLs ──────────────────────────────────────
// "Keep me signed in" → 30 days
const _rememberMeTtlMs  = 30 * 24 * 3600 * 1000;
// Normal session       → 8 hours
const _normalSessionTtlMs =  8 * 3600 * 1000;

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

  final _userFocus = FocusNode();
  final _passFocus = FocusNode();

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

    // Load saved credentials FIRST, then check session.
    // This ensures rememberMe flag is available before the TTL decision.
    _loadSavedCredentialsThenCheckSession();

    _userFocus.addListener(() => setState(() {}));
    _passFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animationController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  /// Load persisted credentials, then evaluate whether the stored session
  /// is still valid using the correct TTL for that user's remember-me choice.
  Future<void> _loadSavedCredentialsThenCheckSession() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Restore remember-me state and pre-fill fields.
    final savedRememberMe = prefs.getBool('remember_me') ?? false;
    setState(() {
      rememberMe = savedRememberMe;
      if (savedRememberMe) {
        usernameController.text = prefs.getString('remembered_user') ?? '';
        passwordController.text = prefs.getString('remembered_pass') ?? '';
      }
    });

    // 2. Now check whether the existing session is still valid.
    final userId    = prefs.getString('userId');
    final loginTime = prefs.getInt('loginTime');

    if (userId != null && loginTime != null) {
      final now       = DateTime.now().millisecondsSinceEpoch;
      final elapsed   = now - loginTime;
      final ttl       = savedRememberMe ? _rememberMeTtlMs : _normalSessionTtlMs;

      if (elapsed < ttl) {
        // Session still valid → go straight to company select.
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/company_select');
        }
        return;
      }

      // Session expired → clear stale session keys but keep
      // remembered credentials so the fields stay pre-filled.
      await prefs.remove('userId');
      await prefs.remove('loginTime');
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

          // Persist session with the current timestamp.
          await prefs.setString('userId', username);
          await prefs.setInt('loginTime', DateTime.now().millisecondsSinceEpoch);

          final success   = data['Success'];
          final staffCode = _extractStaffCode(success, username);
          await prefs.setString('staffCode', staffCode);
          debugPrint("🔑 SAVED staffCode=$staffCode");

          // Handle remember-me preference.
          if (rememberMe) {
            await prefs.setString('remembered_user', username);
            await prefs.setString('remembered_pass', password);
            await prefs.setBool('remember_me', true);
          } else {
            // User explicitly unchecked → wipe any previously saved creds.
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: _navy,
      ),
    );
  }

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Gradient background ──────────────────────────────────
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

          // ── Subtle grid overlay ──────────────────────────────────
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // TOP-RIGHT bubble
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

          // BOTTOM-LEFT bubble
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

          // ── Main content ─────────────────────────────────────────
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

                      // ── LOGO ─────────────────────────────────────
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

                      const SizedBox(height: 36),

                      // ════════════════════════════════════════════
                      // LOGIN CARD
                      // ════════════════════════════════════════════
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.82),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: _borderL.withOpacity(0.75),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withOpacity(0.11),
                                  blurRadius: 48,
                                  offset: const Offset(0, 20),
                                ),
                                BoxShadow(
                                  color: _cyan.withOpacity(0.07),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Blue→Cyan accent bar
                                Container(
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                        colors: [_accent, _cyan]),
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(28)),
                                  ),
                                ),

                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      24, 22, 24, 26),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Header
                                      Row(children: [
                                        Container(
                                          padding: const EdgeInsets.all(9),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                _accent.withOpacity(0.12),
                                                _cyan.withOpacity(0.08),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: _accent
                                                    .withOpacity(0.18)),
                                          ),
                                          child: const Icon(
                                              Icons.waving_hand_rounded,
                                              color: _accent,
                                              size: 17),
                                        ),
                                        const SizedBox(width: 12),
                                        const Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Welcome back!",
                                              style: TextStyle(
                                                color: _textPri,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                            Text(
                                              "Sign in to continue",
                                              style: TextStyle(
                                                  color: _textSec,
                                                  fontSize: 11.5),
                                            ),
                                          ],
                                        ),
                                      ]),

                                      const SizedBox(height: 20),

                                      // Fading divider
                                      Container(
                                        height: 1,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [
                                            _borderL.withOpacity(0),
                                            _borderL.withOpacity(0.9),
                                            _borderL.withOpacity(0),
                                          ]),
                                        ),
                                      ),

                                      const SizedBox(height: 20),

                                      // Fields
                                      _buildField(
                                        controller: usernameController,
                                        focusNode: _userFocus,
                                        icon: Icons.person_outline_rounded,
                                        hint: "User ID",
                                        label: "USER ID",
                                      ),
                                      const SizedBox(height: 14),
                                      _buildField(
                                        controller: passwordController,
                                        focusNode: _passFocus,
                                        icon: Icons.lock_outline_rounded,
                                        hint: "Password",
                                        label: "PASSWORD",
                                        isPassword: true,
                                      ),

                                      const SizedBox(height: 18),

                                      // ── Remember me ─────────────────────────────
                                      // Shows a subtle badge when active so the
                                      // user always knows the 30-day session is on.
                                      GestureDetector(
                                        onTap: () => setState(() =>
                                            rememberMe = !rememberMe),
                                        child: Row(children: [
                                          // Animated checkbox
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              gradient: rememberMe
                                                  ? const LinearGradient(
                                                      colors: [_accent, _cyan],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    )
                                                  : null,
                                              color: rememberMe
                                                  ? null
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: rememberMe
                                                    ? _accent
                                                    : _borderL,
                                                width: 1.6,
                                              ),
                                              boxShadow: rememberMe
                                                  ? [
                                                      BoxShadow(
                                                        color: _accent
                                                            .withOpacity(0.28),
                                                        blurRadius: 8,
                                                        offset:
                                                            const Offset(0, 2),
                                                      )
                                                    ]
                                                  : null,
                                            ),
                                            child: rememberMe
                                                ? const Icon(
                                                    Icons.check_rounded,
                                                    size: 13,
                                                    color: Colors.white)
                                                : null,
                                          ),
                                          const SizedBox(width: 10),
                                          const Text(
                                            "Keep me signed in",
                                            style: TextStyle(
                                              color: _textSec,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          // "30 days" badge – only visible when active
                                          AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 200),
                                            child: rememberMe
                                                ? Padding(
                                                    key: const ValueKey('badge'),
                                                    padding: const EdgeInsets.only(left: 8),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 7, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            _accent.withOpacity(0.12),
                                                            _cyan.withOpacity(0.10),
                                                          ],
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(20),
                                                        border: Border.all(
                                                            color: _accent.withOpacity(0.25)),
                                                      ),
                                                      child: const Text(
                                                        "30 days",
                                                        style: TextStyle(
                                                          color: _accent,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : const SizedBox.shrink(
                                                    key: ValueKey('empty')),
                                          ),
                                        ]),
                                      ),

                                      const SizedBox(height: 26),

                                      // Login button
                                      loading
                                          ? const Center(
                                              child: LoadingIndicator())
                                          : GestureDetector(
                                              onTap: login,
                                              child: Container(
                                                width: double.infinity,
                                                height: 52,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  gradient:
                                                      const LinearGradient(
                                                    colors: [
                                                      _accent,
                                                      Color(0xFF1D4ED8),
                                                    ],
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: _accent
                                                          .withOpacity(0.35),
                                                      blurRadius: 18,
                                                      offset:
                                                          const Offset(0, 6),
                                                    ),
                                                    BoxShadow(
                                                      color: _cyan
                                                          .withOpacity(0.15),
                                                      blurRadius: 28,
                                                      offset:
                                                          const Offset(0, 10),
                                                    ),
                                                  ],
                                                ),
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    // shine
                                                    Positioned(
                                                      top: 0,
                                                      left: 0,
                                                      right: 0,
                                                      child: Container(
                                                        height: 26,
                                                        decoration:
                                                            BoxDecoration(
                                                          borderRadius:
                                                              const BorderRadius
                                                                  .vertical(
                                                                  top: Radius
                                                                      .circular(
                                                                          14)),
                                                          gradient:
                                                              LinearGradient(
                                                            colors: [
                                                              Colors.white
                                                                  .withOpacity(
                                                                      0.14),
                                                              Colors.white
                                                                  .withOpacity(
                                                                      0),
                                                            ],
                                                            begin: Alignment
                                                                .topCenter,
                                                            end: Alignment
                                                                .bottomCenter,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          "SIGN IN",
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: Colors.white,
                                                            letterSpacing: 2.2,
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
                                                        Icon(
                                                          Icons
                                                              .arrow_forward_rounded,
                                                          color: Colors.white,
                                                          size: 16,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  // ================================================================
  // FIELD BUILDER
  // ================================================================
  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String hint,
    required String label,
    bool isPassword = false,
  }) {
    final focused = focusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: focused ? _accent : _textSec,
              letterSpacing: 0.8,
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: focused ? Colors.white : _inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: focused ? _accent : _borderL.withOpacity(0.65),
              width: focused ? 1.6 : 1.0,
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: _accent.withOpacity(0.13),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: focused
                        ? [_accent, _cyan]
                        : [
                            _borderL.withOpacity(0.55),
                            _borderL.withOpacity(0.30),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: focused ? Colors.white : _textSec,
                  size: 15,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  obscureText: isPassword ? obscurePassword : false,
                  style: const TextStyle(
                      color: _textPri,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                        color: _textSec.withOpacity(0.55), fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (isPassword)
                GestureDetector(
                  onTap: () =>
                      setState(() => obscurePassword = !obscurePassword),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: focused ? _accent : _textSec,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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