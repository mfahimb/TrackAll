import 'dart:convert';
import 'package:http/http.dart' as http;

class MachineService {
  static const _base =
      'https://trackall.rflgroupbd.com/ords/rpro/xxtrac_al/machine_management';

  static String _fmtApiDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  /// SCAN_MACHIN_REPORT. [lwmLine] and [unit] are optional (NULL = all).
  static Future<List<Map<String, dynamic>>> getScannedMachineReport({
    required String company,
    required DateTime scanDate,
    String? lwmLine,
    String? unit,
  }) async {
    final params = <String, String>{
      'p_type': 'SCAN_MACHIN_REPORT',
      'login_company': company,
      'scan_date': _fmtApiDate(scanDate),
      if (lwmLine != null && lwmLine.isNotEmpty) 'lwm_line': lwmLine,
      if (unit != null && unit.isNotEmpty) 'unit': unit,
    };

    final uri = Uri.parse(_base).replace(queryParameters: params);
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw Exception('Server error ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded['status'] != 'success') {
      throw Exception(decoded['message'] ?? 'Failed to load data');
    }

    final list = (decoded['result'] as List?) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// LINE_NAME by line QR. Returns null if not found.
  static Future<Map<String, dynamic>?> fetchLineName(String lineQr) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'p_type': 'LINE_NAME',
      'line_qr': lineQr,
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) return null;
    final decoded = jsonDecode(resp.body);
    final list = (decoded['result'] as List?) ?? [];
    if (decoded['status'] != 'success' || list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first as Map);
  }

  /// MACHINE_INFO by machine QR. Returns {OID, AMIM_NAME} or null.
  static Future<Map<String, dynamic>?> fetchMachineInfo(
      String machineQr) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'p_type': 'MACHINE_INFO',
      'machine_qr': machineQr,
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) return null;
    final decoded = jsonDecode(resp.body);
    final list = (decoded['result'] as List?) ?? [];
    if (decoded['status'] != 'success' || list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first as Map);
  }

  /// POST LINE_MACHINE_SCAN. Returns {success, message}.
  static Future<Map<String, dynamic>> submitLineMachine({
    required String lineQr,
    required String machineOid,
    required String appUserId,
    required String company,
  }) async {
    try {
      final uri = Uri.parse(_base).replace(queryParameters: {
        'd_type': 'LINE_MACHINE_SCAN',
        'line_qr': lineQr,
        'machine_id': machineOid,
        'user_hris': appUserId,
        'company_id': company,
      });
      final resp = await http.post(uri).timeout(const Duration(seconds: 30));

      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {}

      final httpOk = resp.statusCode == 200 || resp.statusCode == 201;
      return {
        'success': httpOk && decoded?['status'] == 'success',
        'message': decoded?['message']?.toString() ??
            (httpOk
                ? 'Invalid server response'
                : 'Server error ${resp.statusCode}'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  /// MACHINE_STATUS -> [{D: display, R: value}]
  static Future<List<Map<String, String>>> fetchMachineStatuses() async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'p_type': 'MACHINE_STATUS',
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('Server error ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded['status'] != 'success') {
      throw Exception(decoded['message'] ?? 'Failed to load status');
    }
    return ((decoded['result'] as List?) ?? [])
        .map((e) => {'D': '${e['D']}', 'R': '${e['R']}'})
        .toList();
  }

  /// TO_LOCATION -> [{D: CID_NAME, R: CID_ID}]
  static Future<List<Map<String, String>>> fetchToLocations(
      String company) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'p_type': 'TO_LOCATION',
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) return [];
    final decoded = jsonDecode(resp.body);
    if (decoded['status'] != 'success') return [];
    return ((decoded['result'] as List?) ?? [])
        .map((e) => {'D': '${e['CID_NAME']}', 'R': '${e['CID_ID']}'})
        .toList();
  }

  /// TO_LINE by location (company id) -> [{D: LINE_NAME, R: LINE_ID}]
  static Future<List<Map<String, String>>> fetchLinesByLocation(
      String locationId) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'p_type': 'TO_LINE',
      'to_location': locationId,
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) return [];
    final decoded = jsonDecode(resp.body);
    if (decoded['status'] != 'success') return [];
    return ((decoded['result'] as List?) ?? [])
        .map((e) => {'D': '${e['LINE_NAME']}', 'R': '${e['LINE_ID']}'})
        .toList();
  }

   /// POST MACHINE_TRANSFER. [machines] = [{machine_id, machine_name}]
  static Future<Map<String, dynamic>> submitMachineTransfer({
    required String status,
    String? toLocation,
    String? toLine,
    required List<Map<String, String>> machines,
    required String appUserId,
  }) async {
    try {
      final uri = Uri.parse(_base).replace(queryParameters: {
        'd_type': 'MACHINE_TRANSFER',
        'user_hris': appUserId,
        'status_type': status,
        if (toLocation != null && toLocation.isNotEmpty)
          'location': toLocation,
        if (toLine != null && toLine.isNotEmpty) 'line': toLine,
      });
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'scan_machine_list': jsonEncode(machines)}),
          )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {}

      final httpOk = resp.statusCode == 200 || resp.statusCode == 201;
      return {
        'success': httpOk && decoded?['status'] == 'success',
        'message': decoded?['message']?.toString() ??
            (httpOk
                ? 'Invalid server response'
                : 'Server error ${resp.statusCode}'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }
    /// APPROVAL_DATA -> pending requests
  static Future<List<Map<String, dynamic>>> fetchApprovalData() async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'p_type': 'APPROVAL_DATA',
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('Server error ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded['status'] != 'success') {
      throw Exception(decoded['message'] ?? 'Failed to load approvals');
    }
    return ((decoded['result'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// TODO: real POST. action = 'APPROVE' | 'REJECT'
  static Future<Map<String, dynamic>> submitApproval({
    required String reqNo,
    required String action,
    required String appUserId,
  }) async {
    return {'success': false, 'message': 'Approval API not connected yet'};
  }
    /// TRANSFER_HISTORY -> one row per machine per request
  static Future<List<Map<String, dynamic>>> fetchTransferHistory() async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'p_type': 'TRANSFER_HISTORY',
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('Server error ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded['status'] != 'success') {
      throw Exception(decoded['message'] ?? 'Failed to load history');
    }
    return ((decoded['result'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
  /// PDF_INFO by request no. Returns the first result row (with DETAILS) or null.
  static Future<Map<String, dynamic>?> fetchPdfInfo(String reqNo) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'p_type': 'PDF_INFO',
      'req_no': reqNo,
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) return null;
    final decoded = jsonDecode(resp.body);
    final list = (decoded['result'] as List?) ?? [];
    if (decoded['status'] != 'success' || list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first as Map);
  }
}