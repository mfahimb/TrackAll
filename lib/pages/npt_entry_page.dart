import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:trackall_app/pages/widgets/top_menu_bar.dart';
import './widgets/top_menu_bar.dart'; // Make sure this imports your TopMenuBar

class NptEntryPage extends StatefulWidget {
  const NptEntryPage({super.key});

  @override
  State<NptEntryPage> createState() => _NptEntryPageState();
}

class _NptEntryPageState extends State<NptEntryPage> {
  String? building, process, operation, line, machine, cause;
  String? responsibleDept, responsibleUser;
  String? smv;
  TimeOfDay? startTime, endTime;
  String remarks = "";
  String? editingId;

  List<Map<String, dynamic>> nptList = [];
  late SharedPreferences prefs;
  bool _isLoading = true;

  List<String> buildingList = [];
  List<String> processList = [];
  List<String> operationCategoryList = [];
  List<String> downtimeCauseList = [];
  List<String> lineList = [];
  List<String> machineList = [];

  final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Fetch list of values from API
  Future<List<String>> fetchLov(String type) async {
    try {
      final response = await http.get(
        Uri.parse('https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov?type=$type'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map<String>((e) => e['name'].toString()).toList();
        }
      }
    } catch (e) {
      print("Error fetching $type: $e");
    }
    return [];
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastPage', '/npt_entry');

    // Fetch dropdowns from API
    buildingList = await fetchLov('building');
    processList = await fetchLov('process');
    operationCategoryList = await fetchLov('operation');
    downtimeCauseList = await fetchLov('cause');
    lineList = await fetchLov('line');
    machineList = await fetchLov('machine');

    // Fallback to local storage if API returns empty
    buildingList = buildingList.isNotEmpty
        ? buildingList
        : List<String>.from(jsonDecode(prefs.getString('buildings') ?? '[]'));
    processList = processList.isNotEmpty
        ? processList
        : List<String>.from(jsonDecode(prefs.getString('processes') ?? '[]'));
    operationCategoryList = operationCategoryList.isNotEmpty
        ? operationCategoryList
        : List<String>.from(
            jsonDecode(prefs.getString('operationCategories') ?? '[]'));
    downtimeCauseList = downtimeCauseList.isNotEmpty
        ? downtimeCauseList
        : List<String>.from(
            jsonDecode(prefs.getString('downtimeCauses') ?? '[]'));
    lineList = lineList.isNotEmpty ? lineList : ["L1", "L2", "L3"];
    machineList = machineList.isNotEmpty ? machineList : ["M1", "M2", "M3"];

    // Save fetched values to local cache
    await prefs.setString('buildings', jsonEncode(buildingList));
    await prefs.setString('processes', jsonEncode(processList));
    await prefs.setString('operationCategories', jsonEncode(operationCategoryList));
    await prefs.setString('downtimeCauses', jsonEncode(downtimeCauseList));

    // Load NPT entries from local DB
    final raw = prefs.getString('npt_list');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      nptList = list.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    setState(() => _isLoading = false); // rebuild after lists are ready
  }

  Future<void> _saveLocalDB() async {
    await prefs.setString('npt_list', jsonEncode(nptList));
  }

  String get totalMinutes {
    if (startTime == null || endTime == null) return "--";
    final s = DateTime(2025, 1, 1, startTime!.hour, startTime!.minute);
    final e = DateTime(2025, 1, 1, endTime!.hour, endTime!.minute);
    final diff = e.difference(s);
    if (diff.inMinutes < 0) return "--";
    return diff.inMinutes.toString();
  }

  String get totalTime {
    if (startTime == null || endTime == null) return "--";
    final s = DateTime(2025, 1, 1, startTime!.hour, startTime!.minute);
    final e = DateTime(2025, 1, 1, endTime!.hour, endTime!.minute);
    final diff = e.difference(s);
    if (diff.inMinutes < 0) return "--";
    return "${diff.inHours}h ${diff.inMinutes % 60}m";
  }

  Future<void> pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        if (isStart)
          startTime = picked;
        else
          endTime = picked;
      });
    }
  }

  void clearForm() {
    setState(() {
      building = process = operation = line = machine = cause = null;
      responsibleDept = responsibleUser = null;
      smv = null;
      startTime = endTime = null;
      remarks = "";
      editingId = null;
    });
  }

  void startEditing(Map<String, dynamic> e) {
    setState(() {
      editingId = e['id'];
      building = e['buildingSection'];
      process = e['operationCategory'];
      operation = e['operation'];
      line = e['lineNo'];
      machine = e['machineNo'];
      smv = e['smv']?.toString();
      cause = e['downtimeCause'];
      responsibleDept = e['responsibleDept'];
      responsibleUser = e['responsibleUser'];
      remarks = e['remarks'] ?? "";
      startTime = _parseTimeOfDay(e['startTime']);
      endTime = _parseTimeOfDay(e['endTime']);
    });
  }

  TimeOfDay? _parseTimeOfDay(String? t) {
    if (t == null) return null;
    final parts = t.split(":");
    if (parts.length >= 2) {
      final hh = int.tryParse(parts[0]) ?? 0;
      final mm = int.tryParse(parts[1].split(" ").first) ?? 0;
      return TimeOfDay(hour: hh, minute: mm);
    }
    return null;
  }

  Future<void> saveOrUpdateEntry() async {
    if (building == null || process == null || operation == null || line == null ||
        machine == null || smv == null || cause == null || responsibleDept == null ||
        startTime == null || endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all required fields")));
      return;
    }

    final payload = {
      "id": editingId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      "buildingSection": building,
      "operationCategory": process,
      "operation": operation,
      "lineNo": line,
      "machineNo": machine,
      "smv": smv,
      "downtimeCause": cause,
      "startTime": startTime!.format(context),
      "endTime": endTime!.format(context),
      "totalMinutes": totalMinutes,
      "responsibleDept": responsibleDept,
      "responsibleUser": responsibleUser ?? "",
      "remarks": remarks,
      "date": todayDate,
    };

    setState(() {
      if (editingId == null)
        nptList.add(payload);
      else {
        final index = nptList.indexWhere((e) => e['id'] == editingId);
        if (index != -1) nptList[index] = payload;
      }
    });

    await _saveLocalDB();
    clearForm();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(editingId == null ? "Saved" : "Updated")));
  }

  Future<void> deleteEntry(String id) async {
    setState(() {
      nptList.removeWhere((e) => e['id'] == id);
    });
    await _saveLocalDB();
    if (editingId == id) clearForm();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Deleted")));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final themeColor = const Color(0xFF0066FF);
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade700,
    );

    Widget field(String label, Widget child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: SizedBox(height: 45, child: child),
          ),
        ],
      );
    }

    final allFields = [
      field("Building Section",
          DropdownButtonFormField<String>(
            value: building,
            items: buildingList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => building = v),
            decoration: const InputDecoration(border: InputBorder.none),
          )),
      field("Process",
          DropdownButtonFormField<String>(
            value: process,
            items: processList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => process = v),
            decoration: const InputDecoration(border: InputBorder.none),
          )),
      field("Operation Category",
          DropdownButtonFormField<String>(
            value: operation,
            items: operationCategoryList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => operation = v),
            decoration: const InputDecoration(border: InputBorder.none),
          )),
      field("Line No",
          DropdownButtonFormField<String>(
            value: line,
            items: lineList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => line = v),
            decoration: const InputDecoration(border: InputBorder.none),
          )),
      field("Machine No",
          DropdownButtonFormField<String>(
            value: machine,
            items: machineList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => machine = v),
            decoration: const InputDecoration(border: InputBorder.none),
          )),
      field("SMV",
          TextFormField(
            initialValue: smv,
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() => smv = v),
            decoration: const InputDecoration(border: InputBorder.none),
          )),
      field("Downtime Cause",
          DropdownButtonFormField<String>(
            value: cause,
            items: downtimeCauseList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => cause = v),
            decoration: const InputDecoration(border: InputBorder.none),
          )),
      field("Responsible Dept.",
          DropdownButtonFormField<String>(
            value: responsibleDept,
            items: ["Dept A","Dept B","Dept C"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => responsibleDept = v),
            decoration: const InputDecoration(border: InputBorder.none),
          )),
      field("Responsible User",
          TextFormField(
            initialValue: responsibleUser,
            onChanged: (v) => setState(() => responsibleUser = v),
            decoration: const InputDecoration(border: InputBorder.none),
          )),
      field("Remarks",
          TextFormField(
            initialValue: remarks,
            onChanged: (v) => setState(() => remarks = v),
            decoration: const InputDecoration(border: InputBorder.none),
          )),
      field("Start Time",
          OutlinedButton(
            onPressed: () => pickTime(true),
            child: Text(startTime == null ? "Pick" : startTime!.format(context)),
          )),
      field("End Time",
          OutlinedButton(
            onPressed: () => pickTime(false),
            child: Text(endTime == null ? "Pick" : endTime!.format(context)),
          )),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
        children: [
          const TopMenuBar(), // <-- integrated top menu
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context,constraints){
                              int columns = 1;
                              double maxFieldWidth = constraints.maxWidth;
                              if(constraints.maxWidth>=1200){
                                columns=3;
                                maxFieldWidth = constraints.maxWidth/columns - 14;
                              }else if(constraints.maxWidth>=800){
                                columns=2;
                                maxFieldWidth = constraints.maxWidth/columns - 14;
                              }
                              return Wrap(
                                spacing: 14,
                                runSpacing: 14,
                                children: allFields.map((f)=>ConstrainedBox(
                                  constraints: BoxConstraints(minWidth:150,maxWidth:maxFieldWidth),
                                  child: f
                                )).toList(),
                              );
                            },
                          ),
                          const SizedBox(height:20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors:[themeColor,themeColor.withOpacity(0.7)],begin: Alignment.topLeft,end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: themeColor.withOpacity(0.3),blurRadius:10,offset:const Offset(0,4))]
                            ),
                            child: Text("⏱ Total Time: $totalTime",style: const TextStyle(fontSize:18,fontWeight: FontWeight.w700,color: Colors.white),),
                          ),
                          const SizedBox(height:18),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height:48,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white,foregroundColor: themeColor,elevation:2,shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),side: BorderSide(color: themeColor,width:1.5))),
                                    onPressed: saveOrUpdateEntry,
                                    child: Row(mainAxisAlignment: MainAxisAlignment.center,children: [Icon(editingId==null?Icons.save:Icons.edit,size:20),const SizedBox(width:6),Text(editingId==null?"SAVE":"UPDATE")],),
                                  ),
                                ),
                              ),
                              if(editingId!=null)...[
                                const SizedBox(width:10),
                                SizedBox(width:120,height:48,child: ElevatedButton(style:ElevatedButton.styleFrom(backgroundColor: Colors.redAccent,shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),onPressed: ()=>deleteEntry(editingId!),child: const Text("DELETE"),)),
                                const SizedBox(width:10),
                                SizedBox(width:110,height:48,child: OutlinedButton(style: OutlinedButton.styleFrom(side: BorderSide(color: themeColor,width:1.5),shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),onPressed: clearForm,child: const Text("CANCEL"),)),
                              ]
                            ],
                          ),
                          const SizedBox(height:28),
                          const Text("Local Entries",style: TextStyle(fontSize:20,fontWeight: FontWeight.w700)),
                          const SizedBox(height:10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),blurRadius:6,offset:const Offset(0,4))],
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                                columnSpacing: 14,
                                columns: const [
                                  DataColumn(label: Text("Edit")),
                                  DataColumn(label: Text("Building")),
                                  DataColumn(label: Text("Operation Cat")),
                                  DataColumn(label: Text("Operation")),
                                  DataColumn(label: Text("Line")),
                                  DataColumn(label: Text("Machine")),
                                  DataColumn(label: Text("SMV")),
                                  DataColumn(label: Text("Cause")),
                                  DataColumn(label: Text("Start")),
                                  DataColumn(label: Text("End")),
                                  DataColumn(label: Text("Total Min")),
                                  DataColumn(label: Text("Resp Dept")),
                                  DataColumn(label: Text("Resp User")),
                                  DataColumn(label: Text("Remarks")),
                                ],
                                rows: nptList.map((e)=>DataRow(cells:[
                                  DataCell(IconButton(icon: const Icon(Icons.edit,color: Colors.blue),onPressed: ()=>startEditing(e))),
                                  DataCell(Text(e['buildingSection'] ?? "")),
                                  DataCell(Text(e['operationCategory'] ?? "")),
                                  DataCell(Text(e['operation'] ?? "")),
                                  DataCell(Text(e['lineNo'] ?? "")),
                                  DataCell(Text(e['machineNo'] ?? "")),
                                  DataCell(Text(e['smv']?.toString() ?? "")),
                                  DataCell(Text(e['downtimeCause'] ?? "")),
                                  DataCell(Text(e['startTime'] ?? "")),
                                  DataCell(Text(e['endTime'] ?? "")),
                                  DataCell(Text(e['totalMinutes'] ?? "")),
                                  DataCell(Text(e['responsibleDept'] ?? "")),
                                  DataCell(Text(e['responsibleUser'] ?? "")),
                                  DataCell(Text(e['remarks'] ?? "")),
                                ])).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height:50),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
