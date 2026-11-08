import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/top_menu_bar.dart';
import 'package:trackall_app/services/machine/machine_service.dart';

const _bg = Color(0xFFF0F4FA);
const _blue = Color(0xFF1A73E8);
const _green = Color(0xFF0F9D58);
const _border = Color(0xFFCBD5E1);
const _textPri = Color(0xFF0F172A);
const _textSec = Color(0xFF64748B);

class _Item {
  final String qr, oid, name;
  const _Item(this.qr, this.oid, this.name);
}

class MachineTransferPage extends StatefulWidget {
  const MachineTransferPage({super.key});
  @override
  State<MachineTransferPage> createState() => _MachineTransferPageState();
}

class _MachineTransferPageState extends State<MachineTransferPage> {
  List<Map<String, String>> _statuses = [];
  List<Map<String, String>> _locations = [];
  List<Map<String, String>> _lines = [];
  String? _status, _location, _line;
  final List<_Item> _items = [];
  bool _loading = true, _saving = false;
  String? _error;
  String _company = '';
  String? _user;

  bool get _isTransfer => _status == 'Transfer';
  bool get _canSave =>
      _status != null &&
      _items.isNotEmpty &&
      (!_isTransfer || (_location != null && _line != null));

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _company = prefs.getString('selected_company_id') ?? '';
    _user = prefs.getString('userId');
    try {
      _statuses = await MachineService.fetchMachineStatuses();
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _onStatus(String? v) async {
    setState(() {
      _status = v;
      _location = null;
      _line = null;
      _lines = [];
    });
    if (v == 'Transfer' && _locations.isEmpty) {
      final l = await MachineService.fetchToLocations(_company);
      if (mounted) setState(() => _locations = l);
    }
  }

  Future<void> _onLocation(String? v) async {
    setState(() {
      _location = v;
      _line = null;
      _lines = [];
    });
    if (v == null) return;
    final l = await MachineService.fetchLinesByLocation(v);
    if (mounted) setState(() => _lines = l);
  }

  Future<void> _scan() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => const _ScanSheet(),
    );
    if (code == null || !mounted) return;
    final qr = code.trim();
    if (_items.any((i) => i.qr == qr)) {
      _snack('Already scanned!', Colors.orange);
      return;
    }
    Map<String, dynamic>? res;
    try {
      res = await MachineService.fetchMachineInfo(qr);
    } catch (_) {}
    if (!mounted) return;
    if (res == null) {
      _snack('Machine not found: $qr', Colors.red);
      return;
    }
    setState(() => _items.insert(
        0, _Item(qr, '${res!['OID']}', '${res['AMIM_NAME'] ?? qr}')));
  }

  Future<void> _save() async {
    if (_user == null || _user!.isEmpty) {
      _snack('User not identified', Colors.red);
      return;
    }
    if (_company.isEmpty) {
      _snack('Company not selected', Colors.red);
      return;
    }
    setState(() => _saving = true);
    final r = await MachineService.submitMachineTransfer(
      status: _status!,
      toLocation: _location,
      toLine: _line,
      machines: _items
          .map((e) => {'machine_id': e.oid, 'machine_name': e.name})
          .toList(),
      appUserId: _user!,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final ok = r['success'] == true;
    _snack(r['message']?.toString() ?? (ok ? 'Saved' : 'Failed'),
        ok ? _green : Colors.red);
    if (ok) setState(() => _items.clear());
  }

  void _snack(String m, Color c) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: c,
      behavior: SnackBarBehavior.floating,
    ));
  }

    Widget _dropdown(String label, String? value,
      List<Map<String, String>> items, ValueChanged<String?>? onChanged,
      {String hint = '--Select One--',
      IconData icon = Icons.list_alt_rounded}) {
    final disabled = onChanged == null;
    final selected = items.where((e) => e['R'] == value).toList();
    final text = selected.isEmpty ? hint : selected.first['D']!;

    return GestureDetector(
      onTap: disabled
          ? null
          : () async {
              final picked = await _pickSheet(label, items, value, icon);
              if (picked != null) onChanged(picked);
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFE2E8F0) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected.isEmpty ? _border : _blue.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: disabled ? 0.05 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: _textSec)),
                  const SizedBox(height: 2),
                  Text(text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected.isEmpty
                              ? FontWeight.w500
                              : FontWeight.w700,
                          color: selected.isEmpty ? _textSec : _textPri)),
                ]),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded,
              color: _textSec, size: 22),
        ]),
      ),
    );
  }

  Future<String?> _pickSheet(String title, List<Map<String, String>> items,
      String? current, IconData icon) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String q = '';
        return StatefulBuilder(builder: (ctx, setS) {
          final list = items
              .where((e) => e['D']!.toLowerCase().contains(q.toLowerCase()))
              .toList();
          return Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(children: [
                  Icon(icon, color: _blue, size: 20),
                  const SizedBox(width: 10),
                  Text('Select $title',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textPri)),
                ]),
              ),
              if (items.length > 6)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    onChanged: (v) => setS(() => q = v),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
              Flexible(
                child: list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(28),
                        child: Text('No options',
                            style: TextStyle(color: _textSec)))
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final e = list[i];
                          final sel = e['R'] == current;
                          return GestureDetector(
                            onTap: () => Navigator.pop(ctx, e['R']),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(
                                color: sel
                                    ? _blue.withValues(alpha: 0.1)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: sel
                                        ? _blue.withValues(alpha: 0.5)
                                        : Colors.transparent),
                              ),
                              child: Row(children: [
                                Expanded(
                                  child: Text(e['D']!,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: sel
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: sel ? _blue : _textPri)),
                                ),
                                if (sel)
                                  const Icon(Icons.check_circle_rounded,
                                      color: _blue, size: 20),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
            ]),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        const TopMenuBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _blue))
              : _error != null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, style: const TextStyle(color: _textSec)),
                        TextButton(
                            onPressed: () {
                              setState(() => _loading = true);
                              _init();
                            },
                            child: const Text('Retry')),
                      ]),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: [
                            _dropdown('Status', _status, _statuses, _onStatus,
                                icon: Icons.flag_rounded),
                            if (_isTransfer) ...[
                              _dropdown(
                                  'To Location', _location, _locations, _onLocation,
                                  icon: Icons.business_rounded),
                              _dropdown(
                                  'To Line',
                                  _line,
                                  _lines,
                                  _location == null
                                      ? null
                                      : (v) => setState(() => _line = v),
                                  hint: '--Select Line--',
                                  icon: Icons.view_timeline_rounded),
                            ],
                            SizedBox(
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: _status == null ? null : _scan,
                                icon: const Icon(Icons.qr_code_scanner_rounded,
                                    size: 18),
                                label: const Text('Scan Machine QR'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(children: [
                              const Text('Preview',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: _textPri)),
                              const SizedBox(width: 8),
                              if (_items.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: _blue,
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text('${_items.length}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800)),
                                ),
                              const Spacer(),
                              SizedBox(
                                height: 38,
                                child: ElevatedButton(
                                  onPressed: _canSave && !_saving ? _save : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white))
                                      : const Text('Save'),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            if (_items.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 32),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _border),
                                ),
                                child: const Center(
                                  child: Text('No machines scanned',
                                      style: TextStyle(
                                          color: _textSec, fontSize: 13)),
                                ),
                              ),
                            ..._items.asMap().entries.map((e) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _border),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                          color: _blue,
                                          borderRadius: BorderRadius.circular(8)),
                                      child: Text('${e.key + 1}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(e.value.name,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: _textPri)),
                                          Text(e.value.qr,
                                              style: const TextStyle(
                                                  fontSize: 11, color: _textSec)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded,
                                          size: 18, color: _textSec),
                                      onPressed: () =>
                                          setState(() => _items.removeAt(e.key)),
                                    ),
                                  ]),
                                )),
                          ],
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _ScanSheet extends StatefulWidget {
  const _ScanSheet();
  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> {
  final _ctrl = MobileScannerController(
    facing: CameraFacing.back,
    returnImage: false,
    formats: [BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.code39],
  );
  bool _done = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Stack(children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: (cap) {
            if (_done) return;
            for (final b in cap.barcodes) {
              final v = b.rawValue;
              if (v != null && v.isNotEmpty) {
                _done = true;
                Navigator.pop(context, v);
                return;
              }
            }
          },
        ),
        const Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Text('Point at Machine QR Code',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ]),
    );
  }
}