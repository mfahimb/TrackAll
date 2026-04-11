import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// --- LOV Service ---
class LovService {
  static const String _baseUrl = "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov";
  static const String _loginCompany = "55";

  Future<List<Map<String, String>>> fetchLov({
    required String qryType,
    String? dwSec,
    String? dwLocId,
  }) async {
    try {
      final upperType = qryType.toUpperCase();
      final params = <String, String>{
        "P_QRYTYP": upperType,
        "LOGIN_COMPANY": _loginCompany,
      };

      if (dwLocId != null && dwLocId.isNotEmpty) params["dw_loc_id"] = dwLocId;
      if (dwSec != null && dwSec.isNotEmpty) params["dw_sec"] = dwSec;

      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      final response = await http.get(uri);
      
      if (response.statusCode != 200) throw Exception("HTTP ${response.statusCode}");

      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey(upperType)) return [];
      
      final List list = decoded[upperType];
      if (list.isEmpty) return [];
      
      return list.map<Map<String, String>>((e) => {
        "id": e["R"]?.toString() ?? "",
        "label": e["D"]?.toString() ?? e["NAME"]?.toString() ?? "",
      }).toList();
    } catch (e) {
      debugPrint("Error fetching LOV ($qryType): $e");
      return [];
    }
  }
}

/// --- Singleton App Data ---
class AppData {
  static final AppData _instance = AppData._internal();
  factory AppData() => _instance;
  AppData._internal();

  late SharedPreferences prefs;
  
  List<Map<String, String>> buildings = [];
  List<Map<String, String>> processes = [];
  List<String> lines = []; 
  List<String> operationCategories = [];
  List<String> downtimeCauses = [];

  static const String kBuildings = 'buildings_map';
  static const String kProcesses = 'processes_map';
  static const String kLines = 'lines'; 
  static const String kOperationCategories = 'operationCategories';
  static const String kDowntimeCauses = 'downtimeCauses';

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    _loadMasterLists();
  }

  void _loadMasterLists() {
    buildings = _getMapList(kBuildings);
    processes = _getMapList(kProcesses);
    lines = _getStringList(kLines);
    operationCategories = _getStringList(kOperationCategories);
    downtimeCauses = _getStringList(kDowntimeCauses);
  }

  List<String> _getStringList(String key) {
    String? data = prefs.getString(key);
    return data == null ? [] : List<String>.from(jsonDecode(data));
  }

  List<Map<String, String>> _getMapList(String key) {
    String? data = prefs.getString(key);
    if (data == null) return [];
    return List<Map<String, String>>.from(jsonDecode(data).map((x) => Map<String, String>.from(x)));
  }

  Future<void> saveList(String key, dynamic list) async {
    await prefs.setString(key, jsonEncode(list));
    _loadMasterLists(); 
  }
}

/// --- Admin Panel Page ---
class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final LovService _lovService = LovService();
  bool _isLoading = false;

  String? selectedBuildingId;
  String? selectedProcessId;

  // ALL SET TO FALSE SO THEY START CLOSED
  bool _showBuildings = false;
  bool _showProcesses = false;
  bool _showLines = false;      // Fixed: Now starts closed
  bool _showOperations = false;
  bool _showDowntime = false;

  final bndCtrl = TextEditingController();
  final prsCtrl = TextEditingController();
  final linCtrl = TextEditingController();
  final catCtrl = TextEditingController();
  final dwnCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAppDataAndSilentFetch();
  }

  Future<void> _initAppDataAndSilentFetch() async {
    await AppData().init();
    
    // Background fetch so Green Area dropdowns are ready when the user clicks "View Data"
    if (AppData().buildings.isEmpty) {
       final b = await _lovService.fetchLov(qryType: "BUILDING");
       if (b.isNotEmpty) await AppData().saveList(AppData.kBuildings, b);
    }
    if (AppData().processes.isEmpty) {
       final p = await _lovService.fetchLov(qryType: "PROCESS");
       if (p.isNotEmpty) await AppData().saveList(AppData.kProcesses, p);
    }
    
    if (mounted) setState(() {});
  }

  Future<void> _syncFromApi(String qryType, String storageKey) async {
    if (qryType == "LINE" && (selectedBuildingId == null || selectedProcessId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select Building and Process first!")),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final results = await _lovService.fetchLov(
      qryType: qryType,
      dwLocId: qryType == "LINE" ? selectedBuildingId : null,
      dwSec: qryType == "LINE" ? selectedProcessId : null,
    );

    if (results.isNotEmpty) {
      if (qryType == "BUILDING" || qryType == "PROCESS") {
        await AppData().saveList(storageKey, results);
      } else {
        List<String> labels = results.map((e) => e["label"]!).toList();
        await AppData().saveList(storageKey, labels);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sync Successful!")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data found.")));
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(title: const Text("Admin Config"), centerTitle: true),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildSection("Buildings", AppData().buildings.map((e) => e["label"]!).toList(), bndCtrl, AppData.kBuildings, "BUILDING", _showBuildings, (v) => setState(() => _showBuildings = v)),
                _buildSection("Processes", AppData().processes.map((e) => e["label"]!).toList(), prsCtrl, AppData.kProcesses, "PROCESS", _showProcesses, (v) => setState(() => _showProcesses = v)),
                
                // Lines Section
                _buildSection(
                  "Lines", 
                  AppData().lines, 
                  linCtrl, 
                  AppData.kLines, 
                  "LINE", 
                  _showLines, 
                  (v) => setState(() => _showLines = v),
                  extraHeader: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: "Building", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
                        initialValue: selectedBuildingId,
                        hint: const Text("Select Building"),
                        items: AppData().buildings.map((e) => DropdownMenuItem(value: e["id"], child: Text(e["label"]!))).toList(),
                        onChanged: (val) => setState(() => selectedBuildingId = val),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: "Process", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
                        initialValue: selectedProcessId,
                        hint: const Text("Select Process"),
                        items: AppData().processes.map((e) => DropdownMenuItem(value: e["id"], child: Text(e["label"]!))).toList(),
                        onChanged: (val) => setState(() => selectedProcessId = val),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),

                _buildSection("Operations", AppData().operationCategories, catCtrl, AppData.kOperationCategories, "OPERATION", _showOperations, (v) => setState(() => _showOperations = v)),
                _buildSection("Downtime", AppData().downtimeCauses, dwnCtrl, AppData.kDowntimeCauses, "DOWNTIME", _showDowntime, (v) => setState(() => _showDowntime = v)),
              ],
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> list, TextEditingController ctrl, String key, String qry, bool visible, Function(bool) toggle, {Widget? extraHeader}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: visible ? Colors.blueGrey : Colors.blue),
                  onPressed: () => toggle(!visible), 
                  child: Text(visible ? "Hide Data" : "View Data", style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
            if (visible) ...[
              const Divider(),
              if (extraHeader != null) extraHeader,
              Row(
                children: [
                  Expanded(child: TextField(controller: ctrl, decoration: const InputDecoration(hintText: "Manual entry", border: OutlineInputBorder(), isDense: true))),
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: () => _addItem(key, list, ctrl)),
                  IconButton(icon: const Icon(Icons.cloud_download, color: Colors.green), onPressed: () => _syncFromApi(qry, key)),
                ],
              ),
              const SizedBox(height: 10),
              list.isEmpty 
                ? const Text("No items saved locally", style: TextStyle(color: Colors.grey))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (c, i) => ListTile(
                      title: Text(list[i]),
                      trailing: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => _removeItem(key, list, i)),
                    ),
                  ),
            ]
          ],
        ),
      ),
    );
  }

  void _addItem(String key, List<String> list, TextEditingController ctrl) {
    if (ctrl.text.isEmpty) return;
    setState(() {
      list.add(ctrl.text.trim());
      AppData().saveList(key, list);
      ctrl.clear();
    });
  }

  void _removeItem(String key, List<String> list, int index) {
    setState(() {
      list.removeAt(index);
      AppData().saveList(key, list);
    });
  }
}