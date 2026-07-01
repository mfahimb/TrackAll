import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../../pages/login_page.dart' as login;
import '../../pages/home_page.dart' as home;
import '../../pages/npt_entry_page.dart' as npt;

// Same endpoints + cache identifiers the login page uses.
const _bannerLovUrl =
    "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov";
const _bannerImgUrl =
    "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/qc_img_upload";
const _bannerFileName = "login_banner.img"; // on-disk cached image
const _bannerNameKey  = "login_banner_file"; // prefs: current server file name

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

  // Banner prefetch kicked off the moment the splash appears.
  late Future<void> _bannerPrefetch;

  @override
  void initState() {
    super.initState();

    // Download + cache the login banner during the splash, in parallel with
    // the animation, so it's ready before the login page appears.
    _bannerPrefetch = _prefetchBanner();

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

      // Make sure the banner finished caching before leaving the splash.
      // Capped so a slow network can never hang the splash.
      await _bannerPrefetch
          .timeout(const Duration(seconds: 2), onTimeout: () {});

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

  // ================================================================
  // BANNER PREFETCH  (disk cache + in-memory handoff to login page)
  // ================================================================
  Future<void> _prefetchBanner() async {
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

      // Already cached the latest file? Load it from disk into memory, done.
      if (cachedName == fileName && await file.exists()) {
        try {
          login.loginBannerBytes = await file.readAsBytes();
        } catch (_) {}
        return;
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

      // Hand the decoded bytes to the login page (instant first-frame render)
      login.loginBannerBytes = finalBytes;
    } catch (e) {
      debugPrint("⚠️ Banner prefetch error: $e");
      // Banner is optional — fail silently.
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