import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/menu_config.dart';

class MenuAssignPage extends StatefulWidget {
  const MenuAssignPage({super.key});

  @override
  State<MenuAssignPage> createState() => _MenuAssignPageState();
}

class _MenuAssignPageState extends State<MenuAssignPage> {
  final TextEditingController userCtrl = TextEditingController();
  Map<String, Set<String>> selected = {};

  Future<void> _load() async {
    final uid = userCtrl.text.trim();
    if (uid.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("menu_perm_$uid");

    setState(() {
      if (raw == null) {
        selected = {};
      } else {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        selected = decoded.map(
          (k, v) => MapEntry(k, Set<String>.from(v)),
        );
      }
    });
  }

  Future<void> _save() async {
    final uid = userCtrl.text.trim();
    if (uid.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      "menu_perm_$uid",
      jsonEncode(selected.map((k, v) => MapEntry(k, v.toList()))),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Menu permissions saved")),
    );
  }

  void _toggle(String menu, String sub, bool val) {
    setState(() {
      selected.putIfAbsent(menu, () => {});
      val ? selected[menu]!.add(sub) : selected[menu]!.remove(sub);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Menu Assign")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(
                labelText: "User ID",
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView(
                children: MenuConfig.menus.entries.map((menu) {
                  return Card(
                    child: ExpansionTile(
                      title: Text(menu.key.toUpperCase()),
                      children: menu.value.map((sub) {
                        final checked =
                            selected[menu.key]?.contains(sub) ?? false;
                        return CheckboxListTile(
                          title: Text(sub.replaceAll("_", " ").toUpperCase()),
                          value: checked,
                          onChanged: (v) =>
                              _toggle(menu.key, sub, v ?? false),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text("SAVE"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
