import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class LovService {
  static const String _baseUrl =
      "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov";
  static const String _saveUrl =
      "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/Downtime_api";
  static const String _cid = "55";
  static const String _offlineKey = "offline_npt_queue";

  // ======================================================
  // FETCH LOV
  // ======================================================
  Future<List<Map<String, String>>> fetchLov({
    required String qryType,
    String? dwSec,
    String? dwLocId,
  }) async {
    try {
      final upperType = qryType.toUpperCase();

      if (upperType == "LINE") {
        if (dwLocId == null || dwLocId.isEmpty || dwSec == null || dwSec.isEmpty) {
          return [];
        }
      }

      final params = <String, String>{
        "P_QRYTYP": upperType,
        "LOGIN_COMPANY": _cid,
      };

      if (dwLocId != null && dwLocId.isNotEmpty) {
        params["dw_loc_id"] = dwLocId;
      }
      if (dwSec != null && dwSec.isNotEmpty) {
        params["dw_sec"] = dwSec;
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      final response = await http.get(uri);

      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (!decoded.containsKey(upperType)) return [];

      final List list = decoded[upperType];

      return list
          .map<Map<String, String>>((e) => {
                "id": e["R"]?.toString() ?? "",
                "label": e["D"]?.toString() ??
                    e["NAME"]?.toString() ??
                    "",
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ======================================================
  // PUBLIC SAVE
  // ======================================================
  Future<bool> saveNptEntry({
    required String buildingId,
    required String processId,
    required String lineId,        // LINE NO
    required String machineNo,     // MACHINE NO
    required String smv,
    required String categoryId,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required String cause,
    required String deptId,
    required String responsibleUserId,
    required String remarks,
    required String gmtLossQty,
    required String staffId,       // ✅ STAFF ID ONLY
    required String numberOfOperators,
  }) async {
    final payload = _buildPayload(
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

  // ======================================================
  // AUTO SYNC OFFLINE QUEUE
  // ======================================================
  Future<void> syncOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_offlineKey);
    if (raw == null) return;

    final List queue = jsonDecode(raw);
    final List remaining = [];

    for (final item in queue) {
      final ok = await _post(Map<String, dynamic>.from(item));
      if (!ok) remaining.add(item);
    }

    if (remaining.isEmpty) {
      await prefs.remove(_offlineKey);
    } else {
      await prefs.setString(_offlineKey, jsonEncode(remaining));
    }
  }

  // ======================================================
  // INTERNAL POST
  // ======================================================
  Future<bool> _post(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse(_saveUrl),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(payload),
      );

      debugPrint("Payload Sent: ${jsonEncode(payload)}");
      debugPrint("Server Response: ${response.body}");

      if (response.statusCode != 200) return false;

      final decoded = jsonDecode(response.body);

      return decoded["status"] != null &&
          decoded["status"].toString().toUpperCase() == "SUCCESS";
    } catch (e) {
      debugPrint("POST Error: $e");
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

  // ======================================================
  // PAYLOAD BUILDER (FINAL MAPPING)
  // ======================================================
  Map<String, dynamic> _buildPayload({
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
    final now = DateTime.now();

    final st = DateTime(
        now.year, now.month, now.day, startTime.hour, startTime.minute);
    var et =
        DateTime(now.year, now.month, now.day, endTime.hour, endTime.minute);

    if (et.isBefore(st)) et = et.add(const Duration(days: 1));

    num n(String? v) => num.tryParse(v ?? "") ?? 0;

    return {
      "V_ACTION": "I",
      "DW_DATE": DateFormat('dd-MM-yyyy').format(now),

      "DW_LOC_ID": n(buildingId),
      "DW_SEC": n(processId),
      "DW_PROCS_ID": n(processId),

      // ✅ CORRECT COLUMN MAPPING
      "LINE_NO": n(lineId),          // Line No
      "DW_LINE_NO": n(machineNo),    // Machine No

      "DW_SMV": n(smv),
      "DW_CATA": n(categoryId),
      "DW_ST_TIM": _fmt(st),
      "DW_END_TIM": _fmt(et),
      "DW_TOT_TIM": et.difference(st).inMinutes,

      "DW_NFO": n(numberOfOperators),
      "DW_DEP": n(deptId),
      "DW_RES_USR": n(responsibleUserId),

      "DW_GMT_LOSS_QTY": n(gmtLossQty),
      "CID": n(_cid),

      "REMARKS": remarks,

      // ✅ STAFF ID GOES HERE
      "USER_NAME": staffId,
    };
  }

  String _fmt(DateTime dt) =>
      DateFormat('dd-MM-yyyy HH:mm').format(dt);
}
