import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackall_app/pages/widgets/top_menu_bar.dart';
import '../services/lov_service.dart';
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
                _isScrolled ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
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

  TimeOfDay? startTime, endTime;

  final TextEditingController _startController     = TextEditingController();
  final TextEditingController _endController       = TextEditingController();
  final TextEditingController _smvController       = TextEditingController();
  final TextEditingController _operatorsController = TextEditingController();
  final TextEditingController _gmtLossController   = TextEditingController();
  final TextEditingController _remarksController   = TextEditingController();

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

  static const _kBuilding  = 'building';
  static const _kProcess   = 'process';
  static const _kCategory  = 'category';
  static const _kLine      = 'line';
  static const _kMachine   = 'machine';
  static const _kDept      = 'dept';
  static const _kRespUser  = 'respUser';
  static const _kCause     = 'cause';
  static const _kSmv       = 'smv';
  static const _kOperators = 'operators';
  static const _kGmtLoss   = 'gmtLoss';
  static const _kRemarks   = 'remarks';
  static const _kStartTime = 'startTime';
  static const _kEndTime   = 'endTime';

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
        _lovService.fetchLov(qryType: "RESP_DEPT", appUserId: loginUserId).then((v) => responsibleDeptList   = v),
        _lovService.fetchLov(qryType: "OPERATION", appUserId: loginUserId).then((v) => operationCategoryList = v),
        _lovService.fetchLov(qryType: "RESP_USER", appUserId: loginUserId).then((v) => responsibleUserList   = v),
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

  void _clearAll() {
    setState(() {
      buildingId = null;          buildingLabel = null;
      processId = null;           processLabel = null;
      lineId = null;              lineLabel = null;    lineList = [];
      categoryId = null;          categoryLabel = null;
      responsibleUserId = null;   responsibleUserLabel = null;
      deptId = null;              deptLabel = null;
      causeLabel = null;
      machineNo = null;           machineLabel = null;
      smv = null;  remarks = null;  gmtLossQty = null;  numberOfOperators = null;
      startTime = null;           endTime = null;
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

    final success = await _lovService.saveNptEntry(
      entryDate: selectedDate,
      buildingId: buildingId!, processId: processId!, lineId: lineId!,
      machineNo: machineNo!, smv: smv!, categoryId: categoryId!,
      startTime: startTime!, endTime: endTime!, cause: causeLabel!,
      deptId: deptId!, responsibleUserId: responsibleUserId!,
      remarks: remarks!, gmtLossQty: gmtLossQty!,
      staffId: loginUserId, numberOfOperators: numberOfOperators!,
    );

    nptList.insert(0, {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "building": buildingLabel, "process": processLabel,
      "P_START_TIME": _startController.text,
      "P_END_TIME": _endController.text,
      "totalTime": totalTimeFormatted,
      "gmtLossQty": gmtLossQty,
      "isSynced": success, "date": _dateController.text,
    });

    await prefs.setString('ctl_npt_list', jsonEncode(nptList));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? "Entry Saved Successfully!" : "Saved Offline (Pending Sync)"),
      backgroundColor: success ? Colors.green : Colors.orange,
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
                      setState(() { deptId = id; deptLabel = label; _missingFields.remove(_kDept); });
                    }, width),

                    _timeField("Start Time *", _startController, () => pickTime(true),  width, _kStartTime, icon: Icons.access_time),
                    _timeField("End Time *",   _endController,   () => pickTime(false), width, _kEndTime,   icon: Icons.access_time),

                    _readOnlyField("Total (Min)", totalTimeFormatted, width),

                    // ── SMV — decimal ──────────────────────────────
                    _numberField("SMV *", _smvController, _kSmv, (v) {
                      smv = v;
                      if (v.isNotEmpty) setState(() => _missingFields.remove(_kSmv));
                    }, width),

                    _modernDropdown(context, "Cause *", causeLabel, downtimeCauseList, _kCause, (id, label) {
                      setState(() { causeLabel = label; _missingFields.remove(_kCause); });
                    }, width),

                    // ── Operators — integers ───────────────────────
                    _numberField("Number of Operators *", _operatorsController, _kOperators, (v) {
                      numberOfOperators = v;
                      if (v.isNotEmpty) setState(() => _missingFields.remove(_kOperators));
                    }, width, integersOnly: true),

                    _modernDropdown(context, "Responsible User *", responsibleUserLabel, responsibleUserList, _kRespUser, (id, label) {
                      setState(() { responsibleUserId = id; responsibleUserLabel = label; _missingFields.remove(_kRespUser); });
                    }, width),

                    // ── GMT Loss — decimal ─────────────────────────
                    _numberField("GMT Loss Qty *", _gmtLossController, _kGmtLoss, (v) {
                      gmtLossQty = v;
                      if (v.isNotEmpty) setState(() => _missingFields.remove(_kGmtLoss));
                    }, width),

                    _textField("Remarks *", _remarksController, _kRemarks, (v) {
                      remarks = v;
                      if (v.isNotEmpty) setState(() => _missingFields.remove(_kRemarks));
                    }, width * 2 + 12),

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
  // WIDGET HELPERS
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
          onTap: () => _searchDialog(context, label, list, onSelect),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: _fieldBorder(fieldKey),
              boxShadow: isMissing
                  ? [BoxShadow(color: Colors.red.withOpacity(0.10), blurRadius: 4, offset: const Offset(0, 2))]
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

  // ── Number-only field: centered using isDense + Center wrapper ───
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
                ? [BoxShadow(color: Colors.red.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))]
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

  // ── Plain text field (Remarks) — centered using isDense + Center wrapper ──
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
                ? [BoxShadow(color: Colors.red.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))]
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

  void _searchDialog(BuildContext context, String title,
      List<Map<String, String>> items, void Function(String, String) onSelect) {
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
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Text("Select $title",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
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
                    filtered = items.where((e) => e["label"]!.toLowerCase().contains(v.toLowerCase())).toList();
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
                  if (filtered.isEmpty && currentSearch.isNotEmpty)
                    ListTile(
                      title: Text("Use manual: $currentSearch",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      leading: const Icon(Icons.add_circle, color: Colors.blue),
                      onTap: () { onSelect(currentSearch, currentSearch); Navigator.pop(context); },
                    ),
                  ...filtered.map((item) => ListTile(
                        title: Text(item["label"]!,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        onTap: () { onSelect(item["id"]!, item["label"]!); Navigator.pop(context); },
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