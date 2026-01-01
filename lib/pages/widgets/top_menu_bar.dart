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

  String? userId; // store logged-in staff ID

  // Keys for desktop buttons
  final GlobalKey _workStudyKey = GlobalKey();
  final GlobalKey _dashboardKey = GlobalKey();
  final GlobalKey _adminKey = GlobalKey();

  // Key for mobile hamburger
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
        Tween(begin: const Offset(0, -0.05), end: Offset.zero)
            .animate(_controller);

    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId');
    });
  }

  // ================= DROPDOWN (DESKTOP & MOBILE) =================
  void _showDropdown(
      BuildContext context, GlobalKey key, List<DropdownItem> items) {
    _removeDropdown();

    final box = key.currentContext!.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 720;

    const double desktopWidth = 180;
    final double menuWidth = isMobile ? 180 : desktopWidth;

    double left;

    if (isMobile) {
      left = pos.dx + size.width - menuWidth;
      if (left < 8) left = 8;
    } else {
      left = pos.dx;
    }

    _overlay = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeDropdown,
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: pos.dy + size.height + 6,
              width: menuWidth,
              child: Material(
                color: Colors.transparent,
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade900.withOpacity(.96),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 14,
                            offset: Offset(0, 6),
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
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlay!);
    _controller.forward(from: 0);
  }

  Widget _menuItem(DropdownItem item) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        _removeDropdown();
        item.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.chevron_right, size: 18, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              item.label,
              style: const TextStyle(color: Colors.white, fontSize: 15),
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

  // ================= MOBILE DROPDOWN =================
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

    // Only staff ID 540150 can see admin/report
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

    items.add(
      DropdownItem(
        label: "Logout",
        onTap: _logout,
      ),
    );

    _showDropdown(context, _menuIconKey, items);
  }

  // ✅ LOGOUT
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
          color: Colors.blueGrey.shade900,
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                colors: [Colors.white, Colors.blueAccent],
              ).createShader(rect),
              child: const Text(
                "TrackAll",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
            ),

            const Spacer(),

            if (isMobile)
              IconButton(
                key: _menuIconKey,
                icon: const Icon(Icons.menu, color: Colors.white),
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
                  backgroundColor: Colors.redAccent.shade200,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
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
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
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
