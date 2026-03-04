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

  static const String _offlineKey = "offline_npt_queue";
  static const String _companyPrefKey = "selected_company_id";
  static const String _menuPrefKey = "allowed_menu_ids";

  // ================= GET SELECTED COMPANY =================
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

  // ================= FETCH LOV =================
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
        "P_QRYTYP": upperType,
        "P_APP_USER": appUserId,
        "LOGIN_COMPANY": selectedCompany ?? "0",
      };
      if (dwLocId != null && dwLocId.isNotEmpty) params["dw_loc_id"] = dwLocId;
      if (dwSec != null && dwSec.isNotEmpty) params["dw_sec"] = dwSec;
      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey(upperType)) return [];
      final List list = decoded[upperType];
      if (upperType == "MENU") await _saveMenuPermissions(list);
      return list.map<Map<String, String>>((e) => {
            "id": e["R"]?.toString() ?? e["IDM_ID"]?.toString() ?? "",
            "label": e["D"]?.toString() ?? e["IDM_MENU_NAME"]?.toString() ?? "",
          }).toList();
    } catch (e) {
      return [];
    }
  }

  // ================= FETCH QC LOV =================
  // Used by: QC Entry page only
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

      final upperType = qryType.toUpperCase();
      debugPrint("fetchQcLov => $upperType | bii=$biiId | process=$processId | qcType=$qcType | company=$company");

      final queryParams = {
        "P_QRYTYP": upperType,
        "LOGIN_COMPANY": company,
      };

      switch (upperType) {
        case "QC_BII":
          debugPrint("✅ QC_BII query with company=$company");
          break;

        case "QC_JOB":
          if (biiId == null || biiId.isEmpty) {
            debugPrint("⚠️ QC_JOB: biiId is required");
            return [];
          }
          queryParams["p_bii_id"] = biiId;
          break;

        case "QC_PROCESS":
          if (biiId == null || biiId.isEmpty) return [];
          queryParams["p_bii_id"] = biiId;
          final loginUser1 = appUserId?.trim().isNotEmpty == true
              ? appUserId!
              : await _getLoginUser();
          if (loginUser1 == null || loginUser1.isEmpty) return [];
          queryParams["P_APP_USER"] = loginUser1;
          break;

        case "QC_LINE":
          if (processId == null || processId.isEmpty) return [];
          queryParams["p_process_id"] = processId;
          final loginUser2 = appUserId?.trim().isNotEmpty == true
              ? appUserId!
              : await _getLoginUser();
          if (loginUser2 == null || loginUser2.isEmpty) return [];
          queryParams["P_APP_USER"] = loginUser2;
          break;

        case "QC_TYPE":
          debugPrint("✅ QC_TYPE query with company=$company");
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

      final uri = Uri.parse(
        _baseUrl + "?" +
            queryParams.entries
                .map((e) => "${e.key}=${Uri.encodeComponent(e.value)}")
                .join("&"),
      );

      debugPrint("🌐 QC LOV API => $uri");
      final response = await http.get(uri);

      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey(upperType)) return [];

      final List rawList = decoded[upperType];

      final parsedList = rawList.map<Map<String, String>>((raw) {
        final m = raw as Map;
        String id = "";
        String label = "";

        if (upperType == "QC_JOB") {
          id = m["BPO_ID"]?.toString() ?? "";
          label = m["JOB_NO"]?.toString() ?? "";
        } else {
          if (m.containsKey("R")) id = m["R"]?.toString() ?? "";
          else if (m.containsKey("TP_ID")) id = m["TP_ID"]?.toString() ?? "";
          else if (m.containsKey("TPDTL_ID")) id = m["TPDTL_ID"]?.toString() ?? "";
          else if (m.containsKey("OCSI_SIZE")) id = m["OCSI_SIZE"]?.toString() ?? "";
          else if (m.containsKey("BII_ID")) id = m["BII_ID"]?.toString() ?? "";
          else if (m.containsKey("LINE_ID")) id = m["LINE_ID"]?.toString() ?? "";
          else if (m.containsKey("ITEM_ID")) id = m["ITEM_ID"]?.toString() ?? "";
          else if (m.containsKey("PROCESS_ID")) id = m["PROCESS_ID"]?.toString() ?? "";
          else if (m.containsKey("SIZE_ID")) id = m["SIZE_ID"]?.toString() ?? "";

          if (m.containsKey("D")) label = m["D"]?.toString() ?? "";
          else if (m.containsKey("OCSI_SIZE")) label = m["OCSI_SIZE"]?.toString() ?? "";
          else if (m.containsKey("N1")) label = m["N1"]?.toString() ?? "";
          else if (m.containsKey("TYPE_NAME")) label = m["TYPE_NAME"]?.toString() ?? "";
          else if (m.containsKey("BII_ITEM_DESC")) label = m["BII_ITEM_DESC"]?.toString() ?? "";
          else if (m.containsKey("LINE_NAME")) label = m["LINE_NAME"]?.toString() ?? "";
          else if (m.containsKey("QC_TYPE")) label = m["QC_TYPE"]?.toString() ?? "";
          else if (m.containsKey("ITEM_DESC")) label = m["ITEM_DESC"]?.toString() ?? "";
          else if (m.containsKey("PROCESS_NAME")) label = m["PROCESS_NAME"]?.toString() ?? "";
          else if (m.containsKey("SIZE_NAME")) label = m["SIZE_NAME"]?.toString() ?? "";
          else if (m.containsKey("ISSUE_NAME")) label = m["ISSUE_NAME"]?.toString() ?? "";
        }

        final result = <String, String>{"id": id, "label": label};
        m.forEach((key, value) {
          if (value != null) result[key.toString()] = value.toString();
        });
        return result;
      }).toList();

      debugPrint("✅ $upperType loaded: ${parsedList.length} items");
      return parsedList;
    } catch (e, stackTrace) {
      debugPrint("❌ QC LOV EXCEPTION => $e\n$stackTrace");
      return [];
    }
  }

  // ================= FETCH PRODUCTION LOV =================
  // Used by: Production Entry page & Plan No Wise Production Entry page
  // Supported types: PROD_BII, PROD_JOB, PROD_PROCESS, PROD_LINE,
  //                  PROD_SIZE, PLAN_BII
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

      final upperType = qryType.toUpperCase();
      debugPrint("fetchProductionLov => $upperType | bii=$biiId | process=$processId | company=$company");

      final queryParams = {
        "P_QRYTYP": upperType,
        "LOGIN_COMPANY": company,
      };

      switch (upperType) {
        // ── Items list (original production page) ────────────────
        case "QC_BII":
          // Production Entry still uses QC_BII — no extra params needed
          break;

        // ── Items + Plan data (Plan No Wise page) ────────────────
        case "PLAN_BII":
          // Returns: BII_ID, BII_ITEM_DESC, ORDER_ID, BPO_PO_NO,
          //          STYLE_NO, RPD_PLN_NO, RPD_MNUL_PA_NO
          final loginUser = appUserId?.trim().isNotEmpty == true
              ? appUserId!
              : await _getLoginUser();
          if (loginUser == null || loginUser.isEmpty) {
            debugPrint("❌ PLAN_BII BLOCKED: LOGIN USER NULL");
            return [];
          }
          queryParams["P_APP_USER"] = loginUser;
          break;

        // ── Job No ───────────────────────────────────────────────
        case "QC_JOB":
          if (biiId == null || biiId.isEmpty) {
            debugPrint("⚠️ QC_JOB: biiId is required");
            return [];
          }
          queryParams["p_bii_id"] = biiId;
          break;

        // ── Process list ─────────────────────────────────────────
        case "QC_PROCESS":
          if (biiId == null || biiId.isEmpty) return [];
          queryParams["p_bii_id"] = biiId;
          final loginUser = appUserId?.trim().isNotEmpty == true
              ? appUserId!
              : await _getLoginUser();
          if (loginUser == null || loginUser.isEmpty) return [];
          queryParams["P_APP_USER"] = loginUser;
          break;

        // ── Line list ────────────────────────────────────────────
        case "QC_LINE":
          if (processId == null || processId.isEmpty) return [];
          queryParams["p_process_id"] = processId;
          final loginUser = appUserId?.trim().isNotEmpty == true
              ? appUserId!
              : await _getLoginUser();
          if (loginUser == null || loginUser.isEmpty) return [];
          queryParams["P_APP_USER"] = loginUser;
          break;

        // ── Size list ────────────────────────────────────────────
        case "QC_SIZE":
          if (biiId == null || biiId.isEmpty) return [];
          queryParams["p_bii_id"] = biiId;
          break;

        default:
          debugPrint("❌ Unknown Production LOV type: $upperType");
          return [];
      }

      final uri = Uri.parse(
        _baseUrl + "?" +
            queryParams.entries
                .map((e) => "${e.key}=${Uri.encodeComponent(e.value)}")
                .join("&"),
      );

      debugPrint("🌐 PRODUCTION LOV API => $uri");
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint("❌ PRODUCTION LOV ERROR => Status: ${response.statusCode}");
        return [];
      }

      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey(upperType)) {
        debugPrint("❌ Key '$upperType' not found. Available: ${decoded.keys.toList()}");
        return [];
      }

      final List rawList = decoded[upperType];
      debugPrint("📦 $upperType: ${rawList.length} items");
      if (rawList.isNotEmpty) debugPrint("🔍 First raw item: ${rawList.first}");

      final parsedList = rawList.map<Map<String, String>>((raw) {
        final m = raw as Map;
        String id = "";
        String label = "";

        if (upperType == "QC_JOB") {
          // Job: BPO_ID → id, JOB_NO → label
          id    = m["BPO_ID"]?.toString() ?? "";
          label = m["JOB_NO"]?.toString() ?? "";
        } else if (upperType == "PLAN_BII") {
          // Plan BII: BII_ID → id, BII_ITEM_DESC → label
          // RPD_PLN_NO and RPD_MNUL_PA_NO preserved via forEach below
          id    = m["BII_ID"]?.toString() ?? "";
          label = m["BII_ITEM_DESC"]?.toString() ?? "";
        } else {
          // Generic extraction for QC_BII, QC_PROCESS, QC_LINE, QC_SIZE
          if (m.containsKey("BII_ID"))      id = m["BII_ID"]?.toString() ?? "";
          else if (m.containsKey("R"))       id = m["R"]?.toString() ?? "";
          else if (m.containsKey("LINE_ID")) id = m["LINE_ID"]?.toString() ?? "";
          else if (m.containsKey("PROCESS_ID")) id = m["PROCESS_ID"]?.toString() ?? "";
          else if (m.containsKey("OCSI_SIZE"))  id = m["OCSI_SIZE"]?.toString() ?? "";
          else if (m.containsKey("SIZE_ID"))    id = m["SIZE_ID"]?.toString() ?? "";

          if (m.containsKey("BII_ITEM_DESC"))  label = m["BII_ITEM_DESC"]?.toString() ?? "";
          else if (m.containsKey("D"))          label = m["D"]?.toString() ?? "";
          else if (m.containsKey("LINE_NAME"))  label = m["LINE_NAME"]?.toString() ?? "";
          else if (m.containsKey("PROCESS_NAME")) label = m["PROCESS_NAME"]?.toString() ?? "";
          else if (m.containsKey("OCSI_SIZE"))  label = m["OCSI_SIZE"]?.toString() ?? "";
          else if (m.containsKey("SIZE_NAME"))  label = m["SIZE_NAME"]?.toString() ?? "";
        }

        // Start with id + label, then preserve ALL raw fields
        final result = <String, String>{"id": id, "label": label};
        m.forEach((key, value) {
          if (value != null) result[key.toString()] = value.toString();
        });
        return result;
      }).toList();

      if (parsedList.isNotEmpty) {
        debugPrint("✅ First parsed: id=${parsedList.first['id']}, label=${parsedList.first['label']}");
        if (upperType == "PLAN_BII") {
          debugPrint("🔍 RPD_PLN_NO: ${parsedList.first['RPD_PLN_NO']}");
          debugPrint("🔍 RPD_MNUL_PA_NO: ${parsedList.first['RPD_MNUL_PA_NO']}");
          debugPrint("🔍 BPO_PO_NO: ${parsedList.first['BPO_PO_NO']}");
          debugPrint("🔍 STYLE_NO: ${parsedList.first['STYLE_NO']}");
        }
      }

      debugPrint("✅ $upperType loaded: ${parsedList.length} items");
      return parsedList;
    } catch (e, stackTrace) {
      debugPrint("❌ PRODUCTION LOV EXCEPTION => $e\n$stackTrace");
      return [];
    }
  }

  // ================= FETCH REMAINING QTY =================
  Future<String> fetchRemainingQty({
    required String biiId,
    required String processId,
    required String sizeId,
  }) async {
    try {
      final company = await _getSelectedCompany();
      if (company == null || company.isEmpty) return "0";

      final queryParams = {
        "P_QRYTYP": "REM_QTY",
        "LOGIN_COMPANY": company,
        "p_bii_id": biiId,
        "p_process_id": processId,
        "p_size": sizeId,
      };

      final uri = Uri.parse(
        _baseUrl + "?" +
            queryParams.entries
                .map((e) => "${e.key}=${Uri.encodeComponent(e.value)}")
                .join("&"),
      );

      debugPrint("🌐 REMAINING QTY API => $uri");
      final response = await http.get(uri);
      if (response.statusCode != 200) return "0";

      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey("REM_QTY")) return "0";

      final List rawList = decoded["REM_QTY"];
      if (rawList.isEmpty) return "0";

      final firstItem = rawList.first as Map;
      String remainingQty = "";

      if (firstItem.containsKey("REMAINING_QUANTITY"))
        remainingQty = firstItem["REMAINING_QUANTITY"]?.toString() ?? "0";
      else if (firstItem.containsKey("REMAINING_QTY"))
        remainingQty = firstItem["REMAINING_QTY"]?.toString() ?? "0";
      else if (firstItem.containsKey("REM_QTY"))
        remainingQty = firstItem["REM_QTY"]?.toString() ?? "0";
      else if (firstItem.containsKey("QTY"))
        remainingQty = firstItem["QTY"]?.toString() ?? "0";
      else if (firstItem.containsKey("BALANCE_QTY"))
        remainingQty = firstItem["BALANCE_QTY"]?.toString() ?? "0";
      else {
        for (var key in firstItem.keys) {
          final value = firstItem[key];
          if (value is num || (value is String && num.tryParse(value) != null)) {
            remainingQty = value.toString();
            break;
          }
        }
      }

      debugPrint("✅ REMAINING QTY: $remainingQty");
      return remainingQty.isEmpty ? "0" : remainingQty;
    } catch (e) {
      debugPrint("❌ REMAINING QTY EXCEPTION => $e");
      return "0";
    }
  }

  // ================= SAVE MENU IDS =================
  Future<void> _saveMenuPermissions(List list) async {
    final prefs = await SharedPreferences.getInstance();
    final menuIds = list
        .map((e) => e["IDM_ID"]?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    await prefs.setStringList(_menuPrefKey, menuIds);
  }

  // ================= FETCH SOS LINES =================
  Future<List<Map<String, String>>> fetchSosLines({
    required String appUserId,
  }) async {
    try {
      final selectedCompany = await _getSelectedCompany();
      final params = <String, String>{
        "P_QRYTYP": "SOS_LINE",
        "P_APP_USER": appUserId,
        "LOGIN_COMPANY": selectedCompany ?? "0",
      };
      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey("SOS_LINE")) return [];
      final List list = decoded["SOS_LINE"] as List;
      return list.map<Map<String, String>>((e) => {
            "LINE_ID": e["LINE_ID"]?.toString() ?? "",
            "LINE_NAME": e["LINE_NAME"]?.toString() ?? "Unknown",
            "LINE_STAT": e["LINE_STAT"]?.toString() ?? "Ready",
            "LSH_DATE": e["LSH_DATE"]?.toString() ?? "",
            "STAFF_ID": e["LINE_LST_UPDATE"]?.toString() ?? "N/A",
            "LSH_CMNT": e["LSH_CMNT"]?.toString() ?? "",
            "LINE_PRE_STAT": e["LINE_PRE_STAT"]?.toString() ?? "N",
            "SYSDATE": e["SYSDATE"]?.toString() ?? "",
            "DOWNTIME": e["DOWNTIME"]?.toString() ?? "",
            "DW_LOC_ID": e["DW_LOC_ID"]?.toString() ??
                e["LINE_UNIT"]?.toString() ?? "",
          }).toList();
    } catch (e) {
      return [];
    }
  }

  // ================= SAVE NPT ENTRY =================
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
      entryDate: entryDate,
      businessCompanyId: selectedCompany,
      buildingId: buildingId,
      processId: processId,
      lineId: lineId,
      machineNo: machineNo,
      smv: smv,
      categoryId: categoryId,
      startTime: startTime,
      endTime: endTime,
      cause: cause,
      deptId: deptId,
      responsibleUserId: responsibleUserId,
      remarks: remarks,
      gmtLossQty: gmtLossQty,
      staffId: staffId,
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
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
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
    final raw = prefs.getString(_offlineKey);
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
      "V_ACTION": "I",
      "DW_DATE": DateFormat('dd-MM-yyyy').format(entryDate),
      "BUSINESS_COMPANY": n(businessCompanyId),
      "CID": n(businessCompanyId),
      "DW_LOC_ID": n(buildingId),
      "DW_SEC": n(processId),
      "DW_PROCS_ID": n(processId),
      "LINE_NO": n(lineId),
      "DW_LINE_NO": n(machineNo),
      "DW_SMV": n(smv),
      "DW_CATA": n(categoryId),
      "DW_ST_TIM": _fmt(st),
      "DW_END_TIM": _fmt(et),
      "DW_TOT_TIM": et.difference(st).inMinutes,
      "DW_NFO": n(numberOfOperators),
      "DW_DEP": n(deptId),
      "DW_RES_USR": responsibleUserId,
      "DW_GMT_LOSS_QTY": n(gmtLossQty),
      "REMARKS": remarks,
      "USER_NAME": staffId,
    };
  }

  String _fmt(DateTime dt) => DateFormat('dd-MM-yyyy HH:mm').format(dt);

  // ================= SAVE PRODUCTION ENTRY =================
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
    String pType = 'NORMAL',
    String? planNo,
  }) async {
    try {
      final company = await _getSelectedCompany();
      if (company == null || company.isEmpty) {
        debugPrint("❌ PRODUCTION SAVE BLOCKED: No company selected");
        return false;
      }

      final queryParams = <String, String>{
        "P_ACTION"          : "I",
        "P_TYPE"            : pType,           // 'NORMAL' or 'PLAN'
        "P_PD_BII_ID"       : biiId,
        "P_PD_PROCESS_ID"   : processId,
        "P_PD_LINE_ID"      : lineId,          // ✅ WAS MISSING — THIS IS THE FIX
        "P_PD_SIZE"         : size,
        "P_PD_PROD_QTY"     : prodQty,
        "P_PD_BPO_ID"       : bpoId,
        "P_LOGIN_COMPANY"   : company,
        "P_USER"            : appUser,
        "P_PD_REJECT_QTY"   : rejectQty,
        "P_PD_BUNDDLE_COUNT": bundleCount,
        "P_PD_FLAG"         : flag,
      };

      if (planNo != null && planNo.isNotEmpty) {
        queryParams["P_PD_PLAN_NO"] = planNo;
      }

      final uri = Uri.parse(
        "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/Production_API?" +
            queryParams.entries
                .map((e) => "${e.key}=${Uri.encodeComponent(e.value)}")
                .join("&"),
      );

      debugPrint("📡 PRODUCTION SAVE URL => $uri");

      final request = http.Request('POST', uri);
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("📡 STATUS: ${response.statusCode}");
      debugPrint("📡 BODY:   ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.body.trim();
        if (body.isEmpty) {
          debugPrint("❌ PRODUCTION SAVE: Empty response body");
          return false;
        }
        try {
          final decoded = jsonDecode(body);
          final status = decoded["status"]?.toString().toUpperCase() ?? "";
          if (status == "SUCCESS" || decoded["PD_ID"] != null) {
            debugPrint("✅ PRODUCTION ENTRY SAVED — PD_ID: ${decoded['PD_ID']}");
            return true;
          }
          debugPrint("❌ PRODUCTION SAVE: status=$status | body=$body");
          return false;
        } catch (e) {
          // ✅ No longer silently returning true — log and return false
          debugPrint("❌ PRODUCTION SAVE JSON PARSE ERROR: $e | body=$body");
          return false;
        }
      }
      debugPrint("❌ PRODUCTION SAVE HTTP ERROR: ${response.statusCode}");
      return false;
    } catch (e, st) {
      debugPrint("❌ PRODUCTION SAVE EXCEPTION: $e\n$st");
      return false;
    }
  }

  // ================= SAVE SOS LINE =================
  Future<bool> saveSosLine({
    required String action,
    required String appUser,
    required String lineComment,
    required String lineStatus,
    required String lineId,
    required String company,
  }) async {
    try {
      var request = http.Request(
        'POST',
        Uri.parse(
            "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/line_head_UP_INS"),
      );
      request.headers.addAll({
        'V_ACTION': action,
        'V_LINE_ID': lineId,
        'V_LINE_STAT': lineStatus,
        'V_LINE_CMNT': lineComment,
        'V_APP_USER': appUser,
        'V_COMPANY': company,
      });
      http.StreamedResponse response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ================== CORE UPLOAD METHOD ==================
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
      final uri = Uri.parse(_uploadUrl);
      var request = http.Request('POST', uri);
      request.headers['p_app_user'] = appUser;
      request.headers['Login_company'] = company;
      request.headers['filename'] = filename;
      request.headers['pdqc_bii_id'] = biiId;
      request.headers['pdqc_process_id'] = processId;
      request.headers['pdqc_line_id'] = lineId;
      request.headers['pdqc_qc_type'] = qcType;
      request.headers['pdqc_qc_resp'] = issueTypeId;
      request.headers['side'] = side;
      request.headers['Content-Type'] = 'image/jpeg';
      if (sizeId != null && sizeId.isNotEmpty)
        request.headers['pdqc_size'] = sizeId;
      if (size != null && size.isNotEmpty)
        request.headers['pdqc_size'] = size;
      if (orderNo != null && orderNo.isNotEmpty)
        request.headers['pdqc_order_id'] = orderNo;
      if (rejectQty != null && rejectQty.isNotEmpty)
        request.headers['pdqc_reject_qty'] = rejectQty;
      if (checkedBy != null && checkedBy.isNotEmpty)
        request.headers['pdqc_checked_by'] = checkedBy;
      if (qcPriority != null && qcPriority.isNotEmpty)
        request.headers['pdqc_qc_priority'] = qcPriority;
      request.bodyBytes = bytes;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

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

  // ================== MOBILE IMAGE UPLOAD ==================
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
    String? sizeId,
    String? size,
    String? orderNo,
    String? jobNo,
    String? rejectQty,
    String? checkedBy,
    String? qcPriority,
  }) async {
    try {
      final filename = 'qc_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await imageFile.readAsBytes();
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

  // ================== WEB IMAGE UPLOAD ==================
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
    String? sizeId,
    String? size,
    String? orderNo,
    String? jobNo,
    String? rejectQty,
    String? checkedBy,
    String? qcPriority,
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

  // ================= SAVE QC ENTRY =================
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
    String? imagePath,
    File? mobileImageFile,
    Uint8List? webImageBytes,
  }) async {
    try {
      final selectedCompany = await _getSelectedCompany();
      if (selectedCompany == null || selectedCompany.isEmpty) return false;
      if (imagePath == null &&
          mobileImageFile == null &&
          webImageBytes == null) return false;

      Uint8List? imageBytes;
      String filename = 'qc_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (webImageBytes != null && webImageBytes.isNotEmpty) {
        imageBytes = webImageBytes;
      } else if (mobileImageFile != null) {
        imageBytes = await mobileImageFile.readAsBytes();
      }
      if (imageBytes == null || imageBytes.isEmpty) return false;

      final uri = Uri.parse(_uploadUrl);
      var request = http.Request('POST', uri);
      request.headers['p_app_user'] = appUserId;
      request.headers['Login_company'] = selectedCompany;
      request.headers['filename'] = filename;
      request.headers['pdqc_bii_id'] = biiId;
      request.headers['pdqc_process_id'] = processId;
      request.headers['pdqc_line_id'] = lineId;
      request.headers['pdqc_qc_type'] = qcType;
      request.headers['pdqc_qc_resp'] = issueTypeId;
      request.headers['side'] = side;
      request.headers['pdqc_reject_qty'] = quantity;
      request.headers['pdqc_checked_by'] = checkedById;
      request.headers['pdqc_qc_priority'] = 'Major';
      if (sizeId != null && sizeId.isNotEmpty)
        request.headers['pdqc_size'] = sizeId;
      if (size != null && size.isNotEmpty)
        request.headers['pdqc_size'] = size;
      if (orderNo.isNotEmpty) request.headers['pdqc_order_id'] = orderNo;
      request.headers['Content-Type'] = 'image/jpeg';
      request.bodyBytes = imageBytes;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

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
}