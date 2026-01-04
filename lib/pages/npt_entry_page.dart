import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/lov_service.dart';

class NptEntryPage extends StatefulWidget {
  const NptEntryPage({super.key});

  @override
  State<NptEntryPage> createState() => _NptEntryPageState();
}

class _NptEntryPageState extends State<NptEntryPage> {
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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('npt_list');
    if (raw != null) nptList = List<Map<String, dynamic>>.from(jsonDecode(raw));

    await Future.wait([
      _lovService.fetchLov(qryType: "BUILDING").then((v) => buildingList = v),
      _lovService.fetchLov(qryType: "PROCESS").then((v) => processList = v),
      _lovService.fetchLov(qryType: "DOWNTIME").then((v) => downtimeCauseList = v),
      _lovService.fetchLov(qryType: "RESP_DEPT").then((v) => responsibleDeptList = v),
      _lovService.fetchLov(qryType: "OPERATION").then((v) => operationCategoryList = v),
      _lovService.fetchLov(qryType: "RESP_USER").then((v) => responsibleUserList = v),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> fetchLine() async {
    if (buildingId == null || processId == null) return;
    lineList = await _lovService.fetchLov(
      qryType: "LINE",
      dwLocId: buildingId,
      dwSec: processId,
    );
    setState(() {});
  }

  String get totalTimeFormatted {
    if (startTime == null || endTime == null) return "0";

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, startTime!.hour, startTime!.minute);
    var end = DateTime(now.year, now.month, now.day, endTime!.hour, endTime!.minute);

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
          startTime = picked;
          _startController.text = picked.format(context);
        } else {
          endTime = picked;
          _endController.text = picked.format(context);
        }
      });
    }
  }

  Future<void> _handleSave() async {
    if ([
      buildingId,
      processId,
      categoryId,
      causeLabel,
      startTime,
      endTime,
      responsibleUserId,
      deptId
    ].contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields *"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if ((numberOfOperators != null && int.tryParse(numberOfOperators!) == null) ||
        (gmtLossQty != null && double.tryParse(gmtLossQty!) == null) ||
        (smv != null && double.tryParse(smv!) == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Operators, GMT Loss Qty, and SMV must be numeric"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final s = DateTime(now.year, now.month, now.day, startTime!.hour, startTime!.minute);
    var e = DateTime(now.year, now.month, now.day, endTime!.hour, endTime!.minute);
    if (!e.isAfter(s)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("End Time must be after Start Time"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final loginStaffId = prefs.getString("userId") ?? "0";

    final success = await _lovService.saveNptEntry(
      buildingId: buildingId!,
      processId: processId!,
      lineId: lineId ?? "0",
      machineNo: machineNo ?? "0",
      smv: smv ?? "0",
      categoryId: categoryId!,
      startTime: startTime!,
      endTime: endTime!,
      cause: causeLabel!,
      deptId: deptId!,
      responsibleUserId: responsibleUserId!,
      remarks: remarks ?? "",
      gmtLossQty: gmtLossQty ?? "0",
      staffId: loginStaffId,
      numberOfOperators: numberOfOperators ?? "0",
    );

    nptList.insert(0, {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "building": buildingLabel,
      "process": processLabel,
      "P_START_TIME": _startController.text,
      "P_END_TIME": _endController.text,
      "totalTime": totalTimeFormatted,
      "isSynced": success,
    });

    await prefs.setString('npt_list', jsonEncode(nptList));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? "Entry Saved Successfully!" : "Failed to Save"),
        backgroundColor: success ? Colors.green : Colors.red,
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
      appBar: AppBar(
        title: const Text("NPT Entry", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final width = (constraints.maxWidth - 44) / 2;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Wrap(
            spacing: 12,
            runSpacing: 12, // More compact vertical spacing
            children: [
              _modernDropdown(context, "Building *", buildingLabel, buildingList, (id, label) {
                setState(() {
                  buildingId = id;
                  buildingLabel = label;
                });
                fetchLine();
              }, width),
              _modernDropdown(context, "Process *", processLabel, processList, (id, label) {
                setState(() {
                  processId = id;
                  processLabel = label;
                });
                fetchLine();
              }, width),
              _modernDropdown(context, "Category *", categoryLabel, operationCategoryList, (id, label) {
                setState(() {
                  categoryId = id;
                  categoryLabel = label;
                });
              }, width),
              _modernDropdown(context, "Line No", lineLabel, lineList, (id, label) {
                setState(() {
                  lineId = id;
                  lineLabel = label;
                });
              }, width),
              _modernDropdown(context, "Machine No", machineLabel, machineList, (id, label) {
                setState(() {
                  machineNo = id;
                  machineLabel = label;
                });
              }, width),
              _modernDropdown(context, "Responsible Dept *", deptLabel, responsibleDeptList, (id, label) {
                setState(() {
                  deptId = id;
                  deptLabel = label;
                });
              }, width),
              _timeField("Start Time *", _startController, () => pickTime(true), width, icon: Icons.access_time),
              _timeField("End Time *", _endController, () => pickTime(false), width, icon: Icons.access_time),
              _readOnlyField("Total (Min)", totalTimeFormatted, width),
              _textField("SMV", (v) => smv = v, width, isNumber: true),
              _modernDropdown(context, "Cause *", causeLabel, downtimeCauseList, (id, label) {
                setState(() => causeLabel = label);
              }, width),
              _textField("Number of Operators", (v) => numberOfOperators = v, width, isNumber: true),
              _modernDropdown(context, "Responsible User *", responsibleUserLabel, responsibleUserList, (id, label) {
                setState(() {
                  responsibleUserId = id;
                  responsibleUserLabel = label;
                });
              }, width),
              _textField("GMT Loss Qty", (v) => gmtLossQty = v, width, isNumber: true),
              _textField("Remarks", (v) => remarks = v, width * 2 + 12),
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
                  child: const Text("SAVE ENTRY", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ---------------- SEARCH DIALOG ----------------
  void _searchDialog(BuildContext context, String title, List<Map<String, String>> items,
      void Function(String, String) onSelect) {
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
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300)
                  ),
                  child: TextField(
                    autofocus: false,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, color: Colors.black54),
                        hintText: "Search...",
                        hintStyle: TextStyle(fontSize: 14),
                        border: InputBorder.none),
                    onChanged: (v) => setS(() {
                      currentSearch = v;
                      filtered = items
                          .where((e) => e["label"]!.toLowerCase().contains(v.toLowerCase()))
                          .toList();
                    }),
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
                      ...filtered.map((item) => InkWell(
                            onTap: () {
                              onSelect(item["id"]!, item["label"]!);
                              Navigator.pop(context);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade100),
                                boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))],
                              ),
                              child: Text(item["label"]!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                            ),
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

  // ---------------- MODERN DROPDOWN ----------------
  Widget _modernDropdown(BuildContext context, String label, String? value, List<Map<String, String>> list,
      void Function(String, String) onSelect, double width) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 4),
        Container(
          height: 38, // More compact
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: InkWell(
            onTap: () => _searchDialog(context, label, list, onSelect),
            child: Row(
              children: [
                Expanded(child: Text(value ?? "Select", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                const Icon(Icons.arrow_drop_down, color: Colors.black87, size: 20),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ---------------- TEXT FIELD ----------------
  Widget _textField(String label, Function(String) onChanged, double width,
      {bool isNumber = false}) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 4),
        Container(
          height: 38, // More compact
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: TextField(
            keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10)),
          ),
        ),
      ]),
    );
  }

  // ---------------- TIME FIELD ----------------
  Widget _timeField(String label, TextEditingController controller,
      VoidCallback onTap, double width,
      {IconData? icon}) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: AbsorbPointer(
            child: Container(
              height: 38, // More compact
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Expanded(child: Text(controller.text.isEmpty ? "00:00" : controller.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black))),
                  if (icon != null) Icon(icon, color: Colors.black54, size: 18),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ---------------- READ ONLY FIELD ----------------
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
          decoration: BoxDecoration(
            color: const Color(0xFFE8EAED),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
        ),
      ]),
    );
  }
}