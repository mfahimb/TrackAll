import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// ✅ For MediaType
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show Uint8List; // ✅ ADD FOR WEB SUPPORT



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
  return prefs.getString(_companyPrefKey); // uses the static key
}
  // 🔥 ADD: AUTO READ LOGIN USER (SAFE)
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

      if (upperType == "MENU") {
        await _saveMenuPermissions(list);
      }

      return list.map<Map<String, String>>((e) => {
            "id": e["R"]?.toString() ?? e["IDM_ID"]?.toString() ?? "",
            "label": e["D"]?.toString() ?? e["IDM_MENU_NAME"]?.toString() ?? "",
          }).toList();
    } catch (e) {
      return [];
    }
  }

 // =====================================
// COMPLETE UPDATED fetchQcLov METHOD
// Replace your current fetchQcLov method with this entire code
// =====================================

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
    debugPrint(
        "fetchQcLov => $upperType | bii=$biiId | process=$processId | qcType=$qcType | company=$company");

    // ✅ Base parameters - COMPANY IS ALWAYS INCLUDED
    final queryParams = {
      "P_QRYTYP": upperType,
      "LOGIN_COMPANY": company,
    };

    // Add conditional parameters based on query type
    switch (upperType) {
      case "QC_BII":
        // ✅ QC_BII only needs company, which is already added above
        debugPrint("✅ QC_BII query with company=$company");
        break;

      case "QC_JOB":
        // ✅ NEW: QC_JOB case to fetch job number
        if (biiId == null || biiId.isEmpty) {
          debugPrint("⚠️ QC_JOB: biiId is required");
          return [];
        }
        queryParams["p_bii_id"] = biiId;
        debugPrint("✅ QC_JOB query with bii_id=$biiId, company=$company");
        break;

      case "QC_PROCESS":
        if (biiId == null || biiId.isEmpty) {
          debugPrint("⚠️ QC_PROCESS: biiId is required");
          return [];
        }
        queryParams["p_bii_id"] = biiId;

        final loginUser = appUserId?.trim().isNotEmpty == true
            ? appUserId!
            : await _getLoginUser();
        if (loginUser == null || loginUser.isEmpty) {
          debugPrint("❌ QC_PROCESS BLOCKED: LOGIN USER NULL");
          return [];
        }
        queryParams["P_APP_USER"] = loginUser;
        break;

      case "QC_LINE":
        if (processId == null || processId.isEmpty) {
          debugPrint("⚠️ QC_LINE: processId is required");
          return [];
        }
        queryParams["p_process_id"] = processId;

        final loginUser = appUserId?.trim().isNotEmpty == true
            ? appUserId!
            : await _getLoginUser();
        if (loginUser == null || loginUser.isEmpty) {
          debugPrint("❌ QC_LINE BLOCKED: LOGIN USER NULL");
          return [];
        }
        queryParams["P_APP_USER"] = loginUser;
        break;

      case "QC_TYPE":
        // ✅ QC_TYPE only needs company, which is already added above
        debugPrint("✅ QC_TYPE query with company=$company");
        break;

      case "QC_SIZE":
        if (biiId == null || biiId.isEmpty) {
          debugPrint("⚠️ QC_SIZE: biiId is required");
          return [];
        }
        queryParams["p_bii_id"] = biiId;
        break;

      case "QC_ISSUE":
        if (qcType == null || qcType.isEmpty) {
          debugPrint("⚠️ QC_ISSUE: qcType is required");
          return [];
        }
        queryParams["p_qc_type"] = qcType;
        break;

      default:
        debugPrint("❌ Unknown QC LOV type: $upperType");
        return [];
    }

    final uri = Uri.parse(
      _baseUrl +
          "?" +
          queryParams.entries
              .map((e) => "${e.key}=${Uri.encodeComponent(e.value)}")
              .join("&"),
    );

    debugPrint("🌐 QC LOV API => $uri");

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      debugPrint("❌ QC LOV API ERROR => Status: ${response.statusCode}");
      debugPrint("❌ Response body: ${response.body}");
      return [];
    }

    final decoded = jsonDecode(response.body);
    debugPrint("🔍 API Response Keys: ${decoded.keys.toList()}");

    if (!decoded.containsKey(upperType)) {
      debugPrint("❌ QC LOV RESPONSE ERROR => Key '$upperType' not found");
      debugPrint("Available keys: ${decoded.keys.toList()}");
      return [];
    }

    final List rawList = decoded[upperType];

    if (rawList.isNotEmpty) {
      debugPrint("🔍 First raw item: ${rawList.first}");
    }

    debugPrint("📦 Total items in response: ${rawList.length}");

    // Parse the response
    final parsedList = rawList.map<Map<String, String>>((raw) {
      final m = raw as Map;
      String id = "";
      String label = "";

      if (upperType == "QC_JOB") {
        // Use JOB_NO as label, BPO_ID as id
        id = m["BPO_ID"]?.toString() ?? "";
        label = m["JOB_NO"]?.toString() ?? "";
      } else {
        // Existing logic for other QC types
        if (m.containsKey("R"))
          id = m["R"]?.toString() ?? "";
        else if (m.containsKey("TP_ID"))
          id = m["TP_ID"]?.toString() ?? "";
        else if (m.containsKey("TPDTL_ID"))
          id = m["TPDTL_ID"]?.toString() ?? "";
        else if (m.containsKey("OCSI_SIZE"))
          id = m["OCSI_SIZE"]?.toString() ?? "";
        else if (m.containsKey("BII_ID"))
          id = m["BII_ID"]?.toString() ?? "";
        else if (m.containsKey("LINE_ID"))
          id = m["LINE_ID"]?.toString() ?? "";
        else if (m.containsKey("ITEM_ID"))
          id = m["ITEM_ID"]?.toString() ?? "";
        else if (m.containsKey("PROCESS_ID"))
          id = m["PROCESS_ID"]?.toString() ?? "";
        else if (m.containsKey("SIZE_ID"))
          id = m["SIZE_ID"]?.toString() ?? "";

        // Label extraction
        if (m.containsKey("D"))
          label = m["D"]?.toString() ?? "";
        else if (m.containsKey("OCSI_SIZE"))
          label = m["OCSI_SIZE"]?.toString() ?? "";
        else if (m.containsKey("N1"))
          label = m["N1"]?.toString() ?? "";
        else if (m.containsKey("TYPE_NAME"))
          label = m["TYPE_NAME"]?.toString() ?? "";
        else if (m.containsKey("BII_ITEM_DESC"))
          label = m["BII_ITEM_DESC"]?.toString() ?? "";
        else if (m.containsKey("LINE_NAME"))
          label = m["LINE_NAME"]?.toString() ?? "";
        else if (m.containsKey("QC_TYPE"))
          label = m["QC_TYPE"]?.toString() ?? "";
        else if (m.containsKey("ITEM_DESC"))
          label = m["ITEM_DESC"]?.toString() ?? "";
        else if (m.containsKey("PROCESS_NAME"))
          label = m["PROCESS_NAME"]?.toString() ?? "";
        else if (m.containsKey("SIZE_NAME"))
          label = m["SIZE_NAME"]?.toString() ?? "";
        else if (m.containsKey("ISSUE_NAME"))
          label = m["ISSUE_NAME"]?.toString() ?? "";
      }

      // Start with id and label
      final result = <String, String>{
        "id": id,
        "label": label,
      };

      // ✅ Include ALL raw fields from API response (this ensures JOB_NO, BPO_PO_NO, STYLE_NO are preserved)
      m.forEach((key, value) {
        if (value != null) {
          result[key.toString()] = value.toString();
        }
      });

      return result;
    }).toList();

    if (parsedList.isNotEmpty) {
      debugPrint(
          "✅ First parsed item: id=${parsedList.first['id']}, label=${parsedList.first['label']}");
      
      // ✅ Debug specific query types
      if (upperType == "QC_BII") {
        debugPrint("🔍 JOB_NO: ${parsedList.first['JOB_NO']}");
        debugPrint("🔍 BPO_PO_NO: ${parsedList.first['BPO_PO_NO']}");
        debugPrint("🔍 STYLE_NO: ${parsedList.first['STYLE_NO']}");
        debugPrint("🔍 All keys: ${parsedList.first.keys.toList()}");
      }
      
      if (upperType == "QC_JOB") {
        debugPrint("🔍 JOB_NO: ${parsedList.first['JOB_NO']}");
        debugPrint("🔍 BPO_ID: ${parsedList.first['BPO_ID']}");
      }
    }

    debugPrint("✅ $upperType loaded: ${parsedList.length} items");
    return parsedList;
  } catch (e, stackTrace) {
    debugPrint("❌ QC LOV EXCEPTION => $e");
    debugPrint("Stack trace: $stackTrace");
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
      if (company == null || company.isEmpty) {
        debugPrint("❌ REMAINING QTY BLOCKED: No company selected");
        return "0";
      }

      final queryParams = {
        "P_QRYTYP": "REM_QTY",
        "LOGIN_COMPANY": company,
        "p_bii_id": biiId,
        "p_process_id": processId,
        "p_size": sizeId,
      };

      final uri = Uri.parse(
        _baseUrl +
            "?" +
            queryParams.entries
                .map((e) => "${e.key}=${Uri.encodeComponent(e.value)}")
                .join("&"),
      );

      debugPrint("🌐 REMAINING QTY API => $uri");

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint("❌ REMAINING QTY API ERROR => Status: ${response.statusCode}");
        return "0";
      }

      final decoded = jsonDecode(response.body);
      debugPrint("🔍 API Response Keys: ${decoded.keys.toList()}");

      if (!decoded.containsKey("REM_QTY")) {
        debugPrint("❌ REM_QTY key not found in response");
        return "0";
      }

      final List rawList = decoded["REM_QTY"];
      
      if (rawList.isEmpty) {
        debugPrint("⚠️ No remaining qty found");
        return "0";
      }

      // Extract the remaining quantity from first item
      final firstItem = rawList.first as Map;
      
      debugPrint("🔍 First item: $firstItem");
      
      // Try different possible field names
      String remainingQty = "";
      
      if (firstItem.containsKey("REMAINING_QUANTITY")) {
        remainingQty = firstItem["REMAINING_QUANTITY"]?.toString() ?? "0";
        debugPrint("✅ Found REMAINING_QUANTITY: $remainingQty");
      } else if (firstItem.containsKey("REMAINING_QTY")) {
        remainingQty = firstItem["REMAINING_QTY"]?.toString() ?? "0";
        debugPrint("✅ Found REMAINING_QTY: $remainingQty");
      } else if (firstItem.containsKey("REM_QTY")) {
        remainingQty = firstItem["REM_QTY"]?.toString() ?? "0";
        debugPrint("✅ Found REM_QTY: $remainingQty");
      } else if (firstItem.containsKey("QTY")) {
        remainingQty = firstItem["QTY"]?.toString() ?? "0";
        debugPrint("✅ Found QTY: $remainingQty");
      } else if (firstItem.containsKey("BALANCE_QTY")) {
        remainingQty = firstItem["BALANCE_QTY"]?.toString() ?? "0";
        debugPrint("✅ Found BALANCE_QTY: $remainingQty");
      } else {
        // If none found, try to get the first numeric value
        for (var key in firstItem.keys) {
          final value = firstItem[key];
          if (value is num || (value is String && num.tryParse(value) != null)) {
            remainingQty = value.toString();
            debugPrint("✅ Found numeric value in field '$key': $remainingQty");
            break;
          }
        }
      }

      debugPrint("✅ REMAINING QTY: $remainingQty");
      return remainingQty.isEmpty ? "0" : remainingQty;

    } catch (e, stackTrace) {
      debugPrint("❌ REMAINING QTY EXCEPTION => $e");
      debugPrint("Stack trace: $stackTrace");
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
    debugPrint("MENU PERMISSIONS SAVED => $menuIds");
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
    
    debugPrint("🌐 SOS_LINE API => $uri"); // Debug
    
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      debugPrint("❌ SOS_LINE API ERROR => Status: ${response.statusCode}");
      return [];
    }

    final decoded = jsonDecode(response.body);
    if (!decoded.containsKey("SOS_LINE")) {
      debugPrint("❌ SOS_LINE key not found in response");
      return [];
    }

    final List list = decoded["SOS_LINE"] as List;
    
    // 🔍 DEBUG: Print first item to see structure
    if (list.isNotEmpty) {
      debugPrint("🔍 First SOS_LINE item from API: ${list.first}");
    }

    return list.map<Map<String, String>>((e) {
      final lineMap = {
        "LINE_ID": e["LINE_ID"]?.toString() ?? "",
        "LINE_NAME": e["LINE_NAME"]?.toString() ?? "Unknown",
        "LINE_STAT": e["LINE_STAT"]?.toString() ?? "Ready",
        "LSH_DATE": e["LSH_DATE"]?.toString() ?? "",
        "STAFF_ID": e["LINE_LST_UPDATE"]?.toString() ?? "N/A",
        "LSH_CMNT": e["LSH_CMNT"]?.toString() ?? "",
        "LINE_PRE_STAT": e["LINE_PRE_STAT"]?.toString() ?? "N",
        "SYSDATE": e["SYSDATE"]?.toString() ?? "",
        "DOWNTIME": e["DOWNTIME"]?.toString() ?? "",
        "DW_LOC_ID": e["DW_LOC_ID"]?.toString() ?? e["LINE_UNIT"]?.toString() ?? "", // ✅ MAKE SURE THIS IS INCLUDED
      };
      
      // 🔍 DEBUG each line's DW_LOC_ID
      debugPrint("   Line ${lineMap['LINE_NAME']}: DW_LOC_ID=${lineMap['DW_LOC_ID']}");
      
      return lineMap;
    }).toList();
  } catch (e) {
    debugPrint("❌ Error in fetchSosLines: $e");
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

  // ================== CORE UPLOAD METHOD - SENDS ALL PDQC PARAMETERS IN HEADERS ==================
  // ✅ CRITICAL: Parameters go in HEADERS, not form fields! (Backend requirement)
  // ✅ Based on backend example - ALL parameters must be in headers
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

      // ✅ CRITICAL: Use http.Request NOT MultipartRequest
      var request = http.Request('POST', uri);

      // ✅ Add ALL parameters as HEADERS (backend requirement!)
      // Based on backend example:
      request.headers['p_app_user'] = appUser;
      request.headers['Login_company'] = company;
      request.headers['filename'] = filename;
      request.headers['pdqc_bii_id'] = biiId;
      request.headers['pdqc_process_id'] = processId;
      request.headers['pdqc_line_id'] = lineId;
      request.headers['pdqc_qc_type'] = qcType;
      request.headers['pdqc_qc_resp'] = issueTypeId;
      request.headers['side'] = side;
      request.headers['Content-Type'] = 'image/jpeg'; // ✅ MUST be image/jpeg

      // ✅ Optional parameters as headers
      if (sizeId != null && sizeId.isNotEmpty) {
        request.headers['pdqc_size'] = sizeId;
      }
      if (size != null && size.isNotEmpty) {
        request.headers['pdqc_size'] = size;
      }
      // ✅ pdqc_bpo_id removed - will add later when backend clarifies format
      if (orderNo != null && orderNo.isNotEmpty) {
        request.headers['pdqc_order_id'] = orderNo;
      }
      // ✅ Additional headers from backend example
      if (rejectQty != null && rejectQty.isNotEmpty) {
        request.headers['pdqc_reject_qty'] = rejectQty;
      }
      if (checkedBy != null && checkedBy.isNotEmpty) {
        request.headers['pdqc_checked_by'] = checkedBy;
      }
      if (qcPriority != null && qcPriority.isNotEmpty) {
        request.headers['pdqc_qc_priority'] = qcPriority;
      }

      // ✅ Image bytes go in BODY, not as multipart
      request.bodyBytes = bytes;

      debugPrint("📡 IMAGE UPLOAD START");
      debugPrint("➡️ URL: $_uploadUrl");
      debugPrint("📦 Headers: ${request.headers}");
      debugPrint("📸 File size: ${bytes.length} bytes");
      debugPrint("📸 Content-Type: image/jpeg");

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("📡 UPLOAD STATUS: ${response.statusCode}");
      debugPrint("📡 UPLOAD BODY: ${response.body}");

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          
          // Check for success indicators
          if (decoded['success'] == true || 
              decoded['status']?.toString().toUpperCase() == 'SUCCESS' ||
              decoded['pdqc_id'] != null) {
            
            final imagePath = decoded['pdqc_id']?.toString() ?? 
                             decoded['image_path']?.toString() ?? 
                             decoded['id']?.toString() ??
                             filename;
            
            debugPrint("✅ IMAGE UPLOADED SUCCESSFULLY: $imagePath");
            return imagePath;
          } else {
            debugPrint("❌ UPLOAD FAILED (SERVER RESPONSE): $decoded");
            return null;
          }
        } catch (e) {
          // If response is plain text, treat as success
          debugPrint("✅ IMAGE UPLOADED (Response: ${response.body})");
          return filename;
        }
      } else {
        debugPrint("❌ UPLOAD ERROR: ${response.statusCode}");
        debugPrint("❌ Response: ${response.body}");
        return null;
      }
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
      
      return await _upload(
        bytes,
        filename,
        company: company,
        appUser: appUser,
        biiId: biiId,
        processId: processId,
        lineId: lineId,
        qcType: qcType,
        issueTypeId: issueTypeId,
        side: side,
        sizeId: sizeId,
        size: size,
        orderNo: orderNo,
        jobNo: jobNo,
        rejectQty: rejectQty,
        checkedBy: checkedBy,
        qcPriority: qcPriority,
      );
    } catch (e) {
      debugPrint("❌ Exception in mobile upload: $e");
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
      
      return await _upload(
        bytes,
        filename,
        company: company,
        appUser: appUser,
        biiId: biiId,
        processId: processId,
        lineId: lineId,
        qcType: qcType,
        issueTypeId: issueTypeId,
        side: side,
        sizeId: sizeId,
        size: size,
        orderNo: orderNo,
        jobNo: jobNo,
        rejectQty: rejectQty,
        checkedBy: checkedBy,
        qcPriority: qcPriority,
      );
    } catch (e) {
      debugPrint("❌ Exception in web upload: $e");
      return null;
    }
  }


  // ================= SAVE QC ENTRY - SINGLE ENDPOINT SOLUTION ==================
  // ✅ Send ALL data (entry + image) to the image upload endpoint
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
    File? mobileImageFile,       // ✅ Image file
    Uint8List? webImageBytes,    // ✅ Image bytes
  }) async {
    try {
      final selectedCompany = await _getSelectedCompany();
      if (selectedCompany == null || selectedCompany.isEmpty) {
        debugPrint("❌ Cannot save QC entry: No company selected");
        return false;
      }

      // Check if image is provided
      if (imagePath == null && mobileImageFile == null && webImageBytes == null) {
        debugPrint("❌ Image is required for QC entry");
        return false;
      }

      // Get image bytes
      Uint8List? imageBytes;
      String filename = 'qc_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (webImageBytes != null && webImageBytes.isNotEmpty) {
        imageBytes = webImageBytes;
        debugPrint("✅ Using web image bytes");
      } else if (mobileImageFile != null) {
        imageBytes = await mobileImageFile.readAsBytes();
        debugPrint("✅ Read mobile image bytes: ${imageBytes.length} bytes");
      }

      if (imageBytes == null || imageBytes.isEmpty) {
        debugPrint("❌ Image bytes are empty");
        return false;
      }

      // ✅ SINGLE ENDPOINT: Send everything to qc_img_upload
      final uri = Uri.parse(_uploadUrl);
      var request = http.Request('POST', uri);

      // ✅ ALL parameters as HEADERS (Entry data + Image metadata)
      request.headers['p_app_user'] = appUserId;
      request.headers['Login_company'] = selectedCompany;
      request.headers['filename'] = filename;
      
      // Entry data
      request.headers['pdqc_bii_id'] = biiId;
      request.headers['pdqc_process_id'] = processId;
      request.headers['pdqc_line_id'] = lineId;
      request.headers['pdqc_qc_type'] = qcType;
      request.headers['pdqc_qc_resp'] = issueTypeId;
      request.headers['side'] = side;
      request.headers['pdqc_reject_qty'] = quantity;
      request.headers['pdqc_checked_by'] = checkedById;
      request.headers['pdqc_qc_priority'] = 'Major';
      
      // Optional fields
      if (sizeId != null && sizeId.isNotEmpty) {
        request.headers['pdqc_size'] = sizeId;
      }
      if (size != null && size.isNotEmpty) {
        request.headers['pdqc_size'] = size;
      }
      // ✅ pdqc_bpo_id removed - will add later when backend clarifies format
      if (orderNo.isNotEmpty) {
        request.headers['pdqc_order_id'] = orderNo;
      }
      
      // Image metadata
      request.headers['Content-Type'] = 'image/jpeg';

      // ✅ Image bytes in BODY
      request.bodyBytes = imageBytes;

      debugPrint("📡 QC ENTRY SAVE START (Single Endpoint)");
      debugPrint("➡️ URL: $_uploadUrl");
      debugPrint("📦 Entry Data Headers: {");
      debugPrint("   pdqc_bii_id: $biiId (type: ${biiId.runtimeType})");
      debugPrint("   pdqc_process_id: $processId (type: ${processId.runtimeType})");
      debugPrint("   pdqc_line_id: $lineId (type: ${lineId.runtimeType})");
      debugPrint("   pdqc_qc_type: $qcType (type: ${qcType.runtimeType})");
      debugPrint("   pdqc_qc_resp: $issueTypeId (type: ${issueTypeId.runtimeType})");
      debugPrint("   side: $side");
      debugPrint("   pdqc_reject_qty: $quantity (type: ${quantity.runtimeType})");
      debugPrint("   pdqc_checked_by: $checkedById (type: ${checkedById.runtimeType})");
      debugPrint("   pdqc_qc_priority: Major");
      // pdqc_bpo_id removed - will add later
      debugPrint("   pdqc_order_id: $orderNo");
      debugPrint("   pdqc_size: $sizeId");
      debugPrint("   Content-Type: image/jpeg");
      debugPrint("}");
      debugPrint("📸 Image size: ${imageBytes.length} bytes");

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("📡 SAVE STATUS: ${response.statusCode}");
      debugPrint("📡 SAVE BODY: ${response.body}");

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          
          // Check for success indicators
          if (decoded['success'] == true || 
              decoded['status']?.toString().toUpperCase() == 'SUCCESS' ||
              decoded['pdqc_id'] != null) {
            
            debugPrint("✅ QC ENTRY SAVED SUCCESSFULLY");
            return true;
          } else {
            debugPrint("❌ QC SAVE FAILED (SERVER RESPONSE): $decoded");
            return false;
          }
        } catch (e) {
          // If response is plain text, treat as success
          debugPrint("✅ QC ENTRY SAVED (Response: ${response.body})");
          return true;
        }
      } else if (response.statusCode == 201) {
        debugPrint("✅ QC ENTRY CREATED (Status 201)");
        return true;
      } else {
        debugPrint("❌ QC Entry save failed: ${response.statusCode}");
        debugPrint("Response: ${response.body}");
        return false;
      }

    } on TimeoutException {
      debugPrint("⏱ QC entry save timeout (30 seconds)");
      return false;
    } on http.ClientException catch (e) {
      debugPrint("🌐 NETWORK ERROR: $e");
      return false;
    } catch (e) {
      debugPrint("❌ UNKNOWN ERROR: $e");
      return false;
    }
  }
}