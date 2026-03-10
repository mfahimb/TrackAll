import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show Uint8List;

class LovService {
  static const String _uploadUrl =
      "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/qc_img_upload";
  static const String _baseUrl =
      "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov";
  static const String _saveUrl =
      "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/Downtime_api";

  // ── Packing Production endpoint ────────────────────────────────
  static const String _packingUrl =
      "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/Packing_Production";

  static const String _offlineKey     = "offline_npt_queue";
  static const String _companyPrefKey = "selected_company_id";
  static const String _menuPrefKey    = "allowed_menu_ids";

  // ===============================================================
  // PRIVATE HELPERS — credentials
  // ===============================================================
  Future<String?> _getSelectedCompany() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_companyPrefKey);
  }

  Future<String?> _getLoginUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("staff_id") ??
        prefs.getString("app_user") ??
        prefs.getString("login_staff_id");
  }

  // ===============================================================
  // FETCH LOV  (generic — used by NPT / SOS pages)
  // ===============================================================
  Future<List<Map<String, String>>> fetchLov({
    required String qryType,
    required String appUserId,
    String? dwSec,
    String? dwLocId,
  }) async {
    try {
      final selectedCompany = await _getSelectedCompany();
      final upperType = qryType.toUpperCase();
      final params = <String, String>{
        "P_QRYTYP":      upperType,
        "P_APP_USER":    appUserId,
        "LOGIN_COMPANY": selectedCompany ?? "0",
      };
      if (dwLocId != null && dwLocId.isNotEmpty) params["dw_loc_id"] = dwLocId;
      if (dwSec   != null && dwSec.isNotEmpty)   params["dw_sec"]    = dwSec;
      final uri      = Uri.parse(_baseUrl).replace(queryParameters: params);
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey(upperType)) return [];
      final List list = decoded[upperType];
      if (upperType == "MENU") await _saveMenuPermissions(list);
      return list.map<Map<String, String>>((e) => {
            "id":    e["R"]?.toString()           ?? e["IDM_ID"]?.toString()        ?? "",
            "label": e["D"]?.toString()           ?? e["IDM_MENU_NAME"]?.toString() ?? "",
          }).toList();
    } catch (e) {
      return [];
    }
  }

  // ===============================================================
  // FETCH QC LOV  (QC Entry page)
  // ===============================================================
  Future<List<Map<String, String>>> fetchQcLov({
    required String qryType,
    String? biiId,
    String? processId,
    String? qcType,
    String? appUserId,
  }) async {
    try {
      final company = await _getSelectedCompany();
      if (company == null || company.isEmpty) {
        debugPrint("❌ QC LOV BLOCKED: No company selected");
        return [];
      }

      final upperType   = qryType.toUpperCase();
      final queryParams = {"P_QRYTYP": upperType, "LOGIN_COMPANY": company};

      switch (upperType) {
        case "QC_BII":
          break;

        case "QC_JOB":
          if (biiId == null || biiId.isEmpty) return [];
          queryParams["p_bii_id"] = biiId;
          break;

        case "QC_PROCESS":
          if (biiId == null || biiId.isEmpty) return [];
          queryParams["p_bii_id"] = biiId;
          final lu = appUserId?.trim().isNotEmpty == true ? appUserId! : await _getLoginUser();
          if (lu == null || lu.isEmpty) return [];
          queryParams["P_APP_USER"] = lu;
          break;

        case "QC_LINE":
          if (processId == null || processId.isEmpty) return [];
          queryParams["p_process_id"] = processId;
          final lu = appUserId?.trim().isNotEmpty == true ? appUserId! : await _getLoginUser();
          if (lu == null || lu.isEmpty) return [];
          queryParams["P_APP_USER"] = lu;
          break;

        case "QC_TYPE":
          break;

        case "QC_SIZE":
          if (biiId == null || biiId.isEmpty) return [];
          queryParams["p_bii_id"] = biiId;
          break;

        case "QC_ISSUE":
          if (qcType == null || qcType.isEmpty) return [];
          queryParams["p_qc_type"] = qcType;
          break;

        default:
          debugPrint("❌ Unknown QC LOV type: $upperType");
          return [];
      }

      final uri      = _buildUri(queryParams);
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey(upperType)) return [];

      return (decoded[upperType] as List).map<Map<String, String>>((raw) {
        final m = raw as Map;
        String id = "", label = "";

        if (upperType == "QC_JOB") {
          id    = m["BPO_ID"]?.toString() ?? "";
          label = m["JOB_NO"]?.toString() ?? "";
        } else {
          id    = _extractId(m, upperType);
          label = _extractLabel(m, upperType);
        }

        final result = <String, String>{"id": id, "label": label};
        m.forEach((k, v) { if (v != null) result[k.toString()] = v.toString(); });
        return result;
      }).toList();
    } catch (e, st) {
      debugPrint("❌ QC LOV EXCEPTION => $e\n$st");
      return [];
    }
  }

  // ===============================================================
  // FETCH PRODUCTION LOV  (Production Entry & Plan No Wise pages)
  // ===============================================================
  Future<List<Map<String, String>>> fetchProductionLov({
    required String qryType,
    String? biiId,
    String? processId,
    String? appUserId,
  }) async {
    try {
      final company = await _getSelectedCompany();
      if (company == null || company.isEmpty) {
        debugPrint("❌ PRODUCTION LOV BLOCKED: No company selected");
        return [];
      }

      final upperType   = qryType.toUpperCase();
      final queryParams = {"P_QRYTYP": upperType, "LOGIN_COMPANY": company};

      switch (upperType) {
        case "QC_BII":
          break;

        case "PLAN_BII":
          final lu = appUserId?.trim().isNotEmpty == true ? appUserId! : await _getLoginUser();
          if (lu == null || lu.isEmpty) return [];
          queryParams["P_APP_USER"] = lu;
          break;

        case "QC_JOB":
          if (biiId == null || biiId.isEmpty) return [];
          queryParams["p_bii_id"] = biiId;
          break;

        case "QC_PROCESS":
          if (biiId == null || biiId.isEmpty) return [];
          queryParams["p_bii_id"] = biiId;
          final lu = appUserId?.trim().isNotEmpty == true ? appUserId! : await _getLoginUser();
          if (lu == null || lu.isEmpty) return [];
          queryParams["P_APP_USER"] = lu;
          break;

        case "QC_LINE":
          if (processId == null || processId.isEmpty) return [];
          queryParams["p_process_id"] = processId;
          final lu = appUserId?.trim().isNotEmpty == true ? appUserId! : await _getLoginUser();
          if (lu == null || lu.isEmpty) return [];
          queryParams["P_APP_USER"] = lu;
          break;

        case "QC_SIZE":
          if (biiId == null || biiId.isEmpty) return [];
          queryParams["p_bii_id"] = biiId;
          break;

        default:
          debugPrint("❌ Unknown Production LOV type: $upperType");
          return [];
      }

      final uri      = _buildUri(queryParams);
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey(upperType)) return [];

      return (decoded[upperType] as List).map<Map<String, String>>((raw) {
        final m = raw as Map;
        String id = "", label = "";

        if (upperType == "QC_JOB") {
          id    = m["BPO_ID"]?.toString() ?? "";
          label = m["JOB_NO"]?.toString() ?? "";
        } else if (upperType == "PLAN_BII") {
          id    = m["BII_ID"]?.toString()        ?? "";
          label = m["BII_ITEM_DESC"]?.toString() ?? "";
        } else {
          id    = _extractId(m, upperType);
          label = _extractLabel(m, upperType);
        }

        final result = <String, String>{"id": id, "label": label};
        m.forEach((k, v) { if (v != null) result[k.toString()] = v.toString(); });
        return result;
      }).toList();
    } catch (e, st) {
      debugPrint("❌ PRODUCTION LOV EXCEPTION => $e\n$st");
      return [];
    }
  }

  // ===============================================================
  // FETCH PACKING LOV
  // ===============================================================
  Future<List<Map<String, String>>> fetchPackingLov({
    required String qryType,
    String? processId,
    String? biiId,
    String? countryId,
  }) async {
    try {
      final company = await _getSelectedCompany();
      if (company == null || company.isEmpty) {
        debugPrint("❌ PACKING LOV BLOCKED: No company selected");
        return [];
      }

      final upperType   = qryType.toUpperCase();
      final queryParams = {"P_QRYTYP": upperType, "LOGIN_COMPANY": company};

      switch (upperType) {
        case "PACKING_PROCESS":
          break;

        case "PACKING_BII":
          if (processId == null || processId.isEmpty) return [];
          queryParams["p_process_id"] = processId;
          break;

        case "PACKING_LINE":
          if (processId == null || processId.isEmpty) return [];
          queryParams["p_process_id"] = processId;
          break;

        case "PACKING_COUNTRY":
          if (biiId == null || biiId.isEmpty) return [];
          queryParams["p_bii_id"] = biiId;
          break;

        case "COUNTRY_SIZE":
          if (processId == null || processId.isEmpty ||
              biiId      == null || biiId.isEmpty      ||
              countryId  == null || countryId.isEmpty) {
            debugPrint("⚠️ COUNTRY_SIZE: processId, biiId and countryId are all required");
            return [];
          }
          queryParams["p_process_id"] = processId;
          queryParams["p_bii_id"]     = biiId;
          queryParams["p_country_id"] = countryId;
          break;

        default:
          debugPrint("❌ Unknown Packing LOV type: $upperType");
          return [];
      }

      final uri = _buildUri(queryParams);
      debugPrint("🌐 PACKING LOV API => $uri");
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint("❌ PACKING LOV ERROR => Status: ${response.statusCode}");
        return [];
      }

      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey(upperType)) {
        debugPrint("❌ Key '$upperType' not found. Available: ${decoded.keys.toList()}");
        return [];
      }

      final rawList = decoded[upperType] as List;
      debugPrint("📦 $upperType: ${rawList.length} items");
      if (rawList.isNotEmpty) debugPrint("🔍 First raw item: ${rawList.first}");

      final parsedList = rawList.map<Map<String, String>>((raw) {
        final m = raw as Map;
        String id = "", label = "";

        switch (upperType) {
          case "PACKING_PROCESS":
          case "PACKING_LINE":
            id    = m["R"]?.toString() ?? "";
            label = m["D"]?.toString() ?? "";
            break;

          case "PACKING_BII":
            id    = m["BII_ID"]?.toString()        ?? "";
            label = m["BII_ITEM_DESC"]?.toString() ?? "";
            break;

          case "PACKING_COUNTRY":
            id    = m["R"]?.toString() ?? "";
            label = m["D"]?.toString() ?? "";
            break;

          case "COUNTRY_SIZE":
            id    = m["OCSI_ID"]?.toString()   ?? "";
            label = m["OCSI_SIZE"]?.toString() ?? "";
            break;
        }

        final result = <String, String>{"id": id, "label": label};
        m.forEach((k, v) { if (v != null) result[k.toString()] = v.toString(); });
        return result;
      }).toList();

      debugPrint("✅ $upperType loaded: ${parsedList.length} items");
      return parsedList;
    } catch (e, st) {
      debugPrint("❌ PACKING LOV EXCEPTION => $e\n$st");
      return [];
    }
  }

  // ===============================================================
  // FETCH REMAINING QTY  (Production Entry)
  // ===============================================================
  Future<String> fetchRemainingQty({
    required String biiId,
    required String processId,
    required String sizeId,
  }) async {
    try {
      final company = await _getSelectedCompany();
      if (company == null || company.isEmpty) return "0";

      final queryParams = {
        "P_QRYTYP":      "REM_QTY",
        "LOGIN_COMPANY": company,
        "p_bii_id":      biiId,
        "p_process_id":  processId,
        "p_size":        sizeId,
      };

      final uri      = _buildUri(queryParams);
      final response = await http.get(uri);
      if (response.statusCode != 200) return "0";

      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey("REM_QTY")) return "0";

      final rawList = decoded["REM_QTY"] as List;
      if (rawList.isEmpty) return "0";

      final first = rawList.first as Map;
      for (final key in [
        "REMAINING_QUANTITY", "REMAINING_QTY", "REM_QTY", "QTY", "BALANCE_QTY"
      ]) {
        final v = first[key];
        if (v != null) return v.toString();
      }
      for (final v in first.values) {
        if (v is num || (v is String && num.tryParse(v) != null)) return v.toString();
      }
      return "0";
    } catch (e) {
      debugPrint("❌ REMAINING QTY EXCEPTION => $e");
      return "0";
    }
  }

  // ===============================================================
  // SAVE MENU PERMISSIONS
  // ===============================================================
  Future<void> _saveMenuPermissions(List list) async {
    final prefs   = await SharedPreferences.getInstance();
    final menuIds = list
        .map((e) => e["IDM_ID"]?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    await prefs.setStringList(_menuPrefKey, menuIds);
  }

  // ===============================================================
  // FETCH SOS LINES
  // ===============================================================
  Future<List<Map<String, String>>> fetchSosLines({
    required String appUserId,
  }) async {
    try {
      final selectedCompany = await _getSelectedCompany();
      final params = <String, String>{
        "P_QRYTYP":      "SOS_LINE",
        "P_APP_USER":    appUserId,
        "LOGIN_COMPANY": selectedCompany ?? "0",
      };
      final uri      = Uri.parse(_baseUrl).replace(queryParameters: params);
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey("SOS_LINE")) return [];
      return (decoded["SOS_LINE"] as List).map<Map<String, String>>((e) => {
            "LINE_ID":       e["LINE_ID"]?.toString()         ?? "",
            "LINE_NAME":     e["LINE_NAME"]?.toString()       ?? "Unknown",
            "LINE_STAT":     e["LINE_STAT"]?.toString()       ?? "Ready",
            "LSH_DATE":      e["LSH_DATE"]?.toString()        ?? "",
            "STAFF_ID":      e["LINE_LST_UPDATE"]?.toString() ?? "N/A",
            "LSH_CMNT":      e["LSH_CMNT"]?.toString()        ?? "",
            "LINE_PRE_STAT": e["LINE_PRE_STAT"]?.toString()   ?? "N",
            "SYSDATE":       e["SYSDATE"]?.toString()         ?? "",
            "DOWNTIME":      e["DOWNTIME"]?.toString()        ?? "",
            "DW_LOC_ID":     e["DW_LOC_ID"]?.toString()       ?? e["LINE_UNIT"]?.toString() ?? "",
          }).toList();
    } catch (e) {
      return [];
    }
  }

  // ===============================================================
  // SAVE NPT ENTRY
  // ===============================================================
  Future<bool> saveNptEntry({
    required DateTime entryDate,
    required String buildingId,
    required String processId,
    required String lineId,
    required String machineNo,
    required String smv,
    required String categoryId,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required String cause,
    required String deptId,
    required String responsibleUserId,
    required String remarks,
    required String gmtLossQty,
    required String staffId,
    required String numberOfOperators,
  }) async {
    final selectedCompany = await _getSelectedCompany();
    final payload = _buildPayload(
      entryDate:         entryDate,
      businessCompanyId: selectedCompany,
      buildingId:        buildingId,
      processId:         processId,
      lineId:            lineId,
      machineNo:         machineNo,
      smv:               smv,
      categoryId:        categoryId,
      startTime:         startTime,
      endTime:           endTime,
      cause:             cause,
      deptId:            deptId,
      responsibleUserId: responsibleUserId,
      remarks:           remarks,
      gmtLossQty:        gmtLossQty,
      staffId:           staffId,
      numberOfOperators: numberOfOperators,
    );
    final success = await _post(payload);
    if (!success) await _saveOffline(payload);
    return success;
  }

  Future<bool> _post(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse(_saveUrl),
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(response.body);
      return decoded["status"]?.toString().toUpperCase() == "SUCCESS";
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveOffline(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_offlineKey);
    final List list = raw == null ? [] : jsonDecode(raw);
    list.add(payload);
    await prefs.setString(_offlineKey, jsonEncode(list));
  }

  Map<String, dynamic> _buildPayload({
    required DateTime entryDate,
    required String? businessCompanyId,
    required String buildingId,
    required String processId,
    required String lineId,
    required String machineNo,
    required String smv,
    required String categoryId,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required String cause,
    required String deptId,
    required String responsibleUserId,
    required String remarks,
    required String gmtLossQty,
    required String staffId,
    required String numberOfOperators,
  }) {
    final st = DateTime(entryDate.year, entryDate.month, entryDate.day,
        startTime.hour, startTime.minute);
    var et = DateTime(entryDate.year, entryDate.month, entryDate.day,
        endTime.hour, endTime.minute);
    if (et.isBefore(st)) et = et.add(const Duration(days: 1));
    num n(String? v) => num.tryParse(v ?? "") ?? 0;
    return {
      "V_ACTION":         "I",
      "DW_DATE":          DateFormat('dd-MM-yyyy').format(entryDate),
      "BUSINESS_COMPANY": n(businessCompanyId),
      "CID":              n(businessCompanyId),
      "DW_LOC_ID":        n(buildingId),
      "DW_SEC":           n(processId),
      "DW_PROCS_ID":      n(processId),
      "LINE_NO":          n(lineId),
      "DW_LINE_NO":       n(machineNo),
      "DW_SMV":           n(smv),
      "DW_CATA":          n(categoryId),
      "DW_ST_TIM":        _fmt(st),
      "DW_END_TIM":       _fmt(et),
      "DW_TOT_TIM":       et.difference(st).inMinutes,
      "DW_NFO":           n(numberOfOperators),
      "DW_DEP":           n(deptId),
      "DW_RES_USR":       responsibleUserId,
      "DW_GMT_LOSS_QTY":  n(gmtLossQty),
      "REMARKS":          remarks,
      "USER_NAME":        staffId,
    };
  }

  String _fmt(DateTime dt) => DateFormat('dd-MM-yyyy HH:mm').format(dt);

  // ===============================================================
  // SAVE PRODUCTION ENTRY
  // ===============================================================
  Future<bool> saveProductionEntry({
    required String lineId,
    required String processId,
    required String biiId,
    required String bpoId,
    required String size,
    required String rejectQty,
    required String prodQty,
    required String bundleCount,
    required String flag,
    required String appUser,
    String  pType  = 'NORMAL',
    String? planNo,
  }) async {
    try {
      final company = await _getSelectedCompany();
      if (company == null || company.isEmpty) {
        debugPrint("❌ PRODUCTION SAVE BLOCKED: No company selected");
        return false;
      }

      final queryParams = <String, String>{
        "P_ACTION":           "I",
        "P_TYPE":             pType,
        "P_PD_BII_ID":        biiId,
        "P_PD_PROCESS_ID":    processId,
        "P_PD_LINE_ID":       lineId,
        "P_PD_SIZE":          size,
        "P_PD_PROD_QTY":      prodQty,
        "P_PD_BPO_ID":        bpoId,
        "P_LOGIN_COMPANY":    company,
        "P_USER":             appUser,
        "P_PD_REJECT_QTY":   rejectQty,
        "P_PD_BUNDDLE_COUNT": bundleCount,
        "P_PD_FLAG":          flag,
      };
      if (planNo != null && planNo.isNotEmpty) queryParams["P_PD_PLAN_NO"] = planNo;

      final uri = _buildUri(
        queryParams,
        base: "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/Production_API",
      );
      debugPrint("📡 PRODUCTION SAVE URL => $uri");

      final request  = http.Request('POST', uri);
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      debugPrint("📡 STATUS: ${response.statusCode}");
      debugPrint("📡 BODY:   ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.body.trim();
        if (body.isEmpty) return false;
        try {
          final decoded = jsonDecode(body);
          final status  = decoded["status"]?.toString().toUpperCase() ?? "";
          if (status == "SUCCESS" || decoded["PD_ID"] != null) return true;
          return false;
        } catch (e) {
          debugPrint("❌ PRODUCTION SAVE JSON PARSE ERROR: $e | body=$body");
          return false;
        }
      }
      return false;
    } catch (e, st) {
      debugPrint("❌ PRODUCTION SAVE EXCEPTION: $e\n$st");
      return false;
    }
  }

  // ===============================================================
  // SAVE PACKING ENTRY
  //
  // Matches Postman exactly:
  //   METHOD  : POST
  //   URL     : _packingUrl  (no query params)
  //   HEADERS : P_COMPANY_ID, P_APP_USER, Content-Type
  //   BODY    : JSON — pd_line_id, pd_process_id, pd_bii_id,
  //             pd_country, sizes[{size, qty}]
  // ===============================================================
  Future<bool> savePackingEntry({
    required String lineId,
    required String processId,
    required String biiId,
    required String country,   // R value from PACKING_COUNTRY LOV → pd_country
    required String appUser,
    required List<Map<String, dynamic>> sizes,
    // Each map must contain: { "size": "41", "qty": 10 }
  }) async {
    try {
      final company = await _getSelectedCompany();
      if (company == null || company.isEmpty) {
        debugPrint("❌ PACKING SAVE BLOCKED: No company selected");
        return false;
      }

      // ── Build JSON body (matches Postman exactly) ─────────────
      final body = {
        "pd_line_id":    int.tryParse(lineId)    ?? 0,
        "pd_process_id": int.tryParse(processId) ?? 0,
        "pd_bii_id":     int.tryParse(biiId)     ?? 0,
        "pd_country":    int.tryParse(country)   ?? 0,
        // Strip any extra fields — only send size + qty
        "sizes": sizes.map((s) => <String, dynamic>{
          "size": s["size"]?.toString() ?? "",
          "qty":  (s["qty"] is int) ? s["qty"] : int.tryParse(s["qty"]?.toString() ?? "0") ?? 0,
        }).toList(),
      };

      // ── Build request — credentials go in HEADERS, not query params ──
      final request = http.Request('POST', Uri.parse(_packingUrl));
      request.headers.addAll({
        'P_COMPANY_ID': company,
        'P_APP_USER':   appUser,
        'Content-Type': 'application/json',
      });
      request.body = jsonEncode(body);

      debugPrint("📡 PACKING SAVE URL     => $_packingUrl");
      debugPrint("📡 PACKING SAVE HEADERS => P_COMPANY_ID=$company | P_APP_USER=$appUser");
      debugPrint("📡 PACKING SAVE BODY    => ${jsonEncode(body)}");

      final streamed  = await request.send();
      final response  = await http.Response.fromStream(streamed);

      debugPrint("📡 PACKING STATUS: ${response.statusCode}");
      debugPrint("📡 PACKING BODY:   ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final respBody = response.body.trim();
        if (respBody.isEmpty) return true; // ORDS sometimes returns empty on success
        try {
          final decoded = jsonDecode(respBody);
          final status  = decoded["status"]?.toString().toUpperCase() ?? "";
          return status == "SUCCESS" ||
              decoded["PD_ID"]   != null ||
              decoded["success"] == true;
        } catch (_) {
          // Non-JSON 200 body → treat as success
          debugPrint("⚠️ PACKING: non-JSON 200, treating as success");
          return true;
        }
      }
      return false;
    } catch (e, st) {
      debugPrint("❌ PACKING SAVE EXCEPTION: $e\n$st");
      return false;
    }
  }

  // ===============================================================
// SAVE PLAN WISE PACKING ENTRY
//
//   METHOD  : POST
//   URL     : Plan_Packing_Production
//   HEADERS : P_COMPANY_ID, P_APP_USER, Content-Type
//   BODY    : JSON — pd_line_id, pd_process_id, pd_bii_id,
//             pd_country, pd_plan_no, sizes[{size, qty}]
// ===============================================================
Future<bool> savePlanWisePackingEntry({
  required String lineId,
  required String processId,
  required String biiId,
  required String country,
  required String planNo,
  required String appUser,
  required List<Map<String, dynamic>> sizes,
}) async {
  try {
    final company = await _getSelectedCompany();
    if (company == null || company.isEmpty) {
      debugPrint("❌ PLAN PACKING SAVE BLOCKED: No company selected");
      return false;
    }

    final body = {
      "pd_line_id":    int.tryParse(lineId)    ?? 0,
      "pd_process_id": int.tryParse(processId) ?? 0,
      "pd_bii_id":     int.tryParse(biiId)     ?? 0,
      "pd_country":    int.tryParse(country)   ?? 0,
      "pd_plan_no":    planNo,
      "sizes": sizes.map((s) => <String, dynamic>{
        "size": s["size"]?.toString() ?? "",
        "qty":  (s["qty"] is int) ? s["qty"] : int.tryParse(s["qty"]?.toString() ?? "0") ?? 0,
      }).toList(),
    };

    final request = http.Request(
      'POST',
      Uri.parse("https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/Plan_Packing_Production"),
    );
    request.headers.addAll({
      'P_COMPANY_ID': company,
      'P_APP_USER':   appUser,
      'Content-Type': 'application/json',
    });
    request.body = jsonEncode(body);

    debugPrint("📡 PLAN PACKING SAVE URL     => Plan_Packing_Production");
    debugPrint("📡 PLAN PACKING SAVE HEADERS => P_COMPANY_ID=$company | P_APP_USER=$appUser");
    debugPrint("📡 PLAN PACKING SAVE BODY    => ${jsonEncode(body)}");

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    debugPrint("📡 PLAN PACKING STATUS: ${response.statusCode}");
    debugPrint("📡 PLAN PACKING BODY:   ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      final respBody = response.body.trim();
      if (respBody.isEmpty) return true;
      try {
        final decoded = jsonDecode(respBody);
        final status  = decoded["status"]?.toString().toUpperCase() ?? "";
        return status == "SUCCESS" ||
            decoded["PD_ID"]   != null ||
            decoded["success"] == true;
      } catch (_) {
        debugPrint("⚠️ PLAN PACKING: non-JSON 200, treating as success");
        return true;
      }
    }
    return false;
  } catch (e, st) {
    debugPrint("❌ PLAN PACKING SAVE EXCEPTION: $e\n$st");
    return false;
  }
}

  // ===============================================================
  // SAVE SOS LINE
  // ===============================================================
  Future<bool> saveSosLine({
    required String action,
    required String appUser,
    required String lineComment,
    required String lineStatus,
    required String lineId,
    required String company,
  }) async {
    try {
      final request = http.Request(
        'POST',
        Uri.parse("https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/line_head_UP_INS"),
      );
      request.headers.addAll({
        'V_ACTION':    action,
        'V_LINE_ID':   lineId,
        'V_LINE_STAT': lineStatus,
        'V_LINE_CMNT': lineComment,
        'V_APP_USER':  appUser,
        'V_COMPANY':   company,
      });
      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ===============================================================
  // IMAGE UPLOAD  (shared core)
  // ===============================================================
  Future<String?> _upload(
    Uint8List bytes,
    String filename, {
    required String company,
    required String appUser,
    required String biiId,
    required String processId,
    required String lineId,
    required String qcType,
    required String issueTypeId,
    required String side,
    String? sizeId,
    String? size,
    String? orderNo,
    String? jobNo,
    String? rejectQty,
    String? checkedBy,
    String? qcPriority,
  }) async {
    try {
      final uri     = Uri.parse(_uploadUrl);
      final request = http.Request('POST', uri);
      request.headers['p_app_user']      = appUser;
      request.headers['Login_company']   = company;
      request.headers['filename']        = filename;
      request.headers['pdqc_bii_id']     = biiId;
      request.headers['pdqc_process_id'] = processId;
      request.headers['pdqc_line_id']    = lineId;
      request.headers['pdqc_qc_type']    = qcType;
      request.headers['pdqc_qc_resp']    = issueTypeId;
      request.headers['side']            = side;
      request.headers['Content-Type']    = 'image/jpeg';
      if (sizeId     != null && sizeId.isNotEmpty)     request.headers['pdqc_size']        = sizeId;
      if (size       != null && size.isNotEmpty)       request.headers['pdqc_size']        = size;
      if (orderNo    != null && orderNo.isNotEmpty)    request.headers['pdqc_order_id']    = orderNo;
      if (rejectQty  != null && rejectQty.isNotEmpty)  request.headers['pdqc_reject_qty']  = rejectQty;
      if (checkedBy  != null && checkedBy.isNotEmpty)  request.headers['pdqc_checked_by']  = checkedBy;
      if (qcPriority != null && qcPriority.isNotEmpty) request.headers['pdqc_qc_priority'] = qcPriority;
      request.bodyBytes = bytes;

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded['success'] == true ||
              decoded['status']?.toString().toUpperCase() == 'SUCCESS' ||
              decoded['pdqc_id'] != null) {
            return decoded['pdqc_id']?.toString() ??
                decoded['image_path']?.toString() ??
                decoded['id']?.toString() ??
                filename;
          }
          return null;
        } catch (e) {
          return filename;
        }
      }
      return null;
    } catch (e) {
      debugPrint("❌ Upload Exception: $e");
      return null;
    }
  }

  Future<String?> uploadQcImage(
    File imageFile, {
    required String company,
    required String appUser,
    required String biiId,
    required String processId,
    required String lineId,
    required String qcType,
    required String issueTypeId,
    required String side,
    String? sizeId, String? size, String? orderNo, String? jobNo,
    String? rejectQty, String? checkedBy, String? qcPriority,
  }) async {
    try {
      final filename = 'qc_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes    = await imageFile.readAsBytes();
      return await _upload(bytes, filename,
          company: company, appUser: appUser, biiId: biiId,
          processId: processId, lineId: lineId, qcType: qcType,
          issueTypeId: issueTypeId, side: side, sizeId: sizeId,
          size: size, orderNo: orderNo, jobNo: jobNo,
          rejectQty: rejectQty, checkedBy: checkedBy, qcPriority: qcPriority);
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadQcImageBytes(
    Uint8List bytes, {
    required String company,
    required String appUser,
    required String biiId,
    required String processId,
    required String lineId,
    required String qcType,
    required String issueTypeId,
    required String side,
    String? sizeId, String? size, String? orderNo, String? jobNo,
    String? rejectQty, String? checkedBy, String? qcPriority,
  }) async {
    try {
      final filename = 'qc_${DateTime.now().millisecondsSinceEpoch}.jpg';
      return await _upload(bytes, filename,
          company: company, appUser: appUser, biiId: biiId,
          processId: processId, lineId: lineId, qcType: qcType,
          issueTypeId: issueTypeId, side: side, sizeId: sizeId,
          size: size, orderNo: orderNo, jobNo: jobNo,
          rejectQty: rejectQty, checkedBy: checkedBy, qcPriority: qcPriority);
    } catch (e) {
      return null;
    }
  }

  // ===============================================================
  // SAVE QC ENTRY
  // ===============================================================
  Future<bool> saveQcEntry({
    required String biiId,
    required String jobNo,
    required String orderNo,
    required String articleNo,
    required String processId,
    required String lineId,
    required String qcType,
    String? sizeId,
    String? size,
    required String issueTypeId,
    required String side,
    required String quantity,
    required String checkedById,
    required String appUserId,
    String?    imagePath,
    File?      mobileImageFile,
    Uint8List? webImageBytes,
  }) async {
    try {
      final selectedCompany = await _getSelectedCompany();
      if (selectedCompany == null || selectedCompany.isEmpty) return false;
      if (imagePath == null && mobileImageFile == null && webImageBytes == null) return false;

      Uint8List? imageBytes;
      final filename = 'qc_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (webImageBytes != null && webImageBytes.isNotEmpty) {
        imageBytes = webImageBytes;
      } else if (mobileImageFile != null) {
        imageBytes = await mobileImageFile.readAsBytes();
      }
      if (imageBytes == null || imageBytes.isEmpty) return false;

      final uri     = Uri.parse(_uploadUrl);
      final request = http.Request('POST', uri);
      request.headers['p_app_user']       = appUserId;
      request.headers['Login_company']    = selectedCompany;
      request.headers['filename']         = filename;
      request.headers['pdqc_bii_id']      = biiId;
      request.headers['pdqc_process_id']  = processId;
      request.headers['pdqc_line_id']     = lineId;
      request.headers['pdqc_qc_type']     = qcType;
      request.headers['pdqc_qc_resp']     = issueTypeId;
      request.headers['side']             = side;
      request.headers['pdqc_reject_qty']  = quantity;
      request.headers['pdqc_checked_by']  = checkedById;
      request.headers['pdqc_qc_priority'] = 'Major';
      if (sizeId  != null && sizeId.isNotEmpty) request.headers['pdqc_size']     = sizeId;
      if (size    != null && size.isNotEmpty)   request.headers['pdqc_size']     = size;
      if (orderNo.isNotEmpty)                    request.headers['pdqc_order_id'] = orderNo;
      request.headers['Content-Type'] = 'image/jpeg';
      request.bodyBytes = imageBytes;

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          return decoded['success'] == true ||
              decoded['status']?.toString().toUpperCase() == 'SUCCESS' ||
              decoded['pdqc_id'] != null;
        } catch (e) {
          return true;
        }
      } else if (response.statusCode == 201) {
        return true;
      }
      return false;
    } on TimeoutException {
      return false;
    } on http.ClientException {
      return false;
    } catch (e) {
      return false;
    }
  }

  // ===============================================================
  // PRIVATE HELPERS
  // ===============================================================
  Uri _buildUri(Map<String, String> params, {String? base}) {
    final b = base ?? _baseUrl;
    return Uri.parse(
      "$b?" + params.entries
          .map((e) => "${e.key}=${Uri.encodeComponent(e.value)}")
          .join("&"),
    );
  }

  String _extractId(Map m, String type) {
    for (final k in ["BII_ID", "R", "LINE_ID", "PROCESS_ID", "OCSI_SIZE", "SIZE_ID"]) {
      if (m.containsKey(k)) return m[k]?.toString() ?? "";
    }
    return "";
  }

  String _extractLabel(Map m, String type) {
    for (final k in [
      "BII_ITEM_DESC", "D", "LINE_NAME", "PROCESS_NAME",
      "OCSI_SIZE", "SIZE_NAME", "QC_TYPE", "ITEM_DESC", "ISSUE_NAME",
    ]) {
      if (m.containsKey(k)) return m[k]?.toString() ?? "";
    }
    return "";
  }
}