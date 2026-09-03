import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/top_menu_bar.dart';
import 'package:trackall_app/services/line_balance_service.dart';
import 'package:trackall_app/services/line_staff_service.dart';
import '../Line balancing/time_report.dart';

enum _ScanTarget { none, line, staff }

// ══════════════════════════════════════════════════════════════════════
class LineBalancingTimerPage extends StatefulWidget {
  final String lineId;
  final String lineName;
  // ── New fields ──────────────────────────────────────────────────────
  final String articleId;
  final String articleLabel;
  final String buyerName;
  final String orderId;
  final String orderLabel;
  // ───────────────────────────────────────────────────────────────────
  final String processId;
  final String processLabel;
  final String? dept;
  final String staffId;
  final String staffName;
  final String mobileNo;
  final String appUserId;
  final int? benchmarkTime;

  const LineBalancingTimerPage({
    super.key,
    required this.lineId,
    required this.lineName,
    required this.articleId,
    required this.articleLabel,
    required this.buyerName,
    required this.orderId,
    required this.orderLabel,
    required this.processId,
    required this.processLabel,
    this.dept,
    required this.staffId,
    required this.staffName,
    required this.mobileNo,
    required this.appUserId,
    this.benchmarkTime,
  });

  @override
  State<LineBalancingTimerPage> createState() => _LineBalancingTimerPageState();
}

class _LineBalancingTimerPageState extends State<LineBalancingTimerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final LineBalanceService _lineBalanceSvc = LineBalanceService();
  final LineStaffService _lineStaffSvc = LineStaffService();

  // ── Company ID is read fresh from prefs every time it's needed,
  // rather than cached once, so switching company elsewhere in the app
  // is always reflected here — including at save time.
  Future<String> _resolveCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_company_id') ?? '5';
  }

  // ── Mutable current values — all editable in-place ──────────────────
  late String _lineId        = widget.lineId;
  late String _lineName      = widget.lineName;
  late String _articleId     = widget.articleId;
  late String _articleLabel  = widget.articleLabel;
  late String _buyerName     = widget.buyerName;
  late String _orderId       = widget.orderId;
  late String _orderLabel    = widget.orderLabel;
  late String _processId     = widget.processId;
  late String _processLabel  = widget.processLabel;
  late String? _dept         = widget.dept;
  late int?   _benchmarkTime = widget.benchmarkTime;
  late String _staffId       = widget.staffId;
  late String _staffName     = widget.staffName;
  late String _mobileNo      = widget.mobileNo;

  // ── Process / Article / Order lists (lazy-loaded) ───────────────────
  List<Map<String, String>> _processList    = [];
  List<ArticleItem>         _articleList    = [];
  List<OrderItem>           _orderList      = [];
  bool _loadingProcessList = false;
  bool _loadingArticleList = false;
  bool _loadingOrderList   = false;

  // ── Date & Shift ─────────────────────────────────────────────────────
  final DateTime _today = DateTime.now();
  String get _shift => (DateTime.now().hour >= 8 && DateTime.now().hour < 20) ? 'A' : 'B';

  String get _formattedDate {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return "${_today.day.toString().padLeft(2, '0')} ${m[_today.month - 1]} ${_today.year}";
  }

  // ── Stopwatch ─────────────────────────────────────────────────────────
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool get _isRunning => _stopwatch.isRunning;
  bool _isSaving = false;

  String get _formattedElapsed {
    final h  = _elapsed.inHours.toString().padLeft(2, '0');
    final mi = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s  = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final cs = ((_elapsed.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
    return "$h:$mi:$s.$cs";
  }

  // ── Inline scanner ────────────────────────────────────────────────────
  _ScanTarget _scanTarget = _ScanTarget.none;
  bool _scanBusy = false;
  final Set<String> _sessionCodes = {};
  MobileScannerController? _ctrl;
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  // ─────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.87, end: 1.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _stopwatch.stop();
    _ctrl?.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _ctrl?.stop();
    }
  }

  // ── Stopwatch controls ────────────────────────────────────────────────

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

  // ── Scanner controls ──────────────────────────────────────────────────

  MobileScannerController _freshController() {
    _ctrl?.dispose();
    _ctrl = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
      formats: [
        BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.code39,
        BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE,
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
    if (_scanBusy || _scanTarget == _ScanTarget.none) return;
    String? code;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) { code = v; break; }
    }
    if (code == null || _sessionCodes.contains(code)) return;
    _sessionCodes.add(code);
    _scanBusy = true;
    if (_scanTarget == _ScanTarget.line) _handleLineRescan(code);
    else _handleStaffRescan(code);
  }

  Future<void> _handleLineRescan(String qr) async {
    await _closeScanner();
    final lineId = qr.trim();
    if (lineId.isEmpty) { _showError("Invalid Line QR"); _scanBusy = false; return; }
    final result = await _lineStaffSvc.fetchLineName(lineId);
    if (!mounted) { _scanBusy = false; return; }
    if (result == null) { _showError("Invalid Line QR: $qr"); _scanBusy = false; return; }
    setState(() { _lineId = lineId; _lineName = result["LINE_NAME"] ?? "Unknown Line"; });
    _resetStopwatch();
    _showSuccess("Line changed — timer reset");
    _scanBusy = false;
  }

  Future<void> _handleStaffRescan(String rawBarcode) async {
    await _closeScanner();
    final credNo = rawBarcode.split(',').first.trim();
    final parts = rawBarcode.split(',');
    final embeddedName = parts.length > 1 ? parts[1].trim() : null;
    final staffResult = await _lineStaffSvc.fetchStaffByBarcode(credNo);
    if (!mounted) { _scanBusy = false; return; }
    String? name = staffResult?["STAFF_NAME"];
    String? staffId = staffResult?["STAFF_ID"];
    if (name == null && embeddedName != null && embeddedName.isNotEmpty) {
      name = embeddedName; staffId ??= credNo;
    }
    if (name == null || staffId == null) {
      _showError("Staff not found: $credNo"); _scanBusy = false; return;
    }
    final resolvedName = name;
    setState(() { _staffId = credNo; _staffName = resolvedName; });
    _resetStopwatch();
    _showSuccess("Staff changed — timer reset");
    _scanBusy = false;
  }

  // ── Staff change sheet ────────────────────────────────────────────────

  void _openStaffChangeSheet() {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController(text: _mobileNo);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _BottomSheetHandle(),
          const SizedBox(height: 16),
          const Text("Change Staff",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text("Scan Staff Barcode"),
              onPressed: () { Navigator.pop(ctx); _openStaffScanner(); },
            ),
          ),
          const SizedBox(height: 14),
          Row(children: const [
            Expanded(child: Divider()),
            Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text("OR", style: TextStyle(fontSize: 11, color: Colors.grey))),
            Expanded(child: Divider()),
          ]),
          const SizedBox(height: 14),
          // Staff name
          _InputRow(
            icon: Icons.badge_outlined,
            child: TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: "Write staff name", border: InputBorder.none),
            ),
          ),
          const SizedBox(height: 10),
          // Mobile No
          _InputRow(
            icon: Icons.phone_android_rounded,
            child: TextField(
              controller: mobileCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: const InputDecoration(
                  hintText: "Mobile number (max 11 digits)", border: InputBorder.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F9D58),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) { _showError("Please enter staff name"); return; }
                Navigator.pop(ctx);
                setState(() { _staffId = ''; _staffName = name; _mobileNo = mobileCtrl.text.trim(); });
                _resetStopwatch();
                _showSuccess("Staff changed — timer reset");
              },
              child: const Text("Confirm Name",
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── Mobile No edit ─────────────────────────────────────────────────────

  void _editMobileNo() {
    final ctrl = TextEditingController(text: _mobileNo);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _BottomSheetHandle(),
          const SizedBox(height: 16),
          const Text("Edit Mobile No.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 16),
          _InputRow(
            icon: Icons.phone_android_rounded,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: const InputDecoration(
                  hintText: "Mobile number (max 11 digits)", border: InputBorder.none),
            ),
          ),
          const SizedBox(height: 16),
          _ConfirmBtn(
            label: "Update",
            onTap: () {
              setState(() => _mobileNo = ctrl.text.trim());
              Navigator.pop(ctx);
              _showSuccess("Mobile number updated");
            },
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── Article change ─────────────────────────────────────────────────────

  Future<void> _openArticlePicker() async {
    if (_articleList.isEmpty && !_loadingArticleList) {
      setState(() => _loadingArticleList = true);
      try {
        final companyId = await _resolveCompanyId();
        final list = await _lineBalanceSvc.fetchArticleLov(companyId: companyId);
        if (mounted) setState(() => _articleList = list);
        if (list.isEmpty) _showError("Article list could not be loaded");
      } catch (e) {
        _showError("Failed to load articles: $e");
      } finally {
        if (mounted) setState(() => _loadingArticleList = false);
      }
    }
    if (!mounted) return;
    _showArticlePicker();
  }

  void _showArticlePicker() {
    List<ArticleItem> filtered = List.from(_articleList);
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
            _BottomSheetHandle(),
            const SizedBox(height: 12),
            const Text("Select Article",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 12),
            _SearchField(
              onChanged: (v) => setS(() {
                filtered = _articleList
                    .where((e) => e.label.toLowerCase().contains(v.toLowerCase()))
                    .toList();
              }),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text("No articles found",
                      style: TextStyle(fontSize: 14, color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        return ListTile(
                          title: Text(item.label,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: item.buyerName.isNotEmpty
                              ? Text("Buyer: ${item.buyerName}",
                                  style: const TextStyle(fontSize: 11, color: Colors.grey))
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _articleId = item.id;
                              _articleLabel = item.label;
                              _buyerName = item.buyerName;
                              _orderId = '';
                              _orderLabel = '';
                              _orderList = [];
                            });
                            _resetStopwatch();
                            _showSuccess("Article changed — timer reset");
                          },
                        );
                      }),
            ),
          ]),
        );
      }),
    );
  }

  // ── Order change ───────────────────────────────────────────────────────

  Future<void> _openOrderPicker() async {
    if (_articleId.isEmpty) { _showError("Select an article first"); return; }
    if (_orderList.isEmpty && !_loadingOrderList) {
      setState(() => _loadingOrderList = true);
      try {
        final companyId = await _resolveCompanyId();
        final list = await _lineBalanceSvc.fetchOrdersByArticle(
            companyId: companyId, articleId: _articleId);
        if (mounted) setState(() => _orderList = list);
        if (list.isEmpty) _showError("No orders found for this article");
      } catch (e) {
        _showError("Failed to load orders: $e");
      } finally {
        if (mounted) setState(() => _loadingOrderList = false);
      }
    }
    if (!mounted) return;
    _showOrderPicker();
  }

  void _showOrderPicker() {
    List<OrderItem> filtered = List.from(_orderList);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (c, setS) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(children: [
            _BottomSheetHandle(),
            const SizedBox(height: 12),
            const Text("Select Order No.",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 4),
            Text("Article: $_articleLabel",
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 12),
            _SearchField(
              onChanged: (v) => setS(() {
                filtered = _orderList
                    .where((e) => e.label.toLowerCase().contains(v.toLowerCase()))
                    .toList();
              }),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text("No orders found",
                      style: TextStyle(fontSize: 14, color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        return ListTile(
                          leading: const Icon(Icons.receipt_long_outlined,
                              size: 18, color: Color(0xFF1A73E8)),
                          title: Text(item.label,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() { _orderId = item.id; _orderLabel = item.label; });
                            _resetStopwatch();
                            _showSuccess("Order changed — timer reset");
                          },
                        );
                      }),
            ),
          ]),
        );
      }),
    );
  }

  // ── Process change ─────────────────────────────────────────────────────

  Future<void> _openProcessPicker() async {
    if (_processList.isEmpty && !_loadingProcessList) {
      setState(() => _loadingProcessList = true);
      try {
        final companyId = await _resolveCompanyId();
        final list = await _lineBalanceSvc.fetchProcessLov(companyId: companyId);
        if (mounted) setState(() => _processList = list);
        if (list.isEmpty) _showError("Process list could not be loaded");
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
            _BottomSheetHandle(),
            const SizedBox(height: 12),
            const Text("Select Process",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 12),
            _SearchField(
              onChanged: (v) => setS(() {
                filtered = _processList
                    .where((e) => e["label"]!.toLowerCase().contains(v.toLowerCase()))
                    .toList();
              }),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text("No processes found",
                      style: TextStyle(fontSize: 14, color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        return ListTile(
                          title: Text(item["label"]!,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          onTap: () {
                            setState(() {
                              _processId = item["id"]!;
                              _processLabel = item["label"]!;
                              _dept = item["dept"];
                            });
                            Navigator.pop(ctx);
                            _resetStopwatch();
                            _showSuccess("Process changed — timer reset");
                          },
                        );
                      }),
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
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _BottomSheetHandle(),
          const SizedBox(height: 16),
          const Text("Edit Benchmark Time",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 6),
          Text("Process: $_processLabel",
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          _InputRow(
            icon: Icons.timer_outlined,
            suffix: const Text("sec", style: TextStyle(color: Colors.grey, fontSize: 13)),
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: "Enter benchmark time (seconds)", border: InputBorder.none),
            ),
          ),
          const SizedBox(height: 16),
          _ConfirmBtn(
            label: "Update",
            onTap: () {
              setState(() => _benchmarkTime = int.tryParse(ctrl.text.trim()));
              Navigator.pop(ctx);
              _showSuccess("Benchmark updated");
            },
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── Save ───────────────────────────────────────────────────────────────

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
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF1A73E8), Color(0xFF1557B0)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(color: Color(0xFFEEF4FF), shape: BoxShape.circle),
                  child: const Icon(Icons.save_rounded, color: Color(0xFF1A73E8), size: 28),
                ),
                const SizedBox(height: 16),
                const Text("Save Entry?",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87)),
                const SizedBox(height: 8),
                Text(
                  "Elapsed time: $_formattedElapsed\nDo you want to save this entry?",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
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
                            borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: const Text("Cancel",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
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
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: const Color(0xFF1A73E8).withValues(alpha: 0.35),
                              blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        alignment: Alignment.center,
                        child: const Text("Save",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
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
    if (ok == true) await _handleSave();
  }

  Future<void> _handleSave() async {
    if (_elapsed == Duration.zero) {
      _showError("Please run the stopwatch before saving");
      return;
    }
    setState(() => _isSaving = true);
    try {
      final companyId = await _resolveCompanyId();
      final errorMsg = await _lineBalanceSvc.saveLineBalance(
        lineId: _lineId,
        processId: _processId,
        elapsedSeconds: _elapsed.inMilliseconds / 1000.0,
        appUserId: widget.appUserId,
        companyId: companyId,
        mobileNo: _mobileNo,
        benchmarkTime: _benchmarkTime,
        staffId: _staffId.isNotEmpty ? _staffId : null,
        staffName: _staffId.isEmpty ? _staffName : null,
        orderNo: _orderLabel.isNotEmpty ? _orderLabel : null,
        article: _articleLabel.isNotEmpty ? _articleLabel : null,
        biiId: _articleId.isNotEmpty ? _articleId : null,
        dept: _dept,
      );
      if (!mounted) return;
      if (errorMsg != null) { _showError(errorMsg); return; }
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
      content: Text(msg), backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────

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
                    // ── Compact top strip: Date · Shift · View Lists
                    _buildTopStrip(),
                    const SizedBox(height: 10),
                    _buildHeader(scanLocked: camVisible),
                    const SizedBox(height: 10),
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
                      const SizedBox(height: 10),
                    ],
                    _buildStopwatch(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _buildHeader({required bool scanLocked}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1A73E8), Color(0xFF1557B0)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1A73E8).withValues(alpha: 0.30),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
            child: const Icon(Icons.timer_outlined, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text("Time Study",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 0.2))),
        ]),
        const SizedBox(height: 10),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
        const SizedBox(height: 8),
        _TappableChip(icon: Icons.view_timeline_rounded, label: "Line",
            value: _lineName, onTap: scanLocked ? null : _openLineScanner),
        const SizedBox(height: 6),
        _TappableChip(icon: Icons.article_outlined, label: "Article",
            value: _articleLabel.isNotEmpty ? _articleLabel : "—",
            onTap: scanLocked ? null : _openArticlePicker),
        const SizedBox(height: 6),
        _TappableChip(icon: Icons.receipt_long_outlined, label: "Order No.",
            value: _orderLabel.isNotEmpty ? _orderLabel : "—",
            onTap: scanLocked ? null : _openOrderPicker),
        const SizedBox(height: 6),
        _TappableChip(icon: Icons.tune_rounded, label: "Process",
            value: _processLabel, onTap: scanLocked ? null : _openProcessPicker),
        const SizedBox(height: 6),
        _TappableChip(icon: Icons.timer_outlined, label: "Benchmark",
            value: _benchmarkTime != null ? "$_benchmarkTime sec" : "—",
            onTap: scanLocked ? null : _showBenchmarkEdit),
        const SizedBox(height: 6),
        _TappableChip(icon: Icons.badge_rounded, label: "Staff",
            value: _staffName, onTap: scanLocked ? null : _openStaffChangeSheet),
        const SizedBox(height: 6),
        _TappableChip(icon: Icons.phone_android_rounded, label: "Mobile No.",
            value: _mobileNo.isNotEmpty ? _mobileNo : "—",
            onTap: scanLocked ? null : _editMobileNo),
      ]),
    );
  }

  // ── Compact top strip (Date · Shift · View Lists) ───────────────────

  Widget _buildTopStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(_formattedDate,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87)),
        const SizedBox(width: 14),
        Container(width: 1, height: 14, color: Colors.grey.shade300),
        const SizedBox(width: 14),
        Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text("Shift $_shift",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87)),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TimeReportPage())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.list_alt_rounded, size: 14, color: Color(0xFF1A73E8)),
              SizedBox(width: 5),
              Text("Lists",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: Color(0xFF1A73E8))),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Stopwatch ─────────────────────────────────────────────────────────

  Widget _buildStopwatch() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Text(_formattedElapsed,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900,
                color: Colors.black87, letterSpacing: 1.0,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _StopwatchBtn(
            icon: _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: _isRunning ? "Stop" : "Start",
            colors: _isRunning
                ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                : [const Color(0xFF0F9D58), const Color(0xFF0B8043)],
            onTap: _isRunning ? _stopStopwatch : _startStopwatch,
          ),
          const SizedBox(width: 12),
          _StopwatchBtn(
            icon: Icons.refresh_rounded, label: "Reset",
            colors: [Colors.grey.shade400, Colors.grey.shade500],
            onTap: _resetStopwatch,
          ),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// WIDGETS
// ══════════════════════════════════════════════════════════════════════

class _TappableChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? badge;
  const _TappableChip({required this.icon, required this.label,
      required this.value, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 15),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(label,
                  style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.60),
                      fontWeight: FontWeight.w700, letterSpacing: 0.4)),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(badge!,
                      style: const TextStyle(fontSize: 8, color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
            Text(value,
                style: const TextStyle(fontSize: 12, color: Colors.white,
                    fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis),
          ])),
          if (!disabled)
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFFFBBC05).withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFBBC05).withValues(alpha: 0.4), width: 1),
              ),
              child: const Icon(Icons.edit_rounded, color: Color(0xFFFBBC05), size: 13),
            ),
        ]),
      ),
    );
  }
}

class _StopwatchBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;
  const _StopwatchBtn({required this.icon, required this.label,
      required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.35),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

// ── Camera viewport ───────────────────────────────────────────────────

class _Viewport extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture)? onDetect;
  final Animation<double> pulseAnim;
  final String label;
  final VoidCallback onCancel;
  const _Viewport({required this.controller, required this.onDetect,
      required this.pulseAnim, required this.label, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Stack(fit: StackFit.expand, children: [
        MobileScanner(controller: controller, onDetect: onDetect),
        IgnorePointer(child: CustomPaint(painter: _OverlayP())),
        IgnorePointer(child: Center(child: AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: pulseAnim.value,
            child: SizedBox(width: 280, height: 190, child: CustomPaint(painter: _BracketsP())),
          ),
        ))),
        Positioned(top: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(gradient: LinearGradient(
                colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            child: Row(children: [
              const Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white70)),
                SizedBox(width: 8),
                Text("Scanning...",
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
              ])),
              GestureDetector(onTap: onCancel,
                  child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20)),
            ]),
          ),
        ),
        Positioned(bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.68)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.crop_free_rounded, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────

class _BottomSheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 40, height: 4,
    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
  );
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        onChanged: onChanged,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, color: Colors.black54),
          hintText: "Search...",
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  final IconData icon;
  final Widget child;
  final Widget? suffix;
  const _InputRow({required this.icon, required this.child, this.suffix});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.grey, size: 18),
        const SizedBox(width: 10),
        Expanded(child: child),
        if (suffix != null) suffix!,
      ]),
    );
  }
}

class _ConfirmBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ConfirmBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A73E8),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ),
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
            Rect.fromLTWH((size.width - cw) / 2, (size.height - ch) / 2, cw, ch),
            const Radius.circular(12)))
        ..fillType = PathFillType.evenOdd,
      p,
    );
  }
  @override bool shouldRepaint(_) => false;
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
    canvas.drawPath(Path()..moveTo(0, l)..lineTo(0, 5)..arcToPoint(const Offset(5, 0), radius: r)..lineTo(l, 0), p);
    canvas.drawPath(Path()..moveTo(size.width - l, 0)..lineTo(size.width - 5, 0)..arcToPoint(Offset(size.width, 5), radius: r)..lineTo(size.width, l), p);
    canvas.drawPath(Path()..moveTo(0, size.height - l)..lineTo(0, size.height - 5)..arcToPoint(Offset(5, size.height), radius: r)..lineTo(l, size.height), p);
    canvas.drawPath(Path()..moveTo(size.width - l, size.height)..lineTo(size.width - 5, size.height)..arcToPoint(Offset(size.width, size.height - 5), radius: r)..lineTo(size.width, size.height - l), p);
  }
  @override bool shouldRepaint(_) => false;
}