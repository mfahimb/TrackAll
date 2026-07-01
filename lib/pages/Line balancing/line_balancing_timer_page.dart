import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/top_menu_bar.dart';
import 'package:trackall_app/services/line_balance_service.dart';
import 'package:trackall_app/services/line_staff_service.dart';
import 'package:trackall_app/services/process_smv_service.dart';
import '../Line balancing/time_report.dart';

enum _ScanTarget { none, line, staff }

class LineBalancingTimerPage extends StatefulWidget {
  final String lineId;
  final String lineName;
  final String processId;
  final String processLabel;
  final String staffId;
  final String staffName;
  final String appUserId;
  final int? benchmarkTime;

  const LineBalancingTimerPage({
    super.key,
    required this.lineId,
    required this.lineName,
    required this.processId,
    required this.processLabel,
    required this.staffId,
    required this.staffName,
    required this.appUserId,
    this.benchmarkTime,
  });

  @override
  State<LineBalancingTimerPage> createState() =>
      _LineBalancingTimerPageState();
}

class _LineBalancingTimerPageState extends State<LineBalancingTimerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final LineBalanceService _lineBalanceSvc = LineBalanceService();
  final LineStaffService _lineStaffSvc = LineStaffService();
  final ProcessSmvService _processSvc = ProcessSmvService();
  String _companyId = '5';

  // ── Current line / process / staff — all editable in place ──────────
  late String _lineId = widget.lineId;
  late String _lineName = widget.lineName;
  late String _processId = widget.processId;
  late String _processLabel = widget.processLabel;
  late int? _benchmarkTime = widget.benchmarkTime;
  late String _staffId = widget.staffId;
  late String _staffName = widget.staffName;

  List<Map<String, String>> _processList = [];
  bool _loadingProcessList = false;

  // ── Date — fixed to today, no picker ───────────────────────────────
  final DateTime _today = DateTime.now();

  // ── Shift — auto-computed from current time, read-only ─────────────
  String get _shift {
    final hour = DateTime.now().hour;
    return (hour >= 8 && hour < 20) ? 'A' : 'B';
  }

  // ── Stopwatch ────────────────────────────────────────────────────
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool get _isRunning => _stopwatch.isRunning;

  bool _isSaving = false;

  // ── Inline scanner state ────────────────────────────────────────────
  _ScanTarget _scanTarget = _ScanTarget.none;
  bool _scanBusy = false;
  final Set<String> _sessionCodes = {};
  MobileScannerController? _ctrl;
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCompanyId();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.87, end: 1.0).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _stopwatch.stop();
    _ctrl?.dispose();
    _ctrl = null;
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _ctrl?.stop();
    }
  }

  Future<void> _loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    _companyId = prefs.getString('selected_company_id') ?? '5';
  }

  String get _formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${_today.day.toString().padLeft(2, '0')} "
        "${months[_today.month - 1]} ${_today.year}";
  }

  // ── Stopwatch controls ─────────────────────────────────────────────

  void _startStopwatch() {
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _elapsed = _stopwatch.elapsed);
    });
    setState(() {});
  }

  void _stopStopwatch() {
    _stopwatch.stop();
    _ticker?.cancel();
    setState(() => _elapsed = _stopwatch.elapsed);
    _showSaveConfirm();
  }

  void _resetStopwatch() {
    _stopwatch.stop();
    _stopwatch.reset();
    _ticker?.cancel();
    setState(() => _elapsed = Duration.zero);
  }

  String get _formattedElapsed {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final cs =
        ((_elapsed.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
    return "$h:$m:$s.$cs";
  }

  // ── Inline scanner controls ─────────────────────────────────────────

  MobileScannerController _freshController() {
    _ctrl?.dispose();
    _ctrl = null;
    _ctrl = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
      formats: [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ],
    );
    return _ctrl!;
  }

  void _openLineScanner() {
    _scanBusy = false;
    _sessionCodes.clear();
    _freshController();
    setState(() => _scanTarget = _ScanTarget.line);
  }

  void _openStaffScanner() {
    _scanBusy = false;
    _sessionCodes.clear();
    _freshController();
    setState(() => _scanTarget = _ScanTarget.staff);
  }

  Future<void> _closeScanner() async {
    await _ctrl?.stop();
    _ctrl?.dispose();
    _ctrl = null;
    if (mounted) setState(() => _scanTarget = _ScanTarget.none);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanBusy) return;
    if (_scanTarget == _ScanTarget.none) return;

    String? code;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        code = v;
        break;
      }
    }
    if (code == null) return;
    if (_sessionCodes.contains(code)) return;
    _sessionCodes.add(code);

    _scanBusy = true;
    if (_scanTarget == _ScanTarget.line) {
      _handleLineRescan(code);
    } else {
      _handleStaffRescan(code);
    }
  }

  Future<void> _handleLineRescan(String qr) async {
    await _closeScanner();
    final lineId = qr.trim();
    if (lineId.isEmpty) {
      _showError("Invalid Line QR");
      _scanBusy = false;
      return;
    }

    final result = await _lineStaffSvc.fetchLineName(lineId);
    if (!mounted) {
      _scanBusy = false;
      return;
    }

    if (result == null) {
      _showError("Invalid Line QR: $qr");
      _scanBusy = false;
      return;
    }

    setState(() {
      _lineId = lineId;
      _lineName = result["LINE_NAME"] ?? "Unknown Line";
    });
    _resetStopwatch();
    _showSuccess("Line changed — timer reset");
    _scanBusy = false;
  }

  Future<void> _showSaveConfirm() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF1A73E8), Color(0xFF1557B0)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.save_rounded,
                      color: Color(0xFF1A73E8), size: 28),
                ),
                const SizedBox(height: 16),
                const Text("Save Entry?",
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                Text(
                  "Elapsed time: $_formattedElapsed\nDo you want to save this entry?",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.5),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Text("Cancel",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF1A73E8), Color(0xFF1557B0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF1A73E8)
                                    .withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text("Save",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );

    if (ok == true) {
      await _handleSave();
    }
    // if cancel — stopwatch stays paused at current elapsed, user can resume
  }

  Future<void> _handleStaffRescan(String rawBarcode) async {
    await _closeScanner();

    final credNo = rawBarcode.split(',').first.trim();
    final parts = rawBarcode.split(',');
    final embeddedName = parts.length > 1 ? parts[1].trim() : null;

    final staffResult = await _lineStaffSvc.fetchStaffByBarcode(credNo);
    if (!mounted) {
      _scanBusy = false;
      return;
    }

    String? name = staffResult?["STAFF_NAME"];
    String? staffId = staffResult?["STAFF_ID"];

    if (name == null && embeddedName != null && embeddedName.isNotEmpty) {
      name = embeddedName;
      staffId ??= credNo;
    }

    if (name == null || staffId == null) {
      _showError("Staff not found: $credNo");
      _scanBusy = false;
      return;
    }

    setState(() {
      _staffId = credNo;
      _staffName = name!;
    });
    _resetStopwatch();
    _showSuccess("Staff changed — timer reset");
    _scanBusy = false;
  }

  // ── Process change ───────────────────────────────────────────────

  Future<void> _openProcessPicker() async {
    if (_processList.isEmpty && !_loadingProcessList) {
      setState(() => _loadingProcessList = true);
      try {
        final list = await _processSvc.fetchProcessLov(companyId: _companyId);
        if (mounted) setState(() => _processList = list);
        if (list.isEmpty) {
          _showError("Process list could not be loaded");
        }
      } catch (e) {
        _showError("Failed to load process list: $e");
      } finally {
        if (mounted) setState(() => _loadingProcessList = false);
      }
    }
    if (!mounted) return;
    _showProcessPicker();
  }

  void _showProcessPicker() {
    List<Map<String, String>> filtered = List.from(_processList);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (c, setS) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Text("Select Process",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            const SizedBox(height: 12),
            Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                onChanged: (v) => setS(() {
                  filtered = _processList
                      .where((e) =>
                          e["label"]!.toLowerCase().contains(v.toLowerCase()))
                      .toList();
                }),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, color: Colors.black54),
                  hintText: "Search process...",
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text("No processes found",
                          style: TextStyle(fontSize: 14, color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        return ListTile(
                          title: Text(item["label"]!,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          onTap: () {
                            setState(() {
                              _processId = item["id"]!;
                              _processLabel = item["label"]!;
                            });
                            Navigator.pop(ctx);
                            _resetStopwatch();
                            _showSuccess("Process changed — timer reset");
                          },
                        );
                      },
                    ),
            ),
          ]),
        );
      }),
    );
  }

  void _showBenchmarkEdit() {
    final ctrl = TextEditingController(
        text: _benchmarkTime != null ? _benchmarkTime.toString() : '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text("Edit Benchmark Time",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 6),
          Text("Process: $_processLabel",
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(children: [
              const Icon(Icons.timer_outlined, color: Colors.grey, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: "Enter benchmark time (seconds)",
                    border: InputBorder.none,
                  ),
                ),
              ),
              const Text("sec",
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final val = int.tryParse(ctrl.text.trim());
                setState(() => _benchmarkTime = val);
                Navigator.pop(ctx);
                _showSuccess("Benchmark updated");
              },
              child: const Text("Update",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── Save ─────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    if (_elapsed == Duration.zero) {
      _showError("Please run the stopwatch before saving");
      return;
    }

    setState(() => _isSaving = true);
    try {
     final errorMsg = await _lineBalanceSvc.saveLineBalance(
  lineId: _lineId,
  staffId: _staffId,
  processId: _processId,
  date: _today,
  elapsedSeconds: _elapsed.inMilliseconds / 1000.0,
  appUserId: widget.appUserId,
  companyId: _companyId,
  benchmarkTime: _benchmarkTime,
);

      if (!mounted) return;

      if (errorMsg != null) {
        _showError(errorMsg);
        return;
      }

      _showSuccess("Saved successfully");
      _resetStopwatch();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final camVisible = _scanTarget != _ScanTarget.none;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: Column(children: [
        const TopMenuBar(),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
               child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TimeReportPage())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF1A73E8)
                                    .withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.list_alt_rounded,
                                  size: 16, color: Color(0xFF1A73E8)),
                              const SizedBox(width: 6),
                              const Text("View Lists",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A73E8))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildHeader(),
                    const SizedBox(height: 14),
                    if (camVisible && _ctrl != null) ...[
                      _Viewport(
                        controller: _ctrl!,
                        onDetect: _onDetect,
                        pulseAnim: _pulseAnim,
                        label: _scanTarget == _ScanTarget.line
                            ? "Point at Line QR Code"
                            : "Point at Staff ID / Barcode",
                        onCancel: _closeScanner,
                      ),
                      const SizedBox(height: 14),
                    ],
                    Row(children: [
                      Expanded(child: _buildDateField()),
                      const SizedBox(width: 10),
                      Expanded(child: _buildShiftField()),
                    ]),
                    const SizedBox(height: 20),
                    _buildStopwatch(),
                    const SizedBox(height: 20),
                    
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Header — Line / Process / Staff, each tappable to change ────────

  Widget _buildHeader() {
    final scanLocked = _scanTarget != _ScanTarget.none;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1A73E8), Color(0xFF1557B0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.25))),
            child: const Icon(Icons.timer_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text("Time Study",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.2)),
          ),
        ]),
        const SizedBox(height: 16),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
        const SizedBox(height: 14),
        _TappableChip(
          icon: Icons.view_timeline_rounded,
          label: "Line",
          value: _lineName,
          onTap: scanLocked ? null : _openLineScanner,
        ),
        const SizedBox(height: 8),
        _TappableChip(
          icon: Icons.tune_rounded,
          label: "Process",
          value: _processLabel,
          onTap: scanLocked ? null : _openProcessPicker,
        ),
        const SizedBox(height: 8),
        _TappableChip(
          icon: Icons.timer_outlined,
          label: "Benchmark",
          value: _benchmarkTime != null ? "$_benchmarkTime sec" : "—",
          onTap: scanLocked ? null : _showBenchmarkEdit,
        ),
        const SizedBox(height: 8),
        _TappableChip(
          icon: Icons.badge_rounded,
          label: "Staff",
          value: _staffName,
          onTap: scanLocked ? null : _openStaffScanner,
        ),
      ]),
    );
  }

  // ── Date field (fixed, read-only) ───────────────────────────────────

  Widget _buildDateField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Date",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black)),
          const SizedBox(height: 6),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_rounded,
                  color: Colors.grey.shade500, size: 17),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_formattedDate,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Shift field (fixed, read-only, auto-computed) ───────────────────

  Widget _buildShiftField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Shift",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black)),
          const SizedBox(height: 6),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(children: [
              Icon(Icons.schedule_rounded,
                  color: Colors.grey.shade500, size: 17),
              const SizedBox(width: 10),
              Expanded(
                child: Text("Shift $_shift",
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Stopwatch ──────────────────────────────────────────────────────

  Widget _buildStopwatch() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: [
        Text(_formattedElapsed,
            style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
                letterSpacing: 1.2,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StopwatchBtn(
              icon: _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              label: _isRunning ? "Stop" : "Start",
              colors: _isRunning
                  ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                  : [const Color(0xFF0F9D58), const Color(0xFF0B8043)],
              onTap: _isRunning ? _stopStopwatch : _startStopwatch,
            ),
            const SizedBox(width: 14),
            _StopwatchBtn(
              icon: Icons.refresh_rounded,
              label: "Reset",
              colors: [Colors.grey.shade400, Colors.grey.shade500],
              onTap: _resetStopwatch,
            ),
          ],
        ),
      ]),
    );
  }

  // ── Save button ──────────────────────────────────────────────────

  // Widget _buildSaveButton() {
  //   return GestureDetector(
  //     onTap: _isSaving ? null : _handleSave,
  //     child: Container(
  //       padding: const EdgeInsets.symmetric(vertical: 16),
  //       decoration: BoxDecoration(
  //         gradient: LinearGradient(
  //           colors: _isSaving
  //               ? [Colors.grey.shade400, Colors.grey.shade500]
  //               : [const Color(0xFF1A73E8), const Color(0xFF1557B0)],
  //           begin: Alignment.topLeft,
  //           end: Alignment.bottomRight,
  //         ),
  //         borderRadius: BorderRadius.circular(16),
  //         boxShadow: _isSaving
  //             ? []
  //             : [
  //                 BoxShadow(
  //                     color: const Color(0xFF1A73E8).withValues(alpha: 0.40),
  //                     blurRadius: 14,
  //                     offset: const Offset(0, 5))
  //               ],
  //       ),
  //       child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
  //         if (_isSaving)
  //           const SizedBox(
  //             width: 18,
  //             height: 18,
  //             child:
  //                 CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  //           )
  //         else
  //           const Icon(Icons.save_rounded, color: Colors.white, size: 20),
  //         const SizedBox(width: 10),
  //         Text(_isSaving ? "SAVING..." : "SAVE",
  //             style: const TextStyle(
  //                 color: Colors.white,
  //                 fontSize: 14,
  //                 fontWeight: FontWeight.w900,
  //                 letterSpacing: 1)),
  //       ]),
  //     ),
  //   );
  // }
}

// =====================================================================
// WIDGETS
// =====================================================================

// Header row: icon + label + value, with a trailing "Change" affordance.
// Tapping anywhere on the chip triggers onTap (opens scanner or picker).
class _TappableChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _TappableChip(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
                const SizedBox(height: 1),
                Text(value,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (!disabled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 12),
                SizedBox(width: 3),
                Text("Change",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Viewport extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture)? onDetect;
  final Animation<double> pulseAnim;
  final String label;
  final VoidCallback onCancel;
  const _Viewport(
      {required this.controller,
      required this.onDetect,
      required this.pulseAnim,
      required this.label,
      required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Stack(fit: StackFit.expand, children: [
        MobileScanner(controller: controller, onDetect: onDetect),
        IgnorePointer(child: CustomPaint(painter: _OverlayP())),
        IgnorePointer(
            child: Center(
                child: AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: pulseAnim.value,
            child: SizedBox(
                width: 280,
                height: 190,
                child: CustomPaint(painter: _BracketsP())),
          ),
        ))),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter)),
            child: Row(children: [
              const Expanded(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: Colors.white70)),
                      SizedBox(width: 8),
                      Text("Scanning...",
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ]),
              ),
              GestureDetector(
                onTap: onCancel,
                child: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 20),
              ),
            ]),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.68),
                ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter)),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              const Icon(Icons.crop_free_rounded,
                  color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _OverlayP extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withValues(alpha: 0.48);
    final cw = size.width * 0.86;
    final ch = size.height * 0.55;
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(
                (size.width - cw) / 2, (size.height - ch) / 2, cw, ch),
            const Radius.circular(12)))
        ..fillType = PathFillType.evenOdd,
      p,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _BracketsP extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF60A5FA)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const l = 24.0;
    const r = Radius.circular(5);
    canvas.drawPath(
        Path()
          ..moveTo(0, l)
          ..lineTo(0, 5)
          ..arcToPoint(const Offset(5, 0), radius: r)
          ..lineTo(l, 0),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(size.width - l, 0)
          ..lineTo(size.width - 5, 0)
          ..arcToPoint(Offset(size.width, 5), radius: r)
          ..lineTo(size.width, l),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height - l)
          ..lineTo(0, size.height - 5)
          ..arcToPoint(Offset(5, size.height), radius: r)
          ..lineTo(l, size.height),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(size.width - l, size.height)
          ..lineTo(size.width - 5, size.height)
          ..arcToPoint(Offset(size.width, size.height - 5), radius: r)
          ..lineTo(size.width, size.height - l),
        p);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _StopwatchBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;
  const _StopwatchBtn(
      {required this.icon,
      required this.label,
      required this.colors,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: colors.first.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}