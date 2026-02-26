import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../npt_entry_page.dart';
import '../ctl_npt_entry_page.dart';
import '../company_select_page.dart';
import '../sos_page.dart';
import '../qc_entry_page.dart';
import '../production_entry_page.dart';
import '../kanban_board_page.dart';

class TopMenuBar extends StatefulWidget {
  const TopMenuBar({super.key});

  @override
  State<TopMenuBar> createState() => _TopMenuBarState();
}

class _TopMenuBarState extends State<TopMenuBar> {
  String? userId;
  String? companyLabel;
  List<int> assignedMenuIds = [];

  /// ✅ SAFE ADMIN CHECK
  bool get isAdmin => userId?.trim() == "540150";

  @override
  void initState() {
    super.initState();
    _loadUserData();
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

  // ================= FETCH USER MENU =================
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

  // ================= SHOW MODERN SIDEBAR =================
  void _openSidebar() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Sidebar",
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: _ModernSidebar(
              animation: anim1,
              userId: userId,
              companyLabel: companyLabel,
              isAdmin: isAdmin,
              assignedMenuIds: assignedMenuIds,
              onLogout: _logout,
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: anim1,
            curve: Curves.easeInOutCubic,
          )),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: anim1,
                curve: Curves.easeOut,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, '/login');
  }

  // ================= BUILD TOP BAR =================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    // Bar height - compact
    final barHeight = isMobile ? 48.0 : 54.0;

    return SafeArea(
      child: Container(
        height: barHeight,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12,
          vertical: isMobile ? 4 : 6,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F172A).withOpacity(0.95),
              const Color(0xFF1E293B).withOpacity(0.85),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF60A5FA).withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFF60A5FA).withOpacity(0.2),
              width: 0.8,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LEFT: MENU BUTTON
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF60A5FA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF60A5FA).withOpacity(0.2),
                      width: 0.8,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.menu_rounded,
                      color: const Color(0xFF60A5FA),
                      size: isMobile ? 18 : 20,
                    ),
                    onPressed: _openSidebar,
                    splashRadius: 14,
                    padding: EdgeInsets.all(isMobile ? 4 : 5),
                    constraints: BoxConstraints(
                      minWidth: isMobile ? 30 : 34,
                      minHeight: isMobile ? 30 : 34,
                    ),
                  ),
                ),

                // CENTER: LOGO
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacementNamed(context, '/home');
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 14 : 18,
                          vertical: isMobile ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF60A5FA).withOpacity(0.08),
                              const Color(0xFF38BDF8).withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF60A5FA).withOpacity(0.25),
                            width: 0.8,
                          ),
                        ),
                        child: ShaderMask(
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF60A5FA),
                              Color(0xFF38BDF8),
                            ],
                          ).createShader(rect),
                          child: Text(
                            "TrackAll",
                            style: TextStyle(
                          fontSize: isMobile ? 16 : isTablet ? 18 : 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                if (companyLabel != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile
                          ? screenWidth * 0.36
                          : isTablet
                              ? screenWidth * 0.28
                              : 220,
                    ),
                    child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 12,
                      vertical: isMobile ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withOpacity(0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isMobile ? 3 : 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF60A5FA),
                                Color(0xFF38BDF8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF60A5FA).withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.apartment_rounded,
                            size: isMobile ? 10 : 12,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: isMobile ? 6 : 8),
                        Flexible(
                          child: Text(
                            companyLabel!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 9 : isTablet ? 10 : 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                              height: 1.3,
                            ),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                            maxLines: 3,
                          ),
                        ),
                      ],
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
}

// ================= MODERN SIDEBAR COMPONENT =================
class _ModernSidebar extends StatefulWidget {
  final Animation<double> animation;
  final String? userId;
  final String? companyLabel;
  final bool isAdmin;
  final List<int> assignedMenuIds;
  final VoidCallback onLogout;

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

class _ModernSidebarState extends State<_ModernSidebar> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth * 0.75 > 320 ? 320.0 : screenWidth * 0.75;

    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        width: sidebarWidth,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              children: [
                // HEADER
                _buildHeader(),

                const Divider(color: Colors.white12, height: 1),

                // MENU ITEMS
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      _buildMenuSection("Production", _getProductionItems()),
                      _buildMenuSection("Work Study", _getWorkStudyItems()),
                      _buildMenuSection("Common", _getCommonItems()),
                      if (widget.isAdmin) _buildMenuSection("Admin", _getAdminItems()),

                      const SizedBox(height: 24),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 8),

                      _buildSingleItem(
                        Icons.swap_horiz_rounded,
                        "Change Company",
                        () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CompanySelectPage(),
                            ),
                          );
                        },
                      ),

                      _buildSingleItem(
                        Icons.logout_rounded,
                        "Logout",
                        () {
                          Navigator.pop(context);
                          widget.onLogout();
                        },
                        isDestructive: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _buildHeader() {
     final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF60A5FA).withOpacity(0.15),
            const Color(0xFF38BDF8).withOpacity(0.1),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF60A5FA), Color(0xFF38BDF8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF60A5FA).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: isMobile ? 22 : 28,
                ),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome",
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.userId ?? "User",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 15 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.companyLabel != null) ...[
            SizedBox(height: isMobile ? 10 : 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.apartment_rounded,
                    size: 16,
                    color: Color(0xFF60A5FA),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.companyLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ================= MENU SECTION =================
  Widget _buildMenuSection(String title, List<_MenuItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    final GlobalKey sectionKey = GlobalKey();

    return InkWell(
      key: sectionKey,
      onTap: () {
        if (sectionKey.currentContext != null) {
          final RenderBox box =
              sectionKey.currentContext!.findRenderObject() as RenderBox;
          final Offset globalPosition = box.localToGlobal(Offset.zero);
          final double iconCenterY = globalPosition.dy + (box.size.height / 2);
          _openNestedSidebar(title, items, iconCenterY);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF60A5FA).withOpacity(0.2),
                    const Color(0xFF38BDF8).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getSectionIcon(title),
                size: 20,
                color: const Color(0xFF60A5FA),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.white60,
            ),
          ],
        ),
      ),
    );
  }

  // ================= OPEN NESTED SIDEBAR =================
  void _openNestedSidebar(String title, List<_MenuItem> items, double iconCenterY) {
    final screen = MediaQuery.of(context).size;

    const double submenuWidth = 240.0;
    const double submenuHeight = 260.0;

    final sidebarWidth = screen.width * 0.75 > 320 ? 320.0 : screen.width * 0.75;

    double top = iconCenterY - (submenuHeight / 2);
    top = top.clamp(20.0, screen.height - submenuHeight - 20);

    double left = sidebarWidth - (submenuWidth * 0.8);
    left = left.clamp(0.0, screen.width - submenuWidth);

    top = top + 60.0;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Submenu",
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: _NestedSidebar(
                  animation: anim1,
                  title: title,
                  items: items,
                  icon: _getSectionIcon(title),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(anim1),
            child: child,
          ),
        );
      },
    );
  }

  // ================= SINGLE MENU ITEM =================
  Widget _buildSingleItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withOpacity(0.1)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isDestructive ? Colors.redAccent : const Color(0xFF60A5FA),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isDestructive ? Colors.redAccent : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDestructive ? Colors.red.withOpacity(0.3) : Colors.white30,
            ),
          ],
        ),
      ),
    );
  }

  // ================= SECTION ICONS =================
  IconData _getSectionIcon(String section) {
    switch (section) {
      case "Production":
        return Icons.precision_manufacturing_rounded;
      case "Work Study":
        return Icons.analytics_rounded;
      case "Common":
        return Icons.dashboard_rounded;
      case "Admin":
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  // ================= GET MENU ITEMS =================
  List<_MenuItem> _getProductionItems() {
    final items = <_MenuItem>[];

    if (widget.assignedMenuIds.contains(133)) {
      items.add(_MenuItem(
        label: "QC Entry",
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QCEntryPage()),
        ),
      ));
    }

    if (widget.assignedMenuIds.contains(11)) {
      items.add(_MenuItem(
        label: "Production Entry",
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductionEntryPage()),
        ),
      ));
    }

    return items;
  }

  List<_MenuItem> _getWorkStudyItems() {
    final items = <_MenuItem>[];

    if (widget.assignedMenuIds.contains(40)) {
      items.add(_MenuItem(
        label: "Downtime Entry",
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NptEntryPage()),
        ),
      ));
    }

    if (widget.assignedMenuIds.contains(165)) {
      items.add(_MenuItem(
        label: "CTL Downtime Entry",
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CtlNptEntryPage()),
        ),
      ));
    }

    return items;
  }

  List<_MenuItem> _getCommonItems() {
    final items = <_MenuItem>[];

    if (widget.assignedMenuIds.contains(231)) {
      items.add(_MenuItem(
        label: "Kanban",
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SOSPage()),
        ),
      ));
    }

    if (widget.assignedMenuIds.contains(232)) {
      items.add(_MenuItem(
        label: "Kanban Board",
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const KanbanBoardPage()),
        ),
      ));
    }

    return items;
  }

  List<_MenuItem> _getAdminItems() {
    return [
      _MenuItem(
        label: "Admin Panel",
        onTap: () => Navigator.pushNamed(context, '/admin'),
      ),
    ];
  }
}

// ================= NESTED SIDEBAR =================
class _NestedSidebar extends StatelessWidget {
  final Animation<double> animation;
  final String title;
  final List<_MenuItem> items;
  final IconData icon;

  const _NestedSidebar({
    required this.animation,
    required this.title,
    required this.items,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    final width = screen.width < 400 ? screen.width * 0.55 : 240.0;

    return Container(
      width: width.clamp(180, 260),
      constraints: BoxConstraints(
        maxHeight: screen.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          topLeft: Radius.circular(4),
        ),
        border: Border.all(
          color: const Color(0xFF60A5FA).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(10, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF60A5FA).withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFF60A5FA), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, i) => _buildSubItem(context, items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubItem(BuildContext context, _MenuItem item) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.pop(context);
        item.onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.02),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF38BDF8),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white10, size: 16),
          ],
        ),
      ),
    );
  }
}

// ================= MENU ITEM MODEL =================
class _MenuItem {
  final String label;
  final VoidCallback onTap;

  _MenuItem({required this.label, required this.onTap});
}