import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackall_app/pages/widgets/top_menu_bar.dart';
import 'package:trackall_app/pages/widgets/loading_indicator.dart';
import 'package:trackall_app/services/lov_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:http/http.dart' as http;

// =====================================================================
// SCROLLABLE OVERFLOW TEXT WIDGET
// =====================================================================

class OverflowScrollText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final EdgeInsetsGeometry padding;

  const OverflowScrollText({
    super.key,
    required this.text,
    required this.style,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  @override
  State<OverflowScrollText> createState() => _OverflowScrollTextState();
}

class _OverflowScrollTextState extends State<OverflowScrollText> {
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
  void didUpdateWidget(OverflowScrollText oldWidget) {
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
      duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  void _scrollLeft() => _scrollCtrl.animateTo(0,
      duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  @override
  void dispose() { _scrollCtrl.dispose(); super.dispose(); }

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
                _isScrolled ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                size: 18, color: const Color(0xFF1A73E8),
              ),
            ),
          ),
      ],
    );
  }
}

// =====================================================================
// QC ENTRY PAGE
// =====================================================================

class QCEntryPage extends StatefulWidget {
  const QCEntryPage({super.key});

  @override
  State<QCEntryPage> createState() => _QCEntryPageState();
}

class _QCEntryPageState extends State<QCEntryPage> {
  final LovService _lovService = LovService();

  String? itemId, itemLabel, jobNo, orderNo, articleNo;
  String? processId, processLabel, lineId, lineLabel;
  String? qcType, qcTypeLabel, size, sizeId, issueType, issueTypeId;
  String? checkedBy, checkedById;
  String? quantity;

  final TextEditingController quantityController = TextEditingController();
  int quantityValue = 0;
  String? side;

  File? capturedImageFile;
  String? capturedImagePath;
  Uint8List? capturedImageBytes;

  Map<String, String>? selectedItemMap;
  String? appUser;
  bool isLoading = false;

  List<Map<String, String>> itemList = [];
  List<Map<String, String>> processList = [];
  List<Map<String, String>> lineList = [];
  List<Map<String, String>> qcTypeList = [];
  List<Map<String, String>> sizeList = [];
  List<Map<String, String>> issueTypeList = [];
  List<Map<String, String>> checkerList = [];

  int itemDisplayCount = 10;
  int processDisplayCount = 10;
  int lineDisplayCount = 10;
  int qcTypeDisplayCount = 10;
  int sizeDisplayCount = 10;
  int issueTypeDisplayCount = 10;
  int checkerDisplayCount = 10;

  final List<Map<String, String>> sideList = [
    {"id": "RIGHT", "label": "Right"},
    {"id": "LEFT",  "label": "Left"},
  ];

  bool get hasImage => capturedImageFile != null || capturedImageBytes != null;

  @override
  void initState() { super.initState(); _loadAppUser(); }

  Future<void> _loadAppUser() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    setState(() => appUser = prefs.getString('userId') ?? "");
    await Future.wait([_loadItems(), _loadQcTypes(), _loadCheckers()]);
    setState(() => isLoading = false);
  }

  Future<void> _loadCheckers() async {
    if (appUser == null || appUser!.isEmpty) return;
    try {
      final data = await _lovService.fetchLov(qryType: "RESP_USER", appUserId: appUser!);
      setState(() { checkerList = data; checkerDisplayCount = 10; });
    } catch (e) { debugPrint("❌ Error loading checkers: $e"); }
  }

  Future<void> _loadItems() async {
    try {
      final data = await _lovService.fetchQcLov(qryType: "QC_BII");
      setState(() { itemList = data; itemDisplayCount = 10; });
    } catch (e) { _showError("Failed to load items"); }
  }

  Future<void> _loadProcess() async {
    if (itemId == null || itemId!.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final data = await _lovService.fetchQcLov(
          qryType: "QC_PROCESS", biiId: itemId, appUserId: appUser);
      setState(() {
        processList = data; processDisplayCount = 10;
        processId = null; processLabel = null;
        lineList.clear(); lineId = null; lineLabel = null;
      });
    } catch (e) { _showError("Failed to load process list"); }
    finally { setState(() => isLoading = false); }
  }

  Future<void> _loadLine() async {
    if (processId == null || processId!.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final data = await _lovService.fetchQcLov(
          qryType: "QC_LINE", processId: processId, appUserId: appUser);
      setState(() { lineList = data; lineDisplayCount = 10; lineId = null; lineLabel = null; });
    } catch (e) { _showError("Failed to load line list"); }
    finally { setState(() => isLoading = false); }
  }

  Future<void> _loadQcTypes() async {
    try {
      final data = await _lovService.fetchQcLov(qryType: "QC_TYPE");
      setState(() { qcTypeList = data; qcTypeDisplayCount = 10; });
    } catch (e) { _showError("Failed to load QC types"); }
  }

  Future<void> _loadSizes() async {
    if (itemId == null || itemId!.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final data = await _lovService.fetchQcLov(qryType: "QC_SIZE", biiId: itemId);
      data.sort((a, b) {
        final aS = num.tryParse(a['label'] ?? '0') ?? 0;
        final bS = num.tryParse(b['label'] ?? '0') ?? 0;
        return aS.compareTo(bS);
      });
      setState(() { sizeList = data; sizeDisplayCount = 10; });
    } catch (e) { _showError("Failed to load sizes"); }
    finally { setState(() => isLoading = false); }
  }

  Future<void> _loadIssues() async {
    if (qcType == null || qcType!.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final data = await _lovService.fetchQcLov(qryType: "QC_ISSUE", qcType: qcType);
      setState(() { issueTypeList = data; issueTypeDisplayCount = 10; });
    } catch (e) { _showError("Failed to load issue types"); }
    finally { setState(() => isLoading = false); }
  }

  Future<void> _loadJobNo() async {
    if (itemId == null || itemId?.isEmpty == true) { setState(() => jobNo = ""); return; }
    setState(() => isLoading = true);
    try {
      final data = await _lovService.fetchQcLov(qryType: "QC_JOB", biiId: itemId);
      setState(() => jobNo = data.isNotEmpty
          ? (data.first["label"] ?? data.first["JOB_NO"] ?? "") : "");
    } catch (e) { setState(() => jobNo = ""); }
    finally { setState(() => isLoading = false); }
  }

  // ── Clear all ──────────────────────────────────────────────────────
  void _clearAll() {
    setState(() {
      itemId = null;       itemLabel = null;
      jobNo = null;        orderNo = null;       articleNo = null;
      processId = null;    processLabel = null;
      lineId = null;       lineLabel = null;
      qcType = null;       qcTypeLabel = null;
      size = null;         sizeId = null;
      issueType = null;    issueTypeId = null;
      checkedBy = null;    checkedById = null;
      side = null;
      quantity = null;     quantityValue = 0;
      quantityController.clear();
      capturedImageFile = null;
      capturedImagePath = null;
      capturedImageBytes = null;
      selectedItemMap = null;
      processList.clear(); lineList.clear();
      sizeList.clear();    issueTypeList.clear();
    });
    _loadItems();
  }

  Future<void> _captureImage() async {
    try {
      PermissionStatus status = await Permission.camera.status;
      if (!status.isGranted) status = await Permission.camera.request();
      if (status.isDenied) { _showError("Camera permission denied"); return; }
      if (status.isPermanentlyDenied) {
        _showError("Camera permission permanently denied. Please enable it in settings.");
        await openAppSettings(); return;
      }
      if (status.isGranted) {
        final result = await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const CameraScreen()));
        if (result != null) {
          if (kIsWeb && result is Map) {
            setState(() {
              capturedImagePath  = result['path'];
              capturedImageBytes = result['bytes'];
              capturedImageFile  = null;
            });
            _showSuccess("Image captured successfully");
          } else if (result is String) {
            setState(() {
              capturedImageFile  = File(result);
              capturedImagePath  = result;
              capturedImageBytes = null;
            });
            _showSuccess("Image captured successfully");
          }
        }
      }
    } catch (e) { _showError("Failed to open camera: $e"); }
  }

  void _removeImage() {
    setState(() { capturedImageFile = null; capturedImagePath = null; capturedImageBytes = null; });
    _showSuccess("Image removed");
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message), backgroundColor: Colors.red,
        duration: const Duration(seconds: 3)));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message), backgroundColor: Colors.green,
        duration: const Duration(seconds: 2)));
  }

  Future<void> _handleSave() async {
    if (itemId == null || itemId!.isEmpty)       { _showError("Please select an item"); return; }
    if (jobNo == null || jobNo!.isEmpty)          { _showError("Job No is required."); return; }
    if (orderNo == null || orderNo!.isEmpty)      { _showError("Order No is required."); return; }
    if (articleNo == null || articleNo!.isEmpty)  { _showError("Article No is required."); return; }
    if (processId == null || processId!.isEmpty)  { _showError("Please select a process"); return; }
    if (lineId == null || lineId!.isEmpty)        { _showError("Please select a line"); return; }
    if (qcType == null || qcType!.isEmpty)        { _showError("Please select QC type"); return; }
    if (qcType == "REJECT" && (size == null || size!.isEmpty)) {
      _showError("Please select a size for reject entries"); return;
    }
    if (issueType == null || issueType!.isEmpty)  { _showError("Please select an issue type"); return; }
    if (side == null || side!.isEmpty)            { _showError("Please select side"); return; }
    if (quantity == null || quantity!.isEmpty)    { _showError("Please enter quantity"); return; }
    final qtyValue = int.tryParse(quantity!) ?? 0;
    if (qtyValue <= 0)                            { _showError("Quantity must be greater than 0"); return; }
    if (checkedBy == null || checkedBy!.isEmpty)  { _showError("Please select checker"); return; }

    setState(() => isLoading = true);
    try {
      final success = await _lovService.saveQcEntry(
        biiId: itemId!, jobNo: jobNo!, orderNo: orderNo!, articleNo: articleNo!,
        processId: processId!, lineId: lineId!, qcType: qcType!,
        sizeId: sizeId, size: size, issueTypeId: issueTypeId!,
        side: side!, quantity: quantity ?? "0", checkedById: checkedById!,
        appUserId: appUser!, imagePath: capturedImagePath,
        mobileImageFile: capturedImageFile, webImageBytes: capturedImageBytes,
      );
      if (!mounted) return;
      setState(() => isLoading = false);
      if (success) {
        _showSuccess("QC Entry Saved Successfully");
        setState(() {
          quantity = null; quantityValue = 0; quantityController.clear();
          capturedImageFile = null; capturedImagePath = null; capturedImageBytes = null;
        });
      } else {
        _showError("Database rejected the entry. Check your network or permissions.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      String msg = e.toString();
      if (msg.contains("Failed to fetch"))
        msg = "Network Error: Browser blocked the request (CORS) or Server is down.";
      _showError(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: Stack(
        children: [
          Column(
            children: [
              const TopMenuBar(),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final width = (constraints.maxWidth - 44) / 2;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [

                        // ── ITEM + CLEAR label row ────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text("Item / Color *",
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black)),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: _clearAll,
                                    icon: const Icon(Icons.refresh_rounded, size: 13),
                                    label: const Text("Clear",
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red.shade400,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 2),
                                      backgroundColor: Colors.red.shade50,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20)),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () => _itemTableDialog(
                                  context, "Item / Color *",
                                  itemList, itemDisplayCount,
                                  (id, label) async {
                                    setState(() {
                                      itemId = id; itemLabel = label;
                                      selectedItemMap = itemList.firstWhere(
                                          (item) => item['id'] == id, orElse: () => {});
                                      orderNo  = selectedItemMap?["BPO_PO_NO"] ?? "";
                                      articleNo = selectedItemMap?["STYLE_NO"] ?? "";
                                      processList.clear(); processId = null; processLabel = null;
                                      lineList.clear(); lineId = null; lineLabel = null;
                                      sizeList.clear(); size = null; sizeId = null;
                                      issueTypeList.clear(); issueType = null; issueTypeId = null;
                                    });
                                    await _loadJobNo();
                                    _loadProcess(); _loadSizes();
                                  },
                                ),
                                child: Container(
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                    boxShadow: const [BoxShadow(
                                        color: Color(0x0F000000),
                                        blurRadius: 4, offset: Offset(0, 2))],
                                  ),
                                  child: Row(children: [
                                    Expanded(
                                      child: OverflowScrollText(
                                        text: itemLabel ?? "Select",
                                        style: const TextStyle(fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Icon(Icons.arrow_drop_down,
                                          color: Colors.black87, size: 20),
                                    ),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── JOB + ORDER ────────────────────────────────
                        Row(children: [
                          Expanded(child: _readOnly("Job No", jobNo, double.infinity)),
                          const SizedBox(width: 12),
                          Expanded(child: _readOnly("Order No", orderNo, double.infinity)),
                        ]),

                        // ── ARTICLE ────────────────────────────────────
                        _readOnly("Article No", articleNo, double.infinity),

                        _modernDropdown(context, "Process *", processLabel,
                            processList, processDisplayCount, (id, label) {
                          setState(() {
                            processId = id; processLabel = label;
                            lineList.clear(); lineId = null; lineLabel = null;
                          });
                          _loadLine();
                        }, width),

                        _modernDropdown(context, "Line No *", lineLabel,
                            lineList, lineDisplayCount, (id, label) {
                          setState(() { lineId = id; lineLabel = label; });
                        }, width),

                        _modernDropdown(context, "QC Type *", qcTypeLabel,
                            qcTypeList, qcTypeDisplayCount, (id, label) {
                          setState(() {
                            qcType = id; qcTypeLabel = label;
                            issueTypeList.clear(); issueType = null; issueTypeId = null;
                          });
                          _loadIssues();
                        }, width),

                        if (qcTypeLabel != null &&
                            qcTypeLabel!.toLowerCase().contains("reject"))
                          _modernDropdown(context, "Size *", size,
                              sizeList, sizeDisplayCount, (id, label) {
                            setState(() { sizeId = id; size = label; });
                          }, width),

                        _modernDropdown(context, "Issue Type *", issueType,
                            issueTypeList, issueTypeDisplayCount, (id, label) {
                          setState(() { issueTypeId = id; issueType = label; });
                        }, width),

                        _modernDropdown(context, "Side *", side,
                            sideList, sideList.length, (id, label) {
                          setState(() => side = id);
                        }, width),

                        _quantityField(width),

                        _modernDropdown(context, "Checked By *", checkedBy,
                            checkerList, checkerDisplayCount, (id, label) {
                          setState(() { checkedById = id; checkedBy = label; });
                        }, width),

                        // ── IMAGE ──────────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Capture Image",
                                  style: TextStyle(fontSize: 11,
                                      fontWeight: FontWeight.w800, color: Colors.black)),
                              const SizedBox(height: 8),
                              if (hasImage)
                                Stack(children: [
                                  Container(
                                    height: 200, width: double.infinity,
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey.shade300, width: 2)),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: kIsWeb
                                          ? (capturedImageBytes != null
                                              ? Image.memory(capturedImageBytes!, fit: BoxFit.cover)
                                              : const Center(child: Text("No image")))
                                          : (capturedImageFile != null
                                              ? Image.file(capturedImageFile!, fit: BoxFit.cover)
                                              : const Center(child: Text("No image"))),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8, right: 8,
                                    child: IconButton(
                                      onPressed: _removeImage,
                                      icon: const Icon(Icons.close),
                                      style: IconButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white),
                                    ),
                                  ),
                                ])
                              else
                                InkWell(
                                  onTap: _captureImage,
                                  child: Container(
                                    height: 120, width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFF1A73E8),
                                          width: 2, style: BorderStyle.solid),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt, size: 48,
                                            color: Color(0xFF1A73E8)),
                                        SizedBox(height: 8),
                                        Text("Tap to capture image",
                                            style: TextStyle(fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1A73E8))),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // ── SAVE ──────────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _handleSave,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: const Color(0xFF1A73E8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              disabledBackgroundColor: Colors.grey,
                              elevation: 2,
                            ),
                            child: Text(isLoading ? "LOADING..." : "SAVE",
                                style: const TextStyle(fontWeight: FontWeight.w900,
                                    color: Colors.white, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
          if (isLoading) const LoadingOverlay(),
        ],
      ),
    );
  }

  // ===================== WIDGET HELPERS =====================

  Widget _readOnly(String label, String? value, double width) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 4),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EAED),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: OverflowScrollText(
            text: value ?? "-",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
        ),
      ]),
    );
  }

  Widget _modernDropdown(
    BuildContext context, String label, String? value,
    List<Map<String, String>> list, int displayCount,
    void Function(String, String) onSelect, double width,
  ) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _searchDialog(context, label, list, displayCount, onSelect),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: const [BoxShadow(
                  color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Row(children: [
              Expanded(
                child: OverflowScrollText(
                  text: value ?? "Select",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.arrow_drop_down, color: Colors.black87, size: 20),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _quantityField(double width) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Quantity *", style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF1A73E8).withValues(alpha: 0.25), width: 1.2),
            boxShadow: const [BoxShadow(
                color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Center(
            child: TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A), letterSpacing: 0.5),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                border: InputBorder.none, isDense: true,
                contentPadding: EdgeInsets.zero, hintText: "0",
                hintStyle: TextStyle(
                    color: Colors.grey.shade400, fontWeight: FontWeight.w600),
              ),
              onChanged: (v) => setState(() {
                quantityValue = int.tryParse(v) ?? 0;
                quantity = v.isEmpty ? null : v;
              }),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _qtyIcon(icon: Icons.remove, size: 16, boxSize: 30,
              isDisabled: quantityValue == 0,
              onTap: () {
                if (quantityValue > 0) setState(() {
                  quantityValue--;
                  quantityController.text = quantityValue.toString();
                  quantity = quantityController.text;
                });
              }),
            _qtyIcon(icon: Icons.add, size: 16, boxSize: 30,
              onTap: () => setState(() {
                quantityValue++;
                quantityController.text = quantityValue.toString();
                quantity = quantityController.text;
              })),
          ],
        ),
      ]),
    );
  }

  Widget _qtyIcon({
    required IconData icon, required VoidCallback onTap,
    bool isDisabled = false, double size = 18, double boxSize = 36,
  }) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: boxSize, height: boxSize,
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey.shade200 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isDisabled ? Colors.grey.shade300 : Colors.grey.shade400),
        ),
        child: Icon(icon, size: size,
            color: isDisabled ? Colors.grey : Colors.black87),
      ),
    );
  }

  void _itemTableDialog(
    BuildContext context, String title,
    List<Map<String, String>> items, int displayCount,
    void Function(String, String) onSelect,
  ) {
    List<Map<String, String>> filtered = List.from(items);
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => StatefulBuilder(builder: (c, setS) {
        int cnt = items.length < 10 ? items.length : 10;
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text("Select $title", style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 12),
            Container(
              height: 45, padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300)),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setS(() {
                  final q = v.toLowerCase();
                  filtered = items.where((e) =>
                      (e["label"] ?? "").toLowerCase().contains(q) ||
                      (e["BPO_PO_NO"] ?? "").toLowerCase().contains(q) ||
                      (e["STYLE_NO"]  ?? "").toLowerCase().contains(q)).toList();
                  cnt = 10;
                }),
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.black54),
                    hintText: "Search by color, order no, or article...",
                    border: InputBorder.none),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: const BoxDecoration(color: Color(0xFF1A73E8),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
              child: const Row(children: [
                Expanded(flex: 2, child: Text("Color/Item Desc",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white))),
                SizedBox(width: 8),
                Expanded(flex: 1, child: Text("Order No.",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white))),
                SizedBox(width: 8),
                Expanded(flex: 1, child: Text("Article Name",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white))),
              ]),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8))),
                child: filtered.isEmpty
                    ? const Center(child: Text("No items found",
                        style: TextStyle(fontSize: 14, color: Colors.grey)))
                    : StatefulBuilder(builder: (context, setMS) {
                        return ListView.builder(
                          itemCount: cnt < filtered.length ? cnt + 1 : filtered.length,
                          itemBuilder: (_, idx) {
                            if (idx == cnt && cnt < filtered.length) {
                              return Center(child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: ElevatedButton(
                                  onPressed: () => setMS(() => cnt += 10),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A73E8),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    minimumSize: Size.zero),
                                  child: const Text('Show More', style: TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ));
                            }
                            final item = filtered[idx];
                            return InkWell(
                              onTap: () { onSelect(item["id"] ?? "", item["label"] ?? ""); Navigator.pop(context); },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                decoration: BoxDecoration(border: Border(
                                    bottom: BorderSide(color: Colors.grey.shade300))),
                                child: Row(children: [
                                  Expanded(flex: 2, child: Text(item["label"] ?? "",
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                                      overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 8),
                                  Expanded(flex: 1, child: Text(item["BPO_PO_NO"] ?? "-",
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
                                      overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 8),
                                  Expanded(flex: 1, child: Text(item["STYLE_NO"] ?? "-",
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
                                      overflow: TextOverflow.ellipsis)),
                                ]),
                              ),
                            );
                          },
                        );
                      }),
              ),
            ),
          ]),
        );
      }),
    );
  }

  void _searchDialog(
    BuildContext context, String title,
    List<Map<String, String>> items, int displayCount,
    void Function(String, String) onSelect,
  ) {
    List<Map<String, String>> filtered = List.from(items);
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => StatefulBuilder(builder: (c, setS) {
        int cnt = items.length < 10 ? items.length : 10;
        return Container(
          height: MediaQuery.of(context).size.height * 0.80,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text("Select $title", style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 12),
            Container(
              height: 45, padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300)),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setS(() {
                  filtered = items.where((e) =>
                      (e["label"] ?? "").toLowerCase().contains(v.toLowerCase())).toList();
                  cnt = 10;
                }),
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.black54),
                    hintText: "Search...", border: InputBorder.none),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text("No items found",
                      style: TextStyle(fontSize: 14, color: Colors.grey)))
                  : StatefulBuilder(builder: (context, setMS) {
                      return ListView.builder(
                        itemCount: cnt < filtered.length ? cnt + 1 : filtered.length,
                        itemBuilder: (context, idx) {
                          if (idx == cnt && cnt < filtered.length) {
                            return Center(child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: ElevatedButton(
                                onPressed: () => setMS(() => cnt += 10),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A73E8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  minimumSize: Size.zero),
                                child: const Text('Show More', style: TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ));
                          }
                          final item = filtered[idx];
                          return ListTile(
                            title: Text(item["label"] ?? "", style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                            onTap: () { onSelect(item["id"] ?? "", item["label"] ?? ""); Navigator.pop(context); },
                          );
                        },
                      );
                    }),
            ),
          ]),
        );
      }),
    );
  }
}

// ===================== CAMERA SCREEN =====================
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;

  @override
  void initState() { super.initState(); _initializeCamera(); }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;
      _controller = CameraController(_cameras![0], ResolutionPreset.high,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await _controller!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) { debugPrint("❌ Camera initialization error: $e"); }
  }

  @override
  void dispose() { _controller?.dispose(); super.dispose(); }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final XFile image = await _controller!.takePicture();
      if (kIsWeb) {
        try {
          final response = await http.get(Uri.parse(image.path));
          final bytes = response.bodyBytes;
          if (bytes.isEmpty) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Failed to capture image - empty data"), backgroundColor: Colors.red));
            return;
          }
          if (mounted) Navigator.pop(context, {'path': image.path, 'bytes': bytes});
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Failed to read image: $e"), backgroundColor: Colors.red));
        }
      } else {
        try {
          final directory = await getApplicationDocumentsDirectory();
          final String ts = DateTime.now().millisecondsSinceEpoch.toString();
          final String filePath = path.join(directory.path, 'qc_$ts.jpg');
          await File(image.path).copy(filePath);
          if (mounted) Navigator.pop(context, filePath);
        } catch (_) {
          if (mounted) Navigator.pop(context, image.path);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Failed to take picture: $e"), backgroundColor: Colors.red,
          duration: const Duration(seconds: 2)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Scaffold(backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: CameraPreview(_controller!)),
        Positioned(top: 40, left: 16,
            child: IconButton(onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 32))),
        Positioned(
          bottom: 40, left: 0, right: 0,
          child: Center(child: GestureDetector(
            onTap: _takePicture,
            child: Container(
              width: 70, height: 70,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4)),
              child: Container(margin: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle)),
            ),
          )),
        ),
      ]),
    );
  }
}