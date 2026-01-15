import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CompanySelectPage extends StatefulWidget {
  const CompanySelectPage({super.key});

  @override
  State<CompanySelectPage> createState() => _CompanySelectPageState();
}

class _CompanySelectPageState extends State<CompanySelectPage> {
  String? selectedCompanyId;
  String? selectedCompanyLabel;

  List<Map<String, String>> companyList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  Future<void> _fetchCompanies() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? "0";

      final uri = Uri.parse(
          "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov")
          .replace(queryParameters: {
        "P_QRYTYP": "ASSIGN",
        "P_APP_USER": userId,
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data["ASSIGN"] as List<dynamic>?;

        if (items != null) {
          companyList = items
              .map<Map<String, String>>((item) => {
                    "id": item["R"].toString(),
                    "label": item["D"].toString(),
                  })
              .toList();

          // Remove duplicates
          final seen = <String>{};
          companyList = companyList.where((c) => seen.add(c["id"]!)).toList();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server Error: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmSelection() async {
    if (selectedCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a company")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("selected_company_id", selectedCompanyId!);
    await prefs.setString("selected_company_label", selectedCompanyLabel!);

    Navigator.pushReplacementNamed(context, '/home');
  }

  // ---------------- SEARCHABLE MODERN DROPDOWN ----------------
  void _showCompanyDialog() {
    List<Map<String, String>> filtered = List.from(companyList);
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
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                const Text("Select Company",
                    style: TextStyle(
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
                      border: Border.all(color: Colors.grey.shade300)),
                  child: TextField(
                    autofocus: false,
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, color: Colors.black54),
                        hintText: "Search...",
                        hintStyle: TextStyle(fontSize: 14),
                        border: InputBorder.none),
                    onChanged: (v) => setS(() {
                      currentSearch = v;
                      filtered = companyList
                          .where((e) => e["label"]!
                              .toLowerCase()
                              .contains(v.toLowerCase()))
                          .toList();
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: filtered.map((item) {
                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedCompanyId = item["id"];
                            selectedCompanyLabel = item["label"];
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade100),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x08000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 2))
                            ],
                          ),
                          child: Text(item["label"]!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Company"),
        backgroundColor: const Color(0xFF5C9DED),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showCompanyDialog,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x0F000000),
                              blurRadius: 4,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedCompanyLabel ?? "Select Company",
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down,
                              color: Colors.black87, size: 24),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirmSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C9DED),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "Continue",
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
