import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../npt_entry_page.dart';

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

  final GlobalKey _workStudyKey = GlobalKey();
  final GlobalKey _dashboardKey = GlobalKey();
  final GlobalKey _adminKey = GlobalKey();
  final GlobalKey _menuIconKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide =
        Tween(begin: const Offset(0, -0.04), end: Offset.zero)
            .animate(_controller);

    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => userId = prefs.getString('userId'));
  }

  // ================= DROPDOWN =================
  void _showDropdown(
      BuildContext context, GlobalKey key, List<DropdownItem> items) {
    _removeDropdown();

    final box = key.currentContext!.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    final isMobile = MediaQuery.of(context).size.width < 720;
    const double menuWidth = 190;

    double left = isMobile
        ? (pos.dx + size.width - menuWidth).clamp(8, double.infinity)
        : pos.dx;

    _overlay = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeDropdown,
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: pos.dy + size.height + 8,
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
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF0F172A).withOpacity(0.85),
                                const Color(0xFF020617).withOpacity(0.92),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55000000),
                                blurRadius: 24,
                                offset: Offset(0, 14),
                              )
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: items.map(_menuItem).toList(),
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

  Widget _menuItem(DropdownItem item) {
    return InkWell(
      onTap: () {
        _removeDropdown();
        item.onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x22FFFFFF)),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.arrow_right_rounded,
                size: 20, color: Color(0xFF93C5FD)),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeDropdown() {
    _controller.reverse();
    _overlay?.remove();
    _overlay = null;
  }

  // ================= MOBILE =================
  void _openMobileDropdown(BuildContext context) {
    List<DropdownItem> items = [
      DropdownItem(
        label: "Downtime Entry",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NptEntryPage()),
          );
        },
      ),
    ];

    if (userId == "540150") {
      items.addAll([
        DropdownItem(
          label: "NPT Report",
          onTap: () => Navigator.pushNamed(context, '/npt_entry'),
        ),
        DropdownItem(
          label: "Admin Panel",
          onTap: () => Navigator.pushNamed(context, '/admin'),
        ),
      ]);
    }

    items.add(DropdownItem(label: "Logout", onTap: _logout));

    _showDropdown(context, _menuIconKey, items);
  }

  // ================= LOGOUT =================
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('loginTime');
    Navigator.pushReplacementNamed(context, '/login');
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 720;

    return SafeArea(
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF020617), Color(0xFF0F172A)],
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x44000000), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                colors: [Color(0xFF60A5FA), Color(0xFF38BDF8)],
              ).createShader(rect),
              child: const Text(
                "TrackAll",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: Colors.white,
                ),
              ),
            ),

            const Spacer(),

            if (isMobile)
              IconButton(
                key: _menuIconKey,
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: () => _openMobileDropdown(context),
              ),

            if (!isMobile && userId != null) ...[
              _menuButton("Work Study", _workStudyKey, [
                DropdownItem(
                  label: "Downtime Entry",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NptEntryPage()),
                    );
                  },
                ),
              ]),
              if (userId == "540150")
                _menuButton("Dashboard", _dashboardKey, [
                  DropdownItem(
                    label: "NPT Report",
                    onTap: () =>
                        Navigator.pushNamed(context, '/npt_entry'),
                  ),
                ]),
              if (userId == "540150")
                _menuButton("Admin", _adminKey, [
                  DropdownItem(
                    label: "Admin Panel",
                    onTap: () => Navigator.pushNamed(context, '/admin'),
                  ),
                ]),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text("Logout"),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _menuButton(String text, GlobalKey key, List<DropdownItem> items) {
    return GestureDetector(
      key: key,
      onTap: () {
        _overlay == null
            ? _showDropdown(context, key, items)
            : _removeDropdown();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15.5,
            color: Colors.white,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

// MODEL
class DropdownItem {
  final String label;
  final VoidCallback onTap;

  DropdownItem({required this.label, required this.onTap});
}
