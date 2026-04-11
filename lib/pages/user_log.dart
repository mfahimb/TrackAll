import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackall_app/pages/widgets/top_menu_bar.dart';

// =====================================================================
// USER LOG PAGE  –  "My Log"
// =====================================================================

enum _Shift { all, shiftA, shiftB }

// ── Entry type config ─────────────────────────────────────────────────
class _EntryType {
  final String qryType;
  final String label;
  final Color color;
  final IconData icon;
  final String dateKey;
  final String titleKey;
  final List<String> chipKeys;
  final String? qtyKey;
  final String qtyLabel;

  const _EntryType({
    required this.qryType,
    required this.label,
    required this.color,
    required this.icon,
    required this.dateKey,
    required this.titleKey,
    required this.chipKeys,
    this.qtyKey,
    this.qtyLabel = "Qty",
  });
}

const List<_EntryType> _entryTypes = [
  _EntryType(
    qryType:  "PRO_REPORT",
    label:    "Production",
    color:    Color(0xFF1A73E8),
    icon:     Icons.precision_manufacturing_rounded,
    dateKey:  "CREATED_AT",
    titleKey: "ITEM_NAME",
    chipKeys: ["PROCRSS_NAME", "LINE_NAME", "PD_SIZE"],
    qtyKey:   "PD_PROD_QTY",
    qtyLabel: "Qty",
  ),
  _EntryType(
    qryType:  "PLAN_PRO_REPORT",
    label:    "Plan Wise Production",
    color:    Color(0xFF0EA5E9),
    icon:     Icons.assignment_rounded,
    dateKey:  "CREATED_AT",
    titleKey: "ITEM_NAME",
    chipKeys: ["PD_RPD_PLN_NO", "PROCRSS_NAME", "LINE_NAME", "PD_SIZE"],
    qtyKey:   "PD_PROD_QTY",
    qtyLabel: "Qty",
  ),
  _EntryType(
    qryType:  "PACKING_REPORT",
    label:    "Packing",
    color:    Color(0xFF06B6D4),
    icon:     Icons.inventory_2_rounded,
    dateKey:  "CREATED_AT",
    titleKey: "ITEM_NAME",
    chipKeys: ["LINE_NAME", "COUNTRY_NAME", "PD_SIZE"],
    qtyKey:   "PD_PROD_QTY",
    qtyLabel: "Packing Qty",
  ),
  _EntryType(
    qryType:  "PLAN_PACKING_REPORT",
    label:    "Plan Wise Packing",
    color:    Color(0xFF0284C7),
    icon:     Icons.inventory_rounded,
    dateKey:  "CREATED_AT",
    titleKey: "ITEM_NAME",
    chipKeys: ["PD_RPD_PLN_NO", "LINE_NAME", "COUNTRY_NAME", "PD_SIZE"],
    qtyKey:   "PD_PROD_QTY",
    qtyLabel: "Packing Qty",
  ),
  _EntryType(
    qryType:  "QC_REPORT",
    label:    "QC Entry",
    color:    Color(0xFF10B981),
    icon:     Icons.verified_rounded,
    dateKey:  "PDQC_CREATED_AT",
    titleKey: "ITEM_NAME",
    chipKeys: ["PROCRSS_NAME", "LINE_NAME", "QC_TYPE"],
    qtyKey:   "PDQC_REJECT_QTY",
    qtyLabel: "Reject",
  ),
  _EntryType(
    qryType:  "NPT_REPORT",
    label:    "Downtime",
    color:    Color(0xFFF59E0B),
    icon:     Icons.timer_rounded,
    dateKey:  "CREATED_AT",
    titleKey: "DOWNTIME_CAUSE",
    chipKeys: ["PROCESS_NAME", "LINE_NO"],
    qtyKey:   "TOTA_MINUTE",
    qtyLabel: "Min",
  ),
  _EntryType(
    qryType:  "CTL_NPT_REPORT",
    label:    "CTL Downtime",
    color:    Color(0xFFEC4899),
    icon:     Icons.hourglass_bottom_rounded,
    dateKey:  "CREATED_AT",
    titleKey: "DOWNTIME_CAUSE",
    chipKeys: ["PROCESS_NAME", "LINE_NO"],
    qtyKey:   "TOTA_MINUTE",
    qtyLabel: "Min",
  ),
  _EntryType(
    qryType:  "KANBAN_REPORT",
    label:    "Kanban Status",
    color:    Color(0xFF8B5CF6),
    icon:     Icons.dashboard_rounded,
    dateKey:  "LSH_DATE",
    titleKey: "LINE_NAME",
    chipKeys: ["LSH_LINE_STAT", "LSH_CMNT"],
    qtyKey:   null,
    qtyLabel: "",
  ),
  // ── Incentive (Day Wise Line Setup) ───────────────────────────────
  _EntryType(
    qryType:  "DAY_WISE_LINE_SETUP",
    label:    "Incentive",
    color:    Color(0xFFF97316),
    icon:     Icons.emoji_events_rounded,
    dateKey:  "CREATED_AT",
    titleKey: "LINE_NAME",
    chipKeys: ["AEMP_NAME", "SHIFT_ID", "CATEGORY_NAME"],
    qtyKey:   null,
    qtyLabel: "",
  ),
];

// ── Model ─────────────────────────────────────────────────────────────
class _LogEntry {
  final _EntryType type;
  final Map<String, dynamic> raw;
  final DateTime? dateTime;

  const _LogEntry({
    required this.type,
    required this.raw,
    required this.dateTime,
  });

  String get title => raw[type.titleKey]?.toString() ?? "-";
  String get qty   => raw[type.qtyKey ?? ""]?.toString() ?? "";

  bool get isShiftA {
    if (dateTime == null) return true;
    final m = dateTime!.hour * 60 + dateTime!.minute;
    return m >= 495 && m <= 1215;
  }
}

// ── Service ───────────────────────────────────────────────────────────
class _UserLogService {
  static const _base =
      "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov";

  Future<Map<String, List<_LogEntry>>> fetchAll({
    required String appUser,
    required String createdById,
    required String company,
    required DateTime date,
  }) async {
    final pDates = "${date.month}/${date.day}/${date.year}";

    final futures = _entryTypes.map((type) async {
      try {
        final uri = Uri.parse(_base).replace(queryParameters: {
          "P_QRYTYP":      type.qryType,
          "LOGIN_COMPANY": company,
          "P_DATES":       pDates,
          "P_APP_USER":    appUser,
        });

        debugPrint("📋 MY LOG [${type.qryType}] user=$appUser => $uri");

        final resp =
            await http.get(uri).timeout(const Duration(seconds: 15));
        if (resp.statusCode != 200) {
          return MapEntry(type.qryType, <_LogEntry>[]);
        }

        final decoded = jsonDecode(resp.body) as Map;

        // ── Resolve the data list (exact key or first list fallback) ──
        List raw = [];
        if (decoded.containsKey(type.qryType)) {
          raw = decoded[type.qryType] as List;
        } else {
          for (final e in decoded.entries) {
            if (e.value is List) {
              debugPrint("⚠️ [${type.qryType}] key missing, fallback => '${e.key}'");
              raw = e.value as List;
              break;
            }
          }
        }

        debugPrint("📦 [${type.qryType}] raw rows: ${raw.length}");

        // ── Log all keys from first row to help diagnose field names ──
        if (raw.isNotEmpty && raw.first is Map) {
          debugPrint("🔑 [${type.qryType}] keys: ${(raw.first as Map).keys.toList()}");
        }

        final allRows = raw
            .where((r) => r != null && r is Map)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();

        // ── Filter rows to the logged-in user.
        //    Different reports use different field names for the creator,
        //    so we probe candidates in priority order.
        final needle = createdById.trim().toLowerCase();
        const userFields = [
          "CREATED_BY",
          "CREATED_USER",
          "LSH_USER",
          "APP_USER",
          "USER_ID",
          "USER_NAME",
          "USERID",
        ];

        String? detectedField;
        if (allRows.isNotEmpty) {
          for (final f in userFields) {
            if (allRows.first.containsKey(f)) {
              detectedField = f;
              debugPrint(
                "👤 [${type.qryType}] user field='$f' "
                "val='${allRows.first[f]}' needle='$needle'");
              break;
            }
          }
        }

        final List<Map<String, dynamic>> filtered;
        if (detectedField == null || needle.isEmpty) {
          debugPrint("⚠️ [${type.qryType}] no user field found — 0 rows shown");
          filtered = [];
        } else {
          final field = detectedField;
          filtered = allRows.where((row) {
            return (row[field] ?? "").toString().trim().toLowerCase() == needle;
          }).toList();
        }

        debugPrint("✅ [${type.qryType}] ${filtered.length}/${allRows.length} rows after user filter");

        final entries = filtered.map((row) {
          DateTime? dt;
          final ts = row[type.dateKey]?.toString() ?? "";
          if (ts.isNotEmpty) {
            try {
              final clean = ts.replaceAll(RegExp(r'Z$|\+[0-9:]+$'), '');
              dt = DateTime.parse(clean);
            } catch (_) {}
          }
          return _LogEntry(type: type, raw: row, dateTime: dt);
        }).toList();

        entries.sort((a, b) {
          if (a.dateTime == null) return 1;
          if (b.dateTime == null) return -1;
          return b.dateTime!.compareTo(a.dateTime!);
        });

        debugPrint("✅ MY LOG [${type.qryType}] => ${entries.length} rows");
        return MapEntry(type.qryType, entries);
      } catch (e) {
        debugPrint("❌ MY LOG [${type.qryType}] error: $e");
        return MapEntry(type.qryType, <_LogEntry>[]);
      }
    });

    final results = await Future.wait(futures);
    return Map.fromEntries(results);
  }
}

// =====================================================================
// PAGE
// =====================================================================
class UserLogPage extends StatefulWidget {
  const UserLogPage({super.key});

  @override
  State<UserLogPage> createState() => _UserLogPageState();
}

class _UserLogPageState extends State<UserLogPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = _UserLogService();

  String _appUser = "";
  String _company = "";
  String _createdBy = "";
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;

  Map<String, List<_LogEntry>> _data = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _appUser   = prefs.getString('userId') ?? "";
    _company   = prefs.getString('selected_company_id') ?? "0";
    _createdBy = _appUser;
    await _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final data = await _service.fetchAll(
      appUser:     _appUser,
      createdById: _createdBy,
      company:     _company,
      date:        _selectedDate,
    );
    if (mounted) setState(() { _data = data; _loading = false; });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A73E8),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetch();
    }
  }

  List<_LogEntry> _forShift(String qryType, _Shift shift) {
    final list = _data[qryType] ?? [];
    if (shift == _Shift.shiftA) return list.where((e) =>  e.isShiftA).toList();
    if (shift == _Shift.shiftB) return list.where((e) => !e.isShiftA).toList();
    return list;
  }

  List<_EntryType> _visibleTypes(_Shift shift) =>
      _entryTypes.where((t) => _forShift(t.qryType, shift).isNotEmpty).toList();

  int _totalCount(_Shift shift) =>
      _entryTypes.fold(0, (s, t) => s + _forShift(t.qryType, shift).length);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: Column(
        children: [
          const TopMenuBar(),

          // ── Header ───────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF1A73E8), Color(0xFF38BDF8)]),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.person_pin_circle_rounded,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("My Log",
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A))),
                        Text("User ID: $_appUser",
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                    const Spacer(),

                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A73E8).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF1A73E8).withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                color: Color(0xFF1A73E8), size: 13),
                            const SizedBox(width: 5),
                            Text(
                              DateFormat('dd MMM yyyy').format(_selectedDate),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A73E8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    GestureDetector(
                      onTap: _loading ? null : _fetch,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A73E8).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF1A73E8).withOpacity(0.2)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF1A73E8)),
                                ),
                              )
                            : const Icon(Icons.refresh_rounded,
                                color: Color(0xFF1A73E8), size: 16),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF1A73E8),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF1A73E8),
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                  tabs: [
                    Tab(text: "All (${_totalCount(_Shift.all)})"),
                    Tab(text: "Shift A (${_totalCount(_Shift.shiftA)})"),
                    Tab(text: "Shift B (${_totalCount(_Shift.shiftB)})"),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CardsView(
                  loading: _loading,
                  visibleTypes: _visibleTypes(_Shift.all),
                  getEntries: (t) => _forShift(t.qryType, _Shift.all),
                  selectedDate: _selectedDate,
                ),
                _CardsView(
                  loading: _loading,
                  visibleTypes: _visibleTypes(_Shift.shiftA),
                  getEntries: (t) => _forShift(t.qryType, _Shift.shiftA),
                  selectedDate: _selectedDate,
                  emptyLabel: "No Shift A entries",
                ),
                _CardsView(
                  loading: _loading,
                  visibleTypes: _visibleTypes(_Shift.shiftB),
                  getEntries: (t) => _forShift(t.qryType, _Shift.shiftB),
                  selectedDate: _selectedDate,
                  emptyLabel: "No Shift B entries",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// CARDS VIEW
// =====================================================================
class _CardsView extends StatelessWidget {
  final bool loading;
  final List<_EntryType> visibleTypes;
  final List<_LogEntry> Function(_EntryType) getEntries;
  final DateTime selectedDate;
  final String emptyLabel;

  const _CardsView({
    required this.loading,
    required this.visibleTypes,
    required this.getEntries,
    required this.selectedDate,
    this.emptyLabel = "No entries for this date",
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A73E8)),
        ),
      );
    }

    if (visibleTypes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(emptyLabel,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd MMM yyyy').format(selectedDate),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      children: visibleTypes.map((type) {
        final entries = getEntries(type);
        return _TypeCard(
          type: type,
          entries: entries,
          onTap: () => _openDetail(context, type, entries),
        );
      }).toList(),
    );
  }

  static void _openDetail(
      BuildContext context, _EntryType type, List<_LogEntry> entries) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => type.qryType == "DAY_WISE_LINE_SETUP"
          ? _IncentiveDetailSheet(entries: entries)
          : _DetailSheet(type: type, entries: entries),
    );
  }
}

// ── Summary card per type ─────────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  final _EntryType type;
  final List<_LogEntry> entries;
  final VoidCallback onTap;

  const _TypeCard({
    required this.type,
    required this.entries,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isKanban   = type.qryType == "KANBAN_REPORT";
    final bool isIncentive = type.qryType == "DAY_WISE_LINE_SETUP";

    final totalQty = type.qtyKey == null
        ? 0
        : entries.fold<int>(0, (sum, e) =>
            sum + (int.tryParse(e.raw[type.qtyKey!]?.toString() ?? "") ?? 0));

    final earliest = entries.isNotEmpty ? entries.last.dateTime : null;
    final latest   = entries.isNotEmpty ? entries.first.dateTime : null;

    final earliestStr =
        earliest != null ? DateFormat('hh:mm a').format(earliest) : "";
    final latestStr =
        latest != null ? DateFormat('hh:mm a').format(latest) : "";

    final int readyCount = isKanban
        ? entries.where((e) =>
            (e.raw["LSH_LINE_STAT"]?.toString().toLowerCase() ?? "") == "ready")
            .length
        : 0;
    final int notReadyCount = isKanban ? entries.length - readyCount : 0;

    // Incentive stats
    final int shiftACount = isIncentive
        ? entries.where((e) =>
            (e.raw["SHIFT_ID"]?.toString().toUpperCase() ?? "") == "A").length
        : 0;
    final int shiftBCount = isIncentive
        ? entries.where((e) =>
            (e.raw["SHIFT_ID"]?.toString().toUpperCase() ?? "") == "B").length
        : 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: type.color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: type.color.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header strip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: type.color.withOpacity(0.07),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                border: Border(
                    bottom:
                        BorderSide(color: type.color.withOpacity(0.15))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: type.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(type.icon, color: type.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(type.label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: type.color)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: type.color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}",
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // Stats row
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  if (isKanban) ...[
                    _StatBox(
                      label: "Ready",
                      value: "$readyCount",
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 12),
                    _StatBox(
                      label: "Not Ready",
                      value: "$notReadyCount",
                      color: const Color(0xFFF59E0B),
                    ),
                  ] else if (isIncentive) ...[
                    _StatBox(
                      label: "Shift A",
                      value: "$shiftACount",
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 12),
                    _StatBox(
                      label: "Shift B",
                      value: "$shiftBCount",
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 12),
                    _StatBox(
                      label: "Total",
                      value: "${entries.length}",
                      color: type.color,
                    ),
                  ] else ...[
                    if (type.qtyKey != null) ...[
                      _StatBox(
                          label: "Total ${type.qtyLabel}",
                          value: "$totalQty",
                          color: type.color),
                      const SizedBox(width: 12),
                    ],
                    if (earliestStr.isNotEmpty) ...[
                      _StatBox(
                          label: "First",
                          value: earliestStr,
                          color: const Color(0xFF64748B)),
                      const SizedBox(width: 12),
                      _StatBox(
                          label: "Last",
                          value: latestStr,
                          color: const Color(0xFF64748B)),
                    ],
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Text("View details",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: type.color.withOpacity(0.7))),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14,
                          color: type.color.withOpacity(0.7)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color.withOpacity(0.6))),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color)),
      ],
    );
  }
}

// =====================================================================
// INCENTIVE DETAIL SHEET  –  Serial / Line Name / Staff ID & Name / Shift
// =====================================================================
class _IncentiveDetailSheet extends StatefulWidget {
  final List<_LogEntry> entries;
  const _IncentiveDetailSheet({required this.entries});

  @override
  State<_IncentiveDetailSheet> createState() => _IncentiveDetailSheetState();
}

class _IncentiveDetailSheetState extends State<_IncentiveDetailSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  static const Color _accentColor = Color(0xFFF97316);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_LogEntry> get _filtered {
    if (_searchQuery.isEmpty) return widget.entries;
    final q = _searchQuery.toLowerCase();
    return widget.entries
        .where((e) => e.raw.values
            .any((v) => v?.toString().toLowerCase().contains(q) == true))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle ──────────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),

          // ── Title row ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: _accentColor, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Incentive",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A))),
                    Text(
                      _searchQuery.isNotEmpty
                          ? "${filtered.length} of ${widget.entries.length} entries"
                          : "${widget.entries.length} ${widget.entries.length == 1 ? 'entry' : 'entries'}",
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Search ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: "Search by line, staff, shift...",
                  hintStyle:
                      TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 16, color: Colors.grey.shade400),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = "");
                          },
                          child: Icon(Icons.close_rounded,
                              size: 16, color: Colors.grey.shade400),
                        )
                      : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Column header ────────────────────────────────────────
          Container(
            color: const Color(0xFF1A73E8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: const Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text("#",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text("Line Name",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: Text("Staff ID – Name",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                SizedBox(width: 6),
                SizedBox(
                  width: 46,
                  child: Text("Shift",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                      textAlign: TextAlign.center),
                ),
              ],
            ),
          ),

          // ── List ────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 40, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No results for "$_searchQuery"'
                              : "No incentive entries",
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final entry = filtered[i];
                      final raw = entry.raw;
                      final isEven = i % 2 == 0;

                      final lineName =
                          raw["LINE_NAME"]?.toString() ?? "-";
                      final staffId =
                          raw["AEMP_ID"]?.toString() ??
                          raw["STAFF_ID"]?.toString() ?? "-";
                      final staffName =
                          raw["AEMP_NAME"]?.toString() ?? "-";
                      final shift =
                          raw["SHIFT_ID"]?.toString().toUpperCase() ?? "-";
                      final isShiftA = shift == "A";

                      return Container(
                        color: isEven
                            ? const Color(0xFFF8FAFC)
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Serial
                            SizedBox(
                              width: 28,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _accentColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "${i + 1}",
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: _accentColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Line Name
                            Expanded(
                              flex: 3,
                              child: Text(
                                lineName,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Staff ID – Name
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    staffId,
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade500,
                                        letterSpacing: 0.3),
                                  ),
                                  Text(
                                    staffName,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Shift badge
                            SizedBox(
                              width: 46,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isShiftA
                                        ? const Color(0xFF3B82F6)
                                            .withOpacity(0.12)
                                        : const Color(0xFFF59E0B)
                                            .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isShiftA
                                          ? const Color(0xFF3B82F6)
                                              .withOpacity(0.4)
                                          : const Color(0xFFF59E0B)
                                              .withOpacity(0.4),
                                    ),
                                  ),
                                  child: Text(
                                    shift,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isShiftA
                                            ? const Color(0xFF3B82F6)
                                            : const Color(0xFFF59E0B)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// GENERIC DETAIL BOTTOM SHEET
// =====================================================================
class _DetailSheet extends StatefulWidget {
  final _EntryType type;
  final List<_LogEntry> entries;
  const _DetailSheet({required this.type, required this.entries});

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_LogEntry> get _filtered {
    if (_searchQuery.isEmpty) return widget.entries;
    final q = _searchQuery.toLowerCase();
    return widget.entries
        .where((e) => e.raw.values
            .any((v) => v?.toString().toLowerCase().contains(q) == true))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final filtered = _filtered;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
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
                    color: type.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(type.icon, color: type.color, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A))),
                    Text(
                      _searchQuery.isNotEmpty
                          ? "${filtered.length} of ${widget.entries.length} entries"
                          : "${widget.entries.length} ${widget.entries.length == 1 ? 'entry' : 'entries'}",
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: "Search ${type.label} entries...",
                  hintStyle: TextStyle(
                      fontSize: 12, color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 16, color: Colors.grey.shade400),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = "");
                          },
                          child: Icon(Icons.close_rounded,
                              size: 16, color: Colors.grey.shade400),
                        )
                      : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey.shade200),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text("No results",
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade400)))
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _EntryRow(entry: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Entry row inside generic detail sheet ────────────────────────────
class _EntryRow extends StatelessWidget {
  final _LogEntry entry;
  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final type = entry.type;
    final bool isKanban = type.qryType == "KANBAN_REPORT";
    final timeStr = entry.dateTime != null
        ? DateFormat('hh:mm a').format(entry.dateTime!)
        : "";

    final String kanbanStatus =
        isKanban ? (entry.raw["LSH_LINE_STAT"]?.toString() ?? "") : "";
    final bool isReady = kanbanStatus.toLowerCase() == "ready";

    final chips = type.chipKeys
        .where((k) => !(isKanban && k == "LSH_LINE_STAT"))
        .map((k) => entry.raw[k]?.toString() ?? "")
        .where((v) => v.isNotEmpty)
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Column(
              children: [
                Text(timeStr,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: type.color),
                    textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text(
                  entry.isShiftA ? "Shift A" : "Shift B",
                  style:
                      TextStyle(fontSize: 9, color: Colors.grey.shade400),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          Container(
            width: 1, height: 42,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.grey.shade200,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(entry.title,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isKanban && kanbanStatus.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isReady
                              ? const Color(0xFF10B981).withOpacity(0.12)
                              : const Color(0xFFF59E0B).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isReady
                                ? const Color(0xFF10B981).withOpacity(0.4)
                                : const Color(0xFFF59E0B).withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          kanbanStatus,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isReady
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ...chips.map((c) => _Chip(text: c)),
                    if (!isKanban &&
                        entry.qty.isNotEmpty &&
                        entry.qty != "0" &&
                        entry.qty != "null")
                      _Chip(
                        text: "${type.qtyLabel}: ${entry.qty}",
                        color: type.color,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip ──────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String text;
  final Color? color;
  const _Chip({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: c.withOpacity(0.85))),
    );
  }
}