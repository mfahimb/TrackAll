import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'widgets/top_menu_bar.dart';
import 'widgets/activity_log_widget.dart';
import 'npt_entry_page.dart';
import 'ctl_npt_entry_page.dart';
import 'qc_entry_page.dart';
import 'production_entry_page.dart';
import './Plan no wise production entry page.dart';
import 'packing_production_entry_page.dart';
import 'plan_wise_packing_entry_page.dart';
import 'kanban_board_page.dart';
import 'sos_page.dart';
// LineWiseStaffScanPage loaded via named route '/line-staff-scan' to avoid import conflicts

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? userId;
  String? companyLabel;
  List<int> assignedMenuIds = [];
  bool isDarkMode = false;

  static const int _qaPreviewCount = 6;
  bool _qaExpanded = false;

  final List<_QuickAction> allActions = [
    _QuickAction(
      label: "Production Entry",
      icon: Icons.precision_manufacturing_rounded,
      color: const Color(0xFF60A5FA),
      menuId: 11,
      onTap: () => ProductionEntryPage(),
    ),
    _QuickAction(
      label: "Plan Wise Production",
      icon: Icons.assignment_rounded,
      color: const Color(0xFF0EA5E9),
      menuId: 205,
      onTap: () => PlanNoWiseProductionEntryPage(),
    ),
    _QuickAction(
      label: "Packing Entry",
      icon: Icons.inventory_2_rounded,
      color: const Color(0xFF06B6D4),
      menuId: 37,
      onTap: () => PackingProductionEntryPage(),
    ),
    _QuickAction(
      label: "Plan Wise Packing",
      icon: Icons.inventory_rounded,
      color: const Color(0xFF0284C7),
      menuId: 206,
      onTap: () => PlanWisePackingEntryPage(),
    ),
    _QuickAction(
      label: "QC Entry",
      icon: Icons.verified_rounded,
      color: const Color(0xFF10B981),
      menuId: 133,
      onTap: () => QCEntryPage(),
    ),
    _QuickAction(
      label: "Downtime Entry",
      icon: Icons.timer_rounded,
      color: const Color(0xFFF59E0B),
      menuId: 40,
      onTap: () => NptEntryPage(),
    ),
    _QuickAction(
      label: "CTL Downtime",
      icon: Icons.hourglass_bottom_rounded,
      color: const Color(0xFFEC4899),
      menuId: 165,
      onTap: () => CtlNptEntryPage(),
    ),
    _QuickAction(
      label: "Kanban Board",
      icon: Icons.dashboard_rounded,
      color: const Color(0xFF8B5CF6),
      menuId: 232,
      onTap: () => KanbanBoardPage(),
    ),
    _QuickAction(
      label: "Kanban",
      icon: Icons.analytics_rounded,
      color: const Color(0xFF06B6D4),
      menuId: 231,
      onTap: () => SOSPage(),
    ),
    // ── Line Wise Staff Scan — Incentive ──────────────────────────
    // Navigation handled via pushNamed to avoid import conflict
    _QuickAction(
      label: "Line Wise Staff Scan",
      icon: Icons.qr_code_scanner_rounded,
      color: const Color(0xFF22C55E),
      menuId: 109,
      onTap: null, // handled in _onActionTap
    ),
    _QuickAction(
      label: "Settings",
      icon: Icons.settings_rounded,
      color: const Color(0xFF64748B),
      menuId: null,
      onTap: null,
    ),
    _QuickAction(
      label: "Help",
      icon: Icons.help_rounded,
      color: const Color(0xFF38BDF8),
      menuId: null,
      onTap: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _saveLastPage();
    _checkSession();
    _initializeAnimations();
    _loadUserData();
    _loadDarkMode();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId');
    companyLabel = prefs.getString('selected_company_label');
    if (userId != null) {
      assignedMenuIds = await _fetchUserMenuIds(userId!);
    }
    setState(() {});
  }

  Future<List<int>> _fetchUserMenuIds(String appUser) async {
    try {
      final uri = Uri.parse(
              "https://trackall.rflgroupbd.com/ords/rpro/xxtrac_al/get_lov")
          .replace(queryParameters: {
        'P_QRYTYP': 'MENU',
        'P_APP_USER': appUser,
      });
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return [];
      final decoded = jsonDecode(resp.body);
      final List list = decoded['MENU'] ?? [];
      return list.map<int>((e) => e['IDM_ID'] as int).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _saveDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
  }

  List<_QuickAction> getAccessibleActions() {
    debugPrint("🔑 assignedMenuIds: $assignedMenuIds");
    return allActions.where((action) {
      if (action.menuId == null) return true;
      if (action.menuId == 109) {
        return assignedMenuIds.any((id) => [106, 109, 262].contains(id));
      }
      return assignedMenuIds.contains(action.menuId);
    }).toList();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
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
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final accessibleActions = getAccessibleActions();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDarkMode
                      ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                      : [const Color(0xFFF8FAFC), const Color(0xFFEFF4FF)],
                ),
              ),
            ),
          ),
          Column(
            children: [
              const TopMenuBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildWelcomeCard(isMobile),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: ActivityLogSection(
                            assignedMenuIds: assignedMenuIds,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child:
                              _buildQuickActions(isMobile, accessibleActions),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

   // ── Welcome card ─────────────────────────────────────────────────
  String get _todayLabel {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final d = DateTime.now();
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  Widget _welcomeChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: const Color(0xFF60A5FA)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildWelcomeCard(bool isMobile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF060D1F), Color(0xFF12305E)],
          ),
          border: Border.all(
              color: const Color(0xFF60A5FA).withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -40,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF60A5FA).withValues(alpha: 0.35),
                    const Color(0xFF60A5FA).withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
            Positioned(
              right: 50,
              bottom: -50,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF06B6D4).withValues(alpha: 0.25),
                    const Color(0xFF06B6D4).withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "WELCOME BACK",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            "TrackAll Dashboard",
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Manage your production workflow efficiently",
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6)
                                .withValues(alpha: 0.45),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.dashboard_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (userId != null)
                      _welcomeChip(Icons.person_rounded, userId!),
                    if (companyLabel != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.5),
                        child: _welcomeChip(
                            Icons.business_rounded, companyLabel!),
                      ),
                    _welcomeChip(Icons.calendar_today_rounded, _todayLabel),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick actions ────────────────────────────────────────────────
  Widget _buildQuickActions(bool isMobile, List<_QuickAction> actions) {
    final previewActions = actions.length <= _qaPreviewCount
        ? actions
        : actions.sublist(0, _qaPreviewCount);
    final overflowActions = actions.length <= _qaPreviewCount
        ? <_QuickAction>[]
        : actions.sublist(_qaPreviewCount);
    final hasMore = overflowActions.isNotEmpty;

    Widget grid(List<_QuickAction> items) => GridView.count(
          crossAxisCount: isMobile ? 2 : 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          childAspectRatio: isMobile ? 3.3 : 3.6,
          children: items.map(_actionTile).toList(),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.grid_view_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              "Quick Actions",
              style: TextStyle(
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.w800,
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        grid(previewActions),
        if (hasMore) ...[
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState: _qaExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: grid(overflowActions),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _qaExpanded = !_qaExpanded),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _qaExpanded
                          ? "See Less"
                          : "See More (${overflowActions.length})",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _qaExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 280),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 15,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _onActionTap(_QuickAction action) {
    if (action.label == "Settings") {
      _showSettingsBottomSheet(MediaQuery.of(context).size.width < 600);
    } else if (action.label == "Help") {
      _showHelpBottomSheet(MediaQuery.of(context).size.width < 600);
    } else if (action.label == "Line Wise Staff Scan") {
      Navigator.pushNamed(context, '/line-staff-scan');
    } else if (action.onTap != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => action.onTap!()),
      );
    }
  }

  Widget _actionTile(_QuickAction action) {
    return Material(
      color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _onActionTap(action),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: action.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color:
                        isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsBottomSheet(bool isMobile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Settings",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color:
                        isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isDarkMode ? Icons.dark_mode : Icons.light_mode,
                          color: isDarkMode ? Colors.yellow : Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Dark Mode",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: isDarkMode,
                      onChanged: (value) {
                        setState(() => isDarkMode = value);
                        _saveDarkMode(value);
                        Navigator.pop(context);
                      },
                      activeThumbColor: const Color(0xFF60A5FA),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHelpBottomSheet(bool isMobile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Help & Support",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color:
                        isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Contact CS-MIS-SW Team",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white70
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF60A5FA).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF60A5FA).withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.email_rounded,
                              color: Color(0xFF60A5FA), size: 20),
                          const SizedBox(width: 12),
                          Text(
                            "mis29@mis.prangroup.com",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.email_rounded,
                              color: Color(0xFF60A5FA), size: 20),
                          const SizedBox(width: 12),
                          Text(
                            "mis55@mis.prangroup.com",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final int? menuId;
  final Widget Function()? onTap;

  _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.menuId,
    required this.onTap,
  });
}