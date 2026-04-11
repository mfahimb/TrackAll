import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LineStaffService {
  static const String _baseUrl =
      "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov";

  Future<String?> _getSelectedCompany() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("selected_company_id");
  }

  // ===============================================================
  // FETCH LINE NAME BY LINE ID
  // ===============================================================
  Future<Map<String, String>?> fetchLineName(String lineId) async {
    try {
      final company = await _getSelectedCompany();
      if (company == null || company.isEmpty) {
        debugPrint("❌ LINE NAME BLOCKED: No company selected");
        return null;
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        "P_QRYTYP":      "GET_LINENAME",
        "p_line_id":     lineId,
        "LOGIN_COMPANY": company,
      });

      debugPrint("🌐 FETCH LINE NAME => $uri");
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint("❌ LINE NAME HTTP ${response.statusCode}");
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey("GET_LINENAME")) {
        debugPrint("❌ LINE NAME: key 'GET_LINENAME' missing");
        return null;
      }

      final List rawList = decoded["GET_LINENAME"] as List;
      if (rawList.isEmpty) {
        debugPrint("❌ LINE NAME: no data returned");
        return null;
      }

      final first     = rawList.first as Map;
      final lineIdStr = first["LINE_ID"]?.toString() ?? "";
      final lineName  = first["LINE_NAME"]?.toString() ?? "";

      debugPrint("✅ LINE FOUND: ID=$lineIdStr, NAME=$lineName");
      return {"LINE_ID": lineIdStr, "LINE_NAME": lineName};
    } catch (e, st) {
      debugPrint("❌ LINE NAME EXCEPTION => $e\n$st");
      return null;
    }
  }

  // ===============================================================
  // FETCH STAFF NAME BY BARCODE (card credential number)
  // ===============================================================
  Future<Map<String, String>?> fetchStaffByBarcode(String barcode) async {
    try {
      final company = await _getSelectedCompany();
      if (company == null || company.isEmpty) {
        debugPrint("❌ STAFF LOOKUP BLOCKED: No company selected");
        return null;
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        "P_QRYTYP":      "GET_STAFF",
        "p_crdn_no":     barcode,
        "LOGIN_COMPANY": company,
      });

      debugPrint("🌐 FETCH STAFF => $uri");
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint("❌ STAFF HTTP ${response.statusCode}");
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey("GET_STAFF")) {
        debugPrint("❌ STAFF: key 'GET_STAFF' missing");
        return null;
      }

      final List rawList = decoded["GET_STAFF"] as List;
      if (rawList.isEmpty) {
        debugPrint("❌ STAFF: no data returned (barcode=$barcode)");
        return null;
      }

      final first     = rawList.first as Map;
      final staffId   = first["STAFF_ID"]?.toString() ?? barcode;
      final staffName = first["STAFF_NAME"]?.toString() ??
          first["EMP_NAME"]?.toString() ?? "";

      debugPrint("✅ STAFF FOUND: ID=$staffId, NAME=$staffName");
      return {
        "STAFF_ID":   staffId,
        "STAFF_NAME": staffName,
        "BARCODE":    barcode,
      };
    } catch (e, st) {
      debugPrint("❌ STAFF LOOKUP EXCEPTION => $e\n$st");
      return null;
    }
  }

  // ===============================================================
  // SUBMIT LINE-STAFF MAPPING
  // Returns: {'success': true, 'message': '...'} or
  //          {'success': false, 'message': '...'}
  // ===============================================================
  Future<Map<String, dynamic>> submitLineStaff({
    required String lineId,
    required String staffId,
    required String appUserId,
  }) async {
    try {
      final company = await _getSelectedCompany();
      if (company == null || company.isEmpty) {
        debugPrint("❌ SUBMIT BLOCKED: No company selected");
        return {'success': false, 'message': 'No company selected'};
      }

      final uri = Uri.parse(
        "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/Incentive_Post",
      ).replace(queryParameters: {
        "P_TYPE":       "LINE_WISE_STAFF",
        "P_LINE_ID":    lineId,
        "P_CRDN_NO":    staffId,
        "P_COMPANY_ID": company,
        "P_APP_USER":   appUserId,
      });

      debugPrint("📡 SUBMIT LINE-STAFF:");
      debugPrint("   URI      : $uri");
      debugPrint("   LINE_ID  : $lineId");
      debugPrint("   CRDN_NO  : $staffId");
      debugPrint("   COMPANY  : $company");
      debugPrint("   APP_USER : $appUserId");

      final request  = http.Request('POST', uri);
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      debugPrint("📡 STATUS : ${response.statusCode}");
      debugPrint("📡 BODY   : ${response.body}");

      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final status  = decoded['status']?.toString().toLowerCase();
        final message = decoded['message']?.toString() ?? '';

        // ── API error (e.g. duplicate record) ──────────────────
        if (status == 'error') {
          // Strip Oracle prefix: "ORA-20010: ORA-20005: " → clean message
          final cleaned = message
              .replaceAll(RegExp(r'ORA-\d+:\s*'), '')
              .trim();
          debugPrint("❌ API error: $cleaned");
          return {'success': false, 'message': cleaned};
        }

        // ── API success ────────────────────────────────────────
        if (status == 'success') {
          debugPrint("✅ Submit SUCCESS: $message");
          return {'success': true, 'message': message};
        }

        // ── Fallback for unexpected shape ──────────────────────
        return {'success': false, 'message': 'Unexpected response'};

      } catch (_) {
        // Non-JSON 200 → treat as success
        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint("⚠️ Non-JSON 200 — treating as success");
          return {'success': true, 'message': 'Submitted successfully'};
        }
        return {
          'success': false,
          'message': 'HTTP ${response.statusCode}',
        };
      }
    } catch (e, st) {
      debugPrint("❌ SUBMIT EXCEPTION => $e\n$st");
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}