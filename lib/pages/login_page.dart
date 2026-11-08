import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trackall_app/pages/widgets/loading_indicator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'sign_up_page.dart';
// ── Design tokens (match approved mobile mockup) ──────
const _navy      = Color(0xFF456FBC); // hero background (lightened navy)
const _formBg    = Color(0xFFEDF1F9); // light page background
const _cardWhite = Color(0xFFFFFFFF);

const _titleNavy = Color(0xFF1E2A4A);
const _subtitle  = Color(0xFF8A93A5);
const _brandBlue = Color(0xFF2D6CDF);

const _inputFill   = Color(0xFFE9EDF7);
const _inputBorder = Color(0xFFDBE2F0);
const _iconGray    = Color(0xFF7A8499);
const _rememberTxt = Color(0xFF4A5568);

const _btnLeft  = Color(0xFF1E50E5);
const _btnRight = Color(0xFF3B82F6);

const _heroSub   = Color(0xFFDCE6F5);
const _footerGry = Color(0xFF9CA3AF);

// ── Dynamic banner endpoints + cache keys ─────────────
const _bannerLovUrl =
    "https://trackall.rflgroupbd.com/ords/rpro/xxtrac_al/get_lov";
const _bannerImgUrl =
    "https://trackall.rflgroupbd.com/ords/rpro/xxtrac_al/qc_img_upload";
const _bannerFileName = "login_banner.img"; // on-disk cached image
const _bannerNameKey  = "login_banner_file"; // prefs: current server file name

/// In-memory banner bytes handed over by the splash screen, so the login page
/// can paint the banner on its very first frame (no async gap, no pop-in).
Uint8List? loginBannerBytes;

// ── Session TTL ───────────────────────────────────────
// Remember-me: UNLIMITED — only expires on explicit logout
// Normal session: 8 hours
const _normalSessionTtlMs = 8 * 3600 * 1000;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading         = false;
  bool rememberMe      = false;
  bool obscurePassword = true;

  final _userFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _btnPressed = false;

  // Dynamic banner (animated GIF) shown in the navy hero
  Uint8List? _bannerBytes;

  late AnimationController _animationController;
  late Animation<double>   _heroFade;
  late Animation<Offset>   _heroSlide;
  late Animation<double>   _formFade;
  late Animation<Offset>   _formSlide;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1150));

    // Hero: eases down + fades in (first half)
    _heroFade = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, -0.14),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));

    // Form: glides up + fades in (staggered, second half)
    _formFade = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.28, 1.0, curve: Curves.easeOut),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.28, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();

    // Use the banner the splash already decoded (instant, first frame).
    _bannerBytes = loginBannerBytes;

    _loadSavedCredentialsThenCheckSession();
    _loadBanner();

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

  // ================================================================
  // DYNAMIC BANNER  (instant from memory/disk; splash prefetches it)
  // ================================================================
  Future<void> _loadBanner() async {
    // 1. If the splash didn't hand us bytes in memory, read the disk cache.
    if (_bannerBytes == null) {
      try {
        final file = await _bannerFile();
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          loginBannerBytes = bytes;
          if (mounted) setState(() => _bannerBytes = bytes);
        }
      } catch (_) {
        // ignore — banner is optional
      }
    }

    // 2. Refresh from the server in the background (skips download if unchanged)
    try {
      final prefs = await SharedPreferences.getInstance();
      final lovResp =
          await http.get(Uri.parse('$_bannerLovUrl?P_QRYTYP=LOGO_NAME'));
      if (lovResp.statusCode != 200) return;

      final decoded = jsonDecode(lovResp.body);
      final list = decoded['LOGO_NAME'] as List?;
      if (list == null || list.isEmpty) return;

      final first    = list.first as Map;
      final fileName = first['FILE_NAME']?.toString() ?? '';
      final mime     = first['MIME_TPE']?.toString() ?? '';
      if (fileName.isEmpty) return;

      final file       = await _bannerFile();
      final cachedName = prefs.getString(_bannerNameKey);
      if (cachedName == fileName && await file.exists()) {
        return; // already showing the latest
      }

      final imgUri = Uri.parse(
        '$_bannerImgUrl?p_filename=${Uri.encodeComponent(fileName)}'
        '&p_mime=${Uri.encodeComponent(mime)}',
      );
      final imgResp = await http.get(imgUri);
      if (imgResp.statusCode != 200) return;

      final raw = imgResp.bodyBytes;
      if (raw.isEmpty) return;

      Uint8List finalBytes = raw;
      if (!_looksLikeImage(raw)) {
        try {
          var s = utf8.decode(raw).trim();
          final comma = s.indexOf(',');
          if (s.startsWith('data:') && comma != -1) s = s.substring(comma + 1);
          finalBytes = base64Decode(s);
        } catch (_) {
          // keep raw bytes as a last resort
        }
      }

      await file.writeAsBytes(finalBytes, flush: true);
      await prefs.setString(_bannerNameKey, fileName);

      loginBannerBytes = finalBytes;
      if (mounted) setState(() => _bannerBytes = finalBytes);
    } catch (e) {
      debugPrint("⚠️ Banner load error: $e");
      // Banner is optional — fail silently and keep whatever is on screen.
    }
  }

  Future<File> _bannerFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_bannerFileName');
  }

  bool _looksLikeImage(Uint8List b) {
    if (b.length < 4) return false;
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return true; // GIF
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return true; // PNG
    }
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true; // JPEG
    return false;
  }

  // ================================================================
  // SESSION CHECK + CREDENTIAL PRE-FILL  (unchanged)
  // ================================================================
  Future<void> _loadSavedCredentialsThenCheckSession() async {
    final prefs = await SharedPreferences.getInstance();

    final savedRememberMe = prefs.getBool('remember_me') ?? false;
    final savedUser       = prefs.getString('remembered_user') ?? '';
    final savedPass       = prefs.getString('remembered_pass') ?? '';

    debugPrint("🔑 remember_me        : $savedRememberMe");
    debugPrint("🔑 remembered_user    : $savedUser");
    debugPrint("🔑 userId in prefs    : ${prefs.getString('userId')}");
    debugPrint("🔑 loginTime          : ${prefs.getInt('loginTime')}");

    if (mounted) {
      setState(() {
        rememberMe = savedRememberMe;
        if (savedRememberMe && savedUser.isNotEmpty) {
          usernameController.text = savedUser;
          passwordController.text = savedPass;
        }
      });
    }

    final userId            = prefs.getString('userId');
    final loginTime         = prefs.getInt('loginTime');
    final sessionRememberMe = prefs.getBool('session_remember_me') ?? false;
    final selectedCompany   = prefs.getString('selected_company_id') ?? '';

    debugPrint("🔥 session_remember_me : $sessionRememberMe");
    debugPrint("🏢 selected_company    : $selectedCompany");

    if (userId == null || userId.isEmpty) return;

    bool sessionValid = false;
    if (sessionRememberMe) {
      sessionValid = true; // unlimited until logout
    } else {
      if (loginTime != null) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - loginTime;
        sessionValid  = elapsed < _normalSessionTtlMs;
      }
    }

    debugPrint("⏱ sessionValid : $sessionValid");

    if (!sessionValid) return;
    if (!mounted) return;

    if (selectedCompany.isNotEmpty) {
      debugPrint("🚀 Auto-login → /home");
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      debugPrint("🚀 Auto-login → /company_select");
      Navigator.pushReplacementNamed(context, '/company_select');
    }
  }

  // ================================================================
  // LOGIN  (unchanged)
  // ================================================================
  Future<void> login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      showMessage("Please enter User ID and Password");
      return;
    }

    setState(() => loading = true);

    try {
      final uri = Uri.parse(
        "https://trackall.rflgroupbd.com/ords/rpro/xxtrac_al/login_auth",
      );

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
          final now = DateTime.now().millisecondsSinceEpoch;
          final success = data['Success'];
          final staffCode = _extractStaffCode(success, username);

          await prefs.setString('userId', username);
          await prefs.setString('staffCode', staffCode);
          await prefs.setInt('loginTime', now);
          await prefs.setBool('session_remember_me', rememberMe);

          if (!rememberMe) {
            await prefs.remove('selected_company_id');
            await prefs.remove('selected_company_label');
          }

          await _saveFcmToken(username);

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
            final selectedCompany = prefs.getString('selected_company_id');

            if (rememberMe) {
              if (selectedCompany != null && selectedCompany.isNotEmpty) {
                Navigator.pushReplacementNamed(context, '/home');
              } else {
                Navigator.pushReplacementNamed(context, '/company_select');
              }
            } else {
              Navigator.pushReplacementNamed(context, '/company_select');
            }
          }
        } else {
          showMessage(data['error'] ?? "Invalid credentials");
        }
      } else {
        showMessage("Server error: ${response.statusCode}");
      }
    } catch (e) {
      showMessage("Network error: $e");
    }

    if (mounted) setState(() => loading = false);
  }

  // ================================================================
  // FCM TOKEN  (unchanged)
  // ================================================================
  Future<void> _saveFcmToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint("⚠️ FCM token is null — skipping");
        return;
      }

      debugPrint("📱 FCM Token: $token");

      final uri = Uri.parse(
        'https://trackall.rflgroupbd.com/ords/rpro/xxtrac_al/FCM_TOKENS',
      ).replace(queryParameters: {
        'P_APP_USER':  userId,
        'P_FCM_TOKEN': token,
        'P_PLATFORM':  Platform.isIOS ? 'ios' : 'android',
      });

      final response = await http.post(uri);

      if (response.statusCode == 200) {
        debugPrint("✅ FCM token saved: ${response.body}");
      } else {
        debugPrint("⚠️ FCM token save failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("⚠️ FCM token save error: $e");
    }
  }

  // ================================================================
  // HELPERS  (unchanged)
  // ================================================================
  String _extractStaffCode(dynamic success, String fallback) {
    if (success == null) return fallback;

    if (success is Map) {
      final candidates = [
        'STAFF_CODE', 'STAFF_ID', 'EMP_CODE', 'EMP_ID',
        'USER_CODE',  'APP_USER', 'CREATED_BY', 'LOGIN_ID',
        'STAFF_NO',   'USER_ID',  'USER_NAME',
      ];
      for (final key in candidates) {
        final val = success[key]?.toString().trim() ?? '';
        if (val.isNotEmpty) return val;
      }
      return fallback;
    }

    if (success is List && success.isNotEmpty) {
      return _extractStaffCode(success.first, fallback);
    }

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

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _formBg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeTransition(
              opacity: _heroFade,
              child: SlideTransition(position: _heroSlide, child: _buildHero()),
            ),
            FadeTransition(
              opacity: _formFade,
              child: SlideTransition(
                position: _formSlide,
                child: Transform.translate(
                  offset: const Offset(0, -22),
                  child: _buildFormPanel(),
                ),
              ),
            ),
            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }

  // ── Compact navy hero with dot grid + dynamic banner + wavy bottom ──
  Widget _buildHero() {
    final topInset = MediaQuery.of(context).padding.top;
    final heroHeight = topInset + 210; // full navy height (incl. wave)

    return ClipPath(
      clipper: _WaveClipper(),
      child: Container(
        width: double.infinity,
        height: heroHeight,
        color: _navy,
        child: Stack(
          children: [
            // Dot grid (top-right) — sits behind the banner
            Positioned(
              top: topInset + 6,
              right: 0,
              child: SizedBox(
                width: 70,
                height: 42,
                child: CustomPaint(painter: _DotGridPainter()),
              ),
            ),

            // Dynamic banner (animated GIF from API) — bottom-right corner
            if (_bannerBytes != null)
              Positioned(
                bottom: -55,
                right: -90,
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  child: SizedBox(
                    width: 300,
                    child: Image.memory(
                      _bannerBytes!,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                      cacheWidth: 600,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),

            // Hero text (top-left)
            Positioned(
              top: topInset + 22,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Track. Manage.\nAchieve.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B7BE8), Color(0xFF06B6D4)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  const SizedBox(
                    width: 230,
                    child: Text(
                      "Manage resources, tasks and performance in one smart platform.",
                      style: TextStyle(
                          color: _heroSub, fontSize: 11.5, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form panel (logo + card + footer) ────────────────
  Widget _buildFormPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        children: [
          // Logo (uses your existing asset)
          Image.asset('assets/icon/trackall_logo.png', height: 108),
          const SizedBox(height: 6),
          const Text(
            "Resource Management System",
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _titleNavy),
          ),
          const SizedBox(height: 18),

          // ── White card ───────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
            decoration: BoxDecoration(
              color: _cardWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E2A4A).withValues(alpha: 0.10),
                  blurRadius: 36,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  "Welcome Back!",
                  style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: _titleNavy,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Please sign in to continue",
                  style: TextStyle(fontSize: 13, color: _subtitle),
                ),
                const SizedBox(height: 22),

                // Fields
                _buildField(
                  controller: usernameController,
                  focusNode:  _userFocus,
                  icon:       Icons.person_outline_rounded,
                  hint:       "User ID",
                ),
                const SizedBox(height: 15),
                _buildField(
                  controller: passwordController,
                  focusNode:  _passFocus,
                  icon:       Icons.vpn_key_outlined,
                  hint:       "Password",
                  isPassword: true,
                ),
                const SizedBox(height: 16),

                // Remember username
                GestureDetector(
                  onTap: () => setState(() => rememberMe = !rememberMe),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          color: rememberMe ? _brandBlue : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: rememberMe
                                ? _brandBlue
                                : const Color(0xFFC2CADB),
                            width: 1.5,
                          ),
                        ),
                        child: rememberMe
                            ? const Icon(Icons.check,
                                size: 11, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 9),
                      const Text(
                        "Remember username",
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _rememberTxt),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Sign In button (gradient)
                loading
                    ? const SizedBox(
                        height: 48, child: Center(child: LoadingIndicator()))
                    : GestureDetector(
                        onTapDown: (_) => setState(() => _btnPressed = true),
                        onTapUp: (_) => setState(() => _btnPressed = false),
                        onTapCancel: () => setState(() => _btnPressed = false),
                        onTap: login,
                        child: AnimatedScale(
                          scale: _btnPressed ? 0.97 : 1.0,
                          duration: const Duration(milliseconds: 130),
                          curve: Curves.easeOut,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              gradient: const LinearGradient(
                                colors: [_btnLeft, _btnRight],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _brandBlue
                                      .withValues(alpha: _btnPressed ? 0.18 : 0.30),
                                  blurRadius: _btnPressed ? 10 : 16,
                                  offset: Offset(0, _btnPressed ? 3 : 6),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                "Sign In",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),

         const SizedBox(height: 18),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, size: 12, color: _footerGry),
              const SizedBox(width: 6),
              const Text(
                "Secure Login  ·  © 2026 MIS. All rights reserved.",
                style: TextStyle(fontSize: 11, color: _footerGry),
              ),
            ],
          ),

          // Sign Up link — web & iOS only, hidden on Android
          if (kIsWeb || Platform.isIOS) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpPage()),
                );
              },
              child: RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: "New user? ",
                      style: TextStyle(fontSize: 13, color: _subtitle),
                    ),
                    TextSpan(
                      text: "Sign Up here",
                      style: TextStyle(
                        fontSize: 13,
                        color: _brandBlue,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ================================================================
  // FIELD BUILDER (lavender input, focus → white + blue border)
  // ================================================================
  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String hint,
    bool isPassword = false,
  }) {
    final focused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: focused ? Colors.white : _inputFill,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: focused ? _brandBlue : _inputBorder,
          width: focused ? 1.4 : 1.0,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: _brandBlue.withValues(alpha: 0.10),
                  blurRadius: 6,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: _iconGray),
          const SizedBox(width: 11),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: isPassword ? obscurePassword : false,
              style: const TextStyle(
                  color: _titleNavy,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                    color: Color(0xFF9AA3B5), fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (isPassword)
            GestureDetector(
              onTap: () =>
                  setState(() => obscurePassword = !obscurePassword),
              child: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _iconGray,
                size: 17,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Wavy bottom edge for the navy hero ────────────────
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..lineTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h - 22);
    path.cubicTo(w * 0.85, h - 8, w * 0.70, h - 32, w * 0.50, h - 18);
    path.cubicTo(w * 0.30, h - 6, w * 0.15, h - 34, 0, h - 20);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Dot grid decoration (top-right of hero) ───────────
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF4A6BC4).withValues(alpha: 0.30);
    const cols = 5, rows = 3;
    final dx = size.width / (cols - 1);
    final dy = size.height / (rows - 1);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawCircle(Offset(c * dx, r * dy), 1.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}