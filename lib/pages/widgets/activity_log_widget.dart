import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =====================================================================
// ACTIVITY LOG WIDGET
// =====================================================================

class LogCard {
  final String title;
  final IconData icon;
  final Color color;
  final int menuId;
  final String qryType;
  final List<ColDef> columns;

  const LogCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.menuId,
    required this.qryType,
    required this.columns,
  });
}

class ColDef {
  final String key;
  final String label;
  final int flex;
  final bool isDateTime;
  final double minWidth;
  const ColDef(
    this.key,
    this.label, {
    this.flex = 1,
    this.isDateTime = false,
    this.minWidth = 70,
  });
}

String _formatCell(String value, {bool isDateTime = false}) {
  if (!isDateTime || value.isEmpty || value == "-") return value;
  try {
    final clean = value.replaceAll(RegExp(r'Z$|\+[0-9:]+$'), '');
    final dt = DateTime.parse(clean);
    return DateFormat('hh:mm a').format(dt);
  } catch (_) {
    return value;
  }
}

const List<LogCard> _allLogCards = [
  LogCard(
    title: "Production Entry",
    icon: Icons.precision_manufacturing_rounded,
    color: Color(0xFF60A5FA),
    menuId: 11,
    qryType: "PRO_REPORT",
    columns: [
      ColDef("ORDER_NO",     "Order No",  minWidth: 110),
      ColDef("ITEM_NAME",    "Item Name", minWidth: 180),
      ColDef("PROCRSS_NAME", "Process",   minWidth: 120),
      ColDef("LINE_NAME",    "Line",      minWidth: 110),
      ColDef("PD_SIZE",      "Size",      minWidth: 70),
      ColDef("PD_PROD_QTY",  "Qty",       minWidth: 70),
      ColDef("CREATED_AT",   "Time",      minWidth: 82, isDateTime: true),
    ],
  ),
  LogCard(
    title: "Plan Wise Production",
    icon: Icons.assignment_rounded,
    color: Color(0xFF0EA5E9),
    menuId: 205,
    qryType: "PLAN_PRO_REPORT",
    columns: [
      ColDef("ORDER_NO",      "Order No",  minWidth: 110),
      ColDef("ITEM_NAME",     "Item Name", minWidth: 180),
      ColDef("PD_RPD_PLN_NO", "Plan No",   minWidth: 110),
      ColDef("PROCRSS_NAME",  "Process",   minWidth: 120),
      ColDef("LINE_NAME",     "Line",      minWidth: 110),
      ColDef("PD_SIZE",       "Size",      minWidth: 70),
      ColDef("PD_PROD_QTY",   "Qty",       minWidth: 70),
      ColDef("CREATED_AT",    "Time",      minWidth: 82, isDateTime: true),
    ],
  ),

  // ── Packing Entry — placed before QC Entry ───────────────────────
  LogCard(
    title: "Packing Entry",
    icon: Icons.inventory_2_rounded,
    color: Color(0xFF06B6D4),
    menuId: 230,                          // update menuId to match backend
    qryType: "PACKING_REPORT",
    columns: [
      ColDef("ORDER_NO",       "Order No",    minWidth: 110),
      ColDef("ITEM_NAME",      "Item Name",   minWidth: 180),
      ColDef("LINE_NAME",      "Line",        minWidth: 110),
      ColDef("COUNTRY_NAME",   "Country",     minWidth: 110),
      ColDef("PD_SIZE",        "Size",        minWidth: 70),
      ColDef("PD_PROD_QTY",    "Packing Qty", minWidth: 100),
      ColDef("CREATED_AT",     "Time",        minWidth: 82, isDateTime: true),
    ],
  ),

  LogCard(
    title: "QC Entry",
    icon: Icons.verified_rounded,
    color: Color(0xFF10B981),
    menuId: 133,
    qryType: "QC_REPORT",
    columns: [
      ColDef("ORDER_NO",        "Order No",   minWidth: 110),
      ColDef("ITEM_NAME",       "Item Name",  minWidth: 180),
      ColDef("PROCRSS_NAME",    "Process",    minWidth: 120),
      ColDef("LINE_NAME",       "Line",       minWidth: 110),
      ColDef("EMP_NAME",        "Employee",   minWidth: 130),
      ColDef("PDQC_REJECT_QTY", "Reject Qty", minWidth: 90),
      ColDef("PDQC_CREATED_AT", "Time",       minWidth: 82, isDateTime: true),
    ],
  ),
  LogCard(
    title: "Downtime Entry",
    icon: Icons.timer_rounded,
    color: Color(0xFFF59E0B),
    menuId: 40,
    qryType: "NPT_REPORT",
    columns: [
      ColDef("LCH_NAME",       "Building",   minWidth: 110),
      ColDef("PROCESS_NAME",   "Process",    minWidth: 120),
      ColDef("LINE_NO",        "Line",       minWidth: 90),
      ColDef("DOWNTIME_CAUSE", "Cause",      minWidth: 150),
      ColDef("TOTA_MINUTE",    "Min",        minWidth: 65),
      ColDef("CREATED_USER",   "Created By", minWidth: 120),
    ],
  ),
  LogCard(
    title: "CTL Downtime",
    icon: Icons.hourglass_bottom_rounded,
    color: Color(0xFFEC4899),
    menuId: 165,
    qryType: "NPT_REPORT",
    columns: [
      ColDef("LCH_NAME",       "Building",   minWidth: 110),
      ColDef("PROCESS_NAME",   "Process",    minWidth: 120),
      ColDef("LINE_NO",        "Line",       minWidth: 90),
      ColDef("DOWNTIME_CAUSE", "Cause",      minWidth: 150),
      ColDef("TOTA_MINUTE",    "Min",        minWidth: 65),
      ColDef("CREATED_USER",   "Created By", minWidth: 120),
    ],
  ),
  LogCard(
    title: "Kanban Status",
    icon: Icons.dashboard_rounded,
    color: Color(0xFF8B5CF6),
    menuId: 232,
    qryType: "KANBAN_REPORT",
    columns: [
      ColDef("LINE_NAME",     "Line",    minWidth: 110),
      ColDef("LSH_LINE_STAT", "Status",  minWidth: 100),
      ColDef("LSH_CMNT",      "Comment", minWidth: 180),
      ColDef("LSH_USER",      "User",    minWidth: 120),
      ColDef("LSH_DATE",      "Time",    minWidth: 82, isDateTime: true),
    ],
  ),
];

// Reports that are company-wide (no P_APP_USER)
const _noUserReports = {
  "PRO_REPORT",
  "PLAN_PRO_REPORT",
  "PACKING_REPORT",
  "NPT_REPORT",
  "CTL_NPT_REPORT",
  "QC_REPORT",
  "KANBAN_REPORT",
};

class ActivityLogService {
  static const String _baseUrl =
      "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov";

  Future<List<Map<String, String>>> fetchLog({
    required String qryType,
    required String appUser,
    required String company,
    DateTime? dateObj,
  }) async {
    final date = dateObj ?? DateTime.now();
    final Map<String, String> params;

    if (_noUserReports.contains(qryType)) {
      final pDates = "${date.month}/${date.day}/${date.year}";
      params = {
        "P_QRYTYP":      qryType,
        "LOGIN_COMPANY": company,
        "P_DATES":       pDates,
      };
    } else {
      params = {
        "P_QRYTYP":      qryType,
        "P_APP_USER":    appUser,
        "LOGIN_COMPANY": company,
        "P_DATE":        DateFormat('dd-MM-yyyy').format(date),
      };
    }

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      debugPrint("🌐 FETCH: $uri");
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return [];

      final decoded = jsonDecode(resp.body) as Map;
      debugPrint("🔑 [$qryType] Keys returned: ${decoded.keys.toList()}");

      List raw = [];
      if (decoded.containsKey(qryType)) {
        raw = decoded[qryType] as List;
      } else {
        for (final entry in decoded.entries) {
          if (entry.value is List) {
            debugPrint("⚠️ [$qryType] key not found, using fallback: ${entry.key}");
            raw = entry.value as List;
            break;
          }
        }
      }

      if (raw.isEmpty) return [];

      final result = <Map<String, String>>[];
      for (final item in raw) {
        if (item == null || item is! Map || item.isEmpty) continue;
        final row = (item as Map).map<String, String>(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ""),
        );
        if (row.containsKey("CODE") && row.containsKey("MESSAGE")) continue;
        if (row.containsKey("MESSAGE")) continue;
        final hasReal = row.values.any((v) {
          final t = v.trim();
          return t.isNotEmpty && t != "null" && t != "NULL";
        });
        if (hasReal) result.add(row);
      }

      debugPrint("✅ [$qryType] ${result.length} rows loaded");
      return result;
    } catch (e) {
      debugPrint("❌ fetchLog error [$qryType]: $e");
      return [];
    }
  }

  Future<void> probeQueryTypes({
    required String appUser,
    required String company,
  }) async {
    for (final qry in _noUserReports) {
      try {
        final pDates =
            "${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}";
        final uri = Uri.parse(_baseUrl).replace(queryParameters: {
          "P_QRYTYP":      qry,
          "LOGIN_COMPANY": company,
          "P_DATES":       pDates,
        });
        final resp = await http.get(uri).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final decoded = jsonDecode(resp.body) as Map;
          debugPrint("🔑 PROBE [$qry] Keys: ${decoded.keys.toList()}");
          if (decoded.containsKey(qry)) {
            debugPrint("✅ MY LOG [$qry] => ${(decoded[qry] as List).length} rows");
          }
        }
      } catch (e) {
        debugPrint("❌ $qry => $e");
      }
    }
  }
}

// ── Main Widget ───────────────────────────────────────────────────────
class ActivityLogSection extends StatefulWidget {
  final List<int> assignedMenuIds;
  const ActivityLogSection({super.key, required this.assignedMenuIds});

  @override
  State<ActivityLogSection> createState() => _ActivityLogSectionState();
}

class _ActivityLogSectionState extends State<ActivityLogSection> {
  final _service = ActivityLogService();
  String _appUser = "";
  String _company = "";

  // Keyed by card.title to avoid collisions when two cards share the same qryType
  final Map<String, int?> _counts = {};

  bool _initialized = false;
  bool _loading = false;

  // ── "See More" collapse / expand ─────────────────────────────────
  static const int _previewCount = 6; // cards shown before "See More"
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(ActivityLogSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.assignedMenuIds.length != widget.assignedMenuIds.length ||
        !oldWidget.assignedMenuIds.toSet().containsAll(widget.assignedMenuIds);
    if (changed) _init();
  }

  Future<void> _init() async {
    if (_loading) return;
    final prefs = await SharedPreferences.getInstance();
    _appUser = prefs.getString('userId') ?? "";
    _company = prefs.getString('selected_company_id') ?? "0";
    await _loadCounts();
  }

  List<LogCard> get _visibleCards => _allLogCards
      .where((c) => widget.assignedMenuIds.contains(c.menuId))
      .toList();

  Future<void> _loadCounts() async {
    if (_loading) return;
    final cards = _visibleCards;
    if (cards.isEmpty) {
      if (mounted) setState(() => _initialized = true);
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        for (final c in cards) _counts[c.title] = null;
        _initialized = true;
      });
    }
    final results = await Future.wait(cards.map((c) async {
      final rows = await _service.fetchLog(
        qryType: c.qryType,
        appUser: _appUser,
        company: _company,
      );
      return MapEntry(c.title, rows.length);
    }));
    if (mounted) {
      setState(() {
        for (final e in results) _counts[e.key] = e.value;
        _loading = false;
      });
    }
  }

  void _openDetail(LogCard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        card: card,
        appUser: _appUser,
        company: _company,
        service: _service,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = _visibleCards;
    if (!_initialized || cards.isEmpty) return const SizedBox.shrink();

    // Split into preview and overflow cards
    final previewCards = cards.length <= _previewCount
        ? cards
        : cards.sublist(0, _previewCount);
    final overflowCards = cards.length <= _previewCount
        ? <LogCard>[]
        : cards.sublist(_previewCount);
    final hasMore = overflowCards.isNotEmpty;

    Widget _grid(List<LogCard> items) => GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          childAspectRatio: 2.8,
          children: items
              .map((c) => _CountCard(
                    card: c,
                    count: _counts[c.title],
                    onTap: () => _openDetail(c),
                  ))
              .toList(),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ─────────────────────────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF60A5FA), Color(0xFF38BDF8)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              "Activity Log",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _loading ? null : _loadCounts,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF60A5FA).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF60A5FA).withOpacity(0.2)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF60A5FA)),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded,
                        color: Color(0xFF60A5FA), size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Always-visible first N cards ────────────────────────────
        _grid(previewCards),

        // ── Expandable overflow cards ────────────────────────────────
        if (hasMore) ...[
          // Animated expand/collapse
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _grid(overflowCards),
            ),
          ),
          const SizedBox(height: 6),

          // ── See More / See Less button ────────────────────────────
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF60A5FA).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF60A5FA).withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expanded
                          ? "See Less"
                          : "See More (${overflowCards.length})",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF60A5FA),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 280),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 15,
                        color: Color(0xFF60A5FA),
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
}

// ── Count Card ────────────────────────────────────────────────────────
class _CountCard extends StatelessWidget {
  final LogCard card;
  final int? count;
  final VoidCallback onTap;

  const _CountCard(
      {required this.card, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              card.color.withOpacity(0.15),
              card.color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: card.color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [card.color, card.color.withOpacity(0.8)]),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                      color: card.color.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Icon(card.icon, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    card.title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  count == null
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(card.color),
                          ),
                        )
                      : Text(
                          count == 0
                              ? "No entries today"
                              : "$count ${count == 1 ? 'entry' : 'entries'} today",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: count == 0
                                ? const Color(0xFF94A3B8)
                                : card.color,
                            height: 1.1,
                          ),
                        ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: card.color.withOpacity(0.5), size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Detail Bottom Sheet ───────────────────────────────────────────────
class _DetailSheet extends StatefulWidget {
  final LogCard card;
  final String appUser;
  final String company;
  final ActivityLogService service;

  const _DetailSheet({
    required this.card,
    required this.appUser,
    required this.company,
    required this.service,
  });

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

enum _Shift { all, shiftA, shiftB }

class _DetailSheetState extends State<_DetailSheet> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, String>> _rows = [];
  bool _loading = true;
  String _searchQuery = "";
  _Shift _selectedShift = _Shift.all;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _hScrollCtrl = ScrollController();

  bool get _isKanban => widget.card.qryType == "KANBAN_REPORT";

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _hScrollCtrl.dispose();
    super.dispose();
  }

  bool _isShiftA(Map<String, String> row) {
    final dtCol = widget.card.columns.where((c) => c.isDateTime).toList();
    if (dtCol.isEmpty) return true;
    final raw = row[dtCol.first.key] ?? "";
    if (raw.isEmpty) return true;
    try {
      final clean = raw.replaceAll(RegExp(r'Z$|\+[0-9:]+$'), '');
      final dt = DateTime.parse(clean);
      final mins = dt.hour * 60 + dt.minute;
      return mins >= 495 && mins <= 1215;
    } catch (_) {
      return true;
    }
  }

  List<Map<String, String>> get _shiftRows {
    if (_selectedShift == _Shift.all || _isKanban) return _rows;
    return _rows.where((row) {
      final a = _isShiftA(row);
      return _selectedShift == _Shift.shiftA ? a : !a;
    }).toList();
  }

  List<Map<String, String>> get _filteredRows {
    final base = _shiftRows;
    if (_searchQuery.isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base
        .where((row) => row.values.any((v) => v.toLowerCase().contains(q)))
        .toList();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final rows = await widget.service.fetchLog(
      qryType: widget.card.qryType,
      appUser: widget.appUser,
      company: widget.company,
      dateObj: _selectedDate,
    );
    if (mounted) setState(() { _rows = rows; _loading = false; });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      _searchController.clear();
      setState(() { _selectedDate = picked; _searchQuery = ""; });
      _fetch();
    }
  }

  double _tableWidth(List<ColDef> cols) =>
      cols.fold(0.0, (s, c) => s + c.minWidth) + 32;

  Widget _buildTableRow(List<ColDef> cols, Map<String, String>? data, int idx) {
    final isHeader = data == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: isHeader
          ? const Color(0xFF1A73E8)
          : idx % 2 == 0
              ? const Color(0xFFF8FAFC)
              : Colors.white,
      child: Row(
        children: cols.map((c) {
          Widget cell;
          if (isHeader) {
            cell = Text(c.label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
                overflow: TextOverflow.ellipsis);
          } else if (_isKanban && c.key == "LSH_LINE_STAT") {
            final val = data![c.key] ?? "-";
            final isReady = val.toLowerCase() == "ready";
            cell = Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isReady
                    ? const Color(0xFF10B981).withOpacity(0.15)
                    : const Color(0xFFF59E0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isReady
                      ? const Color(0xFF10B981).withOpacity(0.4)
                      : const Color(0xFFF59E0B).withOpacity(0.4),
                ),
              ),
              child: Text(val,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isReady
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B)),
                  overflow: TextOverflow.ellipsis),
            );
          } else {
            cell = Text(
              data![c.key] == null
                  ? "-"
                  : _formatCell(data[c.key]!, isDateTime: c.isDateTime),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155)),
              softWrap: true,
            );
          }
          return SizedBox(width: c.minWidth, child: cell);
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final cols = widget.card.columns;

    final displayCols = (_rows.isNotEmpty &&
            cols.every((c) =>
                !_rows.first.containsKey(c.key) ||
                (_rows.first[c.key] ?? "").isEmpty))
        ? _rows.first.keys
            .take(6)
            .map((k) => ColDef(k, k, minWidth: 90))
            .toList()
        : cols;

    return Container(
      height: screenH * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),

          // ── Sheet header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      widget.card.color,
                      widget.card.color.withOpacity(0.8)
                    ]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.card.icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.card.title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A))),
                      Text(
                        _loading
                            ? "Loading..."
                            : _searchQuery.isNotEmpty
                                ? "${_filteredRows.length} of ${_shiftRows.length} entries — ${DateFormat('dd MMM yyyy').format(_selectedDate)}"
                                : "${_shiftRows.length} ${_shiftRows.length == 1 ? 'entry' : 'entries'} — ${DateFormat('dd MMM yyyy').format(_selectedDate)}",
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        widget.card.color.withOpacity(0.15),
                        widget.card.color.withOpacity(0.05),
                      ]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: widget.card.color.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            color: widget.card.color, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: widget.card.color),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.grey.shade200),

          // ── Search ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: "Search entries...",
                hintStyle:
                    TextStyle(fontSize: 12, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 16, color: Colors.grey.shade400),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                        child: Icon(Icons.close_rounded,
                            size: 16, color: Colors.grey.shade400),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: widget.card.color.withOpacity(0.4), width: 1.5),
                ),
              ),
            ),
          ),

          // ── Shift tabs (hidden for Kanban) ────────────────────────
          if (!_isKanban)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ShiftTab(
                    label: "All",
                    shift: _Shift.all,
                    selected: _selectedShift,
                    color: widget.card.color,
                    onTap: (s) => setState(() {
                      _selectedShift = s;
                      _searchController.clear();
                      _searchQuery = "";
                    }),
                  ),
                  const SizedBox(width: 8),
                  _ShiftTab(
                    label: "Shift A",
                    shift: _Shift.shiftA,
                    selected: _selectedShift,
                    color: widget.card.color,
                    onTap: (s) => setState(() {
                      _selectedShift = s;
                      _searchController.clear();
                      _searchQuery = "";
                    }),
                  ),
                  const SizedBox(width: 8),
                  _ShiftTab(
                    label: "Shift B",
                    shift: _Shift.shiftB,
                    selected: _selectedShift,
                    color: widget.card.color,
                    onTap: (s) => setState(() {
                      _selectedShift = s;
                      _searchController.clear();
                      _searchQuery = "";
                    }),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 6),

          // ── Table ─────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            widget.card.color)))
                : _rows.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_rounded,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              "No entries on ${DateFormat('dd MMM yyyy').format(_selectedDate)}",
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(builder: (ctx, constraints) {
                        final tWidth = _tableWidth(displayCols);
                        final needsHScroll = tWidth > constraints.maxWidth;
                        final effectiveWidth =
                            needsHScroll ? tWidth : constraints.maxWidth;

                        return SingleChildScrollView(
                          controller: _hScrollCtrl,
                          scrollDirection: Axis.horizontal,
                          physics: needsHScroll
                              ? const BouncingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          child: SizedBox(
                            width: effectiveWidth,
                            child: Column(
                              children: [
                                _buildTableRow(displayCols, null, -1),
                                Expanded(
                                  child: _filteredRows.isEmpty &&
                                          _searchQuery.isNotEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.search_off_rounded,
                                                  size: 40,
                                                  color: Colors.grey.shade300),
                                              const SizedBox(height: 10),
                                              Text(
                                                'No results for "$_searchQuery"',
                                                style: TextStyle(
                                                    color: Colors.grey.shade500,
                                                    fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: _filteredRows.length,
                                          itemBuilder: (_, i) =>
                                              _buildTableRow(
                                            displayCols,
                                            _filteredRows[i],
                                            i,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
          ),
        ],
      ),
    );
  }
}

class _ShiftTab extends StatelessWidget {
  final String label;
  final _Shift shift;
  final _Shift selected;
  final Color color;
  final ValueChanged<_Shift> onTap;

  const _ShiftTab({
    required this.label,
    required this.shift,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = shift == selected;
    return GestureDetector(
      onTap: () => onTap(shift),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : color.withOpacity(0.25),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}