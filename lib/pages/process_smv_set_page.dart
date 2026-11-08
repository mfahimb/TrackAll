import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackall_app/pages/widgets/top_menu_bar.dart';
import 'package:trackall_app/services/process_smv_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// =====================================================================
// SCROLLABLE OVERFLOW TEXT WIDGET
// =====================================================================

class _OverflowScrollText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final EdgeInsetsGeometry padding;

  const _OverflowScrollText({
    required this.text,
    required this.style,
  }) : padding = const EdgeInsets.symmetric(horizontal: 12);

  @override
  State<_OverflowScrollText> createState() => _OverflowScrollTextState();
}

class _OverflowScrollTextState extends State<_OverflowScrollText> {
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
  void didUpdateWidget(_OverflowScrollText oldWidget) {
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
// DATA MODEL — one process row in the table
// =====================================================================

class _ProcessRow {
  int slNo;
  int? bopId; // existing row ID (0 = new)
  int? bopProcessId; // row-level process ID from API
  String? processId; // master process ID (string for LOV match)
  String? processLabel;
  int? bopNxtProcsId; // next process ID from API
  String? nextProcessId;
  String? nextProcessLabel;
  final TextEditingController smvCtrl;
  final TextEditingController actualQtyCtrl;
  final TextEditingController conversionQtyCtrl;

  _ProcessRow({
    required this.slNo,
    this.bopId,
    this.bopProcessId,
    this.processId,
    this.processLabel,
    this.bopNxtProcsId,
    this.nextProcessId,
    this.nextProcessLabel,
    String smv = '',
    String actualQty = '1',
    String conversionQty = '1',
  })  : smvCtrl = TextEditingController(text: smv),
        actualQtyCtrl = TextEditingController(text: actualQty),
        conversionQtyCtrl = TextEditingController(text: conversionQty);

  // true if this row already exists in the database
  bool get existsInDb => bopId != null && bopId != 0;

  // row_actions value for this row when included in a save payload
  String get rowAction => existsInDb ? 'U' : 'C';

  void dispose() {
    smvCtrl.dispose();
    actualQtyCtrl.dispose();
    conversionQtyCtrl.dispose();
  }
}

// =====================================================================
// TABLE ROW WIDGET
// =====================================================================

class _TableRowWidget extends StatelessWidget {
  final _ProcessRow row;
  final int index;
  final List<Map<String, String>> processList;
  final List<Map<String, String>> nextProcessList;
  final bool isLocked; // true when this version is already submitted
  final void Function(int) onRemove;
  final void Function(
    String title,
    List<Map<String, String>> items,
    void Function(String, String) onSelect,
  ) onSearch;
  final void Function(VoidCallback) onSetState;

  const _TableRowWidget({
    required Key key,
    required this.row,
    required this.index,
    required this.processList,
    required this.nextProcessList,
    required this.isLocked,
    required this.onRemove,
    required this.onSearch,
    required this.onSetState,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isEven = index % 2 == 0;
    return Container(
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFFFFDE7) : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // SL No
          Expanded(
            flex: 1,
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Center(
                child: Text(
                  '${row.slNo}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Process Name
          Expanded(
            flex: 5,
            child: _dropdownCell(
              value: row.processLabel,
              hint: 'Select',
              onTap: isLocked
                  ? null
                  : () => onSearch(
                        'Process Name',
                        processList,
                        (id, label) => onSetState(() {
                          row.processId = id;
                          row.processLabel = label;
                        }),
                      ),
            ),
          ),
          const SizedBox(width: 4),

          // SMV
          Expanded(
            flex: 2,
            child: _numberCell(
              controller: row.smvCtrl,
              hint: '0.0',
              decimal: true,
              enabled: !isLocked,
            ),
          ),
          const SizedBox(width: 4),

          // Actual Qty
          Expanded(
            flex: 2,
            child: _numberCell(
              controller: row.actualQtyCtrl,
              hint: '1',
              enabled: !isLocked,
            ),
          ),
          const SizedBox(width: 4),

          // Conv Qty
          Expanded(
            flex: 2,
            child: _numberCell(
              controller: row.conversionQtyCtrl,
              hint: '1',
              enabled: !isLocked,
            ),
          ),
          const SizedBox(width: 4),

          // Next Process
          Expanded(
            flex: 5,
            child: _dropdownCell(
              value: row.nextProcessLabel,
              hint: 'Select',
              onTap: isLocked
                  ? null
                  : () => onSearch(
                        'Next Process',
                        nextProcessList,
                        (id, label) => onSetState(() {
                          row.nextProcessId = id;
                          row.nextProcessLabel = label;
                        }),
                      ),
            ),
          ),
          const SizedBox(width: 4),

          // Delete — hidden once submitted; only editable on a new version
          isLocked
              ? const SizedBox(width: 24)
              : GestureDetector(
                  onTap: () => onRemove(index),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 14, color: Colors.red.shade400),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _dropdownCell({
    required String? value,
    required String hint,
    required VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: onTap == null ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  value ?? hint,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        value != null ? Colors.black87 : Colors.grey.shade400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (onTap != null)
              const Icon(Icons.arrow_drop_down,
                  size: 16, color: Colors.black54),
          ]),
        ),
      );

  Widget _numberCell({
    required TextEditingController controller,
    required String hint,
    bool decimal = false,
    bool enabled = true,
  }) =>
      Container(
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: TextField(
          controller: controller,
          readOnly: !enabled,
          keyboardType: decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          inputFormatters: decimal
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
        ),
      );
}

// =====================================================================
// PAGE
// =====================================================================

class ProcessSmvSetPage extends StatefulWidget {
  const ProcessSmvSetPage({super.key});

  @override
  State<ProcessSmvSetPage> createState() => _ProcessSmvSetPageState();
}

class _ProcessSmvSetPageState extends State<ProcessSmvSetPage> {
  final ProcessSmvService _svc = ProcessSmvService();

  // ── Header state ─────────────────────────────────────────────────
  int? itemBiiId;
  String? itemLabel;
  String? orderType;
  int currentVersion = 0;
  int _existingVersionCount = 0;
  String? orderNo; // BPO_PO_NO from item
  String? smvTotal; // PCH_SMV from item
  String? pocNo; // PCH_NO from item
  bool submitToggle = false;
  bool _alreadySubmittedOnServer = false;

  // ── Lists ─────────────────────────────────────────────────────────
  List<SmvItem> itemList = [];
  List<SmvVersion> versionList = [];
  List<Map<String, String>> processList =
      []; // Process Name dropdown (BOP_PROCESS)
  List<Map<String, String>> nextProcessList =
      []; // Next Process dropdown (BOP_NEXT_PROCESS)

  // ── Table rows ────────────────────────────────────────────────────
  // ── Table rows ────────────────────────────────────────────────────
  final List<_ProcessRow> _rows = [];

  // Rows that existed in the DB and were removed during this session —
  // sent to the backend with row_actions: 'D' on next save.
  final List<_ProcessRow> _deletedRows = [];

  bool isLoading = false;
  String? appUser;
  String companyId = '5';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

 @override
  void dispose() {
    for (final r in _rows) r.dispose();
    for (final r in _deletedRows) r.dispose();
    super.dispose();
  }

  // ── Initial load ──────────────────────────────────────────────────

  Future<void> _loadInitialData() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    appUser = prefs.getString('userId');
    companyId = prefs.getString('selected_company_id') ?? '5';
    await _loadItems();
    setState(() => isLoading = false);
  }

  // 1. Load item list — PROCESS_BII
  Future<void> _loadItems() async {
    try {
      final data = await _svc.fetchItems(companyId: companyId);
      setState(() => itemList = data);
    } catch (e) {
      _showError("Failed to load items: $e");
    }
  }

  // 2. After item selected — load versions (PROCESS_VERSION)
  //    then auto-select the latest version and load its details
  Future<void> _onItemSelected(SmvItem item) async {
    setState(() {
      itemBiiId = item.biiId;
      itemLabel = item.itemDesc;
      orderNo = item.bpoPONo;
      smvTotal = item.smv.toString();
      pocNo = item.pocNo;
      orderType = null;
      currentVersion = 0;
      _existingVersionCount = 0;
      submitToggle = false;
      _alreadySubmittedOnServer = false;
      for (final r in _rows) r.dispose();
      _rows.clear();
      for (final r in _deletedRows) r.dispose();
      _deletedRows.clear();
      versionList.clear();
      processList.clear();
    });

    await Future.wait([
      _loadVersions(item.biiId),
      _loadProcessLov(),
    ]);
  }

  // 3. Load versions for item — PROCESS_VERSION
  Future<void> _loadVersions(int biiId) async {
    setState(() => isLoading = true);
    try {
      final versions = await _svc.fetchVersions(biiId: biiId);
      if (!mounted) return;

      final withOrderType = versions.where((v) => v.orderType.isNotEmpty);
      final itemOrderType =
          withOrderType.isNotEmpty ? withOrderType.first.orderType : null;

      setState(() {
        versionList = versions;
        _existingVersionCount = versions.isNotEmpty
            ? versions.map((v) => v.version).reduce((a, b) => a > b ? a : b)
            : 0;
        orderType = itemOrderType;
      });

      if (versions.isNotEmpty) {
        // Auto-select the latest (highest) version
        final latest = versions.reduce((a, b) => a.version > b.version ? a : b);
        await _selectVersion(biiId, latest);
      } else {
        // No existing version — show one empty row
        await _fetchOrderTypeOnly(biiId);
        setState(() {
          currentVersion = 0;
          submitToggle = false;
        });
        _addEmptyRow();
      }
    } catch (e) {
      _showError("Failed to load versions: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 4. Select a specific version and load its process details
  Future<void> _selectVersion(int biiId, SmvVersion ver) async {
    // Any version that is not the latest must be submitted — you cannot
    // create a newer version without the previous one being submitted.
    // The backend only returns a reliable submitFlag for the latest version,
    // so for all older versions we force submitToggle = true.
    final isLatest = ver.version >= _existingVersionCount;
    final isSubmitted = !isLatest || ver.submitFlag == 1;
    setState(() {
      currentVersion = ver.version;
      submitToggle = isSubmitted;
      _alreadySubmittedOnServer = isSubmitted;
      isLoading = true;
    });
    try {
      final details =
          await _svc.fetchProcessDetails(biiId: biiId, version: ver.version);
      if (!mounted) return;

      for (final r in _rows) r.dispose();
      _rows.clear();
      for (final r in _deletedRows) r.dispose();
      _deletedRows.clear();

      for (int i = 0; i < details.length; i++) {
        final d = details[i];
        final procLabel = _labelForId(d.bopProcessId.toString(), processList);
        final nextLabel =
            _labelForId(d.bopNxtProcsId.toString(), nextProcessList);

        _rows.add(_ProcessRow(
          slNo: d.bopSl,
          bopId: d.bopId,
          bopProcessId: d.bopProcessId,
          processId: d.bopProcessId.toString(),
          processLabel: procLabel,
          bopNxtProcsId: d.bopNxtProcsId,
          nextProcessId: d.bopNxtProcsId.toString(),
          nextProcessLabel: nextLabel,
          smv: d.smv.toString(),
          actualQty: '1',
          conversionQty: '1',
        ));
      }

      if (_rows.isEmpty) _addEmptyRow();
      setState(() {});
    } catch (e) {
      _showError("Failed to load process details: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 5. Load process LOV for dropdowns
  Future<void> _loadProcessLov() async {
    try {
      final results = await Future.wait([
        _svc.fetchProcessLov(companyId: companyId),
        _svc.fetchNextProcessLov(companyId: companyId),
      ]);
      if (!mounted) return;
      setState(() {
        processList = results[0];
        nextProcessList = results[1];
      });
      if (results[0].isEmpty || results[1].isEmpty) {
        _showError(
            "Process list could not be loaded — please check with admin (process LOV query).");
      }
    } catch (e) {
      debugPrint("Process LOV load failed: $e");
    }
  }

  Future<void> _fetchOrderTypeOnly(int biiId) async {
    try {
      final uri = Uri.parse(ProcessSmvService.baseUrl).replace(queryParameters: {
        'P_QRYTYP': 'PROCESS_VERSION',
        'p_bii_id': biiId.toString(),
      });
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final pvList = body['PROCESS_VERSION'] as List<dynamic>? ?? [];
        if (pvList.isNotEmpty) {
          final first = pvList.first as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              orderType = first['ORDER_TYPE'] as String? ?? orderType;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[_fetchOrderTypeOnly] failed: $e');
    }
  }

  String? _labelForId(String id, List<Map<String, String>> list) {
    try {
      return list.firstWhere((e) => e['id'] == id)['label'];
    } catch (_) {
      return null;
    }
  }

  // ── Row management ───────────────────────────────────────────────

  void _addEmptyRow() {
    _rows.add(_ProcessRow(slNo: _rows.length + 1));
  }

  void _removeRow(int index) {
    if (index < 0 || index >= _rows.length) return;
    setState(() {
      final row = _rows.removeAt(index);
      if (row.existsInDb) {
        // Keep it (don't dispose) so we can send bop_id with row_actions: 'D'
        _deletedRows.add(row);
      } else {
        // Never saved — safe to discard entirely
        row.dispose();
      }
      if (_rows.isEmpty) {
        _rows.add(_ProcessRow(slNo: 1));
      } else {
        for (int i = 0; i < _rows.length; i++) {
          _rows[i].slNo = i + 1;
        }
      }
    });
  }

  // ── Version management ───────────────────────────────────────────

  // ── Version management ───────────────────────────────────────────

  Future<void> _createNewVersion() async {
    if (itemBiiId == null) {
      _showError("Please select an item first");
      return;
    }
    if (currentVersion == 0) {
      _showError("No existing version to copy from");
      return;
    }

    setState(() => isLoading = true);
    try {
      final errorMsg = await _svc.createNewVersion(
        biiId:       itemBiiId!,
        fromVersion: currentVersion,
        appUser:     appUser ?? '',
        companyId:   companyId,
      );

      if (!mounted) return;

      if (errorMsg != null) {
        _showError(errorMsg);
        return;
      }

      final newVer = currentVersion + 1;
      _showSuccess("New version $newVer created");

      await _loadVersions(itemBiiId!);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showVersionPicker() {
    if (versionList.isEmpty) return;
    final sorted = List<SmvVersion>.from(versionList)
      ..sort((a, b) => b.version.compareTo(a.version));
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: sorted.length <= 3 ? 0.35 : 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.75,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Text("Select Version",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: sorted.length,
                itemBuilder: (_, i) {
                  final v = sorted[i];
                  return ListTile(
                    title: Text("Version-${v.version}",
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        "${v.orderType}${(v.version < _existingVersionCount || v.submitFlag == 1) ? ' • Submitted' : ''}",
                        style: const TextStyle(fontSize: 11)),
                    trailing: currentVersion == v.version
                        ? const Icon(Icons.check_circle,
                            color: Color(0xFF1A73E8))
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _selectVersion(itemBiiId!, v);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Clear ─────────────────────────────────────────────────────────

  void _clearAll() {
    for (final r in _rows) r.dispose();
    _rows.clear();
    for (final r in _deletedRows) r.dispose();
    _deletedRows.clear();
    setState(() {
      itemBiiId = null;
      itemLabel = null;
      orderType = null;
      currentVersion = 0;
      _existingVersionCount = 0;
      orderNo = null;
      smvTotal = null;
      pocNo = null;
      submitToggle = false;
      _alreadySubmittedOnServer = false;
      versionList.clear();
      processList.clear();
    });
    _addEmptyRow();
    setState(() {});
  }

  // ── Save ─────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    if (itemBiiId == null) {
      _showError("Please select an item");
      return;
    }
    if (orderType == null) {
      _showError("Order type is required");
      return;
    }
    if (currentVersion == 0) {
      // First save for this item — auto-assign version 1
      setState(() => currentVersion = 1);
    }

    for (int i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      if (r.processId == null) {
        _showError("Row ${i + 1}: Please select a process");
        return;
      }
      if (r.smvCtrl.text.trim().isEmpty) {
        _showError("Row ${i + 1}: SMV is required");
        return;
      }
    }

    setState(() => isLoading = true);
    try {
      final activeRows = _rows.map((r) => {
            'row_actions':  r.rowAction, // 'C' or 'U'
            'bop_id':       r.bopId ?? 0,
            'process_id':   int.tryParse(r.processId ?? '0') ?? 0,
            'sl':           r.slNo,
            'smv':          double.tryParse(r.smvCtrl.text) ?? 0.0,
            'flag':         'R',
            'nxt_procs_id': int.tryParse(r.nextProcessId ?? '0') ?? 0,
            'actual_qty':   int.tryParse(r.actualQtyCtrl.text) ?? 1,
            'conv_qty':     int.tryParse(r.conversionQtyCtrl.text) ?? 1,
          }).toList();

      final deletedRowsPayload = _deletedRows.map((r) => {
            'row_actions':  'D',
            'bop_id':       r.bopId,
            'process_id':   int.tryParse(r.processId ?? '0') ?? 0,
            'sl':           r.slNo,
            'smv':          double.tryParse(r.smvCtrl.text) ?? 0.0,
            'flag':         'R',
            'nxt_procs_id': int.tryParse(r.nextProcessId ?? '0') ?? 0,
            'actual_qty':   int.tryParse(r.actualQtyCtrl.text) ?? 1,
            'conv_qty':     int.tryParse(r.conversionQtyCtrl.text) ?? 1,
          }).toList();

      final rows = [...activeRows, ...deletedRowsPayload];

      final errorMsg = await _svc.saveSmvSet(
        biiId:     itemBiiId!,
        version:   currentVersion,
        submit:    submitToggle,
        appUser:   appUser ?? '',
        companyId: companyId,
        rows:      rows,
      );

      if (!mounted) return;

      if (errorMsg == null) {
        _showSuccess("Process & SMV Set saved successfully");
        for (final r in _deletedRows) r.dispose();
        _deletedRows.clear();
        await _loadVersions(itemBiiId!);
      } else {
        _showError(errorMsg);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: Stack(children: [
        Column(children: [
          const TopMenuBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 12),
                  _buildProcessTable(),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.center,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 36, vertical: 14),
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
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ]),
        if (isLoading)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A73E8)),
              ),
            ),
          ),
      ]),
    );
  }

  // ── Header card ───────────────────────────────────────────────────

  Widget _buildHeaderCard() {
    final versionLabel = currentVersion > 0 ? "Version-$currentVersion" : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Row 1: Item label + Clear
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Text("Item Description",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.black)),
          const Spacer(),
          TextButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.refresh_rounded, size: 13),
            label: const Text("Clear",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade400,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              backgroundColor: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ]),
        const SizedBox(height: 4),

        // Item dropdown — opens item table dialog
        _dropdownTrigger(
          value: itemLabel,
          onTap: () => _itemSearchDialog(),
          width: double.infinity,
        ),
        const SizedBox(height: 10),

        // Row 2: Order Type (read-only) | Version (tappable if multiple)
        // Row 2: Version (narrow) | Order Type (narrow) | SMV
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Expanded(
    flex: 1,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Version",
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.black)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: versionList.isNotEmpty ? _showVersionPicker : null,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 6),
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
                child: Text(
                  versionLabel ?? "Select",
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down,
                  color: Colors.black87, size: 16),
            ]),
          ),
        ),
      ],
    ),
  ),
  const SizedBox(width: 8),
  SizedBox(
    width: 110,
    child: _readOnlyField("Order Type", orderType),
  ),
  const SizedBox(width: 8),
  SizedBox(
    width: 90,
    child: _readOnlyField("SMV", smvTotal),
  ),
]),
const SizedBox(height: 10),

// Row 3: Order No (wide) | POC No | Submit
// Row 3: Order No (wide) | POC No | Submit
Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Expanded(
      flex: 6, child: _readOnlyField("Order No", orderNo, wrap: true)),
  const SizedBox(width: 4),
  Expanded(flex: 5, child: _readOnlyField("POC No", pocNo, wrap: true)),
  const SizedBox(width: 8),
  SizedBox(
    width: 52,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text("Submit",
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.black)),
        const SizedBox(height: 2),
        SizedBox(
          width: 52,
          height: 28,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Switch(
  value: submitToggle,
  onChanged: _alreadySubmittedOnServer
      ? (_) {} // locked but keeps active color (no-op instead of null)
      : (v) => setState(() => submitToggle = v),
  activeThumbColor: const Color(0xFF1A73E8),
  activeTrackColor: const Color(0xFF1A73E8).withValues(alpha: 0.5),
),
          ),
        ),
      ],
    ),
  ),
]),
        const SizedBox(height: 10),

        // Row 4: Version exists | New Version
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Version exists : ${_existingVersionCount > 0 ? _existingVersionCount : '-'}",
              style: TextStyle(
                color: Colors.red.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _createNewVersion,
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text("New Version",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A73E8),
                side: const BorderSide(color: Color(0xFF1A73E8), width: 1.2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ]),
    );
  }

  // ── Process table ─────────────────────────────────────────────────

  Widget _buildProcessTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add row button — hidden once submitted; only available on a new version
          if (!_alreadySubmittedOnServer) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: OutlinedButton.icon(
                onPressed: () {
                  if (processList.isEmpty) {
                    _loadProcessLov();
                  }
                  setState(() => _addEmptyRow());
                },
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text("Add row",
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A73E8),
                  side: const BorderSide(color: Color(0xFF1A73E8), width: 1.2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ] else
            const SizedBox(height: 10),

          // Column headers
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A73E8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _th("SL", flex: 1),
                const SizedBox(width: 4),
                _th("Process Name", flex: 5),
                const SizedBox(width: 4),
                _th("SMV", flex: 2),
                const SizedBox(width: 4),
                _th("Act.\nQty", flex: 2),
                const SizedBox(width: 4),
                _th("Conv.\nQty", flex: 2),
                const SizedBox(width: 4),
                _th("Next Process", flex: 5),
                const SizedBox(width: 28),
              ],
            ),
          ),

          // Data rows
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < _rows.length; i++)
                  _TableRowWidget(
                    key: ValueKey(_rows[i].hashCode),
                    row: _rows[i],
                    index: i,
                    processList: processList,
                    nextProcessList: nextProcessList,
                    isLocked: _alreadySubmittedOnServer,
                    onRemove: _removeRow,
                    onSearch: _searchDialog,
                    onSetState: setState,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────

  Widget _th(String label, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
          softWrap: true,
        ),
      );

  Widget _columnDivider() => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: Colors.black12,
      );

  Widget _dropdownTrigger({
    required String? value,
    required VoidCallback onTap,
    required double width,
  }) =>
      SizedBox(
        width: width,
        child: InkWell(
          onTap: onTap,
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
                child: _OverflowScrollText(
                  text: value ?? "Select",
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
      );

  Widget _readOnlyField(String label, String? value, {bool wrap = false}) {
    // Use wrapping text only when wrap:true AND there's real content.
    // Otherwise fall back to the original fixed-height scrollable box
    // so the field doesn't collapse to a tiny height before an item is selected.
    final hasContent = value != null && value.isNotEmpty && value != '-';
    final useWrap = wrap && hasContent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.black)),
        const SizedBox(height: 4),
        Container(
          height: useWrap ? null : 38,
          constraints: useWrap ? const BoxConstraints(minHeight: 38) : null,
          padding: useWrap
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
              : null,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EAED),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: useWrap
              ? Text(
                  value,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                )
              : _OverflowScrollText(
                  text: value ?? "-",
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
        ),
      ],
    );
  }

  // ── Item search dialog ─────────────────────────────────────────────

  void _itemSearchDialog() {
    List<SmvItem> filtered = List.from(itemList);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (c, setS) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
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
            const Text("Select Item",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            const SizedBox(height: 12),
            // Search box
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
                  filtered = itemList.where((e) {
                    return e.itemDesc.toLowerCase().contains(q) ||
                        e.pocNo.toLowerCase().contains(q) ||
                        e.bpoPONo.toLowerCase().contains(q);
                  }).toList();
                }),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, color: Colors.black54),
                  hintText: "Search by item, POC No or PO No...",
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1A73E8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: const Row(children: [
                Expanded(
                    flex: 3,
                    child: Text("Item Desc",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white))),
                SizedBox(width: 6),
                Expanded(
                    flex: 2,
                    child: Text("POC No",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white))),
                SizedBox(width: 6),
                Expanded(
                    flex: 2,
                    child: Text("PO No",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white))),
                SizedBox(width: 6),
                SizedBox(
                    width: 36,
                    child: Text("SMV",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white))),
              ]),
            ),
            // Rows
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: filtered.isEmpty
                    ? const Center(
                        child: Text("No items found",
                            style: TextStyle(fontSize: 14, color: Colors.grey)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final item = filtered[i];
                          return InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              _onItemSelected(item);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 11, horizontal: 12),
                              decoration: BoxDecoration(
                                color: i % 2 == 0
                                    ? Colors.white
                                    : const Color(0xFFF8F9FA),
                                border: Border(
                                  bottom:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                          flex: 3,
                                          child: Text(item.itemDesc,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87))),
                                      _columnDivider(),
                                      Expanded(
                                          flex: 2,
                                          child: Text(item.pocNo,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87))),
                                      _columnDivider(),
                                      Expanded(
                                          flex: 2,
                                          child: Text(item.bpoPONo,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87))),
                                      _columnDivider(),
                                      SizedBox(
                                        width: 36,
                                        child: Text(item.smv.toStringAsFixed(1),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1A73E8))),
                                      ),
                                    ]),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ]),
        );
      }),
    );
  }

  // ── Generic search bottom sheet (process LOV) ─────────────────────

  void _searchDialog(
    String title,
    List<Map<String, String>> items,
    void Function(String, String) onSelect,
  ) {
    List<Map<String, String>> filtered = List.from(items);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (c, setS) {
        int displayCount = items.length < 10 ? items.length : 10;
        return Container(
          height: MediaQuery.of(context).size.height * 0.80,
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
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setS(() {
                  filtered = items
                      .where((e) =>
                          e["label"]!.toLowerCase().contains(v.toLowerCase()))
                      .toList();
                  displayCount = filtered.length < 10 ? filtered.length : 10;
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
              child: filtered.isEmpty
                  ? const Center(
                      child: Text("No items found",
                          style: TextStyle(fontSize: 14, color: Colors.grey)))
                  : ListView.builder(
                      itemCount: displayCount < filtered.length
                          ? displayCount + 1
                          : (displayCount > filtered.length
                              ? filtered.length
                              : displayCount),
                      itemBuilder: (_, index) {
                        if (index == displayCount &&
                            displayCount < filtered.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Center(
                              child: ElevatedButton(
                                onPressed: () => setS(() => displayCount += 10),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A73E8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  minimumSize: Size.zero,
                                ),
                                child: const Text('Show More',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11)),
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
                            Navigator.pop(ctx);
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
}
