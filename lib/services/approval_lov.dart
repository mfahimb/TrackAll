import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────
// BASE URLs
// ─────────────────────────────────────────────
const _baseUrl    = "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov";
const _approveUrl = "https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/POC_APPROVED";

// ─────────────────────────────────────────────
// ── SHARED MODELS ─────────────────────────────
// ─────────────────────────────────────────────

class LovDropItem {
  final String label;
  final int id;

  const LovDropItem({required this.label, required this.id});

  @override
  String toString() => label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LovDropItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────────
// ── POC LIST MODEL
// ─────────────────────────────────────────────

class PocListItem {
  final String description;
  final String title;
  final int pchId;
  final String flagIe;
  final DateTime? createdOn;

  const PocListItem({
    required this.description,
    required this.title,
    required this.pchId,
    required this.flagIe,
    this.createdOn,
  });

  factory PocListItem.fromJson(Map<String, dynamic> j,
    {String flagKey = 'PCH_FLAG_IE'}) {
  DateTime? dt;
  try {
    final raw = j['PCH_CREATED_ON']?.toString() ?? '';
    if (raw.isNotEmpty) {
      dt = DateTime.parse(raw.replaceAll(RegExp(r'Z$|\+[0-9:]+$'), ''));
    }
  } catch (_) {}

  final rawFlag = j[flagKey]?.toString() ?? 'N';
  String resolvedFlag;
  switch (rawFlag.toUpperCase()) {
    case 'APPROVED': resolvedFlag = 'Approved'; break;
    case 'REJECTED': resolvedFlag = 'Rejected'; break;
    default:         resolvedFlag = 'Pending';  // 'N' → 'Pending'
  }

  return PocListItem(
    description: j['DESCRIPTION']?.toString() ?? '',
    title:       j['TITLE']?.toString() ?? '',
    pchId:       j['PCH_ID'] as int? ?? 0,
    flagIe:      resolvedFlag,
    createdOn:   dt,
  );
}

  Color get statusColor {
    switch (flagIe.toLowerCase()) {
      case 'approved': return const Color(0xFF16A34A);
      case 'rejected': return const Color(0xFFDC2626);
      default:         return const Color(0xFFD97706);
    }
  }

  Color get statusBg {
    switch (flagIe.toLowerCase()) {
      case 'approved': return const Color(0xFFF0FDF4);
      case 'rejected': return const Color(0xFFFEF2F2);
      default:         return const Color(0xFFFFFBEB);
    }
  }

  IconData get statusIcon {
    switch (flagIe.toLowerCase()) {
      case 'approved': return Icons.check_circle_rounded;
      case 'rejected': return Icons.cancel_rounded;
      default:         return Icons.hourglass_empty_rounded;
    }
  }
}

// ─────────────────────────────────────────────
// ── POC DETAIL MODELS ─────────────────────────
// ─────────────────────────────────────────────

class PocInfo {
  final int pchId;
  final String pocNo;
  final DateTime? pocDate;
  final int version;
  final double fob;
  final double exWorks;
  final double cm;
  final double smv;
  final double mfgTotal;
  final double othTotal;
  final int qty;
  final String buyerName;
  final String inquiryNo;
  final String itemName;
  final String fgName;
  final String currency;
  final String calType;
  final bool isFinal;
  final String flagIe;
  final double costUnit;
  final double margin;
  final double epm;
  final double targetFob;

  const PocInfo({
    required this.pchId,
    required this.pocNo,
    this.pocDate,
    required this.version,
    required this.fob,
    required this.exWorks,
    required this.cm,
    required this.smv,
    required this.mfgTotal,
    required this.othTotal,
    required this.qty,
    required this.buyerName,
    required this.inquiryNo,
    required this.itemName,
    required this.fgName,
    required this.currency,
    required this.calType,
    required this.isFinal,
    required this.flagIe,
    required this.costUnit,
    required this.margin,
    required this.epm,
    required this.targetFob,
  });

  factory PocInfo.fromJson(Map<String, dynamic> j,
      {String flagKey = 'PCH_FLAG_IE'}) {
    DateTime? dt;
    try {
      final raw = j['PCH_DATE']?.toString() ?? '';
      if (raw.isNotEmpty) {
        dt = DateTime.parse(raw.replaceAll(RegExp(r'Z$|\+[0-9:]+$'), ''));
      }
    } catch (_) {}

    final flagRaw = (j[flagKey]?.toString() ?? '').isNotEmpty
        ? j[flagKey].toString()
        : (j['PCH_FLAG_IE']?.toString() ?? '').isNotEmpty
            ? j['PCH_FLAG_IE'].toString()
            : (j['PCH_FLAG_1']?.toString() ?? '').isNotEmpty
                ? j['PCH_FLAG_1'].toString()
                : 'Pending';

    String flagIe;
    switch (flagRaw.toUpperCase()) {
      case 'APPROVED': flagIe = 'Approved'; break;
      case 'REJECTED': flagIe = 'Rejected'; break;
      default:         flagIe = 'Pending';
    }

    return PocInfo(
      pchId:     j['PCH_ID'] as int? ?? 0,
      pocNo:     j['PCH_NO']?.toString() ?? '',
      pocDate:   dt,
      version:   j['PCH_VERSION'] as int? ?? 1,
      fob:       (j['PCH_FOB']      as num?)?.toDouble() ?? 0,
      exWorks:   (j['PCH_EX_WORKS'] as num?)?.toDouble() ?? 0,
      cm:        (j['PCH_CM']       as num?)?.toDouble() ?? 0,
      smv:       (j['PCH_SMV']      as num?)?.toDouble() ?? 0,
      mfgTotal:  (j['PCH_MFGTOTAL'] as num?)?.toDouble() ?? 0,
      othTotal:  (j['PCH_OTHTOTAL'] as num?)?.toDouble() ?? 0,
      qty:       j['PCH_QTY'] as int? ?? 0,
      buyerName: j['BUYR_NAME']?.toString() ?? '',
      inquiryNo: j['BEH_NO']?.toString() ?? '',
      itemName:  j['BEL_ITEM_DES']?.toString() ?? '',
      fgName:    j['PCH_FG_NAME']?.toString() ?? '',
      currency:  j['PCH_CURRENCY']?.toString() ?? 'USD',
      calType:   j['PCH_CAL_TYPE']?.toString() ?? '',
      isFinal:   (j['PCH_FINAL']?.toString() ?? 'N') == 'Y',
      flagIe:    flagIe,
      costUnit:  (j['PCH_MJR_QTY']  as num?)?.toDouble() ?? 0,
      margin:    (j['PCH_MARGIN']   as num?)?.toDouble() ?? 0,
      epm:       (j['PCH_EPM']      as num?)?.toDouble() ?? 0,
      targetFob: (j['PCH_TRGT_FOB'] as num?)?.toDouble() ?? 0,
    );
  }

  Color get statusColor {
    switch (flagIe.toLowerCase()) {
      case 'approved': return const Color(0xFF16A34A);
      case 'rejected': return const Color(0xFFDC2626);
      default:         return const Color(0xFFD97706);
    }
  }

  Color get statusBg {
    switch (flagIe.toLowerCase()) {
      case 'approved': return const Color(0xFFF0FDF4);
      case 'rejected': return const Color(0xFFFEF2F2);
      default:         return const Color(0xFFFFFBEB);
    }
  }

  IconData get statusIcon {
    switch (flagIe.toLowerCase()) {
      case 'approved': return Icons.check_circle_rounded;
      case 'rejected': return Icons.cancel_rounded;
      default:         return Icons.hourglass_empty_rounded;
    }
  }
}

class PocCostLine {
  final int sl;
  final String category;
  final String head;
  final String sourceType;
  final double rate;
  final double ratePercent;

  const PocCostLine({
    required this.sl,
    required this.category,
    required this.head,
    required this.sourceType,
    required this.rate,
    required this.ratePercent,
  });

  factory PocCostLine.fromJson(Map<String, dynamic> j) => PocCostLine(
        sl:          j['PCL_SL'] as int? ?? 0,
        category:    j['CAT_NAME']?.toString() ?? '',
        head:        j['HEAD']?.toString() ?? '',
        sourceType:  j['PCL_ITM_TYPE']?.toString() ?? '',
        rate:        (j['PCL_RATE'] as num?)?.toDouble() ?? 0,
        ratePercent: (j['RATE_PERCENT'] as num?)?.toDouble() ?? 0,
      );
}

// ─────────────────────────────────────────────
// ── APPROVAL STAGE ENUM ───────────────────────
// ─────────────────────────────────────────────

enum ApprovalStage { ie, coaster, fc }

extension ApprovalStageX on ApprovalStage {
  String get qryType {
    switch (this) {
      case ApprovalStage.ie:      return 'POC_1ST';
      case ApprovalStage.coaster: return 'POC_2ND';
      case ApprovalStage.fc:      return 'POC_3RD';
    }
  }

  String get flagKey {
  switch (this) {
    case ApprovalStage.ie:      return 'PCH_FLAG_IE';
    case ApprovalStage.coaster: return 'PCH_FLAG_1';
    case ApprovalStage.fc:      return 'PCH_FLAG_2';
  }
}

String get detailFlagKey {
  switch (this) {
    case ApprovalStage.ie:      return 'PCH_FLAG_IE';
    case ApprovalStage.coaster: return 'PCH_FLAG_1';
    case ApprovalStage.fc:      return 'PCH_FLAG_2';
  }
}

  String get pActions {
    switch (this) {
      case ApprovalStage.ie:      return 'POC_1ST';
      case ApprovalStage.coaster: return 'POC_2ND';
      case ApprovalStage.fc:      return 'POC_3RD';
    }
  }

  String get label {
    switch (this) {
      case ApprovalStage.ie:      return 'IE POC Approval';
      case ApprovalStage.coaster: return 'Coaster POC Approval';
      case ApprovalStage.fc:      return 'FC POC Approval';
    }
  }

  String get subtitle {
    switch (this) {
      case ApprovalStage.ie:      return '1st Approval — Industrial Engineering';
      case ApprovalStage.coaster: return '2nd Approval — Coaster';
      case ApprovalStage.fc:      return '3rd Approval — FC';
    }
  }

  IconData get icon {
    switch (this) {
      case ApprovalStage.ie:      return Icons.engineering_rounded;
      case ApprovalStage.coaster: return Icons.price_check_rounded;
      case ApprovalStage.fc:      return Icons.account_balance_rounded;
    }
  }
}

// ─────────────────────────────────────────────
// ── APPROVAL LOV SERVICE ──────────────────────
// ─────────────────────────────────────────────

class ApprovalLovService {

  // ── LOV DROPDOWNS ───────────────────────────

  // ── LOV DROPDOWNS — add buyerId parameter ───────────────

Future<List<LovDropItem>> fetchBuyers(String company) =>
    _fetchDrop('POC_BUYER', company, 'BUYR_NAME', 'BUYR_ID');

Future<List<LovDropItem>> fetchItems(String company, {int? buyerId}) =>
    _fetchDrop('POC_ITEM', company, 'BEL_ITEM_DES', 'BEL_ID',
        extraParams: buyerId != null ? {'P_BUYER': buyerId.toString()} : null);

Future<List<LovDropItem>> fetchCostNos(String company,
        {int? buyerId, int? itemId}) =>
    _fetchDrop('POC_COST_NO', company, 'PCH_NO', 'PCH_ID',
        extraParams: {
          if (buyerId != null) 'P_BUYER': buyerId.toString(),
          if (itemId  != null) 'P_ITEM':  itemId.toString(),
        });

Future<({
  List<LovDropItem> buyers,
  List<LovDropItem> items,
  List<LovDropItem> costNos,
})> fetchAll(String company) async {
  final buyers = await fetchBuyers(company);
  return (buyers: buyers, items: <LovDropItem>[], costNos: <LovDropItem>[]);
}

  // ── POC LIST ────────────────────────────────

 Future<List<PocListItem>> fetchPocList({
  required String company,
  required ApprovalStage stage,
  int?    buyerId,
  int?    itemId,
  int?    costNoId,
  String  status = '',
}) async {
  try {
    // ✅ Map display label → backend value
    String mappedStatus;
    switch (status.toLowerCase()) {
      case 'pending':  mappedStatus = 'N';        break;
      case 'approved': mappedStatus = 'Approved'; break;
      case 'rejected': mappedStatus = 'Rejected'; break;
      default:         mappedStatus = '';          break;
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'P_QRYTYP':      stage.qryType,
      'LOGIN_COMPANY': company,
      'P_BUYER':       buyerId?.toString()  ?? '',
      'P_ITEM':        itemId?.toString()   ?? '',
      'P_COSTING_NO':  costNoId?.toString() ?? '',
      'P_STATUS':      mappedStatus,
    });

    debugPrint('🌐 [${stage.qryType}] $uri');

    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return [];

    final decoded = jsonDecode(resp.body) as Map;
    List<dynamic> list = [];
    if (decoded[stage.qryType] is List) {
      list = decoded[stage.qryType] as List;
    } else {
      for (final entry in decoded.entries) {
        if (entry.value is List && (entry.value as List).isNotEmpty) {
          list = entry.value as List;
          break;
        }
      }
    }

    if (list.isNotEmpty) {
      debugPrint('🔍 [${stage.qryType}] flagKey=${stage.flagKey} '
          'value=${(list[0] as Map)[stage.flagKey]}');
    }

    return list
        .map((e) => PocListItem.fromJson(
            e as Map<String, dynamic>, flagKey: stage.flagKey))
        .toList();

  } catch (e) {
    debugPrint('❌ fetchPocList [${stage.qryType}]: $e');
    return [];
  }
}

  // ── POC DETAIL ──────────────────────────────

  Future<({PocInfo? info, List<PocCostLine> lines})> fetchPocInfo({
    required String company,
    required int pchId,
    ApprovalStage? stage,
  }) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'P_QRYTYP':      'POC_INFO',
        'LOGIN_COMPANY': company,
        'P_PCH_ID':      pchId.toString(),
      });

      debugPrint('🌐 fetchPocInfo: $uri');

      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        debugPrint('❌ fetchPocInfo HTTP ${resp.statusCode}');
        return (info: null, lines: <PocCostLine>[]);
      }

      final decoded = jsonDecode(resp.body) as Map;
      final list = (decoded['POC_INFO'] as List?) ?? [];
      if (list.isEmpty) return (info: null, lines: <PocCostLine>[]);

      final key     = stage?.detailFlagKey ?? 'PCH_FLAG_IE';
      final infoObj = PocInfo.fromJson(
          list[0] as Map<String, dynamic>, flagKey: key);

      final pocLines = list
          .map((e) => PocCostLine.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sl.compareTo(b.sl));

      return (info: infoObj, lines: pocLines);

    } catch (e) {
      debugPrint('❌ fetchPocInfo: $e');
      return (info: null, lines: <PocCostLine>[]);
    }
  }

  // ── APPROVAL SUBMISSION ─────────────────────
  // ✅ Now sends P_ACTION (Approved/Rejected) and P_REMARKS in body

  Future<Map<String, dynamic>> submitApproval({
    required int    pchId,
    required String action,   // 'Approved' or 'Rejected'
    required String appUser,
    required String company,
    ApprovalStage?  stage,
    String          remarks = '',
  }) async {
    try {
      final url = Uri.parse(_approveUrl);

      final request = http.Request('POST', url);
      request.headers['Content-Type'] = 'application/x-www-form-urlencoded';

      // ✅ All parameters in the POST body
      request.body = Uri(queryParameters: {
        'P_PCH_ID':   pchId.toString(),
        'P_APP_USER': appUser,
        'P_ACTIONS':  stage?.pActions ?? 'POC_1ST',
        'P_ACTION':   action,    // ✅ 'Approved' or 'Rejected'
        'P_REMARKS':  remarks,   // ✅ rejection reason (empty string if approved)
      }).query;

      debugPrint('📤 submitApproval URL    : $url');
      debugPrint('📤 submitApproval Body   : ${request.body}');
      debugPrint('📤 P_ACTIONS             : ${stage?.pActions ?? 'POC_1ST'}');
      debugPrint('📤 P_ACTION              : $action');
      debugPrint('📤 P_REMARKS             : $remarks');

      final streamed = await request.send().timeout(const Duration(seconds: 15));
      final body     = await streamed.stream.bytesToString();

      debugPrint('📥 Status  : ${streamed.statusCode}');
      debugPrint('📥 Response: $body');

      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        try {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          return {
            'success': decoded['success'] ?? true,
            'message': decoded['message'] ?? '$action successfully',
          };
        } catch (_) {
          // ORDS sometimes returns empty body on success
          return {'success': true, 'message': '$action successfully'};
        }
      } else {
        String errMsg = 'Server error (${streamed.statusCode})';
        try {
          final errBody = jsonDecode(body) as Map<String, dynamic>;
          errMsg = errBody['message']?.toString()
              ?? errBody['cause']?.toString()
              ?? errMsg;
        } catch (_) {}
        debugPrint('❌ ORDS Error: $errMsg');
        return {'success': false, 'message': errMsg};
      }
    } catch (e) {
      debugPrint('❌ submitApproval exception: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── PRIVATE HELPERS ─────────────────────────

 Future<List<LovDropItem>> _fetchDrop(
  String qryType,
  String company,
  String labelKey,
  String idKey, {
  Map<String, String>? extraParams,
}) async {
  try {
    final params = <String, String>{
      'P_QRYTYP':      qryType,
      'LOGIN_COMPANY': company,
      ...?extraParams,
    };

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    debugPrint('🌐 fetchDrop [$qryType]: $uri');

    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      debugPrint('⚠️ fetchDrop [$qryType]: HTTP ${resp.statusCode}');
      return [];
    }

    final decoded = jsonDecode(resp.body) as Map;
    final list = (decoded[qryType] as List?) ?? [];

    return list
        .map((e) => LovDropItem(
              label: e[labelKey]?.toString() ?? '',
              id:    e[idKey] as int? ?? 0,
            ))
        .toList();
  } catch (e, st) {
    debugPrint('❌ fetchDrop [$qryType]: $e\n$st');
    return [];
  }
}
}