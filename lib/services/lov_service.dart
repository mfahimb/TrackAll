import 'dart:convert';
import 'package:http/http.dart' as http;

class LovService {
  static const String _baseUrl =
      "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov";
  
  // Base URL for saving data (assuming it follows your ORDS pattern)
  static const String _saveUrl = 
      "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/npt_save";
      
  static const String _loginCompany = "55";

  Future<List<Map<String, String>>> fetchLov({
    required String qryType,
    String? dwSec,
    String? dwLocId,
  }) async {
    try {
      final upperType = qryType.toUpperCase();

      // 🔒 Guard for LINE
      if (upperType == "LINE") {
        if (dwLocId == null || dwLocId.isEmpty || dwSec == null || dwSec.isEmpty) {
          print("LINE skipped → dw_loc_id or dw_sec missing");
          return [];
        }
      }

      final params = <String, String>{
        "P_QRYTYP": upperType,
        "LOGIN_COMPANY": _loginCompany,
      };

      if (dwLocId != null && dwLocId.isNotEmpty) params["dw_loc_id"] = dwLocId;
      if (dwSec != null && dwSec.isNotEmpty) params["dw_sec"] = dwSec;

      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      print("CALLING URL → $uri");

      final response = await http.get(uri);
      if (response.statusCode != 200) throw Exception("HTTP ${response.statusCode}");

      final decoded = jsonDecode(response.body);
      print("LOV RESPONSE ($upperType): $decoded");

      if (!decoded.containsKey(upperType)) return [];
      final List list = decoded[upperType];
      if (list.isEmpty) return [];
      if (list.length == 1 && (list[0]["CODE"] == -1 || list[0]["CODE"] == 1)) return [];

      return list
          .map<Map<String, String>>((e) => {
                "id": e["R"]?.toString() ?? "",
                "label": e["D"]?.toString() ?? e["NAME"]?.toString() ?? "",
              })
          .toList();
    } catch (e) {
      print("Error fetching LOV ($qryType): $e");
      return [];
    }
  }

  // --- NEW POST METHOD ---
  Future<bool> saveNptEntry(Map<String, dynamic> data) async {
    try {
      print("POSTING DATA TO → $_saveUrl");
      print("PAYLOAD → ${jsonEncode(data)}");

      final response = await http.post(
        Uri.parse(_saveUrl),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("SAVE SUCCESS: ${response.body}");
        return true;
      } else {
        print("SAVE FAILED: Status ${response.statusCode} | Body: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error in saveNptEntry: $e");
      return false;
    }
  }
}