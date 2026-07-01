import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/top_menu_bar.dart';
import 'package:trackall_app/services/line_balance_service.dart';

class TimeReportPage extends StatefulWidget {
  const TimeReportPage({super.key});

  @override
  State<TimeReportPage> createState() => _TimeReportPageState();
}

class _TimeReportPageState extends State<TimeReportPage> {
  final LineBalanceService _svc = LineBalanceService();

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _error;

  final TextEditingController _searchCtrl = TextEditingController();
  // Defaults to today on load — set to null to show all dates.
  DateTime? _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getString('selected_company_id') ?? '5';
      final data = await _svc.fetchTimeStudyReport(companyId: companyId);

      data.sort((a, b) {
        final idA = a['LB_ID'] as int? ?? 0;
        final idB = b['LB_ID'] as int? ?? 0;
        return idB.compareTo(idA);
      });

      if (!mounted) return;
      setState(() {
        _all = data;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to load report: $e";
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((row) {
        if (query.isNotEmpty) {
          final line = (row['LINE_NAME'] ?? '').toString().toLowerCase();
          final process = (row['PROCRSS_NAME'] ?? '').toString().toLowerCase();
          final staff = (row['LB_STAFF_NAME'] ?? '').toString().toLowerCase();
          if (!line.contains(query) &&
              !process.contains(query) &&
              !staff.contains(query)) {
            return false;
          }
        }
        if (_selectedDate != null) {
          final raw = row['DATES']?.toString();
          if (raw == null) return false;
          final rowDate = DateTime.tryParse(raw);
          if (rowDate == null) return false;
          if (rowDate.year != _selectedDate!.year ||
              rowDate.month != _selectedDate!.month ||
              rowDate.day != _selectedDate!.day) {
            return false;
          }
        }
        return true;
      }).toList();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _applyFilters();
    }
  }

  void _clearDate() {
    setState(() => _selectedDate = null);
    _applyFilters();
  }

  bool get _isToday {
    if (_selectedDate == null) return false;
    final now = DateTime.now();
    return _selectedDate!.year == now.year &&
        _selectedDate!.month == now.month &&
        _selectedDate!.day == now.day;
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return "${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: Column(children: [
        const TopMenuBar(),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 12),
                    _buildFilters(),
                    const SizedBox(height: 6),
                    Expanded(child: _buildList()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1A73E8), Color(0xFF1557B0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(11),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.25))),
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text("Time Study Report",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.2)),
        ),
        GestureDetector(
          onTap: _load,
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(11),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.25))),
            child: const Icon(Icons.refresh_rounded,
                color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }

  Widget _buildFilters() {
    return Row(children: [
      Expanded(
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: "Search...",
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: () => _searchCtrl.clear(),
                child: Icon(Icons.close_rounded,
                    color: Colors.grey.shade400, size: 16),
              ),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _pickDate,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_rounded,
                color: Colors.grey.shade500, size: 15),
            const SizedBox(width: 6),
            Text(
              _selectedDate != null
                  ? (_isToday ? "Today" : _formatDate(_selectedDate!))
                  : "Date",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _selectedDate != null
                      ? Colors.black87
                      : Colors.grey.shade400),
            ),
            if (_selectedDate != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _clearDate,
                child: Icon(Icons.close_rounded,
                    color: Colors.grey.shade400, size: 15),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1A73E8)));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.red.shade300, size: 36),
          const SizedBox(height: 10),
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ]),
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_rounded, color: Colors.grey.shade300, size: 40),
          const SizedBox(height: 10),
          Text("No entries found",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade400)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF1A73E8),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _ReportRow(row: _filtered[i]),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final Map<String, dynamic> row;
  const _ReportRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final lineName = row['LINE_NAME']?.toString() ?? '—';
    final processName = row['PROCRSS_NAME']?.toString() ?? '—';
    final staffName = row['LB_STAFF_NAME']?.toString() ?? '—';
    final shift = row['LB_SHIFT']?.toString() ?? '—';
    final time = row['LB_TIME'];
    final benchmark = row['LB_BENCH_MARK'];

    // Determine status: null = neutral, true = over benchmark, false = within.
    bool? isOver;
    Color timeColor = Colors.grey.shade700;
    if (benchmark != null) {
      final timeVal = (time is num) ? time.toDouble() : 0;
      final benchVal = (benchmark is num) ? benchmark.toDouble() : 0;
      isOver = timeVal > benchVal;
      timeColor = isOver ? const Color(0xFFEF4444) : const Color(0xFF0F9D58);
    }

    // Very faint full-card tint based on status.
    final Color cardBg = isOver == null
        ? Colors.white
        : isOver
            ? const Color(0xFFFFF1F1) // very light red
            : const Color(0xFFF0FBF4); // very light green
    final Color cardBorder = isOver == null
        ? Colors.grey.shade200
        : isOver
            ? const Color(0xFFFFD9D9)
            : const Color(0xFFCFEFDB);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(staffName,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.black87),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text("$lineName  |  $processName",
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 7),
        Row(children: [
          _ValueChip(
            icon: Icons.schedule_rounded,
            label: shift,
            bg: const Color(0xFFEDE9FE),
            fg: const Color(0xFF7C3AED),
          ),
          const SizedBox(width: 6),
          _ValueChip(
            icon: Icons.timer_outlined,
            label: time != null ? "Time: ${time}s" : "Time: —",
            bg: timeColor.withValues(alpha: 0.12),
            fg: timeColor,
          ),
          if (benchmark != null) ...[
            const SizedBox(width: 6),
            _ValueChip(
              icon: Icons.flag_rounded,
              label: "BM: ${benchmark}s",
              bg: const Color(0xFFDBEAFE),
              fg: const Color(0xFF1D4ED8),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _ValueChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  const _ValueChip(
      {required this.icon,
      required this.label,
      required this.bg,
      required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
      ]),
    );
  }
}
