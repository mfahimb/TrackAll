import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

class LineBalanceService {
  static const String _baseUrl =
      'https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/line_balancing';

  Future<String?> saveLineBalance({
    required String lineId,
    required String staffId,
    required String processId,
    required DateTime date,
    required double elapsedSeconds,
    required String appUserId,
    required String companyId,
    int? benchmarkTime,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'p_company_id': companyId,
      'p_staff_qr':   staffId,
      'p_time':       elapsedSeconds.toInt().toString(),
      'p_process_id': processId,
      'p_line_id':    lineId,
      'p_app_user':   appUserId,
      if (benchmarkTime != null) 'p_bench_mark': benchmarkTime.toString(),
    });

    debugPrint('[saveLineBalance] POST $uri');

    try {
      final request = http.Request('POST', uri);
      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();

      debugPrint('[saveLineBalance] status=${streamed.statusCode} body=$body');

      if (streamed.statusCode != 200) {
        return 'Server error: ${streamed.statusCode}';
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final status  = json['status']  as String?;
      final message = json['message'] as String?;

      if (status == 'success') return null;
      return message ?? 'Unknown error';
    } catch (e) {
      debugPrint('[saveLineBalance] EXCEPTION: $e');
      return 'Network error: $e';
    }
  }

  Future<List<Map<String, dynamic>>> fetchTimeStudyReport({
    required String companyId,
  }) async {
    final uri = Uri.parse(
            'https://ego.rflgroupbd.com:8077/ords/rpro/xxtrac_al/get_lov')
        .replace(queryParameters: {
      'P_QRYTYP': 'TIMESTUDY_REPORT',
      'LOGIN_COMPANY': companyId,
    });

    debugPrint('[fetchTimeStudyReport] GET $uri');

    try {
      final request = http.Request('GET', uri);
      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();

      debugPrint('[fetchTimeStudyReport] status=${streamed.statusCode}');

      if (streamed.statusCode != 200) return [];

      final json = jsonDecode(body) as Map<String, dynamic>;
      final List list = json['TIMESTUDY_REPORT'] ?? [];
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[fetchTimeStudyReport] EXCEPTION: $e');
      return [];
    }
  }
}