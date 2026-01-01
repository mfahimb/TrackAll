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
      machineNo,
      staffId;

  String? buildingLabel,
      processLabel,
      lineLabel,
      categoryLabel,
      responsibleUserLabel,
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

  // Updated machineList: Only numeric labels
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
      _lovService
          .fetchLov(qryType: "DOWNTIME")
          .then((v) => downtimeCauseList = v),
      _lovService
          .fetchLov(qryType: "RESP_DEPT")
          .then((v) => responsibleDeptList = v),
      _lovService
          .fetchLov(qryType: "OPERATION")
          .then((v) => operationCategoryList = v),
      _lovService
          .fetchLov(qryType: "RESP_USER")
          .then((v) => responsibleUserList = v),
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
    final start = DateTime(
        now.year, now.month, now.day, startTime!.hour, startTime!.minute);
    var end = DateTime(
        now.year, now.month, now.day, endTime!.hour, endTime!.minute);

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

  Future<void> _handleSave() async {
    if ([
      buildingId,
      processId,
      categoryId,
      causeLabel,
      startTime,
      endTime,
      responsibleUserId
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
    final s = DateTime(
        now.year, now.month, now.day, startTime!.hour, startTime!.minute);
    var e =
        DateTime(now.year, now.month, now.day, endTime!.hour, endTime!.minute);
    if (!e.isAfter(s)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("End Time must be after Start Time"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await _lovService.saveNptEntry(
  buildingId: buildingId!,
  processId: processId!,
  lineId: lineId ?? "0",        // LINE_NO
  machineNo: machineNo ?? "0",  // DW_LINE_NO
  smv: smv ?? "0",
  categoryId: categoryId!,
  startTime: startTime!,
  endTime: endTime!,
  cause: causeLabel!,
  deptId: deptId ?? "0",
  responsibleUserId: responsibleUserId!, // DW_RES_USR
  remarks: remarks ?? "",
  gmtLossQty: gmtLossQty ?? "0",
  staffId: prefs.getString("login_id") ?? "0", // created_by
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
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text("NPT Entry",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final width = (constraints.maxWidth - 44) / 2;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              _modernDropdown("Building *", buildingLabel, buildingList,
                  (id, label) {
                setState(() {
                  buildingId = id;
                  buildingLabel = label;
                });
                fetchLine();
              }, width),
              _modernDropdown("Process *", processLabel, processList,
                  (id, label) {
                setState(() {
                  processId = id;
                  processLabel = label;
                });
                fetchLine();
              }, width),
              _modernDropdown("Category *", categoryLabel,
                  operationCategoryList, (id, label) {
                setState(() {
                  categoryId = id;
                  categoryLabel = label;
                });
              }, width),
              _modernDropdown("Line No", lineLabel, lineList, (id, label) {
                setState(() {
                  lineId = id;
                  lineLabel = label;
                });
              }, width),
              _modernDropdown("Machine No", machineLabel, machineList,
                  (id, label) {
                setState(() {
                  machineNo = id;
                  machineLabel = label;
                });
              }, width),
              _timeField("Start Time *", _startController, () => pickTime(true),
                  width,
                  icon: Icons.access_time),
              _timeField("End Time *", _endController, () => pickTime(false),
                  width,
                  icon: Icons.access_time),
              _readOnlyField("Total (Min)", totalTimeFormatted, width),
              _textField("SMV", (v) => smv = v, width, isNumber: true),
              _modernDropdown("Cause *", causeLabel, downtimeCauseList,
                  (id, label) {
                setState(() => causeLabel = label);
              }, width),
              _textField("Number of Operators", (v) => numberOfOperators = v,
                  width,
                  isNumber: true),
              _modernDropdown("Responsible User *", responsibleUserLabel,
                  responsibleUserList, (id, label) {
                setState(() {
                  responsibleUserId = id;
                  responsibleUserLabel = label;
                });
              }, width),
              _textField("GMT Loss Qty", (v) => gmtLossQty = v, width,
                  isNumber: true),
              _textField("Remarks", (v) => remarks = v, width * 2 + 12),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 6,
                  ),
                  child: const Text("SAVE ENTRY",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ---------- UPDATED SEARCH DIALOG ----------
  void _searchDialog(String title, List<Map<String, String>> items,
      void Function(String, String) onSelect) {
    List<Map<String, String>> filtered = List.from(items);
    String currentSearch = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (c, setS) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text("Select $title",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    autofocus: false, // <-- keyboard will open only after tap
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: "Search or Type...",
                        border: InputBorder.none),
                    onChanged: (v) => setS(() {
                      currentSearch = v;
                      filtered = items
                          .where((e) => e["label"]!
                              .toLowerCase()
                              .contains(v.toLowerCase()))
                          .toList();
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    children: [
                      if (filtered.isEmpty && currentSearch.isNotEmpty)
                        ListTile(
                          title: Text("Use manual: $currentSearch"),
                          leading: const Icon(Icons.add, color: Colors.blue),
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
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x0A000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 4))
                                ],
                              ),
                              child: Text(item["label"]!,
                                  style: const TextStyle(fontSize: 14)),
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
  Widget _modernDropdown(String label, String? value, List<Map<String, String>> list,
      void Function(String, String) onSelect, double width) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 12,
                  offset: Offset(0, 6))
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _searchDialog(label, list, onSelect),
            child: Row(
              children: [
                Expanded(
                    child: Text(value ?? "Select",
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis)),
                const Icon(Icons.expand_more, color: Colors.grey),
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
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10,
                  offset: Offset(0, 4))
            ],
          ),
          child: TextField(
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(border: InputBorder.none),
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
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: AbsorbPointer(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 10,
                      offset: Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                      child: Text(
                          controller.text.isEmpty ? "00:00" : controller.text,
                          style: const TextStyle(fontSize: 13))),
                  if (icon != null) Icon(icon, color: Colors.grey, size: 20),
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
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          height: 44,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ]),
    );
  }
}
