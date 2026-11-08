import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

class MachineApprovalPage extends StatefulWidget {
  const MachineApprovalPage({super.key});
  @override
  State<MachineApprovalPage> createState() => _MachineApprovalPageState();
}

class _MachineApprovalPageState extends State<MachineApprovalPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error, _user, _busyReq;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      _user = prefs.getString('userId');
      _rows = await MachineService.fetchApprovalData();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _rows = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows
        .where((r) => [r['REQ_NO'], r['TITLE'], r['CREATED_BY']]
            .any((v) => (v ?? '').toString().toLowerCase().contains(q)))
        .toList();
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

  String _action(String title) {
    final m = RegExp(r'Action:\s*([^|]+)').firstMatch(title);
    return m?.group(1)?.trim() ?? '';
  }

  Future<void> _act(Map<String, dynamic> r, bool approve) async {
    final req = '${r['REQ_NO']}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(approve ? 'Approve request?' : 'Reject request?',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(req, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Approve' : 'Reject',
                style: TextStyle(color: approve ? _green : _red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_user == null || _user!.isEmpty) {
      _snack('User not identified', _red);
      return;
    }
    setState(() => _busyReq = req);
    final res = await MachineService.submitApproval(
      reqNo: req,
      action: approve ? 'APPROVE' : 'REJECT',
      appUserId: _user!,
    );
    if (!mounted) return;
    setState(() => _busyReq = null);
    final success = res['success'] == true;
    _snack(res['message']?.toString() ?? (success ? 'Done' : 'Failed'),
        success ? _green : _red);
    if (success) _load();
  }

  void _openDetail(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        row: r,
        action: _action('${r['TITLE'] ?? ''}'),
        date: _date(r['CREATED_DATE']?.toString()),
        user: _user ?? '',
      ),
    );
  }

  void _snack(String m, Color c) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: c,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _card(Map<String, dynamic> r) {
    final req = '${r['REQ_NO'] ?? '-'}';
    final status = '${r['STATUS'] ?? ''}';
    final pending = status.toUpperCase() == 'PENDING';
    final sColor = pending ? _amber : _green;
    final action = _action('${r['TITLE'] ?? ''}');
    final busy = _busyReq == req;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openDetail(r),
              child: Text(req,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                      decoration: TextDecoration.underline,
                      decorationColor: _blue)),
            ),
          ),
          if (action.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(action,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _blue)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: sColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(status,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: sColor)),
          ),
        ]),
        const SizedBox(height: 8),
        Text('${r['TITLE'] ?? ''}',
            style: const TextStyle(
                fontSize: 12, color: _textPri, height: 1.4)),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.person_rounded, size: 13, color: _textSec),
          const SizedBox(width: 4),
          Text('${r['CREATED_BY'] ?? '-'}',
              style: const TextStyle(fontSize: 11, color: _textSec)),
          const SizedBox(width: 12),
          const Icon(Icons.access_time_rounded, size: 13, color: _textSec),
          const SizedBox(width: 4),
          Expanded(
            child: Text(_date(r['CREATED_DATE']?.toString()),
                style: const TextStyle(fontSize: 11, color: _textSec)),
          ),
        ]),
        if ((r['DESCRIPTION'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${r['DESCRIPTION']}',
              style: const TextStyle(fontSize: 11, color: _textSec)),
        ],
        if (pending) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: OutlinedButton(
                  onPressed: busy ? null : () => _act(r, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    side: const BorderSide(color: _red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Reject'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: busy ? null : () => _act(r, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Approve'),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

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
        child: Text('No approval requests',
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
            const Text('Machine Approval',
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
                child: Text('${_rows.length}',
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
        Expanded(child: _body()),
      ]),
    );
  }
}
class _DetailSheet extends StatefulWidget {
  final Map<String, dynamic> row;
  final String action, date, user;
  const _DetailSheet(
      {required this.row,
      required this.action,
      required this.date,
      required this.user});

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  Map<String, dynamic>? _info;
  List<Map<String, String>>? _machines;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic>? info;
    List<Map<String, String>>? m;
    try {
      info = await MachineService.fetchPdfInfo('${widget.row['REQ_NO']}');
      final details = (info?['DETAILS'] as List?) ?? [];
      m = details
          .map((e) => {
                'name': '${e['MACHINE_NAME'] ?? '-'}',
                'action': '${e['ACTION_TYPE'] ?? '-'}',
                'status': '${e['STATUS'] ?? '-'}',
              })
          .toList();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _info = info;
        _machines = m;
        _loading = false;
      });
    }
  }

  String _part(String key) {
    final m = RegExp('$key:\\s*([^,\\]]+)')
        .firstMatch('${widget.row['TITLE'] ?? ''}');
    return m?.group(1)?.trim() ?? '-';
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

  Widget _table() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: _blue)),
      );
    }
    if (_machines == null || _machines!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
              _machines == null
                  ? "Couldn't load machines"
                  : 'No machines found',
              style: const TextStyle(color: _textSec, fontSize: 12)),
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
        ..._machines!.asMap().entries.map((e) => Container(
              color: e.key.isOdd ? const Color(0xFFF1F5F9) : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                SizedBox(
                    width: 36, child: _cell('${e.key + 1}', center: true)),
                Expanded(flex: 4, child: _cell(e.value['name'] ?? '-')),
                Expanded(flex: 2, child: _cell(e.value['action'] ?? '-')),
                Expanded(flex: 2, child: _cell(e.value['status'] ?? '-')),
              ]),
            )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final status = '${r['STATUS'] ?? ''}';
    final sColor = status.toUpperCase() == 'PENDING' ? _amber : _green;

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
                    Text('REQ NO: ${r['REQ_NO'] ?? '-'}',
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  _kv(
                      'Initiated By',
                      _txt(_info?['USER_NAME']?.toString() ??
                          '${r['CREATED_BY'] ?? '-'}')),
                  _kv('Request Date', _txt(widget.date)),
                  _kv('Action Type',
                      _txt(
                          _info?['ACTION_TYPE']?.toString() ??
                              (widget.action.isEmpty ? '-' : widget.action),
                          c: _red)),
                  _kv(
                      'Status',
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
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
                  _kv('Target Line',
                      _txt(_info?['LINE_NAME']?.toString() ?? _part('Line'))),
                  _kv(
                      'Target Location',
                      _txt(_info?['LOCATION_NAME']?.toString() ??
                          _part('Location'))),
                ]),
              ),
              const SizedBox(height: 12),
              _table(),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text('Generated on: $_generated by ${widget.user}',
                    style: const TextStyle(fontSize: 10, color: _textSec)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}