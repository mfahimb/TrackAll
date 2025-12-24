import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/lov_service.dart';

class NptEntryPage extends StatefulWidget {
  const NptEntryPage({super.key});

  @override
  State<NptEntryPage> createState() => _NptEntryPageState();
}

class _NptEntryPageState extends State<NptEntryPage> {
  String? buildingId, processId, lineId, buildingLabel, processLabel, lineLabel;
  String? machine, smv, cause, responsibleDept, operationCategory, responsibleUser;
  // New Fields
  String? remarks, gmtLossQty;
  TimeOfDay? startTime, endTime;
  String? editingId;

  List<Map<String, String>> buildingList = [], processList = [], lineList = [], responsibleUserList = [];
  List<String> machineList = List.generate(10, (i) => (i + 1).toString());
  List<String> downtimeCauseList = [], responsibleDeptList = [], operationCategoryList = [];

  List<Map<String, dynamic>> nptList = [];
  late SharedPreferences prefs;
  bool _isLoading = true;

  final String todayDate = DateFormat('MM/dd/yyyy').format(DateTime.now());
  final LovService _lovService = LovService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('npt_list');
    if (raw != null) nptList = List<Map<String, dynamic>>.from(jsonDecode(raw));

    await Future.wait([
      _lovService.fetchLov(qryType: "BUILDING").then((v) => buildingList = v),
      _lovService.fetchLov(qryType: "PROCESS").then((v) => processList = v),
      _lovService.fetchLov(qryType: "DOWNTIME").then((v) => downtimeCauseList = v.map((e) => e["label"]!).toList()),
      _lovService.fetchLov(qryType: "RESP_DEPT").then((v) => responsibleDeptList = v.map((e) => e["label"]!).toList()),
      _lovService.fetchLov(qryType: "OPERATION").then((v) => operationCategoryList = v.map((e) => e["label"]!).toList()),
      _lovService.fetchLov(qryType: "RESP_USER").then((v) => responsibleUserList = v),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> fetchLine() async {
    if (buildingId == null || processId == null) return;
    final result = await _lovService.fetchLov(qryType: "LINE", dwLocId: buildingId, dwSec: processId);
    setState(() => lineList = result);
  }

  String get totalTimeFormatted {
    if (startTime == null || endTime == null) return "0h 0m";
    final s = DateTime(2025, 1, 1, startTime!.hour, startTime!.minute);
    final e = DateTime(2025, 1, 1, endTime!.hour, endTime!.minute);
    final diff = e.difference(s);
    return diff.inMinutes < 0 ? "Invalid" : "${diff.inHours}h ${diff.inMinutes % 60}m";
  }

  Future<void> pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => isStart ? startTime = picked : endTime = picked);
  }

  void _resetForm() {
    setState(() {
      editingId = null; machine = null; smv = null; cause = null;
      startTime = null; endTime = null; buildingId = null; buildingLabel = null;
      processId = null; processLabel = null; lineId = null; lineLabel = null;
      operationCategory = null; responsibleDept = null; responsibleUser = null;
      remarks = null; gmtLossQty = null; // Reset new fields
    });
  }

  void _editEntry(Map<String, dynamic> item) {
    setState(() {
      editingId = item['id'];
      buildingLabel = item['building'];
      buildingId = item['buildingId'];
      processLabel = item['process'];
      processId = item['processId'];
      lineLabel = item['line'];
      lineId = item['lineId'];
      machine = item['machine'];
      smv = item['smv'];
      cause = item['cause'];
      operationCategory = item['operationCategory'];
      responsibleDept = item['responsibleDept'];
      responsibleUser = item['responsibleUser'];
      remarks = item['P_REMARKS'];
      gmtLossQty = item['P_GMT_LOSS_QTY'];
      
      final format = DateFormat.jm(); 
      startTime = TimeOfDay.fromDateTime(format.parse(item['P_START_TIME']));
      endTime = TimeOfDay.fromDateTime(format.parse(item['P_END_TIME']));
    });
    fetchLine();
  }

  void _deleteEntry(String id) async {
    setState(() => nptList.removeWhere((e) => e['id'] == id));
    await _saveLocalDB();
  }

  Future<void> _handleSave() async {
    if ([buildingLabel, processLabel, lineLabel, machine, cause, startTime, endTime, responsibleUser].contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields *")));
      return;
    }

    final payload = {
      "P_DATE": todayDate,
      "P_BUILDING_ID": buildingId,
      "P_PROCESS_ID": processId,
      "P_LINE_ID": lineId,
      "P_MACHINE_NO": machine,
      "P_SMV": smv ?? "0",
      "P_CAUSE": cause,
      "P_START_TIME": startTime!.format(context),
      "P_END_TIME": endTime!.format(context),
      "P_OP_CATEGORY": operationCategory,
      "P_RESP_DEPT": responsibleDept,
      "P_RESP_USER": responsibleUser, 
      "P_REMARKS": remarks ?? "",
      "P_GMT_LOSS_QTY": gmtLossQty ?? "0",
    };

    setState(() => _isLoading = true);
    bool isSynced = await _lovService.saveNptEntry(payload);

    if (isSynced) {
      final entry = {
        ...payload,
        "id": editingId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        "building": buildingLabel,
        "process": processLabel,
        "line": lineLabel,
        "totalTime": totalTimeFormatted,
        "buildingId": buildingId,
        "processId": processId,
        "lineId": lineId,
        "operationCategory": operationCategory,
        "responsibleDept": responsibleDept,
        "responsibleUser": responsibleUser,
      };

      setState(() {
        if (editingId != null) {
          int idx = nptList.indexWhere((e) => e['id'] == editingId);
          nptList[idx] = entry;
        } else {
          nptList.add(entry);
        }
        _isLoading = false;
      });

      await _saveLocalDB();
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sync Successful!"), backgroundColor: Colors.green));
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sync Failed"), backgroundColor: Colors.red));
    }
  }

  Future<void> _saveLocalDB() async => prefs.setString('npt_list', jsonEncode(nptList));

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F8),
      appBar: AppBar(
        title: const Text("NPT Entry", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 1,
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        double fieldWidth = (constraints.maxWidth - 44) / 2;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12, runSpacing: 16,
                children: [
                  _buildSearchableSelector("Building *", buildingLabel, buildingList, (id, label) {
                    setState(() { buildingId = id; buildingLabel = label; lineLabel = null; });
                    fetchLine();
                  }, fieldWidth),
                  _buildSearchableSelector("Process *", processLabel, processList, (id, label) {
                    setState(() { processId = id; processLabel = label; lineLabel = null; });
                    fetchLine();
                  }, fieldWidth),
                  _buildSearchableSelector("Category *", operationCategory, operationCategoryList.map((e) => {"id": e, "label": e}).toList(), (id, label) => setState(() => operationCategory = label), fieldWidth),
                  _buildSearchableSelector("Line No", lineLabel, lineList, (id, label) => setState(() { lineId = id; lineLabel = label; }), fieldWidth),
                  _buildSearchableSelector("Machine No", machine, machineList.map((e) => {"id": e, "label": e}).toList(), (id, label) => setState(() => machine = label), fieldWidth),
                  _buildResponsiveTextField("SMV", smv, (v) => smv = v, fieldWidth, isNumber: true),
                  _buildSearchableSelector("Cause *", cause, downtimeCauseList.map((e) => {"id": e, "label": e}).toList(), (id, label) => setState(() => cause = label), fieldWidth),
                  _buildTimeField("Start *", startTime, true, fieldWidth),
                  _buildTimeField("End *", endTime, false, fieldWidth),
                  _buildSearchableSelector("Dept *", responsibleDept, responsibleDeptList.map((e) => {"id": e, "label": e}).toList(), (id, label) => setState(() => responsibleDept = label), fieldWidth),
                  _buildSearchableSelector("Resp. User *", responsibleUser, responsibleUserList, (id, label) => setState(() => responsibleUser = label), fieldWidth),
                  // New Fields added here
                  _buildResponsiveTextField("GMT Loss Qty", gmtLossQty, (v) => gmtLossQty = v, fieldWidth, isNumber: true),
                  _buildResponsiveTextField("Remarks", remarks, (v) => remarks = v, fieldWidth * 2 + 12, isNumber: false), 
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _handleSave,
                  child: Text(editingId == null ? "SAVE & SYNC" : "UPDATE & SYNC", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              if (editingId != null) TextButton(onPressed: _resetForm, child: const Center(child: Text("Cancel Edit", style: TextStyle(color: Colors.red)))),
              const SizedBox(height: 30),
              const Text("Recently Saved Entries", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _buildFullTable(),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildFullTable() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('Action')),
            DataColumn(label: Text('User')),
            DataColumn(label: Text('GMT Loss')), // New column
            DataColumn(label: Text('Remarks')),  // New column
            DataColumn(label: Text('Building')),
            DataColumn(label: Text('Line')),
            DataColumn(label: Text('Machine')),
            DataColumn(label: Text('Cause')),
            DataColumn(label: Text('Start')),
            DataColumn(label: Text('End')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Dept')),
          ],
          rows: nptList.reversed.map((e) => DataRow(cells: [
            DataCell(Row(
              children: [
                IconButton(icon: const Icon(Icons.edit, size: 16, color: Colors.blue), onPressed: () => _editEntry(e)),
                IconButton(icon: const Icon(Icons.delete, size: 16, color: Colors.red), onPressed: () => _deleteEntry(e['id'])),
              ],
            )),
            DataCell(Text(e['responsibleUser'] ?? "", style: const TextStyle(fontSize: 11, color: Colors.blueAccent))),
            DataCell(Text(e['P_GMT_LOSS_QTY'] ?? "0", style: const TextStyle(fontSize: 11))),
            DataCell(Text(e['P_REMARKS'] ?? "", style: const TextStyle(fontSize: 11))),
            DataCell(Text(e['building'] ?? "", style: const TextStyle(fontSize: 11))),
            DataCell(Text(e['line'] ?? "", style: const TextStyle(fontSize: 11))),
            DataCell(Text(e['P_MACHINE_NO'] ?? "", style: const TextStyle(fontSize: 11))),
            DataCell(Text(e['P_CAUSE'] ?? "", style: const TextStyle(fontSize: 11))),
            DataCell(Text(e['P_START_TIME'] ?? "", style: const TextStyle(fontSize: 11))),
            DataCell(Text(e['P_END_TIME'] ?? "", style: const TextStyle(fontSize: 11))),
            DataCell(Text(e['totalTime'] ?? "", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            DataCell(Text(e['responsibleDept'] ?? "", style: const TextStyle(fontSize: 11))),
          ])).toList(),
        ),
      ),
    );
  }

  // --- Helper Methods ---

  Widget _buildResponsiveTextField(String label, String? value, void Function(String) onChanged, double width, {bool isNumber = false}) {
    // We use a Key to ensure the field updates when we clear/edit the form
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextFormField(
              key: Key(editingId ?? "new_$label"), 
              initialValue: value,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
              onChanged: onChanged,
              keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchableSelector(String label, String? currentValue, List<Map<String, String>> list, void Function(String id, String label) onSelected, double width) {
    return _buildResponsiveField(label, InkWell(
      onTap: () => _showSearchableDialog(title: label, items: list, onSelected: onSelected),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(currentValue ?? "Select", style: TextStyle(fontSize: 11, color: currentValue == null ? Colors.grey : Colors.black), overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey),
        ],
      ),
    ), width);
  }

  void _showSearchableDialog({required String title, required List<Map<String, String>> items, required Function(String id, String label) onSelected}) {
    showDialog(context: context, builder: (context) {
      List<Map<String, String>> filteredItems = List.from(items);
      return StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: Text("Search $title"),
          content: SizedBox(width: double.maxFinite, child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(hintText: "Search...", prefixIcon: Icon(Icons.search), isDense: true),
                onChanged: (v) => setDialogState(() => filteredItems = items.where((i) => i["label"]!.toLowerCase().contains(v.toLowerCase())).toList()),
              ),
              const SizedBox(height: 10),
              SizedBox(height: 300, child: ListView.builder(
                itemCount: filteredItems.length,
                itemBuilder: (ctx, i) => ListTile(
                  title: Text(filteredItems[i]["label"]!, style: const TextStyle(fontSize: 13)),
                  onTap: () { onSelected(filteredItems[i]["id"]!, filteredItems[i]["label"]!); Navigator.pop(context); },
                ),
              )),
            ],
          )),
        );
      });
    });
  }

  Widget _buildResponsiveField(String label, Widget child, double width) {
    return SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Container(height: 40, padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), alignment: Alignment.centerLeft, child: child),
    ]));
  }

  Widget _buildTimeField(String label, TimeOfDay? time, bool isStart, double width) {
    return _buildResponsiveField(label, InkWell(onTap: () => pickTime(isStart), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(time?.format(context) ?? "00:00", style: const TextStyle(fontSize: 11)),
      const Icon(Icons.access_time, size: 14, color: Colors.grey),
    ])), width);
  }
}