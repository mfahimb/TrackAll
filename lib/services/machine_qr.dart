import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MachineQrService {
  static const _baseUrl =
      'https://trackall.rflgroupbd.com/ords/rpro/xxtrac_al/get_lov';

  static Map<String, String>? _cache;        // rawQr → machine name
  static Map<String, String>? _idToFullR;    // rawQr → full AMIM string

  Future<void> preload() async {
    if (_cache != null) return;
    try {
      final prefs   = await SharedPreferences.getInstance();
      final company = prefs.getString('selected_company_id') ?? '0';
      final userId  = prefs.getString('userId') ?? '0';

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'P_QRYTYP':      'MACHINE_QR',
        'LOGIN_COMPANY': company,
        'P_APP_USER':    userId,
      });

      final response = await http.get(uri);
      if (response.statusCode != 200) { _cache ??= {}; _idToFullR ??= {}; return; }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (json['MACHINE_QR'] ?? json['machine_qr']) as List<dynamic>?;
      if (list == null) { _cache = {}; _idToFullR = {}; return; }

      _cache     = {};
      _idToFullR = {};

      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final r = m['R']?.toString().trim(); // full AMIM string
        final d = m['D']?.toString().trim(); // machine name
        if (r == null || r.isEmpty || d == null || d.isEmpty) continue;

        // Index by full AMIM string
        _cache![r]     = d;
        _idToFullR![r] = r;

        // ALSO index by every digit sequence (QR physically encodes only the number)
        final digits = RegExp(r'\d+').allMatches(r);
        for (final match in digits) {
          final num = match.group(0)!;
          if (num.length >= 6) {
            _cache![num]     = d;
            _idToFullR![num] = r; // numeric → full AMIM string
          }
        }
      }

      debugPrint('✅ MACHINE_QR cache: ${_cache?.length} entries');
    } catch (e, st) {
      debugPrint('❌ MACHINE_QR EXCEPTION: $e\n$st');
      _cache     ??= {};
      _idToFullR ??= {};
    }
  }

  /// Returns machine display name for the scanned QR value.
  String? lookup(String rawQr) => _cache?[rawQr.trim()];

  /// Returns the full AMIM string (what the backend expects) for the scanned QR value.
  String fullAmimId(String rawQr) => _idToFullR?[rawQr.trim()] ?? rawQr.trim();

  static void invalidate() { _cache = null; _idToFullR = null; }
}