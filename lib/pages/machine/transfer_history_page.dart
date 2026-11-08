import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/top_menu_bar.dart';
import 'package:trackall_app/services/machine/machine_service.dart';

const _bg = Color(0xFFF0F4FA);
const _blue = Color(0xFF1A73E8);
const _green = Color(0xFF0F9D58);
const _red = Color(0xFFEF4444);
const _amber = Color(0xFFF59E0B);
const _border = Color(0xFFE2E8F0);
const _textPri = Color(0xFF0F172A);
const _textSec = Color(0xFF64748B);

class TransferHistoryPage extends StatefulWidget {
  const TransferHistoryPage({super.key});
  @override
  State<TransferHistoryPage> createState() => _TransferHistoryPageState();
}

class _TransferHistoryPageState extends State<TransferHistoryPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _status = 'ALL';
  String _user = '';

  @override
  void initState() {
    super.initState();
    _load();
    SharedPreferences.getInstance().then((p) {
      _user = p.getString('userId') ?? '';
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _rows = await MachineService.fetchTransferHistory();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _rows = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  String _date(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      return DateFormat('dd/MM/yyyy hh:mm a')
          .format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  Future<void> _download(Map<String, dynamic> row) async {
    final req = '${row['REQ_NO']}';
    try {
      final info = await MachineService.fetchPdfInfo(req);
      if (info == null) throw Exception('No data');

      final details = (info['DETAILS'] as List?) ?? [];
      String reqDate = '-';
      try {
        reqDate = DateFormat('dd-MMM-yyyy hh:mm a')
            .format(DateTime.parse('${row['CREATED_DATE']}').toLocal())
            .toUpperCase();
      } catch (_) {}
      final generated = DateFormat('dd-MMM-yyyy hh:mm a')
          .format(DateTime.now())
          .toUpperCase();

      const blue = PdfColor.fromInt(0xFF0B57B7);
      const red = PdfColor.fromInt(0xFFE53935);
      pw.Widget kv(String k, String v, {PdfColor? c}) => pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(
                  text: '$k: ',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.TextSpan(
                  text: v,
                  style: pw.TextStyle(
                      fontSize: 10,
                      color: c,
                      fontWeight: c != null
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal)),
            ]),
          );

      final doc = pw.Document();
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Text('MACHINE TRANSACTION STATEMENT',
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: blue)),
          pw.SizedBox(height: 2),
          pw.Text('REQ NO: $req',
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey700)),
          pw.Divider(color: blue, thickness: 1.5),
          pw.SizedBox(height: 6),
          pw.Container(
            color: const PdfColor.fromInt(0xFFF8FAFC),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(children: [
              pw.Row(children: [
                pw.Expanded(
                    child: kv('Initiated By', '${info['USER_NAME'] ?? '-'}')),
                pw.Expanded(child: kv('Request Date', reqDate)),
              ]),
              pw.SizedBox(height: 8),
              pw.Row(children: [
                pw.Expanded(
                    child: kv('Action Type', '${info['ACTION_TYPE'] ?? '-'}',
                        c: red)),
                pw.Expanded(child: kv('Status', '${info['STATUS'] ?? '-'}')),
              ]),
              pw.SizedBox(height: 8),
              pw.Row(children: [
                pw.Expanded(
                    child: kv('Target Line', '${info['LINE_NAME'] ?? '-'}')),
                pw.Expanded(
                    child: kv('Target Location',
                        '${info['LOCATION_NAME'] ?? '-'}')),
              ]),
            ]),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['SL#', 'Machine Name', 'Action', 'Status'],
            data: details
                .map((e) => [
                      '${e['SL'] ?? ''}',
                      '${e['MACHINE_NAME'] ?? '-'}',
                      '${e['ACTION_TYPE'] ?? '-'}',
                      '${e['STATUS'] ?? '-'}',
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: blue),
            cellStyle: const pw.TextStyle(fontSize: 9),
            oddRowDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FixedColumnWidth(36),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            cellAlignments: {0: pw.Alignment.center},
          ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Generated on: $generated by $_user',
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey600)),
          ),
        ],
      ));

      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save statement',
        fileName: 'Statement_$req.pdf',
        bytes: await doc.save(),
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF saved'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("PDF error: $e"),
          backgroundColor: _red,
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _openDetail(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        row: r,
        date: _date(r['CREATED_DATE']?.toString()),
        user: _user,
        onDownload: () => _download(r),
      ),
    );
  }

  Color _color(String s) {
    switch (s.toUpperCase()) {
      case 'APPROVED':
        return _green;
      case 'REJECTED':
        return _red;
      default:
        return _amber;
    }
  }

  List<String> get _statuses {
    final s = _rows
        .map((r) => '${r['STATUS'] ?? ''}'.toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['ALL', ...s];
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.trim().toLowerCase();
    return _rows.where((r) {
      if (_status != 'ALL' &&
          '${r['STATUS'] ?? ''}'.toUpperCase() != _status) {
        return false;
      }
      if (q.isEmpty) return true;
      return [r['REQ_NO'], r['CREATED_BY'], r['ACTION_TYPE']]
          .any((v) => (v ?? '').toString().toLowerCase().contains(q));
    }).toList();
  }

  Widget _chip(String s) {
    final sel = _status == s;
    return GestureDetector(
      onTap: () => setState(() => _status = s),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? _blue : _border),
        ),
        child: Text(s == 'ALL' ? 'All' : s[0] + s.substring(1).toLowerCase(),
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : _textSec)),
      ),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final status = '${r['STATUS'] ?? ''}';
    final c = _color(status);
    final approved = (r['APPROVED_DISPLAY_COL'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openDetail(r),
              child: Text('${r['REQ_NO'] ?? '-'}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                      decoration: TextDecoration.underline,
                      decorationColor: _blue)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Text(status,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: c)),
          ),
        ]),
        const SizedBox(height: 8),
        _line(Icons.swap_horiz_rounded, 'Action', '${r['ACTION_TYPE'] ?? '-'}'),
        _line(Icons.person_rounded, 'Requested by', '${r['CREATED_BY'] ?? '-'}'),
        _line(Icons.access_time_rounded, 'Requested',
            _date(r['CREATED_DATE']?.toString())),
        if (approved.isNotEmpty)
          _line(Icons.verified_rounded, 'Approved', approved),
      ]),
    );
  }

  Widget _line(IconData i, String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(children: [
          Icon(i, size: 13, color: _blue),
          const SizedBox(width: 8),
          SizedBox(
              width: 82,
              child: Text(k,
                  style: const TextStyle(fontSize: 11.5, color: _textSec))),
          Expanded(
            child: Text(v,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textPri)),
          ),
        ]),
      );

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: _red, size: 36),
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: _textSec)),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }
    final rows = _filtered;
    if (rows.isEmpty) {
      return const Center(
        child: Text('No transfer history',
            style: TextStyle(color: _textSec, fontSize: 14)),
      );
    }
    return RefreshIndicator(
      color: _blue,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
        itemCount: rows.length,
        itemBuilder: (_, i) => _card(rows[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        const TopMenuBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            const Text('Transfer History',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _textPri)),
            const SizedBox(width: 8),
            if (!_loading && _error == null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: _blue, borderRadius: BorderRadius.circular(20)),
                child: Text('${_filtered.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _blue),
              onPressed: _loading ? null : _load,
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: SizedBox(
            height: 40,
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search request no, user...',
                hintStyle: const TextStyle(color: _textSec, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: _textSec),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _blue)),
              ),
            ),
          ),
        ),
        if (!_loading && _error == null)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 0, 6, 6),
              children: _statuses.map(_chip).toList(),
            ),
          ),
        Expanded(child: _body()),
      ]),
    );
  }
}
class _DetailSheet extends StatefulWidget {
  final Map<String, dynamic> row;
  final String date, user;
  final Future<void> Function() onDownload;
  const _DetailSheet(
      {required this.row,
      required this.date,
      required this.user,
      required this.onDownload});

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  Map<String, dynamic>? _info;
  bool _loading = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic>? info;
    try {
      info = await MachineService.fetchPdfInfo('${widget.row['REQ_NO']}');
    } catch (_) {}
    if (mounted) {
      setState(() {
        _info = info;
        _loading = false;
      });
    }
  }

  String get _generated =>
      DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now()).toUpperCase();

  Widget _kv(String k, Widget v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 100,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _textSec))),
          Expanded(child: v),
        ]),
      );

  Widget _txt(String s, {Color? c}) => Text(s,
      style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: c ?? _textPri));

  Widget _cell(String s, {bool head = false, bool center = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(s,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: TextStyle(
                fontSize: 11,
                fontWeight: head ? FontWeight.w800 : FontWeight.w500,
                color: head ? Colors.white : _textPri)),
      );

  Widget _table(List details) {
    if (details.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('No machines found',
              style: TextStyle(color: _textSec, fontSize: 12)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(border: Border.all(color: _border)),
      child: Column(children: [
        Container(
          color: const Color(0xFF0B57B7),
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            SizedBox(width: 36, child: _cell('SL#', head: true, center: true)),
            Expanded(flex: 4, child: _cell('Machine Name', head: true)),
            Expanded(flex: 2, child: _cell('Action', head: true)),
            Expanded(flex: 2, child: _cell('Status', head: true)),
          ]),
        ),
        ...details.asMap().entries.map((e) => Container(
              color: e.key.isOdd ? const Color(0xFFF1F5F9) : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                SizedBox(
                    width: 36,
                    child: _cell('${e.value['SL'] ?? e.key + 1}',
                        center: true)),
                Expanded(
                    flex: 4, child: _cell('${e.value['MACHINE_NAME'] ?? '-'}')),
                Expanded(
                    flex: 2, child: _cell('${e.value['ACTION_TYPE'] ?? '-'}')),
                Expanded(
                    flex: 2, child: _cell('${e.value['STATUS'] ?? '-'}')),
              ]),
            )),
      ]),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: _blue)),
      );
    }
    final info = _info;
    if (info == null) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Text("Couldn't load details",
              style: TextStyle(color: _textSec, fontSize: 13)),
        ),
      );
    }
    final status = '${info['STATUS'] ?? widget.row['STATUS'] ?? ''}';
    final sColor = status.toUpperCase() == 'APPROVED'
        ? _green
        : status.toUpperCase() == 'REJECTED'
            ? _red
            : _amber;
    final details = (info['DETAILS'] as List?) ?? [];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          _kv('Initiated By', _txt('${info['USER_NAME'] ?? '-'}')),
          _kv('Request Date', _txt(widget.date)),
          _kv('Action Type', _txt('${info['ACTION_TYPE'] ?? '-'}', c: _red)),
          _kv(
              'Status',
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                      color: sColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: sColor)),
                ),
              )),
          _kv('Target Line', _txt('${info['LINE_NAME'] ?? '-'}')),
          _kv('Target Location', _txt('${info['LOCATION_NAME'] ?? '-'}')),
        ]),
      ),
      const SizedBox(height: 12),
      _table(details),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: Text('Generated on: $_generated by ${widget.user}',
            style: const TextStyle(fontSize: 10, color: _textSec)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final approved =
        '${widget.row['STATUS']}'.toUpperCase() == 'APPROVED';

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: _border, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MACHINE TRANSACTION STATEMENT',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0B57B7))),
                    const SizedBox(height: 2),
                    Text('REQ NO: ${widget.row['REQ_NO'] ?? '-'}',
                        style:
                            const TextStyle(fontSize: 11, color: _textSec)),
                  ]),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: _textSec),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Container(height: 1.5, color: const Color(0xFF0B57B7)),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _body(),
          ),
        ),
        if (approved && _info != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _downloading
                    ? null
                    : () async {
                        setState(() => _downloading = true);
                        await widget.onDownload();
                        if (mounted) setState(() => _downloading = false);
                      },
                icon: _downloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text('Download PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD9534F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
