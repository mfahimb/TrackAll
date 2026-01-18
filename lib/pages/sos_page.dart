import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/lov_service.dart';

class SOSPage extends StatefulWidget {
  const SOSPage({super.key});

  @override
  State<SOSPage> createState() => _SOSPageState();
}

class _SOSPageState extends State<SOSPage> with SingleTickerProviderStateMixin {
  final LovService _lovService = LovService();
  List<SOSLine> lines = [];
  bool loading = true;
  Timer? _refreshTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _loadSOSLines();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshLinesFromBackend();
    });
  }

  Future<void> _saveLineNotReady(String lineId, DateTime start) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nr_$lineId', start.toIso8601String());
  }

  Future<void> _removeLineNotReady(String lineId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nr_$lineId');
  }

  Future<DateTime?> _loadLineNotReady(String lineId) async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString('nr_$lineId');
    if (val == null) return null;
    return DateTime.tryParse(val);
  }

  DateTime? parseDatabaseDate(String? dbValue) {
    if (dbValue == null || dbValue.isEmpty) return null;
    try {
      final localTimeStr = dbValue.replaceAll('Z', '');
      return DateTime.parse(localTimeStr);
    } catch (e) {
      return null;
    }
  }

  DateTime? parseServerDate(String? dbValue) {
    if (dbValue == null || dbValue.isEmpty) return null;
    try {
      return DateTime.parse(dbValue.replaceAll('Z', ''));
    } catch (_) {
      return null;
    }
  }

  // 🔑 NEW: Parse HH:MM:SS format from backend
  Duration? parseDowntime(String? downtime) {
    if (downtime == null || downtime.isEmpty) return null;
    
    try {
      // Parse "00:00:15" format
      final parts = downtime.split(':');
      if (parts.length != 3) return null;
      
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      final seconds = int.tryParse(parts[2]) ?? 0;
      
      final duration = Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
      );
      
      if (duration.inSeconds <= 0) return null;
      
      print("✅ Parsed downtime '$downtime' = ${duration.inSeconds} seconds");
      return duration;
    } catch (e) {
      print("❌ Error parsing downtime '$downtime': $e");
      return null;
    }
  }

  // ---------------- LOAD LINES ----------------
  Future<void> _loadSOSLines() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? "1";

    try {
      final result = await _lovService.fetchSosLines(appUserId: userId);

      // 🔍 DEBUG: Print raw backend response
      print("=== BACKEND RESPONSE ===");
      for (var e in result) {
        print("Line ${e['LINE_ID']}: Status=${e['LINE_STAT']}, DOWNTIME=${e['DOWNTIME']}");
      }

      final List<SOSLine> loadedLines = [];
      for (final e in result.where((e) => e['LINE_PRE_STAT']?.toString() == 'Y')) {
        DateTime? backendNotReadyStart = parseDatabaseDate(e['LSH_DATE']?.toString());
        final savedStart = await _loadLineNotReady(e['LINE_ID'].toString());
        
        if (savedStart != null) {
          backendNotReadyStart = savedStart;
        }

        // 🔑 Parse DOWNTIME in HH:MM:SS format from backend
        final lastNRDuration = parseDowntime(e['DOWNTIME']?.toString());
        
        // 🔍 DEBUG: Check what we parsed
        print("Line ${e['LINE_ID']}: Parsed duration = ${lastNRDuration?.inSeconds} seconds");

        loadedLines.add(SOSLine(
          id: e['LINE_ID'].toString(),
          name: (e['LINE_NAME'] ?? 'Unknown').toString(),
          initialStatus: e['LINE_STAT']?.toString() ?? 'Ready',
          backendNotReadyStart: backendNotReadyStart,
          serverNow: parseServerDate(e['SYSDATE']?.toString()),
          staffId: e['STAFF_ID']?.toString() ?? 'N/A',
          lastComment: e['LSH_CMNT']?.toString() ?? '',
          lastNotReadyElapsed: lastNRDuration,
          refreshParent: () => setState(() {}),
        ));
      }

      setState(() {
        lines = loadedLines;
        loading = false;
      });
    } catch (e) {
      print("ERROR loading lines: $e");
      setState(() => loading = false);
    }
  }

  // ---------------- REFRESH LINES ----------------
  Future<void> _refreshLinesFromBackend() async {
    if (lines.isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? "1";

    try {
      final result = await _lovService.fetchSosLines(appUserId: userId);

      for (final e in result) {
        final index = lines.indexWhere((l) => l.id == e['LINE_ID'].toString());
        if (index == -1) continue;

        // 🔑 Parse DOWNTIME from backend
        final lastNRDuration = parseDowntime(e['DOWNTIME']?.toString());

        lines[index].updateStatusFromBackend(
          e['LINE_STAT']?.toString() ?? 'Ready',
          parseDatabaseDate(e['LSH_DATE']?.toString()),
          e['STAFF_ID']?.toString() ?? 'N/A',
          parseServerDate(e['SYSDATE']?.toString()),
          e['LSH_CMNT']?.toString() ?? '',
          lastNRDuration,
        );
      }

      setState(() {});
    } catch (e) {
      print("ERROR refreshing: $e");
    }
  }

  @override
  void dispose() {
    for (final l in lines) l.dispose();
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ---------------- STATUS DIALOG ----------------
  Future<void> _showStatusDialog(SOSLine line) async {
    String selectedStatus = line.status;
    TextEditingController commentController = TextEditingController(text: line.lastComment);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Status',
      transitionDuration: const Duration(milliseconds: 300),
      barrierColor: Colors.black.withOpacity(0.6),
      pageBuilder: (_, animation, __) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: StatefulBuilder(builder: (context, setDialogState) {
                  return Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.factory, size: 32, color: Colors.blue.shade700),
                        ),
                        const SizedBox(height: 16),
                        Text(line.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            )),
                        const SizedBox(height: 8),
                        Text('Update Line Status',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: ["Ready", "Not Ready"].map((s) {
                            bool isSelected = selectedStatus == s;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(() => selectedStatus = s),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: EdgeInsets.only(
                                      left: s == "Ready" ? 0 : 6, right: s == "Ready" ? 6 : 0),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                            colors: s == "Ready"
                                                ? [Color(0xFF10B981), Color(0xFF059669)]
                                                : [Color(0xFFF59E0B), Color(0xFFD97706)],
                                          )
                                        : null,
                                    color: isSelected ? null : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? Colors.transparent : Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    s,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: commentController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: "Add a comment...",
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12))),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  final userId = prefs.getString('userId') ?? "1";
                                  final companyId = prefs.getString('selected_company_id') ?? "55";

                                  line.setStatus(selectedStatus, () => setState(() {}));
                                  line.lastComment = commentController.text;

                                  Navigator.pop(context);

                                  try {
                                    bool success = await _lovService.saveSosLine(
                                      action: "I",
                                      appUser: userId,
                                      lineComment: commentController.text,
                                      lineStatus: selectedStatus,
                                      lineId: line.id,
                                      company: companyId,
                                    );

                                    if (success) {
                                      print("✅ Status saved to backend");
                                      // Refresh to get updated DOWNTIME from backend
                                      await _loadSOSLines();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Failed to update line on server')),
                                      );
                                    }
                                  } catch (e) {
                                    print("❌ Error saving: $e");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text(
                                  'Confirm',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 220, 222, 226),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.factory, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              "LINE STATUS",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadSOSLines,
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      body: loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading lines...',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.72,
              ),
              itemCount: lines.length,
              itemBuilder: (_, i) => _SOSCard(
                line: lines[i],
                onTap: () => _showStatusDialog(lines[i]),
                pulseAnimation: _pulseController,
              ),
            ),
    );
  }
}

// ================= MODEL =================
class SOSLine {
  final String id;
  final String name;
  String status;
  DateTime? notReadyStart;
  DateTime? serverNow;
  Duration elapsed = Duration.zero;
  Duration lastNotReadyElapsed = Duration.zero;
  String staffId;
  String lastComment;
  Timer? _timer;
  final VoidCallback? refreshParent;

  Future<void> _saveLineNotReady(String lineId, DateTime start) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nr_$lineId', start.toIso8601String());
  }

  Future<void> _removeLineNotReady(String lineId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nr_$lineId');
  }

  void setStatus(String value, VoidCallback refresh) {
    status = value;
    if (status == "Not Ready") {
      notReadyStart ??= DateTime.now();
      _startTimer();
      _saveLineNotReady(id, notReadyStart!);
    } else {
      _stopTimer();
      _removeLineNotReady(id);
    }
    refresh();
  }

  SOSLine({
    required this.id,
    required this.name,
    required String initialStatus,
    this.lastComment = '',
    DateTime? backendNotReadyStart,
    this.serverNow,
    this.staffId = 'N/A',
    Duration? lastNotReadyElapsed,
    this.refreshParent,
  }) : status = initialStatus {
    // Set last NR duration from backend
    if (lastNotReadyElapsed != null) {
      this.lastNotReadyElapsed = lastNotReadyElapsed;
      print("✅ Line $id: Set lastNRElapsed = ${lastNotReadyElapsed.inSeconds}s from backend");
    }

    if (status == "Not Ready" && backendNotReadyStart != null) {
      notReadyStart = backendNotReadyStart;
      _startTimer();
    }
  }

  void updateStatusFromBackend(
    String value,
    DateTime? backendStart,
    String sId,
    DateTime? serverTime, [
    String comment = '',
    Duration? backendLastNRDuration,
  ]) {
    final oldStatus = status;
    status = value;
    staffId = sId;

    if (serverTime != null) {
      serverNow = serverTime;
    }

    if (comment.isNotEmpty) lastComment = comment;

    if (status == "Not Ready") {
      notReadyStart ??= backendStart;

      if (notReadyStart != null && serverNow != null) {
        elapsed = serverNow!.difference(notReadyStart!);
        if (elapsed.isNegative) elapsed = Duration.zero;
      }

      _startTimer();
    } else {
      // Line is Ready - use backend DOWNTIME
      if (backendLastNRDuration != null) {
        lastNotReadyElapsed = backendLastNRDuration;
        print("✅ Line $id: Updated lastNRElapsed = ${backendLastNRDuration.inSeconds}s from backend");
      } else if (oldStatus == "Not Ready" && backendStart != null && serverNow != null) {
        // Fallback calculation if backend doesn't provide
        lastNotReadyElapsed = serverNow!.difference(backendStart);
        if (lastNotReadyElapsed.isNegative) lastNotReadyElapsed = Duration.zero;
        print("⚠️ Line $id: Calculated lastNRElapsed = ${lastNotReadyElapsed.inSeconds}s (backend didn't provide)");
      }
      
      _stopTimer();
    }

    refreshParent?.call();
  }

  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;
    if (notReadyStart == null) return;

    _calculateElapsed();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _calculateElapsed(),
    );
  }

  void _calculateElapsed() {
    if (notReadyStart != null) {
      final now = serverNow ?? DateTime.now();
      elapsed = now.difference(notReadyStart!);
      if (elapsed.isNegative) elapsed = Duration.zero;
      refreshParent?.call();
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    elapsed = Duration.zero;
    notReadyStart = null;
  }

  String get timeText {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(elapsed.inHours)}:${twoDigits(elapsed.inMinutes % 60)}:${twoDigits(elapsed.inSeconds % 60)}";
  }

  String get lastTimeText {
    final d = lastNotReadyElapsed;
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inHours)}:"
           "${twoDigits(d.inMinutes % 60)}:"
           "${twoDigits(d.inSeconds % 60)}";
  }

  List<Color> get gradientColors {
    if (status == "Ready") return [const Color(0xFF10B981), const Color(0xFF059669)];
    if (elapsed.inMinutes >= 5) return [const Color(0xFFEF4444), const Color(0xFFDC2626)];
    return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
  }

  IconData get statusIcon {
    if (status == "Ready") return Icons.check_circle_rounded;
    if (elapsed.inMinutes >= 5) return Icons.error_rounded;
    return Icons.warning_rounded;
  }

  void dispose() => _timer?.cancel();
}

// ================= COMPACT CARD UI =================
class _SOSCard extends StatelessWidget {
  final SOSLine line;
  final VoidCallback onTap;
  final AnimationController pulseAnimation;

  const _SOSCard({
    required this.line,
    required this.onTap,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNotReady = line.status == "Not Ready";
    final bool isCritical = line.elapsed.inMinutes >= 5;

    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final gapXS = h * 0.02;
          final gapS = h * 0.03;

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
                  spreadRadius: isNotReady ? 1 : 0,
                ),
              ],
            ),
            child: Stack(
              children: [
                if (isCritical)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.25 * pulseAnimation.value),
                                blurRadius: 15 + (5 * pulseAnimation.value),
                                spreadRadius: 1.5 * pulseAnimation.value,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(6),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(line.statusIcon, color: Colors.white, size: 14),
                          ),
                          const Spacer(),
                          if (isNotReady)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Icon(Icons.timer, color: Colors.white, size: 10),
                            ),
                        ],
                      ),

                      SizedBox(height: gapXS),

                      Text(
                        line.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: h * 0.065,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),

                      SizedBox(height: gapXS),

                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0),
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: gapS),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isNotReady
                              ? Colors.orange.withOpacity(0.85)
                              : Colors.green.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            line.status.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1,
                              shadows: [
                                Shadow(
                                  color: Colors.black38,
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: gapS),

                      if (isNotReady || line.lastNotReadyElapsed > Duration.zero)
                        Text(
                          isNotReady ? line.timeText : line.lastTimeText,
                          style: TextStyle(
                            fontSize: h * 0.075,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'monospace',
                            letterSpacing: 1,
                          ),
                        ),

                      SizedBox(height: gapXS),

                      if (isNotReady || line.lastNotReadyElapsed > Duration.zero)
                        Row(
                          children: [
                            Icon(Icons.person,
                                color: Colors.white.withOpacity(0.7), size: 10),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                line.staffId,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: h * 0.045,
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                      if (line.lastComment.isNotEmpty) ...[
                        SizedBox(height: gapXS),
                        Flexible(
                          child: Text(
                            line.lastComment,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: h * 0.042,
                              color: Colors.white.withOpacity(0.8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                    ),
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