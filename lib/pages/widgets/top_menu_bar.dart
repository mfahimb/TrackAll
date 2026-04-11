// lib/pages/widgets/top_menu_bar.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:trackall_app/services/approval_lov.dart';

import '../npt_entry_page.dart';
import '../ctl_npt_entry_page.dart';
import '../company_select_page.dart';
import '../sos_page.dart';
import '../qc_entry_page.dart';
import '../production_entry_page.dart';
import '../Plan no wise production entry page.dart';
import '../kanban_board_page.dart';
import '../user_log.dart';
import '../packing_production_entry_page.dart';
import '../plan_wise_packing_entry_page.dart';
import '../incentive/line_wise_staff_scan_page.dart';
import '../../services/notification_service.dart';

import 'package:trackall_app/services/notification/poc_notification/poc_notification_service.dart';
import 'package:trackall_app/services/notification/poc_notification/poc_notification_overlay.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../Approval/POC Approval/ie_poc_approval.dart';
import '../Approval/POC Approval/coaster_poc_approval.dart';
import '../Approval/POC Approval/fc_poc_approval.dart';

// ─────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────
const _navy       = Color(0xFF060D1F);
const _navyLight  = Color(0xFF0D1B35);
const _accent     = Color(0xFF3B82F6);
const _accentGlow = Color(0xFF60A5FA);
const _cyan       = Color(0xFF06B6D4);
const _border     = Color(0xFF1E3A5F);
const _textPri    = Colors.white;
const _textSec    = Color(0xFF94A3B8);
const _danger     = Color(0xFFEF4444);

// ─────────────────────────────────────────────
// POC STAGE META — used for system notification text + navigation
// ─────────────────────────────────────────────
class _PocStageMeta {
  final String label;
  final String subtitle;
  final int    menuId;
  final int    notifIdOffset; // 0=IE, 1=Coaster, 2=FC
  final String payload;
  final Widget Function() pageBuilder;

  const _PocStageMeta({
    required this.label,
    required this.subtitle,
    required this.menuId,
    required this.notifIdOffset,
    required this.payload,
    required this.pageBuilder,
  });
}

final _pocStageMeta = <ApprovalStage, _PocStageMeta>{
  ApprovalStage.ie: _PocStageMeta(
    label:         'IE POC Approval',
    subtitle:      '1st Approval — Industrial Engineering',
    menuId:        149,
    notifIdOffset: 0,
    payload:       'poc_approval_0',
    pageBuilder:   () => const IEPocApprovalPage(),
  ),
  ApprovalStage.coaster: _PocStageMeta(
    label:         'Coaster POC Approval',
    subtitle:      '2nd Approval — Coaster',
    menuId:        147,
    notifIdOffset: 1,
    payload:       'poc_approval_1',
    pageBuilder:   () => const CoasterPocApprovalPage(),
  ),
  ApprovalStage.fc: _PocStageMeta(
    label:         'FC POC Approval',
    subtitle:      '3rd Approval — FC',
    menuId:        148,
    notifIdOffset: 2,
    payload:       'poc_approval_2',
    pageBuilder:   () => const FcPocApprovalPage(),
  ),
};

// ─────────────────────────────────────────────
// TOP MENU BAR
// ─────────────────────────────────────────────
class TopMenuBar extends StatefulWidget {
  const TopMenuBar({super.key});

  @override
  State<TopMenuBar> createState() => _TopMenuBarState();
}

class _TopMenuBarState extends State<TopMenuBar>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  String?   userId;
  String?   companyLabel;
  String    _company = '5';
  List<int> assignedMenuIds = [];

  final _notifSvc = PocNotificationService();
  late AnimationController _pulse;

  // Tracks what counts were last shown to avoid banner/notif spam
  Map<ApprovalStage, int> _lastShownCounts = {};

  bool get isAdmin => userId?.trim() == "540150";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // ✅ FCM: when a push arrives while app is open (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📨 Foreground FCM: ${message.data}");
      _pollNotifications(); // refresh counts + show in-app banner
    });

    // ✅ FCM: when user taps notification while app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("📨 FCM tapped (background): ${message.data}");
      _handleFcmNavigation(message.data);
    });

    _loadUserData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleNotificationTap(); // local notif tap handler
      _pollNotifications();
    }
  }

  // ── Navigate based on FCM data payload (stage key) ────────────────
  void _handleFcmNavigation(Map<String, dynamic> data) {
    final stage = data['stage'] as String?;
    if (stage == null || !mounted) return;

    Widget? page;
    switch (stage) {
      case 'ie':      page = const IEPocApprovalPage();      break;
      case 'coaster': page = const CoasterPocApprovalPage(); break;
      case 'fc':      page = const FcPocApprovalPage();      break;
    }

    if (page != null) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => page!),
      );
    }
  }

  // ── Handle local system notification tap → navigate ───────────────
  void _handleNotificationTap() {
    final payload = NotificationService.lastTappedPayload;
    if (payload == null) return;
    NotificationService.lastTappedPayload = null;

    Widget? page;
    for (final entry in _pocStageMeta.entries) {
      if (entry.value.payload == payload) {
        page = entry.value.pageBuilder();
        break;
      }
    }

    if (page != null && mounted) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => page!),
      );
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    userId       = prefs.getString('userId');
    companyLabel = prefs.getString('selected_company_label');
    _company     = prefs.getString('selected_company_id') ?? '5';

    if (userId != null) {
      assignedMenuIds = await _fetchUserMenuIds(userId!);
      debugPrint('🔑 User: $userId — Menu IDs: $assignedMenuIds');

      try {
        await NotificationService().scheduleAllForUser(assignedMenuIds);
      } catch (e) {
        debugPrint('⚠️ Notification scheduling failed: $e');
      }
    }

    if (mounted) setState(() {});
    await _pollNotifications();
  }

  // ── Poll API + fire in-app banners + system notifications ─────────
  Future<void> _pollNotifications() async {
    if (assignedMenuIds.isEmpty) return;

    await _notifSvc.refresh(_company, assignedMenuIds);

    if (!mounted) return;

    final rawCounts = _notifSvc.rawCounts;

    bool hasChanges = false;
    final stagesToShow = <ApprovalStage>[];

    for (final stage in ApprovalStage.values) {
      final current  = rawCounts[stage] ?? 0;
      final lastSeen = _lastShownCounts[stage] ?? -1;

      if (current > 0 && current != lastSeen) {
        hasChanges = true;
        stagesToShow.add(stage);

        // ✅ Fire system notification — only if user has menu access
        final meta = _pocStageMeta[stage]!;
        if (assignedMenuIds.contains(meta.menuId)) {
          try {
            await NotificationService().showPocApprovalNotification(
              stage:    meta.label,
              subtitle: meta.subtitle,
              count:    current,
              idOffset: meta.notifIdOffset,
            );
          } catch (e) {
            debugPrint('⚠️ POC system notif failed for ${meta.label}: $e');
          }
        }
      }
    }

    if (hasChanges) {
      showPocBanners(stagesToShow, rawCounts);
      _lastShownCounts = Map.from(rawCounts);
    }

    _notifSvc.clearAlerts();
  }

  Future<List<int>> _fetchUserMenuIds(String appUser) async {
    try {
      final uri = Uri.parse(
              'https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov')
          .replace(queryParameters: {
        'P_QRYTYP':   'MENU',
        'P_APP_USER': appUser,
      });
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return [];
      final decoded = jsonDecode(resp.body);
      final List list = decoded['MENU'] ?? [];
      return list.map<int>((e) => e['IDM_ID'] as int).toList();
    } catch (_) {
      return [];
    }
  }

  void _openSidebar() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Sidebar',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (context, anim1, anim2) => Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: _ModernSidebar(
            animation:       anim1,
            userId:          userId,
            companyLabel:    companyLabel,
            isAdmin:         isAdmin,
            assignedMenuIds: assignedMenuIds,
            onLogout:        _logout,
          ),
        ),
      ),
      transitionBuilder: (context, anim1, anim2, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1, 0),
          end:   Offset.zero,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  // ── LOGOUT — cancel notifications + remove FCM token ──────────────
  Future<void> _logout() async {
    // Cancel all scheduled local notifications
    try {
      await NotificationService().cancelAllNotifications();
    } catch (_) {}

    // ✅ Remove FCM token from backend + delete locally
    // This stops push notifications being sent to this device after logout
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && userId != null) {
          await http.post(
            Uri.parse(
              'https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/remove_fcm_token',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'P_USER_ID':   userId,
              'P_FCM_TOKEN': token,
            }),
          );
          debugPrint("✅ FCM token removed from backend");
        }
        // Delete the token locally so a fresh one is generated on next login
        await FirebaseMessaging.instance.deleteToken();
        debugPrint("✅ FCM token deleted locally");
      } catch (e) {
        debugPrint("⚠️ FCM token removal failed (non-fatal): $e");
      }
    }

    // Clear session but preserve remember-me credentials if set
    final prefs          = await SharedPreferences.getInstance();
    final rememberMe     = prefs.getBool('remember_me')      ?? false;
    final rememberedUser = prefs.getString('remembered_user');
    final rememberedPass = prefs.getString('remembered_pass');

    await prefs.clear();

    if (rememberMe && rememberedUser != null && rememberedPass != null) {
      await prefs.setBool('remember_me',       true);
      await prefs.setString('remembered_user', rememberedUser);
      await prefs.setString('remembered_pass', rememberedPass);
    }

    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final isMobile    = MediaQuery.of(context).size.width < 600;
    final statusBarH  = MediaQuery.of(context).padding.top;
    final barContentH = isMobile ? 52.0 : 58.0;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        height: statusBarH + barContentH,
        decoration: BoxDecoration(
          color: _navy,
          border: Border(
            bottom: BorderSide(
              color: _accent.withValues(alpha: 0.15 + _pulse.value * 0.08),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color:      _accent.withValues(alpha: 0.08 + _pulse.value * 0.04),
              blurRadius: 20,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0, right: 0, bottom: 0,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width < 600 ? 8 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _MenuButton(
                    onTap:    _openSidebar,
                    isMobile: MediaQuery.of(context).size.width < 600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          Navigator.pushReplacementNamed(context, '/home'),
                      child: const _LogoBadge(),
                    ),
                  ),
                  if (companyLabel != null) ...[
                    _CompanyChip(
                      label:    companyLabel!,
                      isMobile: MediaQuery.of(context).size.width < 600,
                    ),
                    const SizedBox(width: 8),
                  ],
                  PocBellIcon(
                    isMobile: MediaQuery.of(context).size.width < 600,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HAMBURGER BUTTON
// ─────────────────────────────────────────────
class _MenuButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isMobile;
  const _MenuButton({required this.onTap, required this.isMobile});

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.isMobile ? 36.0 : 40.0;
    return GestureDetector(
      onTapDown:   (_) { setState(() => _pressed = true);  _ctrl.forward(); },
      onTapUp:     (_) { setState(() => _pressed = false); _ctrl.reverse(); widget.onTap(); },
      onTapCancel: ()  { setState(() => _pressed = false); _ctrl.reverse(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size, height: size,
        decoration: BoxDecoration(
          color: _pressed
              ? _accent.withValues(alpha: 0.2)
              : _accentGlow.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _pressed ? _accent.withValues(alpha: 0.5) : _border,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _bar(1.0), const SizedBox(height: 4),
            _bar(0.7),  const SizedBox(height: 4),
            _bar(0.85),
          ],
        ),
      ),
    );
  }

  Widget _bar(double f) => Container(
        width: 16 * f, height: 1.5,
        decoration: BoxDecoration(
          color: _accentGlow,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

// ─────────────────────────────────────────────
// LOGO BADGE
// ─────────────────────────────────────────────
class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_accent, _cyan],
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight),
            borderRadius: BorderRadius.circular(7),
            boxShadow: [
              BoxShadow(
                  color:      _accent.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset:     const Offset(0, 3)),
            ],
          ),
          child: const Icon(Icons.track_changes_rounded,
              color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        RichText(
          text: const TextSpan(children: [
            TextSpan(
              text: 'Track',
              style: TextStyle(
                  color:         _textPri,
                  fontSize:      18,
                  fontWeight:    FontWeight.w800,
                  letterSpacing: -0.3),
            ),
            TextSpan(
              text: 'All',
              style: TextStyle(
                  color:         _accentGlow,
                  fontSize:      18,
                  fontWeight:    FontWeight.w800,
                  letterSpacing: -0.3),
            ),
          ]),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// COMPANY CHIP
// ─────────────────────────────────────────────
class _CompanyChip extends StatelessWidget {
  final String label;
  final bool isMobile;
  const _CompanyChip({required this.label, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final maxW = isMobile
        ? MediaQuery.of(context).size.width * 0.28
        : 180.0;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 7 : 10,
            vertical:   isMobile ? 5 : 6),
        decoration: BoxDecoration(
          color: _navyLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border, width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
                color: Color(0xFF22C55E), shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                  color:         _textSec,
                  fontSize:      isMobile ? 9 : 10,
                  fontWeight:    FontWeight.w600,
                  letterSpacing: 0.1),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GRID PAINTER
// ─────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _accent.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;
    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────
// MODERN SIDEBAR
// ─────────────────────────────────────────────
class _ModernSidebar extends StatefulWidget {
  final Animation<double> animation;
  final String?           userId;
  final String?           companyLabel;
  final bool              isAdmin;
  final List<int>         assignedMenuIds;
  final VoidCallback      onLogout;

  const _ModernSidebar({
    required this.animation,
    required this.userId,
    required this.companyLabel,
    required this.isAdmin,
    required this.assignedMenuIds,
    required this.onLogout,
  });

  @override
  State<_ModernSidebar> createState() => _ModernSidebarState();
}

class _ModernSidebarState extends State<_ModernSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _stagger;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW  = MediaQuery.of(context).size.width;
    final sidebarW = (screenW * 0.78).clamp(0.0, 300.0);

    final showApproval =
        widget.assignedMenuIds.contains(66)  ||
        widget.assignedMenuIds.contains(146) ||
        widget.assignedMenuIds.contains(149) ||
        widget.assignedMenuIds.contains(147) ||
        widget.assignedMenuIds.contains(148);

    return Container(
      width: sidebarW,
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        color: _navy,
        border: Border(right: BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withValues(alpha: 0.5),
              blurRadius: 32,
              offset:     const Offset(8, 0)),
        ],
      ),
      child: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              children: [
                _anim(0, _section('Production',
                    Icons.precision_manufacturing_rounded,
                    _productionItems())),
                _anim(1, _section('Work Study',
                    Icons.analytics_rounded, _workStudyItems())),
                _anim(2, _section('Common',
                    Icons.dashboard_rounded, _commonItems())),
                if (widget.assignedMenuIds.contains(106) ||
                    widget.assignedMenuIds.contains(109) ||
                    widget.assignedMenuIds.contains(262))
                  _anim(3, _section('Incentive',
                      Icons.emoji_events_rounded, _incentiveItems())),
                if (showApproval)
                  _anim(4, _NestedExpandableSection(
                    title:       'Approval',
                    icon:        Icons.rule_folder_rounded,
                    subSections: _approvalSubSections(),
                  )),
                _anim(5, _navItem(
                  icon:  Icons.person_pin_circle_rounded,
                  label: 'My Log',
                  color: _cyan,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const UserLogPage()));
                  },
                )),
                if (widget.isAdmin)
                  _anim(6, _section('Admin',
                      Icons.admin_panel_settings_rounded,
                      _adminItems())),
                const SizedBox(height: 16),
                _anim(7, Container(
                    height: 1,
                    color: _border,
                    margin: const EdgeInsets.symmetric(vertical: 4))),
                _anim(8, _navItem(
                  icon:  Icons.swap_horiz_rounded,
                  label: 'Change Company',
                  color: _accentGlow,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const CompanySelectPage()));
                  },
                )),
                _anim(9, _navItem(
                  icon:  Icons.logout_rounded,
                  label: 'Logout',
                  color: _danger,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onLogout();
                  },
                )),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _anim(int index, Widget child) {
    final delay = index * 0.08;
    return AnimatedBuilder(
      animation: _stagger,
      builder: (_, __) {
        final t     = ((_stagger.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        final curve = Curves.easeOutCubic.transform(t);
        return Transform.translate(
          offset: Offset(-20 * (1 - curve), 0),
          child: Opacity(opacity: curve, child: child),
        );
      },
    );
  }

  Widget _section(String title, IconData icon, List<_MenuItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return _ExpandableSection(title: title, icon: icon, items: items);
  }

  Widget _navItem({
    required IconData     icon,
    required String       label,
    required Color        color,
    required VoidCallback onTap,
  }) => _SidebarTile(icon: icon, label: label, color: color, onTap: onTap);

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        decoration: BoxDecoration(
            color: _navyLight,
            border: Border(bottom: BorderSide(color: _border, width: 1))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [_accent, _cyan],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight),
                boxShadow: [
                  BoxShadow(
                      color:      _accent.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset:     const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Signed in as',
                      style: TextStyle(
                          color:         _textSec,
                          fontSize:      10,
                          fontWeight:    FontWeight.w500,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 3),
                  Text(widget.userId ?? 'User',
                      style: const TextStyle(
                          color:      _textPri,
                          fontSize:   15,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ]),
          if (widget.companyLabel != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accent.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                const Icon(Icons.business_rounded,
                    size: 13, color: _accentGlow),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(widget.companyLabel!,
                      style: const TextStyle(
                          color:      _accentGlow,
                          fontSize:   11,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ],
        ]),
      );

  List<_MenuItem> _productionItems() {
    final i = <_MenuItem>[];
    if (widget.assignedMenuIds.contains(133))
      i.add(_MenuItem(
          label: 'QC Entry',
          icon:  Icons.verified_rounded,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const QCEntryPage()))));
    if (widget.assignedMenuIds.contains(11))
      i.add(_MenuItem(
          label: 'Production Entry',
          icon:  Icons.add_chart_rounded,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const ProductionEntryPage()))));
    if (widget.assignedMenuIds.contains(205))
      i.add(_MenuItem(
          label: 'Plan No Wise Production',
          icon:  Icons.event_note_rounded,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const PlanNoWiseProductionEntryPage()))));
    if (widget.assignedMenuIds.contains(37))
      i.add(_MenuItem(
          label: 'Packing Entry',
          icon:  Icons.inventory_2_rounded,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const PackingProductionEntryPage()))));
    if (widget.assignedMenuIds.contains(206))
      i.add(_MenuItem(
          label: 'Plan Wise Packing Entry',
          icon:  Icons.inventory_outlined,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const PlanWisePackingEntryPage()))));
    return i;
  }

  List<_MenuItem> _workStudyItems() {
    final i = <_MenuItem>[];
    if (widget.assignedMenuIds.contains(40))
      i.add(_MenuItem(
          label: 'Downtime Entry',
          icon:  Icons.timer_off_rounded,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NptEntryPage()))));
    if (widget.assignedMenuIds.contains(165))
      i.add(_MenuItem(
          label: 'CTL Downtime',
          icon:  Icons.hourglass_bottom_rounded,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const CtlNptEntryPage()))));
    return i;
  }

  List<_MenuItem> _commonItems() {
    final i = <_MenuItem>[];
    if (widget.assignedMenuIds.contains(231))
      i.add(_MenuItem(
          label: 'Kanban',
          icon:  Icons.view_kanban_rounded,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SOSPage()))));
    if (widget.assignedMenuIds.contains(232))
      i.add(_MenuItem(
          label: 'Kanban Board',
          icon:  Icons.dashboard_customize_rounded,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const KanbanBoardPage()))));
    return i;
  }

  List<_MenuItem> _incentiveItems() {
    final i = <_MenuItem>[];
    if (widget.assignedMenuIds.contains(109) ||
        widget.assignedMenuIds.contains(262))
      i.add(_MenuItem(
          label: 'Line Wise Staff Scan',
          icon:  Icons.qr_code_scanner_rounded,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => LineWiseStaffScanPage()))));
    return i;
  }

  List<_SubSection> _approvalSubSections() {
    final poc = <_MenuItem>[];
    if (widget.assignedMenuIds.contains(149))
      poc.add(_MenuItem(
          label: 'IE POC Approval',
          icon:  Icons.engineering_rounded,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const IEPocApprovalPage()))));
    if (widget.assignedMenuIds.contains(147))
      poc.add(_MenuItem(
          label: 'Coster POC Approval',
          icon:  Icons.calculate_rounded,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const CoasterPocApprovalPage()))));
    if (widget.assignedMenuIds.contains(148))
      poc.add(_MenuItem(
          label: 'FC POC Approval',
          icon:  Icons.account_balance_rounded,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const FcPocApprovalPage()))));

    if (poc.isEmpty) return [];
    return [
      _SubSection(
          label: 'POC Approval',
          icon:  Icons.approval_rounded,
          items: poc)
    ];
  }

  List<_MenuItem> _adminItems() => [
        _MenuItem(
            label: 'Admin Panel',
            icon:  Icons.manage_accounts_rounded,
            onTap: () => Navigator.pushNamed(context, '/admin')),
      ];
}

// ─────────────────────────────────────────────
// EXPANDABLE SECTION
// ─────────────────────────────────────────────
class _ExpandableSection extends StatefulWidget {
  final String          title;
  final IconData        icon;
  final List<_MenuItem> items;
  const _ExpandableSection(
      {required this.title, required this.icon, required this.items});

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _exp;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _exp = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            margin:  const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: _open
                  ? _accent.withValues(alpha: 0.07)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _open
                      ? _accent.withValues(alpha: 0.2)
                      : Colors.transparent),
            ),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _open
                      ? _accent.withValues(alpha: 0.15)
                      : _navyLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _open
                          ? _accent.withValues(alpha: 0.3)
                          : _border),
                ),
                child: Icon(widget.icon,
                    size: 15,
                    color: _open ? _accentGlow : _textSec),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(widget.title,
                    style: TextStyle(
                        color:      _open ? _textPri : _textSec,
                        fontSize:   14,
                        fontWeight: _open
                            ? FontWeight.w600
                            : FontWeight.w500)),
              ),
              AnimatedBuilder(
                animation: _exp,
                builder: (_, __) => Transform.rotate(
                  angle: _exp.value * math.pi / 2,
                  child: Icon(Icons.chevron_right_rounded,
                      size:  16,
                      color: _open ? _accentGlow : _textSec),
                ),
              ),
            ]),
          ),
        ),
        SizeTransition(
          sizeFactor: _exp,
          child: Container(
            margin:  const EdgeInsets.only(left: 16, bottom: 4),
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                    color: _accent.withValues(alpha: 0.25), width: 1.5),
              ),
            ),
            child: Column(
                children:
                    widget.items.map((e) => _SubItem(item: e)).toList()),
          ),
        ),
      ]);
}

// ─────────────────────────────────────────────
// NESTED EXPANDABLE SECTION
// ─────────────────────────────────────────────
class _NestedExpandableSection extends StatefulWidget {
  final String            title;
  final IconData          icon;
  final List<_SubSection> subSections;
  const _NestedExpandableSection(
      {required this.title,
       required this.icon,
       required this.subSections});

  @override
  State<_NestedExpandableSection> createState() =>
      _NestedExpandableSectionState();
}

class _NestedExpandableSectionState
    extends State<_NestedExpandableSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _exp;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _exp = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final subs =
        widget.subSections.where((s) => s.items.isNotEmpty).toList();
    if (subs.isEmpty) return const SizedBox.shrink();

    return Column(children: [
      GestureDetector(
        onTap: _toggle,
        child: Container(
          margin:  const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: _open
                ? _accent.withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _open
                    ? _accent.withValues(alpha: 0.2)
                    : Colors.transparent),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _open
                    ? _accent.withValues(alpha: 0.15)
                    : _navyLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _open
                        ? _accent.withValues(alpha: 0.3)
                        : _border),
              ),
              child: Icon(widget.icon,
                  size: 15,
                  color: _open ? _accentGlow : _textSec),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(widget.title,
                  style: TextStyle(
                      color:      _open ? _textPri : _textSec,
                      fontSize:   14,
                      fontWeight: _open
                          ? FontWeight.w600
                          : FontWeight.w500)),
            ),
            AnimatedBuilder(
              animation: _exp,
              builder: (_, __) => Transform.rotate(
                angle: _exp.value * math.pi / 2,
                child: Icon(Icons.chevron_right_rounded,
                    size:  16,
                    color: _open ? _accentGlow : _textSec),
              ),
            ),
          ]),
        ),
      ),
      SizeTransition(
        sizeFactor: _exp,
        child: Container(
          margin:  const EdgeInsets.only(left: 16, bottom: 4),
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                  color: _accent.withValues(alpha: 0.25), width: 1.5),
            ),
          ),
          child: Column(
              children:
                  subs.map((s) => _InnerExpandable(sub: s)).toList()),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// INNER EXPANDABLE
// ─────────────────────────────────────────────
class _InnerExpandable extends StatefulWidget {
  final _SubSection sub;
  const _InnerExpandable({required this.sub});

  @override
  State<_InnerExpandable> createState() => _InnerExpandableState();
}

class _InnerExpandableState extends State<_InnerExpandable>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _exp;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _exp = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            margin:  const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: _open
                  ? _cyan.withValues(alpha: 0.06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(widget.sub.icon,
                  size: 13, color: _open ? _cyan : _textSec),
              const SizedBox(width: 9),
              Expanded(
                child: Text(widget.sub.label,
                    style: TextStyle(
                        color:      _open ? _textPri : _textSec,
                        fontSize:   13,
                        fontWeight: _open
                            ? FontWeight.w600
                            : FontWeight.w500)),
              ),
              AnimatedBuilder(
                animation: _exp,
                builder: (_, __) => Transform.rotate(
                  angle: _exp.value * math.pi / 2,
                  child: Icon(Icons.chevron_right_rounded,
                      size:  13,
                      color: _open ? _cyan : _textSec),
                ),
              ),
            ]),
          ),
        ),
        SizeTransition(
          sizeFactor: _exp,
          child: Container(
            margin:  const EdgeInsets.only(left: 12, bottom: 4),
            padding: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                    color: _cyan.withValues(alpha: 0.2), width: 1),
              ),
            ),
            child: Column(
                children: widget.sub.items
                    .map((e) => _SubItem(item: e))
                    .toList()),
          ),
        ),
      ]);
}

// ─────────────────────────────────────────────
// SUB ITEM
// ─────────────────────────────────────────────
class _SubItem extends StatefulWidget {
  final _MenuItem item;
  const _SubItem({required this.item});

  @override
  State<_SubItem> createState() => _SubItemState();
}

class _SubItemState extends State<_SubItem> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown:   (_) => setState(() => _hov = true),
        onTapUp:     (_) {
          setState(() => _hov = false);
          Navigator.pop(context);
          widget.item.onTap();
        },
        onTapCancel: ()  => setState(() => _hov = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin:  const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: _hov
                ? _accent.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            if (widget.item.icon != null)
              Icon(widget.item.icon!, size: 14, color: _cyan)
            else
              Container(
                  width: 5, height: 5,
                  decoration: const BoxDecoration(
                      color: _cyan, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.item.label,
                  style: const TextStyle(
                      color:      _textSec,
                      fontSize:   13,
                      fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────
// SIDEBAR TILE
// ─────────────────────────────────────────────
class _SidebarTile extends StatefulWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _SidebarTile(
      {required this.icon,
       required this.label,
       required this.color,
       required this.onTap});

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown:   (_) => setState(() => _pressed = true),
        onTapUp:     (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: ()  => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin:  const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: _pressed
                ? widget.color.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _pressed
                    ? widget.color.withValues(alpha: 0.2)
                    : Colors.transparent),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: widget.color.withValues(alpha: 0.2)),
              ),
              child: Icon(widget.icon, size: 15, color: widget.color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(widget.label,
                  style: TextStyle(
                      color:      _pressed ? widget.color : _textSec,
                      fontSize:   14,
                      fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size:  11,
                color: _pressed
                    ? widget.color.withValues(alpha: 0.5)
                    : Colors.white12),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────
class _MenuItem {
  final String       label;
  final VoidCallback onTap;
  final IconData?    icon;
  _MenuItem({required this.label, required this.onTap, this.icon});
}

class _SubSection {
  final String          label;
  final IconData        icon;
  final List<_MenuItem> items;
  _SubSection(
      {required this.label, required this.icon, required this.items});
}