import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:trackall_app/pages/widgets/top_menu_bar.dart';
import '../services/lov_service.dart';

class KanbanBoardPage extends StatefulWidget {
  const KanbanBoardPage({super.key});

  @override
  State<KanbanBoardPage> createState() => _KanbanBoardPageState();
}

class _KanbanBoardPageState extends State<KanbanBoardPage> with TickerProviderStateMixin {
  final LovService _lovService = LovService();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _marqueeController = ScrollController();

  List<SOSLine> lines = [];
  List<Map<String, String>> unitList = [];
  List<Map<String, String>> selectedUnits = [];

  bool loading = true;
  bool _isPaused = false;

  // New Filter State
  String _statusFilter = 'All'; // 'All', 'Ready', 'Not Ready'

  Timer? _autoScrollTimer;
  Timer? _marqueeTimer;
  Timer? _refreshTimer;
  Timer? _clockTimer;
  String _currentTime = "";
  late AnimationController _pulseController;

  List<SOSLine> get filteredLines {
    // 1. Apply unit filter
    List<SOSLine> result = [];
    if (selectedUnits.isEmpty) {
      result = List.from(lines);
    } else {
      result = lines.where((line) {
        return selectedUnits.any((unit) => unit['id'] == line.unitId);
      }).toList();
    }

    // 2. Apply Status Tab Filter
    if (_statusFilter == 'Ready') {
      result = result.where((line) => line.status == 'Ready').toList();
    } else if (_statusFilter == 'Not Ready') {
      result = result.where((line) => line.status == 'Not Ready').toList();
    }

    // 3. Sort: "Not Ready" cards move to the top
    result.sort((a, b) {
      bool isANotReady = a.status == 'Not Ready';
      bool isBNotReady = b.status == 'Not Ready';
      if (isANotReady && !isBNotReady) return -1;
      if (!isANotReady && isBNotReady) return 1;
      return 0;
    });

    return result;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _updateClock();
    _loadInitialData();
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _refreshLinesFromBackend());
    _clockTimer = Timer.periodic(
        const Duration(seconds: 1), (_) => _updateClock());
    _startAutoScroll();
    _startMarquee();
  }

  void _updateClock() {
    if (mounted) {
      setState(() {
        _currentTime =
            DateFormat('dd MMM yyyy|hh:mm:ss a').format(DateTime.now());
      });
    }
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? "1";
    try {
      final units =
          await _lovService.fetchLov(qryType: "BUILDING", appUserId: userId);
      final result = await _lovService.fetchSosLines(appUserId: userId);

      final List<SOSLine> loaded = [];
      for (final e
          in result.where((e) => e['LINE_PRE_STAT']?.toString() == 'Y')) {
        String? finalUnitId = e['DW_LOC_ID']?.toString();
        String lineName =
            (e['LINE_NAME']?.toString() ?? 'Unknown').toUpperCase();

        if (finalUnitId == null ||
            finalUnitId.isEmpty ||
            finalUnitId == "null") {
          RegExp unitPattern = RegExp(r'U(\d+[A-Z]?)');
          final match = unitPattern.firstMatch(lineName);
          if (match != null) {
            String unitCode = match.group(1)!;
            final matchedUnit = units.firstWhere(
              (u) {
                String label = u['label']?.toString().toUpperCase() ?? '';
                return label
                    .replaceAll(' ', '')
                    .contains(unitCode.toUpperCase());
              },
              orElse: () => {},
            );
            if (matchedUnit.isNotEmpty)
              finalUnitId = matchedUnit['id']?.toString();
          }
        }

        loaded.add(SOSLine(
          id: e['LINE_ID'].toString(),
          unitId: finalUnitId,
          name: lineName,
          initialStatus: e['LINE_STAT']?.toString() ?? 'Ready',
          staffId: e['STAFF_ID']?.toString() ?? 'N/A',
          lastComment: e['LSH_CMNT']?.toString() ?? '',
          lastNotReadyElapsed:
              _parseDowntime(e['DOWNTIME']?.toString()),
          serverNow: _parseDbDate(e['SYSDATE']?.toString()),
          backendNotReadyStart: _parseDbDate(e['LSH_DATE']?.toString()),
          refreshParent: () => setState(() {}),
        ));
      }

      setState(() {
        unitList = units;
        lines = loaded;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> _refreshLinesFromBackend() async {
    if (loading) return;
    final userId =
        (await SharedPreferences.getInstance()).getString('userId') ?? "1";
    try {
      final result = await _lovService.fetchSosLines(appUserId: userId);
      for (var line in lines) {
        final match = result.firstWhere(
            (e) => e['LINE_ID'].toString() == line.id,
            orElse: () => {});
        if (match.isNotEmpty) {
          line.updateStatusFromBackend(
            match['LINE_STAT']?.toString() ?? 'Ready',
            _parseDbDate(match['LSH_DATE']?.toString()),
            match['STAFF_ID']?.toString() ?? 'N/A',
            _parseDbDate(match['SYSDATE']?.toString()),
            match['LSH_CMNT']?.toString() ?? '',
            _parseDowntime(match['DOWNTIME']?.toString()),
          );
        }
      }
      setState(() {});
    } catch (e) {
      debugPrint("Refresh Error: $e");
    }
  }

  // --- UI Helpers ---

  Widget _buildStatusTab(String label, Color activeColor) {
    bool isActive = _statusFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? activeColor : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: activeColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  // Marquee and Auto-scroll methods
  void _startMarquee() {
    _marqueeTimer =
        Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!_marqueeController.hasClients) return;
      double maxExtent = _marqueeController.position.maxScrollExtent;
      double currentOffset = _marqueeController.offset;
      _marqueeController
          .jumpTo(currentOffset >= maxExtent ? 0 : currentOffset + 1);
    });
  }

  void _startAutoScroll() {
    // FIX: Increased interval to 100ms and larger step to reduce UI thread pressure on mobile
    _autoScrollTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_scrollController.hasClients ||
          _isPaused ||
          filteredLines.isEmpty) return;
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) return;
      final current = _scrollController.offset;
      _scrollController
          .jumpTo(current >= max ? 0 : current + 1.5);
    });
  }

  void _handleScrollStart() {
    setState(() => _isPaused = true);
  }

  void _handleScrollEnd() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isPaused = false);
    });
  }

  void _showCommentPopup(SOSLine line) {
    final Color primaryColor = line.gradientColors[0];
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(line.statusIcon, color: Colors.white, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("DOWNTIME INFORMATION",
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2)),
                          Text(line.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("REPORTED COMMENT / REASON",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                            left: BorderSide(
                                color: primaryColor, width: 5)),
                      ),
                      child: Text(
                        line.lastComment.isEmpty
                            ? "No specific reason provided for this downtime."
                            : line.lastComment,
                        style: TextStyle(
                          fontSize: 18,
                          color: primaryColor.withOpacity(0.9),
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text("By: ${line.staffId}",
                                style: const TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.history,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text("Duration: ${line.timeText}",
                                style: const TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("DISMISS",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoDataView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text("No lines found for selected units",
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSubHeader() {
    List<String> timeParts = _currentTime.split('|');
    String datePart = timeParts[0];
    String clockPart = timeParts.length > 1 ? timeParts[1] : "";

    return Container(
      height: 45,
      width: double.infinity,
      color: const Color(0xFF0F172A),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 16),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  datePart,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  clockPart,
                  style: const TextStyle(
                    color: Colors.cyan,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(
              color: Colors.white24, indent: 8, endIndent: 8),
          Expanded(
            child: ListView(
              controller: _marqueeController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "🚀 Welcome to TrackAll Kanban Dashboard | Real-time monitoring enabled",
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadInitialData,
            icon:
                const Icon(Icons.refresh, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.filter_alt, size: 14, color: Colors.white),
                SizedBox(width: 5),
                Text("Filter",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Colors.white,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _showMultiSelectDialog(),
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                      color: Colors.grey.shade300, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: selectedUnits.isEmpty
                          ? const Text(
                              "Select production units...",
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children:
                                    selectedUnits.map((unit) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(right: 5),
                                    child: Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.blue.shade500,
                                            Colors.blue.shade700
                                          ],
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blue
                                                .withOpacity(0.3),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            unit['label']!,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          GestureDetector(
                                            onTap: () => setState(() =>
                                                selectedUnits
                                                    .remove(unit)),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.all(
                                                      1.5),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                  Icons.close,
                                                  size: 9,
                                                  color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_drop_down,
                        color: Colors.grey.shade600, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMultiSelectDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade600,
                        Colors.blue.shade800
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.filter_alt,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Select Production Units",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: unitList.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (ct, i) {
                      final isSelected = selectedUnits
                          .any((u) => u['id'] == unitList[i]['id']);
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                selectedUnits.removeWhere((u) =>
                                    u['id'] == unitList[i]['id']);
                              } else {
                                selectedUnits.add(unitList[i]);
                              }
                            });
                            setS(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.shade50
                                  : Colors.transparent,
                              border: isSelected
                                  ? Border(
                                      left: BorderSide(
                                          color: Colors.blue.shade600,
                                          width: 3))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue.shade600
                                        : Colors.white,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blue.shade600
                                          : Colors.grey.shade400,
                                      width: 2,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 14)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    unitList[i]['label']!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.blue.shade900
                                          : Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${selectedUnits.length} selected",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Row(
                        children: [
                          if (selectedUnits.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(
                                    () => selectedUnits.clear());
                                setS(() {});
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade600,
                              ),
                              child: const Text("Clear All",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(8)),
                            ),
                            child: const Text("Apply",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
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

  DateTime? _parseDbDate(String? val) =>
      (val == null || val.isEmpty)
          ? null
          : DateTime.parse(val.replaceAll('Z', ''));

  Duration? _parseDowntime(String? d) {
    if (d == null || d.isEmpty) return null;
    final parts = d.split(':');
    if (parts.length != 3) return null;
    return Duration(
        hours: int.parse(parts[0]),
        minutes: int.parse(parts[1]),
        seconds: int.parse(parts[2]));
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _marqueeTimer?.cancel();
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    _pulseController.dispose();
    _scrollController.dispose();
    _marqueeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDCDFE2),
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: TopMenuBar(),
      ),
      body: Column(
        children: [
          Container(height: 1, color: Colors.black.withOpacity(0.15)),
          _buildSubHeader(),
          Container(height: 1, color: Colors.black.withOpacity(0.1)),
          _buildFilterBar(),

          // Status Tabs Row
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _buildStatusTab(
                    'All', const Color(0xFF64748B)),
                const SizedBox(width: 8),
                _buildStatusTab('Ready', Colors.green.shade600),
                const SizedBox(width: 8),
                _buildStatusTab(
                    'Not Ready', Colors.red.shade600),
                const Spacer(),
                Text(
                  "${filteredLines.length} Lines",
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : filteredLines.isEmpty
                    ? _buildNoDataView()
                    : MouseRegion(
                        onEnter: (_) => _handleScrollStart(),
                        onExit: (_) => _handleScrollEnd(),
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification
                                is UserScrollNotification) {
                              if (notification.direction ==
                                  ScrollDirection.idle) {
                                _handleScrollEnd();
                              } else {
                                _handleScrollStart();
                              }
                            }
                            return false;
                          },
                          child: GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            // FIX 1: BouncingScrollPhysics for smoother native mobile feel
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            // FIX 2: Pre-render cards outside viewport to reduce jank
                            cacheExtent: 800,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: filteredLines.length,
                            // FIX 3: RepaintBoundary isolates each card's repaint layer
                            itemBuilder: (_, i) => RepaintBoundary(
                              child: _SOSCard(
                                line: filteredLines[i],
                                pulseAnimation: _pulseController,
                                onTap: filteredLines[i].status ==
                                        "Ready"
                                    ? null
                                    : () => _showCommentPopup(
                                        filteredLines[i]),
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

class SOSLine {
  final String id;
  final String? unitId;
  final String name;
  String status;
  String staffId;
  String lastComment;
  DateTime? backendNotReadyStart;
  DateTime? serverNow;
  Duration elapsed = Duration.zero;
  Duration lastNotReadyElapsed = Duration.zero;
  Timer? _timer;
  final VoidCallback? refreshParent;

  SOSLine({
    required this.id,
    this.unitId,
    required this.name,
    required String initialStatus,
    this.staffId = 'N/A',
    this.lastComment = '',
    Duration? lastNotReadyElapsed,
    this.serverNow,
    this.backendNotReadyStart,
    this.refreshParent,
  })  : status = initialStatus,
        lastNotReadyElapsed = lastNotReadyElapsed ?? Duration.zero {
    if (status == "Not Ready") _startTimer();
  }

  void updateStatusFromBackend(String val, DateTime? start, String sId,
      DateTime? sNow, String cmnt, Duration? lastDowntime) {
    status = val;
    staffId = sId;
    lastComment = cmnt;
    serverNow = sNow;
    if (lastDowntime != null) lastNotReadyElapsed = lastDowntime;
    if (status == "Not Ready") {
      backendNotReadyStart ??= start;
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _calculate();
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => _calculate());
  }

  void _calculate() {
    if (backendNotReadyStart != null) {
      final newElapsed =
          (serverNow ?? DateTime.now()).difference(backendNotReadyStart!);
      final clamped =
          newElapsed.isNegative ? Duration.zero : newElapsed;
      // FIX 4: Only trigger setState if the displayed second actually changed
      // — avoids redundant rebuilds every tick when second hasn't flipped
      if (clamped.inSeconds != elapsed.inSeconds) {
        elapsed = clamped;
        refreshParent?.call();
      }
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    elapsed = Duration.zero;
    backendNotReadyStart = null;
  }

  String get timeText => _fmt(elapsed);
  String get lastTimeText => _fmt(lastNotReadyElapsed);
  String _fmt(Duration d) =>
      "${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";

  List<Color> get gradientColors {
    if (status == "Ready")
      return [const Color(0xFF10B981), const Color(0xFF059669)];
    if (elapsed.inMinutes >= 5)
      return [const Color(0xFFEF4444), const Color(0xFFDC2626)];
    return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
  }

  IconData get statusIcon => status == "Ready"
      ? Icons.check_circle_rounded
      : (elapsed.inMinutes >= 5
          ? Icons.error_rounded
          : Icons.warning_rounded);
}

class _SOSCard extends StatelessWidget {
  final SOSLine line;
  final VoidCallback? onTap;
  final AnimationController pulseAnimation;

  const _SOSCard(
      {required this.line,
      this.onTap,
      required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    final bool isNotReady = line.status == "Not Ready";
    final bool isCritical = isNotReady && line.elapsed.inMinutes >= 5;

    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: line.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: line.gradientColors[0].withOpacity(0.3),
                  blurRadius: isNotReady ? 10 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                if (isCritical)
                  // FIX 5: RepaintBoundary on the pulse animation so it doesn't
                  // dirty the parent card layer on every animation tick
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: pulseAnimation,
                        builder: (context, _) => Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(
                                    0.25 * pulseAnimation.value),
                                blurRadius:
                                    15 + (5 * pulseAnimation.value),
                                spreadRadius:
                                    1.5 * pulseAnimation.value,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(line.statusIcon,
                              color: Colors.white, size: 14),
                          const Spacer(),
                          if (isNotReady)
                            const Icon(Icons.timer,
                                color: Colors.white, size: 12),
                        ],
                      ),
                      SizedBox(height: h * 0.04),
                      Text(
                        line.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: h * 0.065,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isNotReady
                              ? Colors.orange.withOpacity(0.8)
                              : Colors.green.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            line.status.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: h * 0.03),
                      Text(
                        isNotReady
                            ? line.timeText
                            : line.lastTimeText,
                        style: TextStyle(
                          fontSize: h * 0.075,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                      ),
                      SizedBox(height: h * 0.02),
                      Row(
                        children: [
                          const Icon(Icons.person,
                              color: Colors.white70, size: 10),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              line.staffId,
                              style: TextStyle(
                                  fontSize: h * 0.045,
                                  color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}