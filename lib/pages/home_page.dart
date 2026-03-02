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
import 'kanban_board_page.dart';
import 'sos_page.dart';

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

  final List<_QuickAction> allActions = [
    _QuickAction(
      label: "Production Entry",
      icon: Icons.precision_manufacturing_rounded,
      color: const Color(0xFF60A5FA),
      menuId: 11,
      onTap: () => ProductionEntryPage(),
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
              "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov")
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
    return allActions.where((action) {
      if (action.menuId == null) return true;
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
          // ── Background gradient ──────────────────────────────────
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
          // ── Decorative circles ───────────────────────────────────
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF60A5FA).withOpacity(0.2),
                    const Color(0xFF60A5FA).withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF38BDF8).withOpacity(0.15),
                    const Color(0xFF38BDF8).withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          // ── Main content ─────────────────────────────────────────
          Column(
            children: [
              const TopMenuBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome card
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildWelcomeCard(isMobile),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Activity Log
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: ActivityLogSection(
                            assignedMenuIds: assignedMenuIds,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Quick Actions
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildQuickActions(isMobile, accessibleActions),
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

  Widget _buildWelcomeCard(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ]
              : [
                  const Color(0xFF60A5FA).withOpacity(0.1),
                  const Color(0xFF38BDF8).withOpacity(0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? const Color(0xFF60A5FA).withOpacity(0.2)
              : const Color(0xFF60A5FA).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF60A5FA), Color(0xFF38BDF8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF60A5FA).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome Back!",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.7)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      "TrackAll Dashboard",
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 20,
                        fontWeight: FontWeight.w900,
                        color: isDarkMode
                            ? Colors.white
                            : const Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Manage your production workflow efficiently",
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isMobile, List<_QuickAction> actions) {
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
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: isMobile ? 2 : 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          childAspectRatio: isMobile ? 2.8 : 2.8,
          children: actions.map((action) {
            if (action.label == "Settings") {
              return _buildSettingsCard(isMobile, action);
            } else if (action.label == "Help") {
              return _buildHelpCard(isMobile, action);
            } else {
              return _buildActionCard(isMobile, action);
            }
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionCard(bool isMobile, _QuickAction action) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            action.color.withOpacity(0.15),
            action.color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: action.color.withOpacity(0.25), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => action.onTap!()),
          ),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [action.color, action.color.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: action.color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(action.icon, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.white
                          : const Color(0xFF0F172A),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(bool isMobile, _QuickAction action) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            action.color.withOpacity(0.15),
            action.color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: action.color.withOpacity(0.25), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSettingsBottomSheet(isMobile),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [action.color, action.color.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: action.color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(action.icon, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.white
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelpCard(bool isMobile, _QuickAction action) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            action.color.withOpacity(0.15),
            action.color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: action.color.withOpacity(0.25), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showHelpBottomSheet(isMobile),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [action.color, action.color.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: action.color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(action.icon, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.white
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
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
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
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
                      activeColor: const Color(0xFF60A5FA),
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
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
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
                    color: const Color(0xFF60A5FA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF60A5FA).withOpacity(0.2),
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