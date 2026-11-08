import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackall_app/pages/widgets/top_menu_bar.dart';
import '../services/lov_service.dart';
import '../services/machine_qr.dart';
import 'package:intl/intl.dart';

// =====================================================================
// SCROLLABLE OVERFLOW TEXT WIDGET
// =====================================================================
class CtlOverflowScrollText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final EdgeInsetsGeometry padding;

  const CtlOverflowScrollText({
    super.key,
    required this.text,
    required this.style,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  @override
  State<CtlOverflowScrollText> createState() => _CtlOverflowScrollTextState();
}

class _CtlOverflowScrollTextState extends State<CtlOverflowScrollText> {
  final ScrollController _scrollCtrl = ScrollController();
  bool _isOverflowing = false;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
    _scrollCtrl.addListener(() {
      final scrolled = _scrollCtrl.offset > 0;
      if (scrolled != _isScrolled) setState(() => _isScrolled = scrolled);
    });
  }

  @override
  void didUpdateWidget(CtlOverflowScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollCtrl.jumpTo(0);
        _checkOverflow();
      });
    }
  }

  void _checkOverflow() {
    if (!mounted) return;
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final available = renderBox.size.width - 20 - 24;
    setState(() => _isOverflowing = tp.width > available);
  }

  void _scrollRight() => _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

  void _scrollLeft() => _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: widget.padding,
            child: Text(widget.text, style: widget.style, maxLines: 1),
          ),
        ),
        if (_isOverflowing)
          GestureDetector(
            onTap: _isScrolled ? _scrollLeft : _scrollRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                _isScrolled
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 18,
                color: const Color(0xFF1A73E8),
              ),
            ),
          ),
      ],
    );
  }
}

// =====================================================================
// MACHINE SCANNER BOTTOM SHEET
// =====================================================================
class MachineScannerSheet extends StatefulWidget {
  /// Pre-existing scanned machines so re-opening keeps history
  final List<Map<String, String>> initialMachines;

  const MachineScannerSheet({super.key, this.initialMachines = const []});

  @override
  State<MachineScannerSheet> createState() => _MachineScannerSheetState();
}

class _MachineScannerSheetState extends State<MachineScannerSheet> {
  final MobileScannerController _scanCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  late List<Map<String, String>> _scannedMachines;
  bool _isScannerActive = true;
  bool _isPreloading = true;
  String? _lastScanned;
  DateTime? _lastSnackbarTime;
  final MachineQrService _qrService = MachineQrService();

  @override
  void initState() {
    super.initState();
    _scannedMachines = List.from(widget.initialMachines);
    _qrService.preload().then((_) {
      if (mounted) setState(() => _isPreloading = false);
    });
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

void _onDetect(BarcodeCapture capture) {
  // 1. Still loading — show feedback instead of silently dropping
  if (_isPreloading) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        content: Text("Still loading machine list, please wait..."),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.blueGrey,
      ));
    return;
  }

  final barcode = capture.barcodes.firstOrNull;
  if (barcode == null) return;
  final raw = barcode.rawValue?.trim();
  if (raw == null || raw.isEmpty) return;

  // 2. Duplicate already in list
   final fullAmim = _qrService.fullAmimId(raw);
   final isDuplicate = _scannedMachines.any((m) => m['id'] == fullAmim);
   
  if (isDuplicate) {
    final now = DateTime.now();
    final lastTime = _lastSnackbarTime;
    if (lastTime == null || now.difference(lastTime).inMilliseconds > 2000) {
      _lastSnackbarTime = now;
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text("This machine is already added."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ));
      }
    }
    return;
  }

  // 3. Throttle: same raw value within 1.5 s → ignore (avoids double-fire)
  final now = DateTime.now();
  if (_lastScanned == raw) {
    final lastTime = _lastSnackbarTime;
    if (lastTime != null && now.difference(lastTime).inMilliseconds < 1500) return;
  }

  // 4. Lookup
  final machineName = _qrService.lookup(raw);
  debugPrint('🔎 Scanned raw: "$raw" → name: "$machineName"');

  if (machineName == null) {
    _lastScanned = raw;
    _lastSnackbarTime = now;
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text("No machine found for QR: $raw"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ));
    }
    return;
  }

  // 5. Success
  // 5. Success
  HapticFeedback.mediumImpact();
  _lastScanned = raw;
  _lastSnackbarTime = now;
  if (mounted) {
    setState(() {
      _scannedMachines.add({
        'id':   _qrService.fullAmimId(raw), // full AMIM string for backend
        'name': machineName,
      });
    });
  }
}

  void _removeMachine(int index) {
    setState(() {
      _scannedMachines.removeAt(index);
      _lastScanned = null;
    });
  }

  void _toggleScanner() {
    setState(() => _isScannerActive = !_isScannerActive);
    if (_isScannerActive) {
      _scanCtrl.start();
    } else {
      _scanCtrl.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle ──────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // ── Title ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner_rounded,
                    color: Color(0xFF1A73E8), size: 20),
                const SizedBox(width: 8),
                const Text(
                  "Scan Machine QR",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _toggleScanner,
                  icon: Icon(
                      _isScannerActive ? Icons.pause_circle : Icons.play_circle,
                      size: 16),
                  label: Text(_isScannerActive ? "Pause" : "Resume",
                      style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1A73E8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    backgroundColor: const Color(0xFFE8F0FE),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Camera viewport ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: _scanCtrl,
                      onDetect: _onDetect,
                    ),
                    // Scan frame overlay
                    Center(
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFF1A73E8), width: 2.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    // Hint / loading label
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _isPreloading
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.70),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 12, height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    ),
                                    SizedBox(width: 8),
                                    Text("Loading machine list...",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  "Point at machine QR code",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Scanned list header ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  "Scanned Machines (${_scannedMachines.length})",
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.black),
                ),
                const Spacer(),
                if (_scannedMachines.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _scannedMachines.clear()),
                    child: Text(
                      "Clear All",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade400),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // ── Scanned list ─────────────────────────────────────────
          Expanded(
            child: _scannedMachines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_2_rounded,
                            color: Colors.grey.shade300, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          "No machines scanned yet",
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _scannedMachines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final machine = _scannedMachines[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD0E0FF)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A73E8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  "${index + 1}",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    machine['name']!,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _removeMachine(index),
                              child: Icon(Icons.close_rounded,
                                  size: 18, color: Colors.red.shade400),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // ── OK Button ────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, _scannedMachines),
                icon: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 18),
                label: Text(
                  _scannedMachines.isEmpty
                      ? "OK (No Machines Selected)"
                      : "OK  ·  ${_scannedMachines.length} Machine${_scannedMachines.length > 1 ? 's' : ''} Added",
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: _scannedMachines.isEmpty
                      ? Colors.grey.shade400
                      : const Color(0xFF1A73E8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// CTL NPT ENTRY PAGE
// =====================================================================
class CtlNptEntryPage extends StatefulWidget {
  const CtlNptEntryPage({super.key});

  @override
  State<CtlNptEntryPage> createState() => _CtlNptEntryPageState();
}

class _CtlNptEntryPageState extends State<CtlNptEntryPage> {
  DateTime selectedDate = DateTime.now();
  final TextEditingController _dateController = TextEditingController();

  String? buildingId, processId, lineId, categoryId,
      responsibleUserId, deptId, machineNo;
  String? buildingLabel, processLabel, lineLabel, categoryLabel,
      responsibleUserLabel, deptLabel, causeLabel, machineLabel;
  String? smv, remarks, gmtLossQty, numberOfOperators;
  String? causeId;

  TimeOfDay? startTime, endTime;

  final TextEditingController _startController     = TextEditingController();
  final TextEditingController _endController       = TextEditingController();
  final TextEditingController _smvController       = TextEditingController();
  final TextEditingController _operatorsController = TextEditingController();
  final TextEditingController _gmtLossController   = TextEditingController();
  final TextEditingController _remarksController   = TextEditingController();

  // ── QR scanned machines ────────────────────────────────────────────
  List<Map<String, String>> _scannedMachines = [];

  List<Map<String, String>> buildingList        = [],
                             processList         = [],
                             lineList            = [],
                             responsibleUserList = [],
                             responsibleDeptList = [],
                             downtimeCauseList   = [],
                             operationCategoryList = [];

  final List<Map<String, String>> machineList =
      List.generate(10, (i) => {"id": "${i + 1}", "label": "${i + 1}"});

  List<Map<String, dynamic>> nptList = [];
  late SharedPreferences prefs;
  bool _isLoading = true;
  final Set<String> _missingFields = {};
  final LovService _lovService = LovService();
  late String loginUserId;
  late String selectedCompanyId;

  static const _kBuilding      = 'building';
  static const _kProcess       = 'process';
  static const _kCategory      = 'category';
  static const _kLine          = 'line';
  static const _kMachine       = 'machine';
  static const _kDept          = 'dept';
  static const _kRespUser      = 'respUser';
  static const _kCause         = 'cause';
  static const _kSmv           = 'smv';
  static const _kOperators     = 'operators';
  static const _kGmtLoss       = 'gmtLoss';
  static const _kRemarks       = 'remarks';
  static const _kStartTime     = 'startTime';
  static const _kEndTime       = 'endTime';
  static const _kScannedMachines = 'scannedMachines'; // ← new

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd-MM-yyyy').format(selectedDate);
    _loadInitialData();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _startController.dispose();
    _endController.dispose();
    _smvController.dispose();
    _operatorsController.dispose();
    _gmtLossController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    prefs             = await SharedPreferences.getInstance();
    loginUserId       = prefs.getString("userId") ?? "0";
    selectedCompanyId = prefs.getString("selected_company_id") ?? "0";

    final raw = prefs.getString('ctl_npt_list');
    if (raw != null) nptList = List<Map<String, dynamic>>.from(jsonDecode(raw));

    try {
      await Future.wait([
        _lovService.fetchLov(qryType: "BUILDING",  appUserId: loginUserId).then((v) => buildingList          = v),
        _lovService.fetchLov(qryType: "PROCESS",   appUserId: loginUserId).then((v) => processList           = v),
        _lovService.fetchLov(qryType: "DOWNTIME",  appUserId: loginUserId).then((v) => downtimeCauseList     = v),
        _lovService.fetchRespDeptCtl(appUserId: loginUserId).then((v) => responsibleDeptList   = v),
        _lovService.fetchLov(qryType: "OPERATION", appUserId: loginUserId).then((v) => operationCategoryList = v),
      ]);
    } catch (e) {
      debugPrint("Error fetching LOVs: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> fetchLine() async {
    if (buildingId == null || processId == null) return;
    try {
      lineList = await _lovService.fetchLov(
        qryType: "LINE", dwLocId: buildingId, dwSec: processId, appUserId: loginUserId,
      );
      setState(() {});
    } catch (e) {
      debugPrint("Error fetching lines: $e");
    }
  }

  Future<void> _fetchRespUserByDept(String deptId) async {
    debugPrint('🔄 Loading RESP_USER for dept: $deptId');
    setState(() {
      responsibleUserList  = [];
      responsibleUserId    = null;
      responsibleUserLabel = null;
    });
    final users = await _lovService.fetchRespUserByDept(
      deptId:    deptId,
      appUserId: loginUserId,
    );
    if (mounted) {
      setState(() {
        responsibleUserList = users;
        debugPrint('✅ RESP_USER loaded: ${users.length} users for dept $deptId');
      });
    }
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: selectedDate,
      firstDate: DateTime(2020), lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        _dateController.text = DateFormat('dd-MM-yyyy').format(selectedDate);
      });
    }
  }

  String get totalTimeFormatted {
    if (startTime == null || endTime == null) return "0";
    final start = DateTime(selectedDate.year, selectedDate.month,
        selectedDate.day, startTime!.hour, startTime!.minute);
    var end = DateTime(selectedDate.year, selectedDate.month,
        selectedDate.day, endTime!.hour, endTime!.minute);
    if (end.isBefore(start)) end = end.add(const Duration(days: 1));
    return end.difference(start).inMinutes.toString();
  }

  Future<void> pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? (startTime ?? TimeOfDay.now()) : (endTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startTime = picked; _startController.text = picked.format(context);
          _missingFields.remove(_kStartTime);
        } else {
          endTime = picked; _endController.text = picked.format(context);
          _missingFields.remove(_kEndTime);
        }
      });
    }
  }

  /// Opens the machine scanner bottom sheet, preserving existing scans
  Future<void> _openMachineScanner() async {
    final result = await showModalBottomSheet<List<Map<String, String>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MachineScannerSheet(initialMachines: _scannedMachines),
    );
    if (result != null) {
      setState(() {
        _scannedMachines = result;
        if (_scannedMachines.isNotEmpty) _missingFields.remove(_kScannedMachines);
      });
    }
  }

  void _clearAll() {
    setState(() {
      buildingId = null;          buildingLabel = null;
      processId = null;           processLabel = null;
      lineId = null;              lineLabel = null;    lineList = [];
      categoryId = null;          categoryLabel = null;
      responsibleUserId = null;   responsibleUserLabel = null;
      deptId = null;              deptLabel = null;
      causeLabel = null;          causeId = null;
      machineNo = null;          machineLabel = null;
      smv = null;  remarks = null;  gmtLossQty = null;  numberOfOperators = null;
      startTime = null;           endTime = null;
      _scannedMachines = [];      // ← clear scanned machines too
      _missingFields.clear();
    });
    _startController.clear();  _endController.clear();
    _smvController.clear();    _operatorsController.clear();
    _gmtLossController.clear(); _remarksController.clear();
  }

  Future<void> _handleSave() async {
    final missing = <String>{};
    if (buildingId == null)                                             missing.add(_kBuilding);
    if (processId == null)                                              missing.add(_kProcess);
    if (categoryId == null)                                             missing.add(_kCategory);
    if (lineId == null)                                                 missing.add(_kLine);
    if (machineNo == null)                                              missing.add(_kMachine);
    if (deptId == null)                                                 missing.add(_kDept);
    if (responsibleUserId == null)                                      missing.add(_kRespUser);
    if (causeLabel == null || causeLabel!.trim().isEmpty)               missing.add(_kCause);
    if (smv == null || smv!.trim().isEmpty)                             missing.add(_kSmv);
    if (numberOfOperators == null || numberOfOperators!.trim().isEmpty) missing.add(_kOperators);
    if (gmtLossQty == null || gmtLossQty!.trim().isEmpty)               missing.add(_kGmtLoss);
    if (remarks == null || remarks!.trim().isEmpty)                     missing.add(_kRemarks);
    if (startTime == null)                                              missing.add(_kStartTime);
    if (endTime == null)                                                missing.add(_kEndTime);
    // Note: scanned machines are optional for now — add validation when API is ready:
    // if (_scannedMachines.isEmpty) missing.add(_kScannedMachines);

    if (missing.isNotEmpty) {
      setState(() => _missingFields..clear()..addAll(missing));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("All fields marked with * are mandatory."),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (int.tryParse(numberOfOperators!) == null ||
        double.tryParse(smv!) == null ||
        double.tryParse(gmtLossQty!) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("SMV, Operators, and GMT Loss Qty must be numeric"),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _missingFields.clear());

    // TODO: pass scannedMachines to saveNptEntry when API is ready
    final success = await _lovService.saveNptEntry(
      entryDate:         selectedDate,
      buildingId:        buildingId!,
      processId:         processId!,
      lineId:            lineId!,
      machineNo:         machineNo!,
      smv:               smv!,
      categoryId:        categoryId!,
      startTime:         startTime!,
      endTime:           endTime!,
      cause:             causeLabel!,
      causeId:           causeId,
      deptId:            deptId!,
      responsibleUserId: responsibleUserId!,
      remarks:           remarks!,
      gmtLossQty:        gmtLossQty!,
      staffId:           loginUserId,
      numberOfOperators: numberOfOperators!,
      scannedMachines:   _scannedMachines,   // ← ADD THIS
    );

    nptList.insert(0, {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "building": buildingLabel, "process": processLabel,
      "P_START_TIME": _startController.text,
      "P_END_TIME": _endController.text,
      "totalTime": totalTimeFormatted,
      "gmtLossQty": gmtLossQty,
      "scannedMachines": _scannedMachines.map((m) => m['name']).join(', '),
      "isSynced": success, "date": _dateController.text,
    });

    await prefs.setString('ctl_npt_list', jsonEncode(nptList));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? "Entry Saved Successfully!"
          : "Save Failed — server rejected the entry. Contact administrator."),
      backgroundColor: success ? Colors.green : Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: Column(
        children: [
          const TopMenuBar(),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final width = (constraints.maxWidth - 44) / 2;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(children: [
                  SizedBox(
                    width: constraints.maxWidth - 32,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        const Text("Date *",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _clearAll,
                          icon: const Icon(Icons.refresh_rounded, size: 13),
                          label: const Text("Clear", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade400,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            backgroundColor: Colors.red.shade50,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: pickDate,
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          child: Row(children: [
                            Expanded(
                              child: CtlOverflowScrollText(
                                text: _dateController.text,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: Icon(Icons.calendar_today, color: Colors.black54, size: 16),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  Wrap(spacing: 12, runSpacing: 12, children: [
                    _modernDropdown(context, "Building *", buildingLabel, buildingList, _kBuilding, (id, label) {
                      setState(() {
                        buildingId = id; buildingLabel = label;
                        processId = null; processLabel = null;
                        lineId = null; lineLabel = null; lineList = [];
                        _missingFields.remove(_kBuilding);
                      });
                      fetchLine();
                    }, width),

                    _modernDropdown(context, "Process *", processLabel, processList, _kProcess, (id, label) {
                      setState(() {
                        processId = id; processLabel = label;
                        lineId = null; lineLabel = null; lineList = [];
                        _missingFields.remove(_kProcess);
                      });
                      fetchLine();
                    }, width),

                    _modernDropdown(context, "Category *", categoryLabel, operationCategoryList, _kCategory, (id, label) {
                      setState(() { categoryId = id; categoryLabel = label; _missingFields.remove(_kCategory); });
                    }, width),

                    _modernDropdown(context, "Line No *", lineLabel, lineList, _kLine, (id, label) {
                      setState(() { lineId = id; lineLabel = label; _missingFields.remove(_kLine); });
                    }, width),

                    _modernDropdown(context, "Machine No *", machineLabel, machineList, _kMachine, (id, label) {
                      setState(() { machineNo = id; machineLabel = label; _missingFields.remove(_kMachine); });
                    }, width),

                    _modernDropdown(context, "Responsible Dept *", deptLabel, responsibleDeptList, _kDept, (id, label) {
                      setState(() {
                        deptId               = id;
                        deptLabel            = label;
                        responsibleUserId    = null;
                        responsibleUserLabel = null;
                        responsibleUserList  = [];
                        _missingFields.remove(_kDept);
                      });
                      _fetchRespUserByDept(id);
                    }, width),

                    _timeField("Start Time *", _startController, () => pickTime(true),  width, _kStartTime, icon: Icons.access_time),
                    _timeField("End Time *",   _endController,   () => pickTime(false), width, _kEndTime,   icon: Icons.access_time),

                    _readOnlyField("Total (Min)", totalTimeFormatted, width),

                    _numberField("SMV *", _smvController, _kSmv, (v) {
                      smv = v;
                      if (v.isNotEmpty) setState(() => _missingFields.remove(_kSmv));
                    }, width),

                    _modernDropdown(context, "Cause *", causeLabel, downtimeCauseList, _kCause, (id, label) {
                                         debugPrint('🧪 CAUSE selected => id="$id" label="$label"');
                      setState(() { causeId = id; causeLabel = label; _missingFields.remove(_kCause); });
                    }, width),

                    _numberField("Number of Operators *", _operatorsController, _kOperators, (v) {
                      numberOfOperators = v;
                      if (v.isNotEmpty) setState(() => _missingFields.remove(_kOperators));
                    }, width, integersOnly: true),

                    _modernDropdown(
                      context,
                      deptId == null
                          ? "Responsible User * (select dept first)"
                          : responsibleUserList.isEmpty
                              ? "Responsible User * (loading...)"
                              : "Responsible User *",
                      responsibleUserLabel,
                      responsibleUserList,
                      _kRespUser,
                      (id, label) {
                        setState(() {
                          responsibleUserId    = id;
                          responsibleUserLabel = label;
                          _missingFields.remove(_kRespUser);
                        });
                      },
                      width,
                    ),

                    _numberField("GMT Loss Qty *", _gmtLossController, _kGmtLoss, (v) {
                      gmtLossQty = v;
                      if (v.isNotEmpty) setState(() => _missingFields.remove(_kGmtLoss));
                    }, width),

                    _textField("Remarks *", _remarksController, _kRemarks, (v) {
                      remarks = v;
                      if (v.isNotEmpty) setState(() => _missingFields.remove(_kRemarks));
                    }, width * 2 + 12),

                    // ── Machine Scan field (full width) ──────────────
                    _machineScanField(width * 2 + 12),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF1A73E8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: const Text("SAVE",
                            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                      ),
                    ),
                  ]),
                ]),
              );
            }),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // MACHINE SCAN FIELD
  // =====================================================================
  Widget _machineScanField(double width) {
    const isMissing = false;
    final hasScanned = _scannedMachines.isNotEmpty;

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(children: [
            const Icon(Icons.qr_code_scanner_rounded, size: 13, color: Color(0xFF1A73E8)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                "Machine Scan",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isMissing ? Colors.red.shade600 : Colors.black),
              ),
            ),
            if (hasScanned) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${_scannedMachines.length}",
                  style: const TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 4),

          // Scan button
          InkWell(
            onTap: _openMachineScanner,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: hasScanned ? const Color(0xFFE8F0FE) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMissing
                      ? Colors.red.shade400
                      : hasScanned
                          ? const Color(0xFF1A73E8)
                          : Colors.grey.shade300,
                  width: hasScanned ? 1.5 : 1,
                ),
                boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Row(children: [
                const SizedBox(width: 12),
                Icon(
                  hasScanned ? Icons.qr_code_2_rounded : Icons.qr_code_scanner_rounded,
                  size: 16,
                  color: hasScanned ? const Color(0xFF1A73E8) : Colors.black54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasScanned
                        ? _scannedMachines.map((m) => m['name']).join(', ')
                        : "Tap to scan machine QR codes",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: hasScanned ? FontWeight.w700 : FontWeight.w500,
                      color: hasScanned ? const Color(0xFF1A73E8) : Colors.grey.shade500,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: hasScanned ? const Color(0xFF1A73E8) : Colors.black38,
                  ),
                ),
              ]),
            ),
          ),


        ],
      ),
    );
  }

  // =====================================================================
  // WIDGET HELPERS (unchanged)
  // =====================================================================

  Border _fieldBorder(String fieldKey) => _missingFields.contains(fieldKey)
      ? Border.all(color: Colors.red.shade400, width: 1.5)
      : Border.all(color: Colors.grey.shade300);

  Widget _modernDropdown(BuildContext context, String label, String? value,
      List<Map<String, String>> list, String fieldKey,
      void Function(String, String) onSelect, double width) {
    final isMissing = _missingFields.contains(fieldKey);
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: isMissing ? Colors.red.shade600 : Colors.black)),
          ),
          if (isMissing) ...[
            const SizedBox(width: 4),
            Text("required", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.red.shade400)),
          ],
        ]),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _searchDialog(
            context,
            label,
            list,
            onSelect,
            allowManual: label.contains("Machine"),
          ),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: _fieldBorder(fieldKey),
              boxShadow: isMissing
                  ? [BoxShadow(color: Colors.red.withValues(alpha: 0.10), blurRadius: 4, offset: const Offset(0, 2))]
                  : const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Row(children: [
              Expanded(
                child: CtlOverflowScrollText(
                  text: value ?? "Select",
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: isMissing && value == null ? Colors.red.shade300 : Colors.black87),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.arrow_drop_down,
                    color: isMissing ? Colors.red.shade400 : Colors.black87, size: 20),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _readOnlyField(String label, String value, double width) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 4),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EAED),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: CtlOverflowScrollText(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ]),
    );
  }

  Widget _timeField(String label, TextEditingController controller,
      VoidCallback onTap, double width, String fieldKey, {IconData? icon}) {
    final isMissing = _missingFields.contains(fieldKey);
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: isMissing ? Colors.red.shade600 : Colors.black)),
          ),
          if (isMissing) ...[
            const SizedBox(width: 4),
            Text("required", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.red.shade400)),
          ],
        ]),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: _fieldBorder(fieldKey),
            ),
            child: Row(children: [
              Expanded(
                child: CtlOverflowScrollText(
                  text: controller.text.isEmpty ? "00:00" : controller.text,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: isMissing && controller.text.isEmpty ? Colors.red.shade300 : Colors.black87),
                ),
              ),
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(icon, color: isMissing ? Colors.red.shade400 : Colors.black54, size: 18),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _numberField(
    String label,
    TextEditingController controller,
    String fieldKey,
    Function(String) onChanged,
    double width, {
    bool integersOnly = false,
  }) {
    final isMissing = _missingFields.contains(fieldKey);
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: isMissing ? Colors.red.shade600 : Colors.black)),
          ),
          if (isMissing) ...[
            const SizedBox(width: 4),
            Text("required", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.red.shade400)),
          ],
        ]),
        const SizedBox(height: 4),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: isMissing ? Colors.red.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: _fieldBorder(fieldKey),
            boxShadow: isMissing
                ? [BoxShadow(color: Colors.red.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))]
                : const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Center(
            child: TextField(
              controller: controller,
              keyboardType: integersOnly
                  ? TextInputType.number
                  : const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: integersOnly
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              onChanged: onChanged,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: isMissing ? Colors.red.shade700 : Colors.black87),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                hintText: "0",
                hintStyle: TextStyle(
                    color: isMissing ? Colors.red.shade200 : Colors.grey.shade400,
                    fontSize: 12),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _textField(String label, TextEditingController controller,
      String fieldKey, Function(String) onChanged, double width) {
    final isMissing = _missingFields.contains(fieldKey);
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: isMissing ? Colors.red.shade600 : Colors.black)),
          ),
          if (isMissing) ...[
            const SizedBox(width: 4),
            Text("required", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.red.shade400)),
          ],
        ]),
        const SizedBox(height: 4),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: isMissing ? Colors.red.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: _fieldBorder(fieldKey),
            boxShadow: isMissing
                ? [BoxShadow(color: Colors.red.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))]
                : const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Center(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: isMissing ? Colors.red.shade700 : Colors.black87),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                hintText: "",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  void _searchDialog(
    BuildContext context,
    String title,
    List<Map<String, String>> items,
    void Function(String, String) onSelect, {
    bool allowManual = false,
  }) {
    List<Map<String, String>> filtered = List.from(items);
    String currentSearch = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(builder: (c, setS) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.80,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Text("Select $title",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
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
                  autofocus: false,
                  onChanged: (v) => setS(() {
                    currentSearch = v;
                    filtered = items
                        .where((e) =>
                            e["label"]!.toLowerCase().contains(v.toLowerCase()))
                        .toList();
                  }),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.black54),
                    hintText: "Search...",
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(children: [
                  if (allowManual && filtered.isEmpty && currentSearch.isNotEmpty)
                    ListTile(
                      title: Text("Use manual: $currentSearch",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      leading: const Icon(Icons.add_circle, color: Colors.blue),
                      onTap: () {
                        onSelect(currentSearch, currentSearch);
                        Navigator.pop(context);
                      },
                    ),
                  ...filtered.map((item) => ListTile(
                        title: Text(item["label"]!,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        onTap: () {
                          onSelect(item["id"]!, item["label"]!);
                          Navigator.pop(context);
                        },
                      )),
                ]),
              ),
            ]),
          );
        });
      },
    );
  }
}