import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackall_app/pages/widgets/top_menu_bar.dart';
import 'package:trackall_app/services/lov_service.dart';

// =====================================================================
// PACKING PRODUCTION ENTRY PAGE
// =====================================================================

class PackingProductionEntryPage extends StatefulWidget {
  const PackingProductionEntryPage({super.key});

  @override
  State<PackingProductionEntryPage> createState() =>
      _PackingProductionEntryPageState();
}

// ── Size row model ─────────────────────────────────────────────────────
class _SizeRow {
  final String ocsiId;
  final String sizeLabel;
  final int orderQty;
  final int productionQty;
  final int packingQty;
  final int packingRemaining;
  final int remainingBalance;
  final TextEditingController qtyCtrl;
  int qty;

  _SizeRow({
    required this.ocsiId,
    required this.sizeLabel,
    required this.orderQty,
    required this.productionQty,
    required this.packingQty,
    required this.packingRemaining,
    required this.remainingBalance,
    this.qty = 0,
  }) : qtyCtrl = TextEditingController();

  void dispose() => qtyCtrl.dispose();
}

class _PackingProductionEntryPageState
    extends State<PackingProductionEntryPage> {
  final LovService _lovService = LovService();

  String? processId,  processLabel;
  String? itemId,     itemLabel;
  String? lineId,     lineLabel;
  String? countryId,  countryLabel;
  String? country;
  String? jobNo, orderNo, articleName;
  String? appUser;

  bool isLoading      = false;
  bool sizesGenerated = false;

  List<Map<String, String>> processList = [];
  List<Map<String, String>> itemList    = [];
  List<Map<String, String>> lineList    = [];
  List<Map<String, String>> countryList = [];
  List<_SizeRow>            sizeRows    = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final r in sizeRows) r.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    appUser = prefs.getString('userId') ?? "";
    await _loadProcess();
    setState(() => isLoading = false);
  }

  Future<void> _loadProcess() async {
    try {
      final data = await _lovService.fetchPackingLov(qryType: "PACKING_PROCESS");
      if (data.isNotEmpty) {
        processId    = data.first["id"]    ?? "";
        processLabel = data.first["label"] ?? "Packing";
      } else {
        processId    = "";
        processLabel = "Packing";
      }
      setState(() => processList = data);
      await Future.wait([_loadItems(), _loadLines()]);
    } catch (_) {}
  }

  Future<void> _loadItems() async {
    if (processId == null) return;
    setState(() => isLoading = true);
    try {
      final data = await _lovService.fetchPackingLov(
          qryType: "PACKING_BII", processId: processId);
      setState(() => itemList = data);
    } catch (_) {
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadLines() async {
    if (processId == null) return;
    setState(() => isLoading = true);
    try {
      final data = await _lovService.fetchPackingLov(
          qryType: "PACKING_LINE", processId: processId);
      setState(() => lineList = data);
    } catch (_) {
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadCountries() async {
    if (itemId == null) return;
    setState(() => isLoading = true);
    try {
      final data = await _lovService.fetchPackingLov(
          qryType: "PACKING_COUNTRY", biiId: itemId);
      setState(() => countryList = data);
    } catch (_) {
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _generateSizes() async {
    if (processId == null || itemId == null || countryId == null) {
      _showError("Please select Process, Item and Country first");
      return;
    }
    setState(() {
      isLoading      = true;
      sizesGenerated = false;
    });
    try {
      final data = await _lovService.fetchPackingLov(
        qryType:   "COUNTRY_SIZE",
        processId: processId,
        biiId:     itemId,
        countryId: countryId,
      );

      data.sort((a, b) {
        final an = num.tryParse(a['label'] ?? '');
        final bn = num.tryParse(b['label'] ?? '');
        if (an != null && bn != null) return an.compareTo(bn);
        return (a['label'] ?? '').compareTo(b['label'] ?? '');
      });

      final rows = data.map((s) {
        final oQty      = int.tryParse(s["ORDER_QTY"]        ?? "0") ?? 0;
        final pkQty     = int.tryParse(s["PACKING_QTY"]      ?? "0") ?? 0;
        final remBal    = int.tryParse(s["REMAINING_BLANCE"] ?? "0") ?? 0;
        final prodQty   = int.tryParse(s["PROD_QTY"]         ?? "0") ?? 0;
        final procesTyp = int.tryParse(s["PROCESS_TYP"]      ?? "0") ?? 0;
        final pkgRemaining = procesTyp == 0 ? remBal : prodQty - pkQty;
        return _SizeRow(
          ocsiId:           s["OCSI_ID"]   ?? s["id"]    ?? "",
          sizeLabel:        s["OCSI_SIZE"] ?? s["label"] ?? "",
          orderQty:         oQty,
          productionQty:    prodQty,
          packingQty:       pkQty,
          packingRemaining: pkgRemaining,
          remainingBalance: remBal,
        );
      }).toList();

      for (final r in sizeRows) r.dispose();
      setState(() {
        sizeRows       = rows;
        sizesGenerated = rows.isNotEmpty;
      });
      if (rows.isEmpty) {
        _showError("No sizes found for the selected combination");
      }
    } catch (_) {
      _showError("Failed to generate sizes");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _handleSave() async {
    if (processId == null) { _showError("Please select a process");     return; }
    if (itemId    == null) { _showError("Please select an item");       return; }
    if (lineId    == null) { _showError("Please select a line");        return; }
    if (countryId == null) { _showError("Please select a country");     return; }
    if (!sizesGenerated)   { _showError("Please generate sizes first"); return; }

    final filled = sizeRows.where((r) => r.qty > 0).toList();
    if (filled.isEmpty) {
      _showError("Please enter qty for at least one size");
      return;
    }

    setState(() => isLoading = true);

    final sizesPayload = filled.map((row) => <String, dynamic>{
      "size": row.sizeLabel,
      "qty":  row.qty,
    }).toList();

    try {
      final ok = await _lovService.savePackingEntry(
        lineId:    lineId!,
        processId: processId!,
        biiId:     itemId!,
        country:   country ?? "0",
        appUser:   appUser ?? "",
        sizes:     sizesPayload,
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      if (ok) {
        _showSuccess(
            "${filled.length} size${filled.length > 1 ? 's' : ''} saved successfully");
        for (final r in sizeRows) {
          r.qty = 0;
          r.qtyCtrl.clear();
        }
        setState(() {});
      } else {
        _showError("Save failed. Please retry.");
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showError("Save failed. Please retry.");
    }
  }

  void _clearAll() {
    setState(() {
      itemId      = null; itemLabel    = null;
      lineId      = null; lineLabel    = null;
      countryId   = null; countryLabel = null;
      country     = null;
      jobNo       = null; orderNo      = null;
      articleName = null;
      itemList.clear();
      countryList.clear();
      for (final r in sizeRows) r.dispose();
      sizeRows       = [];
      sizesGenerated = false;
    });
    _loadItems();
    _loadLines();
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

  // ================================================================
  // BUILD
  // ================================================================
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
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hardcodedProcess(),
                      const SizedBox(height: 12),
                      _itemTableDropdown(
                        context,
                        "Item Description / Color",
                        itemLabel,
                        itemList,
                        (id, label, item) {
                          setState(() {
                            itemId      = id;
                            itemLabel   = label;
                            jobNo       = item["JOB_NO"]    ?? "";
                            orderNo     = item["BPO_PO_NO"] ?? "";
                            articleName = item["STYLE_NO"]  ?? "";
                            countryId   = null; countryLabel = null;
                            country     = null;
                            countryList.clear();
                            for (final r in sizeRows) r.dispose();
                            sizeRows       = [];
                            sizesGenerated = false;
                          });
                          _loadCountries();
                        },
                        double.infinity,
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _readOnly("Job No",   jobNo,   double.infinity)),
                        const SizedBox(width: 12),
                        Expanded(child: _readOnly("Order No", orderNo, double.infinity)),
                      ]),
                      const SizedBox(height: 12),
                      _readOnly("Article Name", articleName, double.infinity),
                      const SizedBox(height: 12),
                      _modernDropdown(
                        context,
                        "Line No *",
                        lineLabel,
                        lineList,
                        (id, label) =>
                            setState(() { lineId = id; lineLabel = label; }),
                        double.infinity,
                      ),
                      const SizedBox(height: 12),
                      _countryDropdown(double.infinity),
                      const SizedBox(height: 12),
                      Center(child: _sizeGenerateButton()),
                      const SizedBox(height: 12),
                      if (sizesGenerated && sizeRows.isNotEmpty) ...[
                        _sizeTable(double.infinity),
                        const SizedBox(height: 12),
                      ] else
                        const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFF1A73E8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            disabledBackgroundColor: Colors.grey,
                            elevation: 2,
                          ),
                          child: Text(
                            isLoading ? "SAVING..." : "SAVE",
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF1A73E8))),
              ),
            ),
        ],
      ),
    );
  }

  // ================================================================
  // HARDCODED PROCESS WIDGET
  // ================================================================
  Widget _hardcodedProcess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Text("Process Name",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black)),
          const Spacer(),
          TextButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.refresh_rounded, size: 13),
            label: const Text("Clear",
                style:
                    TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade400,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              backgroundColor: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFE8F0FE), Color(0xFFD2E3FC)]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF1A73E8).withOpacity(0.35),
                width: 1.4),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 4,
                  offset: Offset(0, 2))
            ],
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: const Text("Packing",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A73E8))),
        ),
      ],
    );
  }

  // ================================================================
  // COUNTRY DROPDOWN
  // ================================================================
  Widget _countryDropdown(double width) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Country *",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black)),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _countryTableDialog(
              context,
              "Country",
              countryList,
              (id, label, item) {
                setState(() {
                  countryId    = id;
                  countryLabel = label;
                  country      = id;
                  for (final r in sizeRows) r.dispose();
                  sizeRows       = [];
                  sizesGenerated = false;
                });
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
                    child: _OverflowText(
                  text: countryLabel ?? "Select",
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                )),
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
    );
  }

  // ================================================================
  // SIZE GENERATE BUTTON
  // ================================================================
  Widget _sizeGenerateButton() {
    return OutlinedButton.icon(
      onPressed: isLoading ? null : _generateSizes,
      icon: const Icon(Icons.auto_fix_high_rounded, size: 15),
      label: const Text("Size Generate",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1A73E8),
        side: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ================================================================
  // SIZE TABLE
  // ================================================================
  Widget _sizeTable(double width) {
    const colW = [60.0, 90.0, 100.0, 110.0, 110.0, 120.0, 75.0];
    const colL = [
      "Size", "Order Qty", "Production Qty", "Packing Done Qty",
      "Packing Remaining", "Order Remaining Qty", "Qty"
    ];
    final tableW = colW.fold(0.0, (s, w) => s + w) + 32.0;
    final hScrollCtrl = ScrollController();

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Sizes",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black)),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 4,
                    offset: Offset(0, 2))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SingleChildScrollView(
                controller: hScrollCtrl,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableW,
                  child: Column(
                    children: [
                      // Header
                      Container(
                        color: const Color(0xFF1A73E8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: List.generate(
                              colL.length,
                              (i) => SizedBox(
                                    width: colW[i],
                                    child: Text(colL[i],
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white)),
                                  )),
                        ),
                      ),

                      // Rows
                      ...sizeRows.asMap().entries.map((e) {
                        final i   = e.key;
                        final row = e.value;

                        // ── fix 2: disable input when packingRemaining <= 0 ──
                        final bool canInput = row.packingRemaining > 0;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                          color: i % 2 == 0
                              ? const Color(0xFFFFFBEB)
                              : Colors.white,
                          child: Row(children: [
                            SizedBox(
                              width: colW[0],
                              child: Text(row.sizeLabel,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A))),
                            ),
                            SizedBox(
                              width: colW[1],
                              child: Text(row.orderQty.toString(),
                                  textAlign: TextAlign.center,
                                  style: _cellStyle),
                            ),
                            SizedBox(
                              width: colW[2],
                              child: Text(row.productionQty.toString(),
                                  textAlign: TextAlign.center,
                                  style: _cellStyle),
                            ),
                            SizedBox(
                              width: colW[3],
                              child: Text(row.packingQty.toString(),
                                  textAlign: TextAlign.center,
                                  style: _cellStyle),
                            ),
                            SizedBox(
                              width: colW[4],
                              child: Text(
                                row.packingRemaining.toString(),
                                textAlign: TextAlign.center,
                                style: _cellStyle.copyWith(
                                  color: canInput
                                      ? const Color(0xFF475569)
                                      : Colors.red,
                                  fontWeight: canInput
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: colW[5],
                              child: Text(
                                row.remainingBalance.toString(),
                                textAlign: TextAlign.center,
                                style: _cellStyle.copyWith(
                                    color: row.remainingBalance > 0
                                        ? const Color(0xFF475569)
                                        : Colors.red),
                              ),
                            ),
                            // ── Qty input cell ───────────────────────────
                            SizedBox(
                              width: colW[6],
                              child: canInput
                                  // ── fix 1: white bg + fix 2: enabled ──
                                  ? Container(
                                      height: 32,
                                      margin:
                                          const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white, // ← white bg
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                            color: const Color(0xFF1A73E8)
                                                .withOpacity(0.4),
                                            width: 1.2),
                                        boxShadow: const [
                                          BoxShadow(
                                              color: Color(0x0A1A73E8),
                                              blurRadius: 4,
                                              offset: Offset(0, 1))
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: TextField(
                                        controller: row.qtyCtrl,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        textAlignVertical:
                                            TextAlignVertical.center,
                                        maxLines: 1,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly
                                        ],
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1A73E8)),
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 7),
                                          hintText: "0",
                                          hintStyle: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 12),
                                        ),
                                        onChanged: (v) {
                                          final entered =
                                              int.tryParse(v) ?? 0;
                                          if (entered >
                                              row.packingRemaining) {
                                            row.qty = row.packingRemaining;
                                            row.qtyCtrl.text =
                                                row.packingRemaining
                                                    .toString();
                                            row.qtyCtrl.selection =
                                                TextSelection.collapsed(
                                                    offset: row
                                                        .qtyCtrl.text.length);
                                            _showError(
                                                "Max qty for size ${row.sizeLabel} is ${row.packingRemaining}");
                                          } else {
                                            row.qty = entered;
                                          }
                                          setState(() {});
                                        },
                                      ),
                                    )
                                  // ── fix 2: locked cell when remaining <= 0 ──
                                  : Container(
                                      height: 32,
                                      margin:
                                          const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(Icons.block_rounded,
                                          size: 14,
                                          color: Colors.grey.shade400),
                                    ),
                            ),
                          ]),
                        );
                      }),

                      // Totals row
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          border: Border(
                              top: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(children: [
                          SizedBox(
                            width: colW[0],
                            child: const Text("Total",
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1A73E8))),
                          ),
                          ...[
                            sizeRows.fold(0, (s, r) => s + r.orderQty),
                            sizeRows.fold(0, (s, r) => s + r.productionQty),
                            sizeRows.fold(0, (s, r) => s + r.packingQty),
                            sizeRows.fold(0, (s, r) => s + r.packingRemaining),
                            sizeRows.fold(0, (s, r) => s + r.remainingBalance),
                            sizeRows.fold(0, (s, r) => s + r.qty),
                          ].asMap().entries.map((e) => SizedBox(
                                width: colW[e.key + 1],
                                child: Padding(
                                  padding: e.key == 5
                                      ? const EdgeInsets.only(right: 8)
                                      : EdgeInsets.zero,
                                  child: Text(e.value.toString(),
                                      textAlign: TextAlign.center,
                                      style: e.key == 5
                                          ? _totStyle.copyWith(
                                              color: const Color(0xFF1A73E8))
                                          : _totStyle),
                                ),
                              )),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _cellStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Color(0xFF475569));
  static const _totStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: Color(0xFF0F172A));

  // ================================================================
  // WIDGET HELPERS
  // ================================================================
  Widget _readOnly(String label, String? value, double width) {
    return SizedBox(
      width: width,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.black)),
            const SizedBox(height: 4),
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EAED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: _OverflowText(
                  text: value ?? "-",
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ),
          ]),
    );
  }

  Widget _modernDropdown(
      BuildContext context,
      String label,
      String? value,
      List<Map<String, String>> list,
      void Function(String, String) onSelect,
      double width) {
    return SizedBox(
      width: width,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.black)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _searchDialog(context, label, list, onSelect),
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
                      child: _OverflowText(
                          text: value ?? "Select",
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87))),
                  const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.arrow_drop_down,
                          color: Colors.black87, size: 20)),
                ]),
              ),
            ),
          ]),
    );
  }

  Widget _itemTableDropdown(
      BuildContext context,
      String label,
      String? value,
      List<Map<String, String>> list,
      void Function(String id, String label, Map<String, String> item)
          onSelect,
      double width) {
    return SizedBox(
      width: width,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.black)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () =>
                  _itemTableDialog(context, label, list, onSelect),
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
                      child: _OverflowText(
                          text: value ?? "Select",
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87))),
                  const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.arrow_drop_down,
                          color: Colors.black87, size: 20)),
                ]),
              ),
            ),
          ]),
    );
  }

  // ── Item bottom sheet ─────────────────────────────────────────
  void _itemTableDialog(
      BuildContext context,
      String title,
      List<Map<String, String>> items,
      void Function(String id, String label, Map<String, String> item)
          onSelect) {
    List<Map<String, String>> filtered = List.from(items);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) =>
          StatefulBuilder(builder: (c, setS) {
        int cnt = items.length < 10 ? items.length : 10;
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
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
                  border: Border.all(color: Colors.grey.shade300)),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setS(() {
                  final q = v.toLowerCase();
                  filtered = items
                      .where((e) =>
                          (e["label"] ?? "").toLowerCase().contains(q) ||
                          (e["BPO_PO_NO"] ?? "").toLowerCase().contains(q) ||
                          (e["STYLE_NO"] ?? "").toLowerCase().contains(q) ||
                          (e["JOB_NO"] ?? "").toLowerCase().contains(q))
                      .toList();
                  cnt = 10;
                }),
                decoration: const InputDecoration(
                    prefixIcon:
                        Icon(Icons.search, color: Colors.black54),
                    hintText:
                        "Search by color, order no, or article...",
                    border: InputBorder.none),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 12),
              decoration: const BoxDecoration(
                  color: Color(0xFF1A73E8),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(8))),
              child: const Row(children: [
                Expanded(
                    flex: 2,
                    child: Text("Color/Item Desc",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white))),
                SizedBox(width: 8),
                Expanded(
                    flex: 1,
                    child: Text("Order No.",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white))),
                SizedBox(width: 8),
                Expanded(
                    flex: 1,
                    child: Text("Article",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white))),
              ]),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(8))),
                child: filtered.isEmpty
                    ? const Center(
                        child: Text("No items found",
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey)))
                    : StatefulBuilder(builder: (context, setMS) {
                        return ListView.builder(
                          itemCount: cnt < filtered.length
                              ? cnt + 1
                              : filtered.length,
                          itemBuilder: (_, idx) {
                            if (idx == cnt && cnt < filtered.length) {
                              return Center(
                                  child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: ElevatedButton(
                                          onPressed: () =>
                                              setMS(() => cnt += 10),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF1A73E8),
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 6),
                                              minimumSize: Size.zero),
                                          child: const Text('Show More',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11)))));
                            }
                            final item = filtered[idx];
                            return InkWell(
                              onTap: () {
                                onSelect(item["id"] ?? "",
                                    item["label"] ?? "", item);
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 12),
                                decoration: BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Colors.grey.shade300))),
                                child: Row(children: [
                                  Expanded(
                                      flex: 2,
                                      child: Text(item["label"] ?? "",
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87),
                                          overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      flex: 1,
                                      child: Text(item["BPO_PO_NO"] ?? "-",
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87),
                                          overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      flex: 1,
                                      child: Text(item["STYLE_NO"] ?? "-",
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87),
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

  // ── Country bottom sheet ──────────────────────────────────────
  void _countryTableDialog(
      BuildContext context,
      String title,
      List<Map<String, String>> items,
      void Function(String id, String label, Map<String, String> item)
          onSelect) {
    List<Map<String, String>> filtered = List.from(items);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) =>
          StatefulBuilder(builder: (c, setS) {
        int cnt = items.length < 10 ? items.length : 10;
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
                  border: Border.all(color: Colors.grey.shade300)),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setS(() {
                  filtered = items
                      .where((e) => (e["label"] ?? "")
                          .toLowerCase()
                          .contains(v.toLowerCase()))
                      .toList();
                  cnt = 10;
                }),
                decoration: const InputDecoration(
                    prefixIcon:
                        Icon(Icons.search, color: Colors.black54),
                    hintText: "Search...",
                    border: InputBorder.none),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text("No items found",
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey)))
                  : StatefulBuilder(builder: (context, setMS) {
                      return ListView.builder(
                        itemCount: cnt < filtered.length
                            ? cnt + 1
                            : filtered.length,
                        itemBuilder: (context, idx) {
                          if (idx == cnt && cnt < filtered.length) {
                            return Center(
                                child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: ElevatedButton(
                                        onPressed: () =>
                                            setMS(() => cnt += 10),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF1A73E8),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 6),
                                            minimumSize: Size.zero),
                                        child: const Text('Show More',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11)))));
                          }
                          final item = filtered[idx];
                          return ListTile(
                            title: Text(item["label"] ?? "",
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            onTap: () {
                              onSelect(item["id"] ?? "",
                                  item["label"] ?? "", item);
                              Navigator.pop(context);
                            },
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

  // ── Generic search bottom sheet ───────────────────────────────
  void _searchDialog(
      BuildContext context,
      String title,
      List<Map<String, String>> items,
      void Function(String, String) onSelect) {
    List<Map<String, String>> filtered = List.from(items);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) =>
          StatefulBuilder(builder: (c, setS) {
        int cnt = items.length < 10 ? items.length : 10;
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
                  border: Border.all(color: Colors.grey.shade300)),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setS(() {
                  filtered = items
                      .where((e) => (e["label"] ?? "")
                          .toLowerCase()
                          .contains(v.toLowerCase()))
                      .toList();
                  cnt = 10;
                }),
                decoration: const InputDecoration(
                    prefixIcon:
                        Icon(Icons.search, color: Colors.black54),
                    hintText: "Search...",
                    border: InputBorder.none),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text("No items found",
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey)))
                  : StatefulBuilder(builder: (context, setMS) {
                      return ListView.builder(
                        itemCount: cnt < filtered.length
                            ? cnt + 1
                            : filtered.length,
                        itemBuilder: (context, idx) {
                          if (idx == cnt && cnt < filtered.length) {
                            return Center(
                                child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: ElevatedButton(
                                        onPressed: () =>
                                            setMS(() => cnt += 10),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF1A73E8),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 6),
                                            minimumSize: Size.zero),
                                        child: const Text('Show More',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11)))));
                          }
                          final item = filtered[idx];
                          return ListTile(
                            title: Text(item["label"] ?? "",
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            onTap: () {
                              onSelect(item["id"] ?? "",
                                  item["label"] ?? "");
                              Navigator.pop(context);
                            },
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

// ================================================================
// OVERFLOW TEXT WIDGET
// ================================================================
class _OverflowText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final EdgeInsetsGeometry padding;

  const _OverflowText({
    required this.text,
    required this.style,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  @override
  State<_OverflowText> createState() => _OverflowTextState();
}

class _OverflowTextState extends State<_OverflowText> {
  final ScrollController _sc = ScrollController();
  bool _over = false, _scrolled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    _sc.addListener(() {
      final s = _sc.offset > 0;
      if (s != _scrolled) setState(() => _scrolled = s);
    });
  }

  @override
  void didUpdateWidget(_OverflowText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) { _sc.jumpTo(0); _check(); });
    }
  }

  void _check() {
    if (!mounted) return;
    final tp = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: 1,
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: double.infinity);
    final rb = context.findRenderObject() as RenderBox?;
    if (rb == null) return;
    setState(() => _over = tp.width > rb.size.width - 44);
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: SingleChildScrollView(
          controller: _sc,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: widget.padding,
          child: Text(widget.text, style: widget.style, maxLines: 1),
        ),
      ),
      if (_over)
        GestureDetector(
          onTap: () => _scrolled
              ? _sc.animateTo(0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut)
              : _sc.animateTo(_sc.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
                _scrolled
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 18,
                color: const Color(0xFF1A73E8)),
          ),
        ),
    ]);
  }
}