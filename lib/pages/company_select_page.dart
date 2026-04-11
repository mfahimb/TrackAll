import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Design tokens (matches login_page.dart) ───────────────────────────
const _accent  = Color(0xFF3B82F6);
const _cyan    = Color(0xFF06B6D4);
const _navy    = Color(0xFF0F172A);
const _bgTop   = Color(0xFFEFF6FF);
const _bgBottom= Color(0xFFF8FAFC);
const _borderL = Color(0xFFBFDBFE);
const _textPri = Color(0xFF0F172A);
const _textSec = Color(0xFF64748B);
const _inputBg = Color(0xFFF1F5F9);

class CompanySelectPage extends StatefulWidget {
  const CompanySelectPage({super.key});

  @override
  State<CompanySelectPage> createState() => _CompanySelectPageState();
}

class _CompanySelectPageState extends State<CompanySelectPage>
    with SingleTickerProviderStateMixin {
  String? selectedCompanyId;
  String? selectedCompanyLabel;
  List<Map<String, String>> companyList = [];
  bool _isLoading = true;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fetchCompanies();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanies() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? "0";

      final uri = Uri.parse(
              "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov")
          .replace(queryParameters: {
        "P_QRYTYP": "ASSIGN",
        "P_APP_USER": userId,
      });

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data["ASSIGN"] as List<dynamic>?;
        if (items != null) {
          companyList = items
              .map<Map<String, String>>((item) => {
                    "id": item["R"].toString(),
                    "label": item["D"].toString(),
                  })
              .toList();
          final seen = <String>{};
          companyList =
              companyList.where((c) => seen.add(c["id"]!)).toList();
        }
      } else {
        _showSnack("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      _showSnack("Network Error: $e");
    } finally {
      setState(() => _isLoading = false);
      _animCtrl.forward();
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _navy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _confirmSelection() async {
    if (selectedCompanyId == null) {
      _showSnack("Please select a company");
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("selected_company_id", selectedCompanyId!);
    await prefs.setString("selected_company_label", selectedCompanyLabel!);
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _showCompanyDialog() {
    List<Map<String, String>> filtered = List.from(companyList);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(builder: (c, setS) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),

              // Sheet title
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_accent.withOpacity(0.13), _cyan.withOpacity(0.09)]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _accent.withOpacity(0.18)),
                  ),
                  child: const Icon(Icons.business_rounded,
                      color: _accent, size: 16),
                ),
                const SizedBox(width: 10),
                const Text("Select Company",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _textPri)),
              ]),
              const SizedBox(height: 16),

              // Search
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: _inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderL.withOpacity(0.65)),
                ),
                child: TextField(
                  autofocus: false,
                  style: const TextStyle(
                      color: _textPri,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded,
                        color: _textSec, size: 18),
                    hintText: "Search company...",
                    hintStyle: TextStyle(
                        color: _textSec.withOpacity(0.6), fontSize: 13),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setS(() {
                    filtered = companyList
                        .where((e) => e["label"]!
                            .toLowerCase()
                            .contains(v.toLowerCase()))
                        .toList();
                  }),
                ),
              ),
              const SizedBox(height: 12),

              // Company list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 40, color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            Text("No companies found",
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final item = filtered[i];
                          final isSelected =
                              item["id"] == selectedCompanyId;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedCompanyId = item["id"];
                                selectedCompanyLabel = item["label"];
                              });
                              Navigator.pop(context);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 13, horizontal: 14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _accent.withOpacity(0.07)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? _accent.withOpacity(0.4)
                                      : _borderL.withOpacity(0.5),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: _accent.withOpacity(0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : [
                                        const BoxShadow(
                                          color: Color(0x06000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        )
                                      ],
                              ),
                              child: Row(children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isSelected
                                          ? [_accent, _cyan]
                                          : [
                                              _borderL.withOpacity(0.5),
                                              _borderL.withOpacity(0.3),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.business_rounded,
                                    color: isSelected
                                        ? Colors.white
                                        : _textSec,
                                    size: 15,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item["label"]!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? _accent
                                          : _textPri,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                          colors: [_accent, _cyan]),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 13),
                                  ),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      }),
    );
  }

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

          // ── Grid overlay ─────────────────────────────────────────
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // ── Top-right bubble ─────────────────────────────────────
          Positioned(
            top: -110,
            right: -110,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _accent.withOpacity(0.50),
                  _accent.withOpacity(0),
                ]),
              ),
            ),
          ),

          // ── Bottom-left bubble ───────────────────────────────────
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _cyan.withOpacity(0.45),
                  _cyan.withOpacity(0),
                ]),
              ),
            ),
          ),

          // ── Main content ─────────────────────────────────────────
          SafeArea(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(_accent),
                    ),
                  )
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // ── Icon + heading ───────────────────
                              Container(
                                width: 64,
                                height: 64,
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
                                  Icons.business_center_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                "Select Company",
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: _textPri,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Choose the company you want to work with",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: _textSec.withOpacity(0.8),
                                ),
                              ),

                              const SizedBox(height: 36),

                              // ── Frosted card ─────────────────────
                              ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: 16, sigmaY: 16),
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
                                          color: _accent.withOpacity(0.10),
                                          blurRadius: 48,
                                          offset: const Offset(0, 20),
                                        ),
                                        BoxShadow(
                                          color: _cyan.withOpacity(0.06),
                                          blurRadius: 24,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        // Top accent bar
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
                                              // Label
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 2, bottom: 6),
                                                child: Text(
                                                  "COMPANY",
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: selectedCompanyId != null
                                                        ? _accent
                                                        : _textSec,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ),

                                              // Dropdown trigger
                                              GestureDetector(
                                                onTap: _showCompanyDialog,
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                      milliseconds: 200),
                                                  decoration: BoxDecoration(
                                                    color: selectedCompanyId != null
                                                        ? Colors.white
                                                        : _inputBg,
                                                    borderRadius:
                                                        BorderRadius.circular(14),
                                                    border: Border.all(
                                                      color: selectedCompanyId != null
                                                          ? _accent
                                                          : _borderL.withOpacity(0.65),
                                                      width: selectedCompanyId != null
                                                          ? 1.6
                                                          : 1.0,
                                                    ),
                                                    boxShadow: selectedCompanyId != null
                                                        ? [
                                                            BoxShadow(
                                                              color: _accent.withOpacity(0.12),
                                                              blurRadius: 14,
                                                              offset: const Offset(0, 4),
                                                            )
                                                          ]
                                                        : [],
                                                  ),
                                                  child: Row(children: [
                                                    // Icon badge
                                                    Container(
                                                      margin: const EdgeInsets.all(10),
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: selectedCompanyId != null
                                                              ? [_accent, _cyan]
                                                              : [
                                                                  _borderL.withOpacity(0.55),
                                                                  _borderL.withOpacity(0.30),
                                                                ],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                      ),
                                                      child: Icon(
                                                        Icons.business_rounded,
                                                        color: selectedCompanyId != null
                                                            ? Colors.white
                                                            : _textSec,
                                                        size: 15,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        selectedCompanyLabel ?? "Tap to select",
                                                        style: TextStyle(
                                                          fontSize: 13.5,
                                                          fontWeight: FontWeight.w500,
                                                          color: selectedCompanyId != null
                                                              ? _textPri
                                                              : _textSec.withOpacity(0.65),
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.only(right: 14),
                                                      child: Icon(
                                                        Icons.keyboard_arrow_down_rounded,
                                                        color: selectedCompanyId != null
                                                            ? _accent
                                                            : _textSec,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ]),
                                                ),
                                              ),

                                              const SizedBox(height: 26),

                                              // Continue button
                                              GestureDetector(
                                                onTap: _confirmSelection,
                                                child: Container(
                                                  width: double.infinity,
                                                  height: 52,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(14),
                                                    gradient: LinearGradient(
                                                      colors: selectedCompanyId != null
                                                          ? const [_accent, Color(0xFF1D4ED8)]
                                                          : [
                                                              Colors.grey.shade300,
                                                              Colors.grey.shade300,
                                                            ],
                                                      begin: Alignment.centerLeft,
                                                      end: Alignment.centerRight,
                                                    ),
                                                    boxShadow: selectedCompanyId != null
                                                        ? [
                                                            BoxShadow(
                                                              color: _accent.withOpacity(0.35),
                                                              blurRadius: 18,
                                                              offset: const Offset(0, 6),
                                                            ),
                                                            BoxShadow(
                                                              color: _cyan.withOpacity(0.15),
                                                              blurRadius: 28,
                                                              offset: const Offset(0, 10),
                                                            ),
                                                          ]
                                                        : [],
                                                  ),
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      // Shine
                                                      if (selectedCompanyId != null)
                                                        Positioned(
                                                          top: 0,
                                                          left: 0,
                                                          right: 0,
                                                          child: Container(
                                                            height: 26,
                                                            decoration: BoxDecoration(
                                                              borderRadius:
                                                                  const BorderRadius.vertical(
                                                                      top: Radius.circular(14)),
                                                              gradient: LinearGradient(
                                                                colors: [
                                                                  Colors.white.withOpacity(0.14),
                                                                  Colors.white.withOpacity(0),
                                                                ],
                                                                begin: Alignment.topCenter,
                                                                end: Alignment.bottomCenter,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            "CONTINUE",
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight: FontWeight.w800,
                                                              color: selectedCompanyId != null
                                                                  ? Colors.white
                                                                  : Colors.grey.shade500,
                                                              letterSpacing: 2.2,
                                                            ),
                                                          ),
                                                          if (selectedCompanyId != null) ...[
                                                            const SizedBox(width: 8),
                                                            const Icon(
                                                              Icons.arrow_forward_rounded,
                                                              color: Colors.white,
                                                              size: 16,
                                                            ),
                                                          ],
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Grid painter (matches login page) ─────────────────────────────────
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