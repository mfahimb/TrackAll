import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackall_app/pages/widgets/top_menu_bar.dart';
import '../services/lov_service.dart';
import 'package:intl/intl.dart';

class NptEntryPage extends StatefulWidget {
  const NptEntryPage({super.key});

  @override
  State<NptEntryPage> createState() => _NptEntryPageState();
}

class _NptEntryPageState extends State<NptEntryPage> {
  // ================= DATE =================
  DateTime selectedDate = DateTime.now();
  final TextEditingController _dateController = TextEditingController();

  String? buildingId,
      processId,
      lineId,
      categoryId,
      responsibleUserId,
      deptId,
      machineNo;

  String? buildingLabel,
      processLabel,
      lineLabel,
      categoryLabel,
      responsibleUserLabel,
      deptLabel,
      causeLabel,
      machineLabel;

  String? smv, remarks, gmtLossQty, numberOfOperators;

  TimeOfDay? startTime, endTime;

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  List<Map<String, String>> buildingList = [],
      processList = [],
      lineList = [],
      responsibleUserList = [],
      responsibleDeptList = [],
      downtimeCauseList = [],
      operationCategoryList = [];

  final List<Map<String, String>> machineList =
      List.generate(10, (i) => {"id": "${i + 1}", "label": "${i + 1}"});

  List<Map<String, dynamic>> nptList = [];

  late SharedPreferences prefs;
  bool _isLoading = true;

  final LovService _lovService = LovService();

  late String loginUserId;
  late String selectedCompanyId;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd-MM-yyyy').format(selectedDate);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    prefs = await SharedPreferences.getInstance();
    loginUserId = prefs.getString("userId") ?? "0";
    selectedCompanyId = prefs.getString("selected_company_id") ?? "0";

    final raw = prefs.getString('npt_list');
    if (raw != null) nptList = List<Map<String, dynamic>>.from(jsonDecode(raw));

    try {
      await Future.wait([
        _lovService
            .fetchLov(qryType: "BUILDING", appUserId: loginUserId)
            .then((v) => buildingList = v),
        _lovService
            .fetchLov(qryType: "PROCESS", appUserId: loginUserId)
            .then((v) => processList = v),
        _lovService
            .fetchLov(qryType: "DOWNTIME", appUserId: loginUserId)
            .then((v) => downtimeCauseList = v),
        _lovService
            .fetchLov(qryType: "RESP_DEPT", appUserId: loginUserId)
            .then((v) => responsibleDeptList = v),
        _lovService
            .fetchLov(qryType: "OPERATION", appUserId: loginUserId)
            .then((v) => operationCategoryList = v),
        _lovService
            .fetchLov(qryType: "RESP_USER", appUserId: loginUserId)
            .then((v) => responsibleUserList = v),
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
        qryType: "LINE",
        dwLocId: buildingId,
        dwSec: processId,
        appUserId: loginUserId,
      );
      setState(() {});
    } catch (e) {
      debugPrint("Error fetching lines: $e");
    }
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
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
    var end = DateTime(selectedDate.year, selectedDate.month, selectedDate.day,
        endTime!.hour, endTime!.minute);
    if (end.isBefore(start)) end = end.add(const Duration(days: 1));
    return end.difference(start).inMinutes.toString();
  }

  Future<void> pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          isStart ? (startTime ?? TimeOfDay.now()) : (endTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startTime = picked;
          _startController.text = picked.format(context);
        } else {
          endTime = picked;
          _endController.text = picked.format(context);
        }
      });
    }
  }

 // ================= SAVE HANDLER (UPDATED) =================
Future<void> _handleSave() async {
  if ([
        buildingId,
        processId,
        categoryId,
        lineId,
        machineNo,
        deptId,
        responsibleUserId,
        causeLabel,
        smv,
        numberOfOperators,
        gmtLossQty,
        remarks,
        startTime,
        endTime,
      ].any((e) => e == null || (e is String && e.trim().isEmpty))) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("All fields are mandatory. Please complete the form."),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  if (int.tryParse(numberOfOperators!) == null ||
      double.tryParse(gmtLossQty!) == null ||
      double.tryParse(smv!) == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("SMV, Operators, and GMT Loss Qty must be numeric"),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  final success = await _lovService.saveNptEntry(
    entryDate: selectedDate,
    buildingId: buildingId!,
    processId: processId!,
    lineId: lineId!,
    machineNo: machineNo!,
    smv: smv!,
    categoryId: categoryId!,
    startTime: startTime!,
    endTime: endTime!,
    cause: causeLabel!,
    deptId: deptId!,
    responsibleUserId: responsibleUserId!,
    remarks: remarks!,
    gmtLossQty: gmtLossQty!,
    staffId: loginUserId,
    numberOfOperators: numberOfOperators!,
  );

  nptList.insert(0, {
    "id": DateTime.now().millisecondsSinceEpoch.toString(),
    "building": buildingLabel,
    "process": processLabel,
    "P_START_TIME": _startController.text,
    "P_END_TIME": _endController.text,
    "totalTime": totalTimeFormatted,
    "isSynced": success,
    "date": _dateController.text,
  });

  await prefs.setString('npt_list', jsonEncode(nptList));

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
          success ? "Entry Saved Successfully!" : "Saved Offline (Pending Sync)"),
      backgroundColor: success ? Colors.green : Colors.orange,
    ),
  );
}


 @override
Widget build(BuildContext context) {
  if (_isLoading) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  return Scaffold(
    backgroundColor: const Color(0xFFF0F2F8),
    body: Column(
      children: [
        // ✅ TOP MENU BAR ADDED (NEW)
        const TopMenuBar(),

        // ✅ PAGE CONTENT (UNCHANGED)
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final width = (constraints.maxWidth - 44) / 2;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  _dateField(
                    "Date *",
                    _dateController,
                    pickDate,
                    constraints.maxWidth - 32,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _modernDropdown(context, "Building *", buildingLabel,
                          buildingList, (id, label) {
                        setState(() {
                          buildingId = id;
                          buildingLabel = label;
                          processId = null;
                          processLabel = null;
                          lineId = null;
                          lineLabel = null;
                          lineList = [];
                        });
                        fetchLine();
                      }, width),
                      _modernDropdown(context, "Process *", processLabel,
                          processList, (id, label) {
                        setState(() {
                          processId = id;
                          processLabel = label;
                          lineId = null;
                          lineLabel = null;
                          lineList = [];
                        });
                        fetchLine();
                      }, width),
                      _modernDropdown(context, "Category *", categoryLabel,
                          operationCategoryList, (id, label) {
                        setState(() {
                          categoryId = id;
                          categoryLabel = label;
                        });
                      }, width),
                      _modernDropdown(context, "Line No", lineLabel, lineList,
                          (id, label) {
                        setState(() {
                          lineId = id;
                          lineLabel = label;
                        });
                      }, width),
                      _modernDropdown(context, "Machine No", machineLabel,
                          machineList, (id, label) {
                        setState(() {
                          machineNo = id;
                          machineLabel = label;
                        });
                      }, width),
                      _modernDropdown(context, "Responsible Dept *", deptLabel,
                          responsibleDeptList, (id, label) {
                        setState(() {
                          deptId = id;
                          deptLabel = label;
                        });
                      }, width),
                      _timeField("Start Time *", _startController,
                          () => pickTime(true), width,
                          icon: Icons.access_time),
                      _timeField("End Time *", _endController,
                          () => pickTime(false), width,
                          icon: Icons.access_time),
                      _readOnlyField(
                          "Total (Min)", totalTimeFormatted, width),
                      _textField("SMV", (v) => smv = v, width,
                          isNumber: true),
                      _modernDropdown(context, "Cause *", causeLabel,
                          downtimeCauseList, (id, label) {
                        setState(() => causeLabel = label);
                      }, width),
                      _textField("Number of Operators",
                          (v) => numberOfOperators = v, width,
                          isNumber: true),
                      _modernDropdown(context, "Responsible User *",
                          responsibleUserLabel, responsibleUserList,
                          (id, label) {
                        setState(() {
                          responsibleUserId = id;
                          responsibleUserLabel = label;
                        });
                      }, width),
                      _textField("GMT Loss Qty", (v) => gmtLossQty = v, width,
                          isNumber: true),
                      _textField(
                          "Remarks", (v) => remarks = v, width * 2 + 12),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleSave,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFF1A73E8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: const Text(
                            "SAVE",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1,
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
      ],
    ),
  );
}


  // --- UI Helpers below remain unchanged ---
  Widget _dateField(String label, TextEditingController controller, VoidCallback onTap, double width) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Row(
              children: [
                Expanded(child: Text(controller.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black))),
                const Icon(Icons.calendar_today, color: Colors.black54, size: 16),
              ],
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(builder: (c, setS) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.80,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                Text("Select $title", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 12),
                Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF1F3F4), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                  child: TextField(
                    autofocus: false,
                    onChanged: (v) => setS(() {
                      currentSearch = v;
                      filtered = items.where((e) => e["label"]!.toLowerCase().contains(v.toLowerCase())).toList();
                    }),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.black54), hintText: "Search...", border: InputBorder.none),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      if (filtered.isEmpty && currentSearch.isNotEmpty)
                        ListTile(
                          title: Text("Use manual: $currentSearch", style: const TextStyle(fontWeight: FontWeight.bold)),
                          leading: const Icon(Icons.add_circle, color: Colors.blue),
                          onTap: () {
                            onSelect(currentSearch, currentSearch);
                            Navigator.pop(context);
                          },
                        ),
                      ...filtered.map((item) => ListTile(
                        title: Text(item["label"]!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        onTap: () {
                          onSelect(item["id"]!, item["label"]!);
                          Navigator.pop(context);
                        },
                      )),
                    ],
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _modernDropdown(BuildContext context, String label, String? value, List<Map<String, String>> list, void Function(String, String) onSelect, double width) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _searchDialog(context, label, list, onSelect),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300), boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))]),
            child: Row(children: [
              Expanded(child: Text(value ?? "Select", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87), overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down, color: Colors.black87, size: 20),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _textField(String label, Function(String) onChanged, double width, {bool isNumber = false}) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 4),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
          child: TextField(
            keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
          ),
        ),
      ]),
    );
  }

  Widget _timeField(String label, TextEditingController controller, VoidCallback onTap, double width, {IconData? icon}) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: Row(children: [
              Expanded(child: Text(controller.text.isEmpty ? "00:00" : controller.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              if (icon != null) Icon(icon, color: Colors.black54, size: 18),
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
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: const Color(0xFFE8EAED), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade400)),
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ]),
    );
  }
}