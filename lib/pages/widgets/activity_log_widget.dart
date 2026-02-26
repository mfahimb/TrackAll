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
  const ColDef(this.key, this.label, {this.flex = 1});
}

// ── Column config — keys must match EXACT API response field names ────
// Check debug console for "🔑 AVAILABLE KEYS" after first run and update keys
const List<LogCard> _allLogCards = [
  LogCard(
    title: "Production Entry",
    icon: Icons.precision_manufacturing_rounded,
    color: Color(0xFF60A5FA),
    menuId: 11,
    qryType: "PROD_LOG",
    columns: [
      ColDef("ORDER_NO",     "Order No",   flex: 2),
      ColDef("ITEM_NAME",    "Item Name",  flex: 3),
      ColDef("PROCESS_NAME", "Process",    flex: 2),
      ColDef("LINE_NAME",    "Line",       flex: 2),
      ColDef("SIZE",         "Size",       flex: 1),
      ColDef("QTY",          "Qty",        flex: 1),
      ColDef("CREATED_AT",   "Created At", flex: 2),
    ],
  ),
  LogCard(
    title: "QC Entry",
    icon: Icons.verified_rounded,
    color: Color(0xFF10B981),
    menuId: 133,
    qryType: "QC_LOG",
    columns: [
      ColDef("ORDER_NO",   "Order No",  flex: 2),
      ColDef("ITEM_NAME",  "Item Name", flex: 3),
      ColDef("QC_TYPE",    "QC Type",   flex: 2),
      ColDef("ISSUE_TYPE", "Issue",     flex: 2),
      ColDef("SIZE",       "Size",      flex: 1),
      ColDef("QTY",        "Qty",       flex: 1),
      ColDef("CREATED_AT", "Created At",flex: 2),
    ],
  ),
  LogCard(
    title: "Downtime Entry",
    icon: Icons.timer_rounded,
    color: Color(0xFFF59E0B),
    menuId: 40,
    qryType: "NPT_LOG",
    columns: [
      ColDef("BUILDING",     "Building",  flex: 2),
      ColDef("PROCESS_NAME", "Process",   flex: 2),
      ColDef("LINE_NAME",    "Line",      flex: 2),
      ColDef("CAUSE",        "Cause",     flex: 2),
      ColDef("TOTAL_MIN",    "Min",       flex: 1),
      ColDef("CREATED_AT",   "Created At",flex: 2),
    ],
  ),
  LogCard(
    title: "CTL Downtime",
    icon: Icons.hourglass_bottom_rounded,
    color: Color(0xFFEC4899),
    menuId: 165,
    qryType: "CTL_NPT_LOG",
    columns: [
      ColDef("BUILDING",     "Building",  flex: 2),
      ColDef("PROCESS_NAME", "Process",   flex: 2),
      ColDef("LINE_NAME",    "Line",      flex: 2),
      ColDef("CAUSE",        "Cause",     flex: 2),
      ColDef("TOTAL_MIN",    "Min",       flex: 1),
      ColDef("CREATED_AT",   "Created At",flex: 2),
    ],
  ),
];

// ── Service ───────────────────────────────────────────────────────────
class ActivityLogService {
  static const String _baseUrl =
      "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov";

  Future<List<Map<String, String>>> fetchLog({
    required String qryType,
    required String appUser,
    required String company,
    String? date,
  }) async {
    final effectiveDate =
        date ?? DateFormat('dd-MM-yyyy').format(DateTime.now());

    final params = {
      "P_QRYTYP":      qryType,
      "P_APP_USER":    appUser,
      "LOGIN_COMPANY": company,
      "P_DATE":        effectiveDate,
    };

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      debugPrint("📋 ACTIVITY LOG REQUEST => $uri");

      final resp =
          await http.get(uri).timeout(const Duration(seconds: 15));
      debugPrint("📋 STATUS => ${resp.statusCode}");
      debugPrint("📋 RAW BODY => ${resp.body}");

      if (resp.statusCode != 200) return [];

      final decoded = jsonDecode(resp.body) as Map;
      debugPrint("📋 TOP-LEVEL KEYS => ${decoded.keys.toList()}");

      if (!decoded.containsKey(qryType)) {
        debugPrint(
            "❌ Key '$qryType' not found. Available: ${decoded.keys.toList()}");
        return [];
      }

      final List raw = decoded[qryType] as List;
      debugPrint("📋 RAW ROW COUNT => ${raw.length}");
      for (int i = 0; i < raw.length && i < 5; i++) {
        debugPrint("🔍 ROW[$i] => ${raw[i]}");
      }
      if (raw.isEmpty) return [];
      final result = <Map<String, String>>[];
      for (final item in raw) {
        if (item == null || item is! Map || item.isEmpty) continue;
        final row = (item as Map).map<String, String>(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ""),
        );
        // Skip backend error rows e.g. {"CODE":"1","MESSAGE":"Data not found"}
        if (row.containsKey("CODE") && row.containsKey("MESSAGE")) continue;
        if (row.containsKey("MESSAGE")) continue;

        final hasReal = row.values.any((v) {
          final t = v.trim();
          return t.isNotEmpty && t != "null" && t != "NULL";
        });
        if (hasReal) result.add(row);
      }
      debugPrint("✅ $qryType => ${result.length} valid rows");
      if (result.isNotEmpty) debugPrint("🔑 KEYS => ${result.first.keys.toList()}");
      return result;
    } catch (e, st) {
      debugPrint("❌ fetchLog error: $e\n$st");
      return [];
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

  final Map<String, int?> _counts = {};
  bool _initialized = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // Only re-fetch when assignedMenuIds actually changes
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
        for (final c in cards) {
          _counts[c.qryType] = null; // show spinner
        }
        _initialized = true;
      });
    }

    // Fetch all in parallel, then single setState
    final results = await Future.wait(cards.map((c) async {
      final rows = await _service.fetchLog(
        qryType: c.qryType,
        appUser: _appUser,
        company: _company,
      );
      return MapEntry(c.qryType, rows.length);
    }));

    if (mounted) {
      setState(() {
        for (final e in results) {
          _counts[e.key] = e.value;
        }
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
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
              "Today's Activity",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            // Refresh button — spinner while loading
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

        const SizedBox(height: 12),

        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.6,
          children: cards
              .map((c) => _CountCard(
                    card: c,
                    count: _counts[c.qryType],
                    onTap: () => _openDetail(c),
                  ))
              .toList(),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              padding: const EdgeInsets.all(7),
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
              child: Icon(card.icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
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
                  const SizedBox(height: 2),
                  count == null
                      ? SizedBox(
                          width: 16,
                          height: 16,
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
                            fontSize: 13,
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
                color: card.color.withOpacity(0.5), size: 16),
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

class _DetailSheetState extends State<_DetailSheet> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, String>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final rows = await widget.service.fetchLog(
      qryType: widget.card.qryType,
      appUser: widget.appUser,
      company: widget.company,
      date: DateFormat('dd-MM-yyyy').format(_selectedDate),
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
      setState(() => _selectedDate = picked);
      _fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final cols = widget.card.columns;

    // Fallback: if configured keys don't match API, show all keys from first row
    final displayCols = (_rows.isNotEmpty &&
            cols.every((c) =>
                !_rows.first.containsKey(c.key) ||
                (_rows.first[c.key] ?? "").isEmpty))
        ? _rows.first.keys
            .take(6)
            .map((k) => ColDef(k, k, flex: 1))
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
                  child: Icon(widget.card.icon,
                      color: Colors.white, size: 18),
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
                            : "${_rows.length} ${_rows.length == 1 ? 'entry' : 'entries'} — ${DateFormat('dd MMM yyyy').format(_selectedDate)}",
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
                          DateFormat('dd MMM yyyy')
                              .format(_selectedDate),
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
                                size: 48,
                                color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              "No entries on ${DateFormat('dd MMM yyyy').format(_selectedDate)}",
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            color: const Color(0xFF1A73E8),
                            child: Row(
                              children: displayCols
                                  .map((c) => Expanded(
                                        flex: c.flex,
                                        child: Text(c.label,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.w800,
                                                color: Colors.white),
                                            overflow:
                                                TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _rows.length,
                              itemBuilder: (_, i) {
                                final row = _rows[i];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 9),
                                  color: i % 2 == 0
                                      ? const Color(0xFFF8FAFC)
                                      : Colors.white,
                                  child: Row(
                                    children: displayCols
                                        .map((c) => Expanded(
                                              flex: c.flex,
                                              child: Text(
                                                row[c.key] ?? "-",
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w500,
                                                    color: Color(
                                                        0xFF334155)),
                                                overflow: TextOverflow
                                                    .ellipsis,
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}