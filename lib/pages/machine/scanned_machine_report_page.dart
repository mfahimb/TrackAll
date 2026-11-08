import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackall_app/services/machine/machine_service.dart';

const _navy     = Color(0xFF060D1F); // app bar only
const _bg       = Color(0xFFF1F5F9);
const _card     = Colors.white;
const _accent   = Color(0xFF3B82F6);
const _border   = Color(0xFFCBD5E1);
const _textPri  = Color(0xFF0F172A);
const _textSec  = Color(0xFF64748B);
const _headBg   = Color(0xFFB3D4F5);
const _headText = Color(0xFF1E3A8A);
const _rowAlt   = Color(0xFFE8ECF1);
const _danger   = Color(0xFFEF4444);

class ScannedMachineReportPage extends StatefulWidget {
  const ScannedMachineReportPage({super.key});

  @override
  State<ScannedMachineReportPage> createState() =>
      _ScannedMachineReportPageState();
}

class _ScannedMachineReportPageState extends State<ScannedMachineReportPage> {
  // column flex: Line, Unit, Machine, Scanned By, Scan Date
  static const _flex = [20, 26, 28, 22, 30];

  DateTime _date = DateTime.now();
  String _company = '55';
  String _search = '';
  String? _unit;
  String? _line;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _company = prefs.getString('selected_company_id') ?? '55';
    await _load();
  }

  String _fmtUi(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _rows = await MachineService.getScannedMachineReport(
        company: _company,
        scanDate: _date,
      );
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _rows = [];
    }
    if (_unit != null && !_units.contains(_unit)) _unit = null;
    if (_line != null && !_lines.contains(_line)) _line = null;
    if (mounted) setState(() => _loading = false);
  }

  void _clear() {
    _searchCtrl.clear();
    setState(() {
      _date = DateTime.now();
      _unit = null;
      _line = null;
      _search = '';
    });
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  List<String> get _units => (_rows
          .map((r) => (r['UNIT_NAME'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList())
      ..sort();

  // lines only for the selected unit
  List<String> get _lines {
    if (_unit == null) return [];
    return (_rows
            .where((r) => r['UNIT_NAME'] == _unit)
            .map((r) => (r['LINE_NAME'] ?? '').toString())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList())
        ..sort();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.trim().toLowerCase();
    return _rows.where((r) {
      if (_unit != null && r['UNIT_NAME'] != _unit) return false;
      if (_line != null && r['LINE_NAME'] != _line) return false;
      if (q.isEmpty) return true;
      return [
        r['LWM_MACHINE_NAME'],
        r['LINE_NAME'],
        r['UNIT_NAME'],
        r['LWM_ISSUE_BY'],
      ].any((v) => (v ?? '').toString().toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Scanned Machine Report',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(children: [
            Expanded(
              child: _dropdown('Unit', 'All Units', _unit, _units, (v) {
                setState(() {
                  _unit = v;
                  _line = null;
                });
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _dropdown(
                'Line Name',
                _unit == null ? 'Select unit first' : 'All Lines',
                _line,
                _lines,
                _unit == null ? null : (v) => setState(() => _line = v),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(children: [
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 14, color: _accent),
                  const SizedBox(width: 6),
                  Text(_fmtUi(_date),
                      style: const TextStyle(
                          color: _textPri,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: const Text('Search'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 42,
                child: OutlinedButton(
                  onPressed: _clear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textSec,
                    backgroundColor: _card,
                    side: const BorderSide(color: _border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Clear'),
                ),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: _textPri, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search machine, line, unit, scanned by…',
                hintStyle: const TextStyle(color: _textSec, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: _textSec),
                filled: true,
                fillColor: _card,
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _accent)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${rows.length} machines scanned',
                style: const TextStyle(color: _textSec, fontSize: 12)),
          ),
        ),
        Expanded(child: _body(rows)),
      ]),
    );
  }

  Widget _dropdown(String label, String allText, String? value,
      List<String> items, ValueChanged<String?>? onChanged) {
    final disabled = onChanged == null;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFE2E8F0) : _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          dropdownColor: _card,
          iconEnabledColor: _textSec,
          style: const TextStyle(color: _textPri, fontSize: 13),
          hint: Text(allText,
              style: const TextStyle(color: _textSec, fontSize: 13)),
          items: [
            DropdownMenuItem<String?>(
                value: null,
                child: Text(allText,
                    style: const TextStyle(color: _textSec, fontSize: 13))),
            ...items.map((e) => DropdownMenuItem<String?>(
                value: e, child: Text(e, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _body(List<Map<String, dynamic>> rows) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: _danger, size: 36),
          const SizedBox(height: 8),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSec, fontSize: 13)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }
    if (rows.isEmpty) {
      return const Center(
        child: Text('No scanned machines found',
            style: TextStyle(color: _textSec, fontSize: 14)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: _card,
            border: Border.all(color: _border),
          ),
          child: Column(children: [
            _row(['Line', 'Unit', 'Machine', 'Scanned By', 'Scan Date'],
                header: true),
            Expanded(
              child: RefreshIndicator(
                color: _accent,
                onRefresh: _load,
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    return _row([
                      '${r['LINE_NAME'] ?? '-'}',
                      '${r['UNIT_NAME'] ?? '-'}',
                      '${r['LWM_MACHINE_NAME'] ?? '-'}',
                      '${r['LWM_ISSUE_BY'] ?? '-'}',
                      '${r['LWM_ISSUE_DATE'] ?? '-'}',
                    ], odd: i.isOdd);
                  },
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _row(List<String> cells, {bool header = false, bool odd = false}) {
    return Container(
      color: header ? _headBg : (odd ? _rowAlt : _card),
      padding: EdgeInsets.symmetric(vertical: header ? 10 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(cells.length, (i) {
          return Expanded(
            flex: _flex[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                cells[i],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: header ? _headText : _textPri,
                  fontSize: header ? 11 : 11,
                  fontWeight: header ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}