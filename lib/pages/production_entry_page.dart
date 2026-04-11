import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackall_app/pages/widgets/top_menu_bar.dart';
import 'package:trackall_app/services/lov_service.dart';

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
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final available = renderBox.size.width - 20 - 24;
    setState(() => _isOverflowing = tp.width > available);
  }

  void _scrollRight() {
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollLeft() {
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

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
// PRODUCTION ENTRY PAGE  (Menu ID: 11)
// =====================================================================

class ProductionEntryPage extends StatefulWidget {
  const ProductionEntryPage({super.key});

  @override
  State<ProductionEntryPage> createState() => _ProductionEntryPageState();
}

class _ProductionEntryPageState extends State<ProductionEntryPage> {
  final LovService _lovService = LovService();

  String? itemId, itemLabel, jobNo, orderNo, articleNo;
  String? bpoId;
  String? processId, processLabel, lineId, lineLabel;
  String? sizeId, size;
  String? remainingQty = "0";

  final TextEditingController productionQtyController = TextEditingController();
  int productionQtyValue = 0;
  String? productionQty;

  int bundleQtyValue = 1;
  String? bundleQty = "1";
  final TextEditingController bundleQtyController =
      TextEditingController(text: "1");

  int rejectQtyValue = 0;
  String? rejectQty = "0";
  final TextEditingController rejectQtyController =
      TextEditingController(text: "0");

  String? flag = "I";

  Map<String, String>? selectedItemMap;
  String? appUser;
  bool isLoading = false;

  List<Map<String, String>> itemList = [];
  List<Map<String, String>> processList = [];
  List<Map<String, String>> lineList = [];
  List<Map<String, String>> sizeList = [];

  int itemDisplayCount = 10;
  int processDisplayCount = 10;
  int lineDisplayCount = 10;
  int sizeDisplayCount = 10;

  final List<Map<String, String>> flagList = [
    {"id": "I", "label": "Internal"},
    {"id": "E", "label": "External"},
  ];

  @override
  void initState() {
    super.initState();
    _loadAppUser();
  }

  Future<void> _loadAppUser() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('userId') ?? "";
    setState(() => appUser = user);
    await Future.wait([_loadItems()]);
    setState(() => isLoading = false);
  }

  Future<void> _loadItems() async {
    try {
      final data = await _lovService.fetchQcLov(qryType: "QC_BII");
      setState(() { itemList = data; itemDisplayCount = 10; });
    } catch (e) {
      _showError("Failed to load items");
    }
  }

  Future<void> _loadProcess() async {
    if (itemId == null || itemId!.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final data = await _lovService.fetchQcLov(
        qryType: "QC_PROCESS", biiId: itemId, appUserId: appUser,
      );
      setState(() {
        processList = data; processDisplayCount = 10;
        processId = null; processLabel = null;
        lineList.clear(); lineId = null; lineLabel = null;
      });
    } catch (e) {
      _showError("Failed to load process list");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadLine() async {
    if (processId == null || processId!.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final data = await _lovService.fetchQcLov(
        qryType: "QC_LINE", processId: processId, appUserId: appUser,
      );
      setState(() {
        lineList = data; lineDisplayCount = 10;
        lineId = null; lineLabel = null;
      });
    } catch (e) {
      _showError("Failed to load line list");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadSizes() async {
    if (itemId == null || itemId!.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final data = await _lovService.fetchQcLov(qryType: "QC_SIZE", biiId: itemId);
      data.sort((a, b) {
        final aSize = num.tryParse(a['label'] ?? '0') ?? 0;
        final bSize = num.tryParse(b['label'] ?? '0') ?? 0;
        return aSize.compareTo(bSize);
      });
      setState(() { sizeList = data; sizeDisplayCount = 10; });
    } catch (e) {
      _showError("Failed to load sizes");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadJobNo() async {
    if (itemId == null || itemId!.isEmpty) {
      setState(() { jobNo = ""; bpoId = null; });
      return;
    }
    setState(() => isLoading = true);
    try {
      final data = await _lovService.fetchQcLov(qryType: "QC_JOB", biiId: itemId);
      if (data.isNotEmpty) {
        setState(() {
          jobNo = data.first["label"] ?? data.first["JOB_NO"] ?? "";
          bpoId = data.first["BPO_ID"] ?? data.first["id"] ?? "";
        });
      } else {
        setState(() { jobNo = ""; bpoId = null; });
      }
    } catch (e) {
      setState(() { jobNo = ""; bpoId = null; });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadRemainingQty() async {
    if (itemId == null || processId == null || sizeId == null) {
      setState(() => remainingQty = "0");
      return;
    }
    setState(() => isLoading = true);
    try {
      final remainingQtyStr = await _lovService.fetchRemainingQty(
        biiId: itemId!, processId: processId!, sizeId: sizeId!,
      );
      setState(() => remainingQty = remainingQtyStr);
    } catch (e) {
      setState(() => remainingQty = "0");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ── Clear all selections ─────────────────────────────────────────
  void _clearAll() {
    setState(() {
      itemId = null;       itemLabel = null;
      jobNo = null;        orderNo = null;       articleNo = null;
      bpoId = null;
      processId = null;    processLabel = null;
      lineId = null;       lineLabel = null;
      sizeId = null;       size = null;
      remainingQty = "0";
      selectedItemMap = null;
      processList.clear(); lineList.clear(); sizeList.clear();
      productionQty = null; productionQtyValue = 0;
      productionQtyController.clear();
      bundleQtyValue = 1;  bundleQty = "1";
      bundleQtyController.text = "1";
      rejectQtyValue = 0;  rejectQty = "0";
      rejectQtyController.text = "0";
      flag = "I";
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _handleSave() async {
    if (itemId == null || itemId!.isEmpty) { _showError("Please select an item"); return; }
    if (jobNo == null || jobNo!.isEmpty) { _showError("Job No is required."); return; }
    if (bpoId == null || bpoId!.isEmpty) { _showError("BPO ID is missing."); return; }
    if (orderNo == null || orderNo!.isEmpty) { _showError("Order No is required."); return; }
    if (articleNo == null || articleNo!.isEmpty) { _showError("Article No is required."); return; }
    if (processId == null || processId!.isEmpty) { _showError("Please select a process"); return; }
    if (lineId == null || lineId!.isEmpty) { _showError("Please select a line"); return; }
    if (sizeId == null || sizeId!.isEmpty) { _showError("Please select a size"); return; }
    if (productionQty == null || productionQty!.isEmpty) { _showError("Please enter production quantity"); return; }

    final prodQtyValue = int.tryParse(productionQty!) ?? 0;
    if (prodQtyValue <= 0) { _showError("Production quantity must be greater than 0"); return; }

    final remainingValue = int.tryParse(remainingQty ?? "0") ?? 0;
    if (prodQtyValue > remainingValue) {
      _showError("Production qty cannot be greater than remaining qty ($remainingValue)");
      return;
    }

    setState(() => isLoading = true);
    try {
      final success = await _lovService.saveProductionEntry(
        lineId: lineId!, processId: processId!, biiId: itemId!, bpoId: bpoId!,
        size: size ?? sizeId ?? "", rejectQty: rejectQty ?? "0",
        prodQty: productionQty!, bundleCount: bundleQty ?? "1",
        flag: flag ?? "I", appUser: appUser ?? "",
      );
      if (!mounted) return;
      if (success) {
        _showSuccess("Production Entry Saved Successfully");
        setState(() {
          productionQty = null; productionQtyValue = 0;
          productionQtyController.clear();
          bundleQtyValue = 1; bundleQty = "1"; bundleQtyController.text = "1";
          rejectQtyValue = 0; rejectQty = "0"; rejectQtyController.text = "0";
          flag = "I";
        });
      } else {
        _showError("Failed to save production entry.");
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
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
                              // Label row: text left, clear button right
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text("Item Description/ Color *",
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
                              // Dropdown trigger (full width)
                              InkWell(
                                onTap: () => _itemTableDialog(
                                  context,
                                  "Item Description/ Color *",
                                  itemList,
                                  itemDisplayCount,
                                  (id, label) async {
                                    setState(() {
                                      itemId = id; itemLabel = label;
                                      selectedItemMap = itemList.firstWhere(
                                        (item) => item['id'] == id,
                                        orElse: () => {},
                                      );
                                      orderNo = selectedItemMap?["BPO_PO_NO"] ?? "";
                                      articleNo = selectedItemMap?["STYLE_NO"] ?? "";
                                      bpoId = null; jobNo = null;
                                      processList.clear(); processId = null; processLabel = null;
                                      lineList.clear(); lineId = null; lineLabel = null;
                                      sizeList.clear(); sizeId = null; size = null;
                                      remainingQty = "0";
                                    });
                                    await _loadJobNo();
                                    _loadProcess();
                                    _loadSizes();
                                  },
                                ),
                                child: Container(
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Color(0x0F000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 2))
                                    ],
                                  ),
                                  child: Row(children: [
                                    Expanded(
                                      child: OverflowScrollText(
                                        text: itemLabel ?? "Select",
                                        style: const TextStyle(
                                            fontSize: 12,
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

                        // ── JOB + ORDER ───────────────────────────────
                        Row(children: [
                          Expanded(child: _readOnly("Job No", jobNo, double.infinity)),
                          const SizedBox(width: 12),
                          Expanded(child: _readOnly("Order No", orderNo, double.infinity)),
                        ]),

                        // ── ARTICLE ───────────────────────────────────
                        _readOnly("Article Name", articleNo, double.infinity),

                        // ── PROCESS ───────────────────────────────────
                        _modernDropdown(context, "Process Name *", processLabel,
                          processList, processDisplayCount,
                          (id, label) {
                            setState(() {
                              processId = id; processLabel = label;
                              lineList.clear(); lineId = null; lineLabel = null;
                              remainingQty = "0";
                            });
                            _loadLine();
                          }, width),

                        // ── LINE ──────────────────────────────────────
                        _modernDropdown(context, "Line No/Machine No *", lineLabel,
                          lineList, lineDisplayCount,
                          (id, label) => setState(() { lineId = id; lineLabel = label; }),
                          width),

                        // ── SIZE ──────────────────────────────────────
                        _modernDropdown(context, "Size *", size,
                          sizeList, sizeDisplayCount,
                          (id, label) {
                            setState(() { sizeId = id; size = label; });
                            _loadRemainingQty();
                          }, width),

                        _readOnly("Remaining Qty", remainingQty ?? "0", width, highlight: true),

                        // ── PRODUCTION QTY ────────────────────────────
                        _quantityField("Production Qty *", productionQtyController,
                          (v) => setState(() {
                            productionQtyValue = int.tryParse(v) ?? 0;
                            productionQty = v.isEmpty ? null : v;
                          }), width),

                        // ── BUNDLE QTY ────────────────────────────────
                        _centeredInputField(
                          label: "Bundle Qty", controller: bundleQtyController,
                          hintText: "1", width: width,
                          onChanged: (v) => setState(() {
                            bundleQtyValue = int.tryParse(v) ?? 1;
                            bundleQty = v.isEmpty ? "1" : v;
                          })),

                        // ── REJECT QTY ────────────────────────────────
                        _centeredInputField(
                          label: "Reject Qty", controller: rejectQtyController,
                          hintText: "0", width: width,
                          onChanged: (v) => setState(() {
                            rejectQtyValue = int.tryParse(v) ?? 0;
                            rejectQty = v.isEmpty ? "0" : v;
                          })),

                        // ── FLAG ──────────────────────────────────────
                        _modernDropdown(context, "Flag",
                          flagList.firstWhere((f) => f["id"] == flag,
                            orElse: () => {"id": "I", "label": "Internal"})["label"],
                          flagList, flagList.length,
                          (id, label) => setState(() => flag = id), width),

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
                            child: Text(
                              isLoading ? "SAVING..." : "SAVE",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900, color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A73E8)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===================== WIDGET HELPERS =====================

  Widget _readOnly(String label, String? value, double width, {bool highlight = false}) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 4),
          Container(
            height: highlight ? 40 : 38,
            decoration: highlight
                ? BoxDecoration(
                    color: const Color(0xFFF7FAFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF1A73E8).withOpacity(0.25), width: 1.2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2))
                    ],
                  )
                : BoxDecoration(
                    color: const Color(0xFFE8EAED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
            child: highlight
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        value ?? "-",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                : OverflowScrollText(
                    text: value ?? "-",
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
          ),
        ],
      ),
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
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _searchDialog(context, label, list, displayCount, onSelect),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: const [
                BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
            child: Row(children: [
              Expanded(
                child: OverflowScrollText(
                  text: value ?? "Select",
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
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

  Widget _itemTableDropdown(
    BuildContext context, String label, String? value,
    List<Map<String, String>> list, int displayCount,
    void Function(String, String) onSelect, double width,
  ) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 4),
          InkWell(
            onTap: () =>
                _itemTableDialog(context, label, list, displayCount, onSelect),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: const [
                  BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))
                ],
              ),
              child: Row(children: [
                Expanded(
                  child: OverflowScrollText(
                    text: value ?? "Select",
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.arrow_drop_down, color: Colors.black87, size: 20),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quantityField(
    String label, TextEditingController controller,
    Function(String) onChanged, double width,
  ) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 4),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF1A73E8).withOpacity(0.25), width: 1.2),
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
            child: Center(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A), letterSpacing: 0.5),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  border: InputBorder.none, isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: "0",
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontWeight: FontWeight.w600),
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _centeredInputField({
    required String label, required TextEditingController controller,
    required String hintText, required double width,
    required Function(String) onChanged,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
          const SizedBox(height: 4),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: const [
                BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
            child: Center(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  border: InputBorder.none, isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: hintText,
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
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
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(builder: (c, setS) {
          int currentDisplayCount = items.length < 10 ? items.length : 10;
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(width: 40, height: 4,
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
                      final q = v.toLowerCase();
                      filtered = items.where((e) {
                        final iDesc = (e["label"] ?? "").toLowerCase();
                        final oNo = (e["BPO_PO_NO"] ?? "").toLowerCase();
                        final aNo = (e["STYLE_NO"] ?? "").toLowerCase();
                        return iDesc.contains(q) || oNo.contains(q) || aNo.contains(q);
                      }).toList();
                      currentDisplayCount = 10;
                    }),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Colors.black54),
                      hintText: "Search by color, order no, or article...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A73E8),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
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
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    ),
                    child: filtered.isEmpty
                        ? const Center(child: Text("No items found",
                            style: TextStyle(fontSize: 14, color: Colors.grey)))
                        : StatefulBuilder(builder: (context, setModalState) {
                            return ListView.builder(
                              itemCount: currentDisplayCount < filtered.length
                                  ? currentDisplayCount + 1 : currentDisplayCount,
                              itemBuilder: (_, index) {
                                if (index == currentDisplayCount &&
                                    currentDisplayCount < filtered.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Center(
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            setModalState(() => currentDisplayCount += 10),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1A73E8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 6),
                                          minimumSize: Size.zero,
                                        ),
                                        child: const Text('Show More',
                                            style: TextStyle(color: Colors.white,
                                                fontWeight: FontWeight.bold, fontSize: 11)),
                                      ),
                                    ),
                                  );
                                }
                                final item = filtered[index];
                                return InkWell(
                                  onTap: () {
                                    onSelect(item["id"] ?? "", item["label"] ?? "");
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 12),
                                    decoration: BoxDecoration(
                                        border: Border(
                                            bottom: BorderSide(color: Colors.grey.shade300))),
                                    child: Row(children: [
                                      Expanded(flex: 2, child: Text(item["label"] ?? "",
                                          style: const TextStyle(fontSize: 12,
                                              fontWeight: FontWeight.w600, color: Colors.black87),
                                          overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 8),
                                      Expanded(flex: 1, child: Text(item["BPO_PO_NO"] ?? "-",
                                          style: const TextStyle(fontSize: 12,
                                              fontWeight: FontWeight.w500, color: Colors.black87),
                                          overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 8),
                                      Expanded(flex: 1, child: Text(item["STYLE_NO"] ?? "-",
                                          style: const TextStyle(fontSize: 12,
                                              fontWeight: FontWeight.w500, color: Colors.black87),
                                          overflow: TextOverflow.ellipsis)),
                                    ]),
                                  ),
                                );
                              },
                            );
                          }),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _searchDialog(
    BuildContext context, String title,
    List<Map<String, String>> items, int displayCount,
    void Function(String, String) onSelect,
  ) {
    List<Map<String, String>> filtered = List.from(items);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(builder: (c, setS) {
          int currentDisplayCount = items.length < 10 ? items.length : 10;
          return Container(
            height: MediaQuery.of(context).size.height * 0.80,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(width: 40, height: 4,
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
                      filtered = items.where((e) => e["label"]!
                          .toLowerCase().contains(v.toLowerCase())).toList();
                      currentDisplayCount = 10;
                    }),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Colors.black54),
                      hintText: "Search...", border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: currentDisplayCount < filtered.length
                        ? currentDisplayCount + 1 : currentDisplayCount,
                    itemBuilder: (context, index) {
                      if (index == currentDisplayCount &&
                          currentDisplayCount < filtered.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Center(
                            child: ElevatedButton(
                              onPressed: () => setS(() => currentDisplayCount += 10),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A73E8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              child: const Text('Show More',
                                  style: TextStyle(color: Colors.white,
                                      fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ),
                        );
                      }
                      final item = filtered[index];
                      return ListTile(
                        title: Text(item["label"]!,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        onTap: () {
                          onSelect(item["id"]!, item["label"]!);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}