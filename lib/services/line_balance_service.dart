import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

// ── Models ─────────────────────────────────────────────────────────────

/// One row from the QC_BII LOV.
/// Real API keys (confirmed from live response):
///   BII_ID          -> internal id, used for downstream QC_JOB / QC_PROCESS calls
///   STYLE_NO        -> Article name (shown as the main label in the dropdown)
///   BPO_PO_NO       -> Order No. (human-readable PO number)
///   BII_ITEM_DESC   -> Item No. / item description (e.g. color variant)
///   ORDER_ID        -> internal numeric order id (kept in case a downstream
///                      call ever needs it instead of the human PO number)
class ArticleItem {
  final String id;          // BII_ID
  final String label;       // STYLE_NO (Article name)
  final String orderNo;     // BPO_PO_NO
  final String orderId;     // ORDER_ID (internal id, may be needed later)
  final String itemNo;      // BII_ITEM_DESC
  final String buyerName;   // kept for UI compatibility; empty if not returned

  const ArticleItem({
    required this.id,
    required this.label,
    required this.orderNo,
    required this.orderId,
    required this.itemNo,
    this.buyerName = '',
  });

  factory ArticleItem.fromJson(Map<String, dynamic> j) => ArticleItem(
        id:        j['BII_ID']?.toString()        ?? '',
        label:     j['STYLE_NO']?.toString()       ?? '',
        orderNo:   j['BPO_PO_NO']?.toString()      ?? '',
        orderId:   j['ORDER_ID']?.toString()       ?? '',
        itemNo:    j['BII_ITEM_DESC']?.toString()  ?? '',
        buyerName: j['BUYER_NAME']?.toString()     ?? '',
      );
}

/// Kept for backward compatibility with pages that still reference OrderItem,
/// e.g. if you want to show just the order in its own picker.
/// With QC_BII, order info now comes bundled inside ArticleItem directly,
/// so this is just a thin wrapper — no separate network call needed.
class OrderItem {
  final String id;
  final String label;

  const OrderItem({required this.id, required this.label});

  factory OrderItem.fromArticle(ArticleItem a) => OrderItem(
        id: a.orderId.isNotEmpty ? a.orderId : a.orderNo,
        label: a.orderNo,
      );
}

// ── Service ────────────────────────────────────────────────────────────

class LineBalanceService {
  static const String _baseUrl =
      'https://trackall.rflgroupbd.com/ords/rpro/xxtrac_al/line_balancing';
  static const String _lovUrl =
      'https://trackall.rflgroupbd.com/ords/rpro/xxtrac_al/get_lov';

  // ── Save line balance entry ──────────────────────────────────────────
  // Real API params (confirmed from live sample):
  //   p_company_id, p_time, p_process_id, p_line_id, p_app_user,
  //   p_staff_name, p_staff_mobile, p_order_no, p_article, p_bii_id, p_dept

  Future<String?> saveLineBalance({
    required String lineId,
    required String processId,
    required double elapsedSeconds,
    required String appUserId,
    required String companyId,
    required String mobileNo,
    String? staffId,
    String? staffName,
    String? orderNo,
    String? article,
    String? biiId,
    String? dept,
    int? benchmarkTime,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'p_company_id':   companyId,
      'p_time':         elapsedSeconds.toInt().toString(),
      'p_process_id':   processId,
      'p_line_id':      lineId,
      'p_app_user':     appUserId,
      'p_staff_mobile': mobileNo,
      if (staffId   != null && staffId.isNotEmpty)   'p_staff_qr':   staffId,
      if (staffName != null && staffName.isNotEmpty) 'p_staff_name': staffName,
      if (orderNo != null && orderNo.isNotEmpty) 'p_order_no': orderNo,
      if (article != null && article.isNotEmpty) 'p_article':  article,
      if (biiId   != null && biiId.isNotEmpty)   'p_bii_id':   biiId,
      if (dept    != null && dept.isNotEmpty)    'p_dept':     dept,
      if (benchmarkTime != null) 'p_bench_mark': benchmarkTime.toString(),
    });

    debugPrint('[saveLineBalance] POST $uri');

    try {
      final request  = http.Request('POST', uri);
      final streamed = await request.send();
      final body     = await streamed.stream.bytesToString();

      debugPrint('[saveLineBalance] status=${streamed.statusCode} body=$body');

      if (streamed.statusCode != 200) {
        return 'Server error: ${streamed.statusCode}';
      }

      final json    = jsonDecode(body) as Map<String, dynamic>;
      final status  = json['status']  as String?;
      final message = json['message'] as String?;

      if (status == 'success') return null;
      return message ?? 'Unknown error';
    } catch (e) {
      debugPrint('[saveLineBalance] EXCEPTION: $e');
      return 'Network error: $e';
    }
  }

  // ── Time study report ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchTimeStudyReport({
    required String companyId,
  }) async {
    final uri = Uri.parse(_lovUrl).replace(queryParameters: {
      'P_QRYTYP':      'TIMESTUDY_REPORT',
      'LOGIN_COMPANY': companyId,
    });

    debugPrint('[fetchTimeStudyReport] GET $uri');

    try {
      final request  = http.Request('GET', uri);
      final streamed = await request.send();
      final body     = await streamed.stream.bytesToString();

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

  // ── Article LOV (now backed by QC_BII — Article + Order + Item No. in one row) ──

  Future<List<ArticleItem>> fetchArticleLov({
    required String companyId,
  }) async {
    final uri = Uri.parse(_lovUrl).replace(queryParameters: {
      'P_QRYTYP':      'QC_BII',
      'LOGIN_COMPANY': companyId,
    });

    debugPrint('[fetchArticleLov] GET $uri');

    try {
      final response = await http.get(uri);
      debugPrint('[fetchArticleLov] status=${response.statusCode}');

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final List raw = json['QC_BII'] ?? [];

      if (raw.isNotEmpty) {
        debugPrint('[fetchArticleLov] first raw item: ${raw.first}');
      }

      return raw.cast<Map<String, dynamic>>().map(ArticleItem.fromJson).toList();
    } catch (e) {
      debugPrint('[fetchArticleLov] EXCEPTION: $e');
      return [];
    }
  }

  // ── Order LOV — no longer a separate API call. ──────────────────────
  // Order No. and Item No. already arrive bundled inside each ArticleItem
  // from fetchArticleLov (QC_BII). This method is kept only so existing
  // call sites don't break; it just wraps the already-selected article's
  // own order info instead of hitting the network again.
  Future<List<OrderItem>> fetchOrdersByArticle({
    required String companyId,
    required String articleId,
    ArticleItem? selectedArticle,
  }) async {
    if (selectedArticle == null) return [];
    return [OrderItem.fromArticle(selectedArticle)];
  }

  // ── Process LOV (now backed by TIME_STUDY_PROCESS) ───────────────────
  // Real API keys (confirmed from live response):
  //   SM_ID        -> internal process id
  //   SM_DEPT      -> department id
  //   SM_PRO_NAME  -> process name (shown as the label in the dropdown)

  Future<List<Map<String, String>>> fetchProcessLov({
    required String companyId,
  }) async {
    final uri = Uri.parse(_lovUrl).replace(queryParameters: {
      'P_QRYTYP':      'TIME_STUDY_PROCESS',
      'LOGIN_COMPANY': companyId,
    });

    debugPrint('[fetchProcessLov] GET $uri');

    try {
      final request  = http.Request('GET', uri);
      final streamed = await request.send();
      final body     = await streamed.stream.bytesToString();

      debugPrint('[fetchProcessLov] status=${streamed.statusCode}');

      if (streamed.statusCode != 200) {
        debugPrint('[fetchProcessLov] error: ${streamed.reasonPhrase}');
        return [];
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final List raw = json['TIME_STUDY_PROCESS'] ?? [];

      if (raw.isNotEmpty) {
        debugPrint('[fetchProcessLov] first raw item: ${raw.first}');
      }

      return raw.cast<Map<String, dynamic>>().map((j) {
        return {
          'id':    j['SM_ID']?.toString()       ?? '',
          'label': j['SM_PRO_NAME']?.toString()  ?? '',
          'dept':  j['SM_DEPT']?.toString()      ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('[fetchProcessLov] EXCEPTION: $e');
      return [];
    }
  }
}