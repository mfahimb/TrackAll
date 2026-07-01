import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

// =====================================================================
// MODELS
// =====================================================================

class SmvItem {
  final int    biiId;
  final String itemDesc;
  final String pocNo;
  final String bpoPONo;
  final double smv;

  SmvItem({
    required this.biiId,
    required this.itemDesc,
    required this.pocNo,
    required this.bpoPONo,
    required this.smv,
  });

  factory SmvItem.fromJson(Map<String, dynamic> j) {
    // ── ISSUE #1 FIX ──────────────────────────────────────────────
    // POC No was only ever read from "PCH_NO". If the backend actually
    // names this field something else (POC_NO / BII_POC_NO / etc.) it
    // silently came back empty. Try the likely candidates and log the
    // raw keys when none match, so you can confirm the real key name.
    final pocRaw = j["PCH_NO"] ??
        j["POC_NO"] ??
        j["BII_POC_NO"] ??
        j["PCH_POC_NO"];

    if (pocRaw == null) {
      debugPrint(
          '[SmvItem] POC No key not found. Available keys: ${j.keys.toList()}');
    }

    return SmvItem(
      biiId:    j["BII_ID"]        as int,
      itemDesc: j["BII_ITEM_DESC"] as String? ?? "",
      pocNo:    pocRaw?.toString() ?? "",
      bpoPONo:  j["BPO_PO_NO"]    as String? ?? "",
      smv:      (j["PCH_SMV"] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SmvVersion {
  final int    version;
  final int    submitFlag; // 0 = not submitted, 1 = submitted
  final String orderType;  // only populated for the latest version

  SmvVersion({
    required this.version,
    this.submitFlag = 0,
    this.orderType  = "",
  });

  SmvVersion copyWith({int? submitFlag, String? orderType}) => SmvVersion(
        version:    version,
        submitFlag: submitFlag ?? this.submitFlag,
        orderType:  orderType  ?? this.orderType,
      );
}

class SmvProcessDetail {
  final int    bopId;
  final int    bopProcessId;   // also serves as the master process ID for LOV match
  final int    dltId;
  final int    bopSl;
  final double smv;
  final String bopFlag;
  final int    bopBiiId;
  final double bopExtraPer;
  final int    bopNxtProcsId;

  SmvProcessDetail({
    required this.bopId,
    required this.bopProcessId,
    required this.dltId,
    required this.bopSl,
    required this.smv,
    required this.bopFlag,
    required this.bopBiiId,
    required this.bopExtraPer,
    required this.bopNxtProcsId,
  });

  factory SmvProcessDetail.fromJson(Map<String, dynamic> j) =>
      SmvProcessDetail(
        bopId:         j["BOP_ID"]           as int? ?? 0,
        bopProcessId:  j["BOP_PROCESS_ID"]   as int? ?? 0,
        dltId:         j["DLT_ID"]           as int? ?? 0,
        bopSl:         j["BOP_SL"]           as int? ?? 0,
        smv:           (j["SMV"] as num?)?.toDouble() ?? 0.0,
        bopFlag:       j["BOP_FLAG"]         as String? ?? "",
        bopBiiId:      j["BOP_BII_ID"]       as int? ?? 0,
        bopExtraPer:   (j["BOP_EXTRA_PER"] as num?)?.toDouble() ?? 0.0,
        bopNxtProcsId: j["BOP_NXT_PROCS_ID"] as int? ?? 0,
      );
}

// =====================================================================
// SERVICE
// =====================================================================

class ProcessSmvService {
  static const String baseUrl =
      'https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov';

  // ── 1. Item list ─────────────────────────────────────────────────
  // GET ?P_QRYTYP=PROCESS_BII&LOGIN_COMPANY=<companyId>
  // Returns: PROCESS_BII [ { BII_ID, BII_ITEM_DESC, PCH_NO, BPO_PO_NO, PCH_SMV } ]
  Future<List<SmvItem>> fetchItems({required String companyId}) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      'P_QRYTYP':      'PROCESS_BII',
      'LOGIN_COMPANY': companyId,
    });

    final response = await http.get(uri);
    _assertOk(response, 'fetchItems');

    final body    = jsonDecode(response.body) as Map<String, dynamic>;
    final list    = body['PROCESS_BII'] as List<dynamic>? ?? [];
    return list
        .map((e) => SmvItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── 2. Version list for a selected item ──────────────────────────
  // GET ?P_QRYTYP=PROCESS_VERSION&p_bii_id=<biiId>
  // Returns: PROCESS_VERSION [ { BOP_VERSION, BOP_SUBMIT, ORDER_TYPE } ]
  Future<List<SmvVersion>> fetchVersions({required int biiId}) async {
    // 1. Get the FULL version list (VERSION_LOV) — confirmed this
    //    returns every version, unlike PROCESS_VERSION which only
    //    ever returns the latest one regardless of P_VERSION passed.
    final lovUri = Uri.parse(baseUrl).replace(queryParameters: {
      'P_QRYTYP': 'VERSION_LOV',
      'p_bii_id': biiId.toString(),
    });
    final lovResponse = await http.get(lovUri);
    _assertOk(lovResponse, 'fetchVersions(VERSION_LOV)');
    debugPrint('[fetchVersions] VERSION_LOV biiId=$biiId raw: ${lovResponse.body}');

    final lovBody = jsonDecode(lovResponse.body) as Map<String, dynamic>;
    final lovList = lovBody['VERSION_LOV'] as List<dynamic>? ?? [];
    final versions = lovList.map((e) {
      final m = e as Map<String, dynamic>;
      return SmvVersion(version: m["R"] as int? ?? 0);
    }).toList();

    // 2. Get order type / submit flag — only available for the LATEST
    //    version via PROCESS_VERSION. Confirmed: passing P_VERSION for
    //    an older version still returns the latest version's data, so
    //    older versions simply don't have this info available anywhere.
    try {
      final pvUri = Uri.parse(baseUrl).replace(queryParameters: {
        'P_QRYTYP': 'PROCESS_VERSION',
        'p_bii_id': biiId.toString(),
      });
      final pvResponse = await http.get(pvUri);
      if (pvResponse.statusCode == 200) {
        final pvBody = jsonDecode(pvResponse.body) as Map<String, dynamic>;
        final pvList = pvBody['PROCESS_VERSION'] as List<dynamic>? ?? [];
        if (pvList.isNotEmpty) {
          final latest = pvList.first as Map<String, dynamic>;
          final latestVerNum = latest["BOP_VERSION"] as int? ?? 0;
          final idx = versions.indexWhere((v) => v.version == latestVerNum);
          if (idx != -1) {
            versions[idx] = versions[idx].copyWith(
              submitFlag: latest["BOP_SUBMIT"] as int? ?? 0,
              orderType:  latest["ORDER_TYPE"] as String? ?? "",
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[fetchVersions] PROCESS_VERSION fetch failed: $e');
    }

    debugPrint(
        '[fetchVersions] parsed ${versions.length} version(s): ${versions.map((v) => v.version).toList()}');

    return versions;
  }
  // ── 3. Process details for a selected item + version ─────────────
  // GET ?P_QRYTYP=PROCESS_DETAILS&p_bii_id=<biiId>&P_VERSION=<version>
  // Returns: PROCESS_DETAILS [ { BOP_ID, BOP_PROCESS_ID, DLT_ID, BOP_SL,
  //   SMV, BOP_FLAG, BOP_BII_ID, BOP_EXTRA_PER, BOP_MST_PROCESS_ID,
  //   BOP_ACTUAL_QTY, BOP_CONV_QTY, BOP_NXT_PROCS_ID } ]
  // Note: rows come unsorted — sort by BOP_SL before displaying.
  Future<List<SmvProcessDetail>> fetchProcessDetails({
    required int biiId,
    required int version,
  }) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      'P_QRYTYP': 'PROCESS_DETAILS',
      'p_bii_id': biiId.toString(),
      'P_VERSION': version.toString(),
    });

    final response = await http.get(uri);
    _assertOk(response, 'fetchProcessDetails');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['PROCESS_DETAILS'] as List<dynamic>? ?? [];
    final details = list
        .map((e) =>
            SmvProcessDetail.fromJson(e as Map<String, dynamic>))
        .toList();

    // Sort by SL ascending (API does not guarantee order)
    details.sort((a, b) => a.bopSl.compareTo(b.bopSl));
    return details;
  }

  // ── 4. Process LOV (dropdown list of processes) ───────────────────
  // ── ISSUES #2/#3 ROOT CAUSE ───────────────────────────────────────
  // 'SMV_PROCESS_LOV' below is a PLACEHOLDER that was never confirmed
  // with the backend (see original TODO). This is almost certainly why
  // both the Process Name and Next Process dropdowns show "data not
  // found" — they both read from this same processList. You need the
  // real P_QRYTYP value for the process master LOV from the backend
  // team. The debug print below will show you exactly what comes back
  // so you can confirm (likely an error payload, not a list).
 // ── 4. Process LOV (dropdown list of processes) ───────────────────
  // Confirmed: P_QRYTYP=BOP_PROCESS, scoped by LOGIN_COMPANY (not
  // p_bii_id — it's a company-wide process master list, not specific
  // to one item). Response shape matches VERSION_LOV: { D, R }.
  Future<List<Map<String, String>>> fetchProcessLov({
    required String companyId,
  }) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      'P_QRYTYP':      'BOP_PROCESS',
      'LOGIN_COMPANY': companyId,
    });

    final response = await http.get(uri);
    debugPrint(
        '[fetchProcessLov] companyId=$companyId status=${response.statusCode} body=${response.body}');

    if (response.statusCode != 200) return [];

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = body['BOP_PROCESS'] as List<dynamic>? ?? [];
      return list.map<Map<String, String>>((e) {
        final m = e as Map<String, dynamic>;
        return {
          'id':    m['R']?.toString() ?? '',
          'label': m['D']?.toString() ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('[fetchProcessLov] Parse error: $e');
      return [];
    }
  }

  // ── 4b. Next Process LOV (separate from Process Name LOV) ─────────
  // Confirmed distinct from BOP_PROCESS — same D/R shape, but includes
  // extra entries like "Not Applicable" not present in the process list.
  Future<List<Map<String, String>>> fetchNextProcessLov({
    required String companyId,
  }) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      'P_QRYTYP':      'BOP_NEXT_PROCESS',
      'LOGIN_COMPANY': companyId,
    });

    final response = await http.get(uri);
    debugPrint(
        '[fetchNextProcessLov] companyId=$companyId status=${response.statusCode} body=${response.body}');

    if (response.statusCode != 200) return [];

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = body['BOP_NEXT_PROCESS'] as List<dynamic>? ?? [];
      return list.map<Map<String, String>>((e) {
        final m = e as Map<String, dynamic>;
        return {
          'id':    m['R']?.toString() ?? '',
          'label': m['D']?.toString() ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('[fetchNextProcessLov] Parse error: $e');
      return [];
    }
  }

  // ── 5. Save ───────────────────────────────────────────────────────
  // TODO: confirm endpoint, method (POST/PUT) and payload shape with backend.
  // Placeholder implementation shown below.
  // ── 5. Save (SAVE mode) ────────────────────────────────────────────
  // POST .../Process_and_smv/new_version?p_app_user=&p_company_id=&p_dtype=SAVE&p_action=
  // Body: { p_bii_id, p_version, p_submit, details: [ {...} ] }
  // NOTE: row-level action travels inside each detail row as
  // "row_actions" (C/U/D) — the p_action query param is required as a
  // bind variable but is no longer used by the backend for row
  // processing, so we send it empty.
  static const String _saveUrl =
      'https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/Process_and_smv/new_version';

  Future<String?> saveSmvSet({
    required int    biiId,
    required int    version,
    required bool   submit,
    required String appUser,
    required String companyId,
    required List<Map<String, dynamic>> rows,
    // rows shape per element (matches JSON_TABLE columns under $.details[*]):
    // {
    //   "row_actions":   String,  // 'C', 'U', or 'D' — per row
    //   "bop_id":        int,     // 0 if new row
    //   "process_id":    int,
    //   "sl":            int,
    //   "smv":           double,
    //   "flag":          String,
    //   "nxt_procs_id":  int,
    //   "actual_qty":    int,
    //   "conv_qty":      int,
    // }
  }) async {
    final uri = Uri.parse(_saveUrl).replace(queryParameters: {
      'p_app_user':   appUser,
      'p_company_id': companyId,
      'p_dtype':      'SAVE',
      'p_action':     '', // unused by backend now; kept for bind compatibility
    });

    final payload = jsonEncode({
      'p_bii_id':  biiId,
      'p_version': version,
      'p_submit':  submit ? 1 : 0,
      'details':   rows,
    });

    debugPrint('[saveSmvSet] POST $uri body=$payload');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: payload,
    );

    return _parseSaveResponse(response, 'saveSmvSet');
  }

  // ── 6. Create new version (NEW_VERSION mode) ───────────────────────
  // POST .../Process_and_smv/new_version?p_app_user=&p_company_id=&p_dtype=NEW_VERSION&p_action=
  // Body only needs p_bii_id + p_version (the version being copied FROM —
  // backend inserts copies at BOP_VERSION + 1 for every row matching
  // BOP_BII_ID + BOP_VERSION). 'details' is not read in this branch.
  Future<String?> createNewVersion({
    required int    biiId,
    required int    fromVersion,
    required String appUser,
    required String companyId,
  }) async {
    final uri = Uri.parse(_saveUrl).replace(queryParameters: {
      'p_app_user':   appUser,
      'p_company_id': companyId,
      'p_dtype':      'NEW_VERSION',
      'p_action':     '',
    });

    final payload = jsonEncode({
      'p_bii_id':  biiId,
      'p_version': fromVersion,
      'p_submit':  0,
    });

    debugPrint('[createNewVersion] POST $uri body=$payload');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: payload,
    );

    return _parseSaveResponse(response, 'createNewVersion');
  }

  // ── Shared response parser for both SAVE and NEW_VERSION ──────────
  // Backend always returns {"status":"success"|"error","message":"..."}
  String? _parseSaveResponse(http.Response response, String caller) {
    debugPrint(
        '[$caller] status=${response.statusCode} body=${response.body}');
    if (response.statusCode != 200) {
      return 'Server error: ${response.statusCode}';
    }
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status  = body['status']  as String?;
      final message = body['message'] as String?;
      if (status == 'success') return null;
      return message ?? 'Unknown error';
    } catch (e) {
      return 'Failed to parse server response: $e';
    }
  }

  // ── Helper ────────────────────────────────────────────────────────
  void _assertOk(http.Response response, String caller) {
    if (response.statusCode != 200) {
      throw Exception(
          '[$caller] HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
  }
}