import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// --- Singleton for shared data ---
class AppData {
  static final AppData _instance = AppData._internal();
  factory AppData() => _instance;
  AppData._internal();

  late SharedPreferences prefs;

  List<String> buildings = [];
  List<String> processes = [];
  List<String> operationCategories = [];
  List<String> downtimeCauses = [];
  List<Map<String, dynamic>> nptList = [];

  static const String kBuildings = 'buildings';
  static const String kProcesses = 'processes';
  static const String kOperationCategories = 'operationCategories';
  static const String kDowntimeCauses = 'downtimeCauses';
  static const String kNptList = 'npt_list';

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    _loadMasterLists();
    _loadNptList();
  }

  void _loadMasterLists() {
    try {
      buildings = List<String>.from(jsonDecode(prefs.getString(kBuildings) ?? '[]'));
      processes = List<String>.from(jsonDecode(prefs.getString(kProcesses) ?? '[]'));
      operationCategories =
          List<String>.from(jsonDecode(prefs.getString(kOperationCategories) ?? '[]'));
      downtimeCauses = List<String>.from(jsonDecode(prefs.getString(kDowntimeCauses) ?? '[]'));
    } catch (_) {
      buildings = [];
      processes = [];
      operationCategories = [];
      downtimeCauses = [];
    }
  }

  void _loadNptList() {
    try {
      final raw = prefs.getString(kNptList);
      if (raw != null) {
        final List<dynamic> list = jsonDecode(raw);
        nptList = list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {
      nptList = [];
    }
  }

  Future<void> saveMasterList(String key, List<String> list) async {
    await prefs.setString(key, jsonEncode(list));
    _loadMasterLists(); // refresh local copy
  }

  Future<void> saveNptList() async {
    await prefs.setString(kNptList, jsonEncode(nptList));
  }
}

/// --- Admin Panel Page ---
class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  List<String> buildings = [];
  List<String> processes = [];
  List<String> operationCategories = [];
  List<String> downtimeCauses = [];

  final TextEditingController buildingController = TextEditingController();
  final TextEditingController processController = TextEditingController();
  final TextEditingController opCatController = TextEditingController();
  final TextEditingController downtimeController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await AppData().init();
    setState(() {
      buildings = AppData().buildings;
      processes = AppData().processes;
      operationCategories = AppData().operationCategories;
      downtimeCauses = AppData().downtimeCauses;
      _isLoading = false;
    });
  }

  Future<void> _addItem(List<String> list, TextEditingController controller, String key) async {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    setState(() {
      list.add(value);
      controller.clear();
    });
    await AppData().saveMasterList(key, list);
  }

  Future<void> _removeItem(List<String> list, int index, String key) async {
    setState(() {
      list.removeAt(index);
    });
    await AppData().saveMasterList(key, list);
  }

  Widget _buildList(String title, List<String> list, TextEditingController controller, String key) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Add new $title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _addItem(list, controller, key),
                  child: const Text("Add"),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...list.asMap().entries.map((e) {
              return ListTile(
                title: Text(e.value),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeItem(list, e.key, key),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildList("Buildings", buildings, buildingController, AppData.kBuildings),
            _buildList("Processes", processes, processController, AppData.kProcesses),
            _buildList("Operation Categories", operationCategories, opCatController, AppData.kOperationCategories),
            _buildList("Downtime Causes", downtimeCauses, downtimeController, AppData.kDowntimeCauses),
          ],
        ),
      ),
    );
  }
}
