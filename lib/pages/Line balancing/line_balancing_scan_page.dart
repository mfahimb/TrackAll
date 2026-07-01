import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/top_menu_bar.dart';
import 'package:trackall_app/services/line_staff_service.dart';
import 'package:trackall_app/services/process_smv_service.dart';
import 'line_balancing_timer_page.dart';
import '../Line balancing/time_report.dart';

enum _Phase { idle, scanningLine, lineReady, selectingProcess, processReady, scanningStaff }

class _LineInfo {
  final String qr;
  final String lineNo;
  final String lineName;
  const _LineInfo(
      {required this.qr, required this.lineNo, required this.lineName});
  String get display => lineName;
}

class LineBalancingScanPage extends StatefulWidget {
  const LineBalancingScanPage({super.key});
  @override
  State<LineBalancingScanPage> createState() => _S();
}

class _S extends State<LineBalancingScanPage>
    with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.idle;
  _LineInfo? _line;

  // ── Process selection (one-time, for initial setup) ─────────────────
  final ProcessSmvService _processSvc = ProcessSmvService();
  List<Map<String, String>> _processList = [];
  String? _processId;
  String? _processLabel;
  int? _benchmarkTime;
  bool _loadingProcessList = false;
  String _companyId = '5';

  MobileScannerController? _ctrl;

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

  bool _busy = false;
  bool _camVisible = false;
  final Set<String> _sessionCodes = {};

  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  final LineStaffService _service = LineStaffService();
  String? _appUserId;

  @override
  void initState() {
    super.initState();
    _loadAppUser();
    _loadCompanyId();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.87, end: 1.0).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _ctrl = null;
    _pulse.dispose();
    super.dispose();
  }

  // ── Camera controls ────────────────────────────────────────────────

  Future<void> _startLineScan() async {
    _busy = false;
    _sessionCodes.clear();
    _freshController();
    setState(() {
      _phase = _Phase.scanningLine;
      _camVisible = true;
    });
  }

  Future<void> _startStaffScan() async {
    _busy = false;
    _sessionCodes.clear();
    _freshController();
    setState(() {
      _phase = _Phase.scanningStaff;
      _camVisible = true;
    });
  }

  Future<void> _stopCamera() async {
    if (mounted) setState(() => _camVisible = false);
    await _ctrl?.stop();
    _ctrl?.dispose();
    _ctrl = null;
  }

  Future<void> _reset() async {
    _busy = false;
    _sessionCodes.clear();
    await _ctrl?.stop();
    _ctrl?.dispose();
    _ctrl = null;
    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _camVisible = false;
      _line = null;
      _processId = null;
      _processLabel = null;
      _benchmarkTime = null;
    });
  }

  // ── Detect handler ─────────────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    if (_phase != _Phase.scanningLine && _phase != _Phase.scanningStaff) return;

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

    _busy = true;
    debugPrint("📷 DETECTED [$code] format=${capture.barcodes.first.format}");

    if (_phase == _Phase.scanningLine) {
      _handleLine(code);
    } else {
      _handleStaff(code);
    }
  }

  // ── Handle line QR — then move to process selection ─────────────────

  Future<void> _handleLine(String qr) async {
    await _stopCamera();
    setState(() => _phase = _Phase.lineReady);

    final info = await _parseLineQR(qr);
    if (!mounted) {
      _busy = false;
      return;
    }

    if (info == null) {
      _snack("Invalid Line QR: $qr", Colors.red, Icons.error_rounded);
      setState(() => _phase = _Phase.idle);
      _busy = false;
      return;
    }

    setState(() {
      _line = info;
      _phase = _Phase.selectingProcess;
    });
    _snack("✓ ${info.display}", const Color(0xFF0F9D58),
        Icons.check_circle_rounded);
    _busy = false;

    if (_processList.isEmpty && !_loadingProcessList) {
      await _loadProcessLov();
    }
  }

  // ── Load process LOV ──────────────────────────────────────────────

  Future<void> _loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    _companyId = prefs.getString('selected_company_id') ?? '5';
  }

  Future<void> _loadProcessLov() async {
    setState(() => _loadingProcessList = true);
    try {
      final list = await _processSvc.fetchProcessLov(companyId: _companyId);
      if (!mounted) return;
      setState(() => _processList = list);
      if (list.isEmpty) {
        _snack("Process list could not be loaded", Colors.red,
            Icons.error_rounded);
      }
    } catch (e) {
      _snack("Failed to load process list: $e", Colors.red,
          Icons.error_rounded);
    } finally {
      if (mounted) setState(() => _loadingProcessList = false);
    }
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
                            Navigator.pop(ctx);
                            _showBenchmarkInput(item["id"]!, item["label"]!);
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

  void _showBenchmarkInput(String processId, String processLabel) {
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
          const Text("Benchmark Time",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 6),
          Text("Process: $processLabel",
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
                setState(() {
                  _processId = processId;
                  _processLabel = processLabel;
                  _benchmarkTime = val;
                  _phase = _Phase.processReady;
                });
                Navigator.pop(ctx);
              },
              child: const Text("Confirm",
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

  // ── Handle staff barcode — then navigate to timer page ──────────────

  Future<void> _handleStaff(String rawBarcode) async {
    await _stopCamera();

    final credNo = rawBarcode.split(',').first.trim();
    final parts = rawBarcode.split(',');
    final embeddedName = parts.length > 1 ? parts[1].trim() : null;

    debugPrint("📦 Raw barcode   : '$rawBarcode'");
    debugPrint("📦 Credential No : '$credNo'");

    final staffResult = await _service.fetchStaffByBarcode(credNo);
    if (!mounted) {
      _busy = false;
      return;
    }

    String? name = staffResult?["STAFF_NAME"];
    String? staffId = staffResult?["STAFF_ID"];

    if (name == null && embeddedName != null && embeddedName.isNotEmpty) {
      debugPrint("⚠️ API lookup failed — using embedded name: $embeddedName");
      name = embeddedName;
      staffId ??= credNo;
    }

    if (name == null || staffId == null) {
      _snack("Staff not found: $credNo", Colors.red, Icons.person_off_rounded);
      _busy = false;
      await _startStaffScan();
      return;
    }

    _snack("✓ $name", const Color(0xFF0F9D58), Icons.check_circle_rounded);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) {
      _busy = false;
      return;
    }

    // Navigate to the timer page — from here on, Line/Process/Staff can
    // all be changed in-place on that page; this scan page is only used
    // for the initial one-time setup.
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
       builder: (_) => LineBalancingTimerPage(
          lineId: _line!.qr,
          lineName: _line!.display,
          processId: _processId!,
          processLabel: _processLabel!,
          benchmarkTime: _benchmarkTime,
          staffId: credNo,
          staffName: name!,
          appUserId: _appUserId ?? '',
        ),
      ),
    );

    _busy = false;
    if (!mounted) return;
    await _reset();
  }

  // ── Snackbar ───────────────────────────────────────────────────────

  void _snack(String msg, Color color, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: color,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(14),
    ));
  }

  // ── API helpers ────────────────────────────────────────────────────

  Future<void> _loadAppUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appUserId = prefs.getString('userId') ??
          prefs.getString('staff_id') ??
          prefs.getString('app_user');
    });
    debugPrint("👤 appUser loaded: '$_appUserId'");
  }

  Future<_LineInfo?> _parseLineQR(String qr) async {
    final lineId = qr.trim();
    if (lineId.isEmpty) return null;
    final result = await _service.fetchLineName(lineId);
    if (result == null) return null;
    return _LineInfo(
      qr: lineId,
      lineNo: result["LINE_ID"] ?? lineId,
      lineName: result["LINE_NAME"] ?? "Unknown Line",
    );
  }

  // ── Build ──────────────────────────────────────────────────────────

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
                    _Header(
                        phase: _phase,
                        line: _line,
                        processLabel: _processLabel),
                    const SizedBox(height: 14),
                    if (_camVisible && _ctrl != null) ...[
                      _Viewport(
                        controller: _ctrl!,
                        onDetect: _onDetect,
                        pulseAnim: _pulseAnim,
                        label: _phase == _Phase.scanningLine
                            ? "Point at Line QR Code"
                            : "Point at Staff ID / Barcode",
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_phase == _Phase.selectingProcess) ...[
                      _ProcessPickerCard(
                        loading: _loadingProcessList,
                        processLabel: _processLabel,
                        onTap: _loadingProcessList ? null : _showProcessPicker,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_phase == _Phase.processReady) ...[
                      _ProcessPickerCard(
                        loading: _loadingProcessList,
                        processLabel: _processLabel,
                        onTap: _loadingProcessList ? null : _showProcessPicker,
                      ),
                      const SizedBox(height: 10),
                      Container(
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
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF4FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.timer_outlined,
                                color: Color(0xFF1A73E8), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Benchmark Time",
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black54)),
                                const SizedBox(height: 2),
                                Text(
                                  _benchmarkTime != null
                                      ? "$_benchmarkTime seconds"
                                      : "Not set",
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _benchmarkTime != null
                                          ? Colors.black87
                                          : Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showBenchmarkInput(
                                _processId!, _processLabel!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF4FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF1A73E8)
                                        .withValues(alpha: 0.3)),
                              ),
                              child: const Text("Change",
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A73E8))),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Row(children: [
                      Expanded(
                          child: _MainBtn(
                        phase: _phase,
                        onStartLineScan: _startLineScan,
                        onScanStaff: _startStaffScan,
                      )),
                      const SizedBox(width: 10),
                      _ResetBtn(onTap: _reset),
                    ]),
                    const SizedBox(height: 20),
                    if (_phase == _Phase.idle)
                      const _Hint(
                          icon: Icons.qr_code_2_rounded,
                          text: "Tap Start Scan to begin"),
                    if (_phase == _Phase.selectingProcess)
                      const _Hint(
                          icon: Icons.tune_rounded,
                          text: "Select a process to continue"),
                    if (_phase == _Phase.processReady)
                      const _Hint(
                          icon: Icons.badge_outlined,
                          text: "Tap Scan Staff to scan ID card"),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// =====================================================================
// WIDGETS
// =====================================================================

class _Header extends StatelessWidget {
  final _Phase phase;
  final _LineInfo? line;
  final String? processLabel;
  const _Header({required this.phase, this.line, this.processLabel});

  String get _status => switch (phase) {
        _Phase.idle => "Ready — tap Start Scan to begin",
        _Phase.scanningLine => "Scanning for Line QR code...",
        _Phase.lineReady => "Line confirmed...",
        _Phase.selectingProcess => "Select a process to continue",
        _Phase.processReady => "Ready — scan staff ID",
        _Phase.scanningStaff => "Scanning for staff barcode...",
      };

  Color get _dotColor => switch (phase) {
        _Phase.idle => Colors.white38,
        _Phase.scanningLine => const Color(0xFFFBBF24),
        _Phase.lineReady => const Color(0xFF34D399),
        _Phase.selectingProcess => const Color(0xFFFBBF24),
        _Phase.processReady => const Color(0xFF34D399),
        _Phase.scanningStaff => const Color(0xFF34D399),
      };

  String get _dotLabel => switch (phase) {
        _Phase.idle => "IDLE",
        _Phase.scanningLine => "SCANNING",
        _Phase.lineReady => "READY",
        _Phase.selectingProcess => "SELECT",
        _Phase.processReady => "READY",
        _Phase.scanningStaff => "SCANNING",
      };

  @override
  Widget build(BuildContext context) {
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
          BoxShadow(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.15),
              blurRadius: 32,
              offset: const Offset(0, 10)),
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
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text("Time Study",
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.2)),
                const SizedBox(height: 2),
                Text(_status,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w500,
                        height: 1.3)),
              ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _dotColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _dotColor.withValues(alpha: 0.45), width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: _dotColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: _dotColor.withValues(alpha: 0.7),
                            blurRadius: 4)
                      ])),
              const SizedBox(width: 5),
              Text(_dotLabel,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _dotColor,
                      letterSpacing: 0.8)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
        const SizedBox(height: 14),
        Row(children: [
          _Chip(
              icon: Icons.view_timeline_rounded,
              label: "Line",
              value: line?.display ?? "—",
              active: line != null),
          const SizedBox(width: 10),
          _Chip(
              icon: Icons.tune_rounded,
              label: "Process",
              value: processLabel ?? "—",
              active: processLabel != null),
        ]),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool active;
  const _Chip(
      {required this.icon,
      required this.label,
      required this.value,
      required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: active ? 0.20 : 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.white.withValues(alpha: active ? 0.38 : 0.15)),
        ),
        child: Row(children: [
          Icon(icon, color: active ? Colors.white : Colors.white38, size: 15),
          const SizedBox(width: 7),
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
                    style: TextStyle(
                        fontSize: 11,
                        color: active ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
              ])),
        ]),
      ),
    );
  }
}

class _ProcessPickerCard extends StatelessWidget {
  final bool loading;
  final String? processLabel;
  final VoidCallback? onTap;
  const _ProcessPickerCard(
      {required this.loading, this.processLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
          const Text("Process",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(children: [
                Icon(Icons.precision_manufacturing_outlined,
                    color: Colors.grey.shade500, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: loading
                      ? const Text("Loading processes...",
                          style: TextStyle(fontSize: 13, color: Colors.grey))
                      : Text(
                          processLabel ?? "Select process",
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: processLabel != null
                                  ? Colors.black87
                                  : Colors.grey.shade400),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                if (loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF1A73E8)),
                  )
                else
                  const Icon(Icons.arrow_drop_down, color: Colors.black54),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Viewport extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture)? onDetect;
  final Animation<double> pulseAnim;
  final String label;
  const _Viewport(
      {required this.controller,
      required this.onDetect,
      required this.pulseAnim,
      required this.label});

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
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter)),
            child: const Row(
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

class _MainBtn extends StatelessWidget {
  final _Phase phase;
  final VoidCallback onStartLineScan;
  final VoidCallback onScanStaff;
  const _MainBtn(
      {required this.phase,
      required this.onStartLineScan,
      required this.onScanStaff});

  @override
  Widget build(BuildContext context) {
    final busy = phase == _Phase.scanningLine || phase == _Phase.scanningStaff;
    final String label = switch (phase) {
      _Phase.idle => "Start Scan",
      _Phase.scanningLine => "Scanning Line...",
      _Phase.lineReady => "Loading...",
      _Phase.selectingProcess => "Select Process Above",
      _Phase.processReady => "Scan Staff",
      _Phase.scanningStaff => "Scanning Staff...",
    };
    final IconData icon = switch (phase) {
      _Phase.idle => Icons.qr_code_rounded,
      _Phase.scanningLine => Icons.hourglass_top_rounded,
      _Phase.lineReady => Icons.hourglass_top_rounded,
      _Phase.selectingProcess => Icons.tune_rounded,
      _Phase.processReady => Icons.badge_rounded,
      _Phase.scanningStaff => Icons.hourglass_top_rounded,
    };
    final bool tappable = phase == _Phase.idle || phase == _Phase.processReady;
    final List<Color> gradColors = !tappable
        ? [Colors.grey.shade400, Colors.grey.shade500]
        : phase == _Phase.processReady
            ? [const Color(0xFF0F9D58), const Color(0xFF0B8043)]
            : [const Color(0xFF1A73E8), const Color(0xFF1557B0)];
    final Color shadowColor = !tappable
        ? Colors.transparent
        : phase == _Phase.processReady
            ? const Color(0xFF0F9D58)
            : const Color(0xFF1A73E8);

    return GestureDetector(
      onTap: !tappable
          ? null
          : (phase == _Phase.idle ? onStartLineScan : onScanStaff),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: !tappable
              ? []
              : [
                  BoxShadow(
                      color: shadowColor.withValues(alpha: 0.40),
                      blurRadius: 14,
                      offset: const Offset(0, 5))
                ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3)),
          if (phase == _Phase.scanningLine || phase == _Phase.scanningStaff) ...[
            const SizedBox(width: 10),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
          ],
        ]),
      ),
    );
  }
}

class _ResetBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _ResetBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFF97316), Color(0xFFEA580C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFF97316).withValues(alpha: 0.40),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ],
        ),
        child:
            const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Hint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100, width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
              color: Color(0xFFEEF4FF), shape: BoxShape.circle),
          child: Icon(icon,
              size: 36, color: const Color(0xFF1A73E8).withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 12),
        Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade400)),
      ]),
    );
  }
}