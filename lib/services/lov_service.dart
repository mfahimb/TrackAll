import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LovService {
  static const String _baseUrl =
      "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov";
  static const String _saveUrl =
      "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/Downtime_api";

  static const String _offlineKey = "offline_npt_queue";
  static const String _companyPrefKey = "selected_company_id";
  static const String _menuPrefKey = "allowed_menu_ids";

  Future<String?> _getSelectedCompany() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_companyPrefKey);
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

      // 🔐 MENU PERMISSION SAVE
      if (upperType == "MENU") {
        await _saveMenuPermissions(list);
      }

      return list.map<Map<String, String>>((e) => {
            "id": e["R"]?.toString() ??
                e["IDM_ID"]?.toString() ??
                "",
            "label": e["D"]?.toString() ??
                e["IDM_MENU_NAME"]?.toString() ??
                "",
          }).toList();
    } catch (e) {
      return [];
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
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey("SOS_LINE")) return [];

      final List list = decoded["SOS_LINE"] as List;

      return list.map<Map<String, String>>((e) {
        return {
          "LINE_ID": e["LINE_ID"]?.toString() ?? "",
          "LINE_NAME": e["LINE_NAME"]?.toString() ?? "Unknown",
          "LINE_STAT": e["LINE_STAT"]?.toString() ?? "Ready",
          "LSH_DATE": e["LSH_DATE"]?.toString() ?? "",
          "STAFF_ID": e["LINE_LST_UPDATE"]?.toString() ?? "N/A",
          "LSH_CMNT": e["LSH_CMNT"]?.toString() ?? "",
          "LINE_PRE_STAT": e["LINE_PRE_STAT"]?.toString() ?? "N",
          "SYSDATE": e["SYSDATE"]?.toString() ?? "",
        };
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

  String _fmt(DateTime dt) =>
      DateFormat('dd-MM-yyyy HH:mm').format(dt);

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
}
