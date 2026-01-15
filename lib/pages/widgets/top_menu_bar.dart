import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../npt_entry_page.dart';
import '../company_select_page.dart';
import '../sos_page.dart';

class TopMenuBar extends StatefulWidget {
  const TopMenuBar({super.key});

  @override
  State<TopMenuBar> createState() => _TopMenuBarState();
}

class _TopMenuBarState extends State<TopMenuBar>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  String? userId;
  String? companyLabel;

  List<int> assignedMenuIds = []; // fetched from API

  /// ✅ SAFE ADMIN CHECK
  bool get isAdmin => userId?.trim() == "540150";

  final GlobalKey _menuIconKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide =
        Tween(begin: const Offset(0, -0.04), end: Offset.zero).animate(_controller);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId');
    companyLabel = prefs.getString('selected_company_label');

    if (userId != null) {
      assignedMenuIds = await _fetchUserMenuIds(userId!);
    }

    setState(() {}); // refresh UI after menu load
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
      // Assuming response is a List of menu objects
      final List list = decoded['MENU'] ?? [];
      return list.map<int>((e) => e['IDM_ID'] as int).toList();
    } catch (e) {
      return [];
    }
  }

  // ================= DROPDOWN =================
  void _showDropdown(BuildContext context) {
    _removeDropdown();
    final box = _menuIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    const double menuWidth = 200;

    _overlay = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeDropdown,
        child: Stack(
          children: [
            Positioned(
              top: pos.dy + size.height + 8,
              right: 16,
              width: menuWidth,
              child: Material(
                color: Colors.transparent,
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF0F172A).withOpacity(0.95),
                                const Color(0xFF020617).withOpacity(0.98),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x55000000),
                                  blurRadius: 24,
                                  offset: Offset(0, 14))
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: _buildMobileMenuItems(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlay!);
    _controller.forward(from: 0);
  }

  // ================= MOBILE MENU ITEMS =================
  List<Widget> _buildMobileMenuItems() {
    final List<Widget> items = [];

    final workStudy = _workStudyItems();
    if (workStudy.isNotEmpty) items.add(_submenuItem("Work Study", workStudy));

    final common = _commonItems();
    if (common.isNotEmpty) items.add(_submenuItem("Common", common));

    if (isAdmin) {
      items.add(_submenuItem("Admin", _adminItems()));
    }

    items.add(_menuSingleItem(
      "Change Company",
      () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const CompanySelectPage())),
    ));

    items.add(_menuSingleItem("Logout", _logout));

    return items;
  }

  Widget _menuSingleItem(String label, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        _removeDropdown();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 8, color: Color(0xFF60A5FA)),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _submenuItem(String label, List<DropdownItem> submenuItems) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      collapsedIconColor: Colors.white,
      iconColor: Colors.white,
      childrenPadding: const EdgeInsets.only(left: 24),
      title: Row(
        children: [
          const Icon(Icons.folder, size: 18, color: Color(0xFF93C5FD)),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
      children: submenuItems
          .map((e) => InkWell(
                onTap: () {
                  _removeDropdown();
                  e.onTap();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_right_rounded,
                          size: 16, color: Color(0xFF60A5FA)),
                      const SizedBox(width: 10),
                      Text(e.label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  // ================= WORK STUDY ITEMS =================
  List<DropdownItem> _workStudyItems() {
    final items = <DropdownItem>[];
    if (assignedMenuIds.contains(40)) {
      items.add(
        DropdownItem(
          label: "Downtime Entry",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NptEntryPage()),
          ),
        ),
      );
    }
    return items;
  }

  // ================= COMMON ITEMS =================
  List<DropdownItem> _commonItems() {
    final items = <DropdownItem>[];
    if (assignedMenuIds.contains(231)) {
      items.add(
        DropdownItem(
          label: "Kanban",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SOSPage()),
          ),
        ),
      );
    }
    return items;
  }

  // ================= ADMIN ITEMS =================
  List<DropdownItem> _adminItems() => [
        DropdownItem(
          label: "Admin Panel",
          onTap: () => Navigator.pushNamed(context, '/admin'),
        ),
      ];

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _removeDropdown() {
    _controller.reverse();
    _overlay?.remove();
    _overlay = null;
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 720;

    return SafeArea(
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF020617), Color(0xFF0F172A)]),
          boxShadow: [BoxShadow(color: Color(0x44000000), blurRadius: 10)],
        ),
        child: Stack(
          children: [
            // LEFT LOGO
            // LEFT LOGO
Align(
  alignment: Alignment.centerLeft,
  child: GestureDetector(
    onTap: () {
      // Navigate to home page
      Navigator.pushReplacementNamed(context, '/home'); 
      // or Navigator.push(context, MaterialPageRoute(builder: (_) => HomePage()));
    },
    child: ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
              colors: [Color(0xFF60A5FA), Color(0xFF38BDF8)])
          .createShader(rect),
      child: const Text("TrackAll",
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: Colors.white)),
    ),
  ),
),


            // CENTER COMPANY MODERN
            if (companyLabel != null)
              Align(
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.05),
                            Colors.white.withOpacity(0.10),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        companyLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // RIGHT MENU
            Align(
              alignment: Alignment.centerRight,
              child: isMobile
                  ? IconButton(
                      key: _menuIconKey,
                      icon: const Icon(Icons.menu_rounded, color: Colors.white),
                      onPressed: () => _showDropdown(context),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _desktopMenuButton("Work Study", _workStudyItems()),
                        _desktopMenuButton("Common", _commonItems()),
                        if (isAdmin) _desktopMenuButton("Admin", _adminItems()),
                        _desktopMenuButton(
                            "Change Company",
                            [
                              DropdownItem(
                                  label: "Change Company",
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const CompanySelectPage()))),
                            ]),
                        _desktopMenuButton("Logout",
                            [DropdownItem(label: "Logout", onTap: _logout)]),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopMenuButton(String text, List<DropdownItem> items) {
    return GestureDetector(
      onTap: () {
        _removeDropdown();
        if (items.length == 1) {
          items.first.onTap();
        } else {
          _showDropdown(context);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(text,
            style: const TextStyle(
                fontSize: 15.5, color: Colors.white, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class DropdownItem {
  final String label;
  final VoidCallback onTap;
  DropdownItem({required this.label, required this.onTap});
}
