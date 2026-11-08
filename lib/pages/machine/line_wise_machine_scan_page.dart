import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/top_menu_bar.dart';
import 'package:trackall_app/services/machine/machine_service.dart';

enum _Phase { idle, scanningLine, lineReady, scanningMachine }

class _LineInfo {
  final String qr;
  final String lineName;
  const _LineInfo({required this.qr, required this.lineName});
}

class _MachineEntry {
  final String qr;
  final String oid;
  final String name;
  final TimeOfDay time;
  const _MachineEntry(
      {required this.qr,
      required this.oid,
      required this.name,
      required this.time});
}

class LineWiseMachineScanPage extends StatefulWidget {
  const LineWiseMachineScanPage({super.key});
  @override
  State<LineWiseMachineScanPage> createState() => _S();
}

class _S extends State<LineWiseMachineScanPage>
    with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.idle;
  _LineInfo? _line;
  final List<_MachineEntry> _machines = [];

  MobileScannerController _ctrl = _newCtrl();

  static MobileScannerController _newCtrl() => MobileScannerController(
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.normal,
        returnImage: false,
        formats: [
          BarcodeFormat.qrCode,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
        ],
      );

  MobileScannerController _freshController() {
    _ctrl.dispose();
    _ctrl = _newCtrl();
    return _ctrl;
  }

  bool _busy = false;
  bool _dialog = false;
  bool _camVisible = false;
  final Set<String> _sessionCodes = {};

  late AnimationController _pulse;
  late Animation<double> _pulseAnim;
  String? _appUserId;
  String _company = '';

  @override
  void initState() {
    super.initState();
    _loadAppUser();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.87, end: 1.0).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadAppUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _company = prefs.getString('selected_company_id') ?? '';
    setState(() {
      _appUserId = prefs.getString('userId') ??
          prefs.getString('staff_id') ??
          prefs.getString('app_user');
    });
  }

  // ── Camera ─────────────────────────────────────────────────────────

  Future<void> _startLineScan() async {
    _busy = false;
    _sessionCodes.clear();
    _freshController();
    setState(() {
      _phase = _Phase.scanningLine;
      _camVisible = true;
    });
  }

  Future<void> _startMachineScan() async {
    _busy = false;
    _sessionCodes.clear();
    _freshController();
    setState(() {
      _phase = _Phase.scanningMachine;
      _camVisible = true;
    });
  }

  Future<void> _stopCamera() async {
    if (mounted) setState(() => _camVisible = false);
    await _ctrl.stop();
    _ctrl.dispose();
  }

  Future<void> _reset() async {
    _busy = false;
    _dialog = false;
    _sessionCodes.clear();
    await _ctrl.stop();
    _ctrl.dispose();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _camVisible = false;
      _line = null;
      _machines.clear();
    });
  }

  // ── Detect ─────────────────────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    if (_busy || _dialog) return;
    if (_phase != _Phase.scanningLine && _phase != _Phase.scanningMachine) {
      return;
    }
    String? code;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        code = v;
        break;
      }
    }
    if (code == null || _sessionCodes.contains(code)) return;
    _sessionCodes.add(code);
    _busy = true;
    debugPrint('📷 DETECTED [$code]');

    if (_phase == _Phase.scanningLine) {
      _handleLine(code);
    } else {
      _handleMachine(code);
    }
  }

  // ── Line ───────────────────────────────────────────────────────────

  Future<void> _handleLine(String qr) async {
    await _stopCamera();
    setState(() => _phase = _Phase.lineReady);

    Map<String, dynamic>? res;
    try {
      res = await MachineService.fetchLineName(qr.trim());
    } catch (e) {
      debugPrint('❌ line lookup: $e');
    }
    if (!mounted) {
      _busy = false;
      return;
    }
    if (res == null) {
      _snack('Invalid Line QR: $qr', Colors.red, Icons.error_rounded);
      setState(() => _phase = _Phase.idle);
      _busy = false;
      return;
    }
    setState(() => _line = _LineInfo(
        qr: qr.trim(), lineName: '${res!['LINE_NAME'] ?? 'Unknown Line'}'));
    _snack('✓ ${_line!.lineName}', const Color(0xFF0F9D58),
        Icons.check_circle_rounded);
    _busy = false;
  }

  // ── Machine ────────────────────────────────────────────────────────

  Future<void> _handleMachine(String qr) async {
    await _stopCamera();
    final code = qr.trim();

    if (_machines.any((m) => m.qr == code)) {
      _snack('Already scanned!', Colors.orange, Icons.warning_rounded);
      _busy = false;
      await _startMachineScan();
      return;
    }

    Map<String, dynamic>? res;
    try {
      res = await MachineService.fetchMachineInfo(code);
    } catch (e) {
      debugPrint('❌ machine lookup: $e');
    }
    if (!mounted) {
      _busy = false;
      return;
    }
    if (res == null) {
      _snack('Machine not found: $code', Colors.red, Icons.error_rounded);
      _busy = false;
      await _startMachineScan();
      return;
    }

    final oid = '${res['OID']}';
    final name = '${res['AMIM_NAME'] ?? code}';

    _dialog = true;
    final ok = await _showConfirm(lineName: _line!.lineName, machineName: name);
    _dialog = false;
    if (!mounted) {
      _busy = false;
      return;
    }

    if (ok == true) {
      if (_appUserId == null || _appUserId!.isEmpty) {
        _snack('User not identified', Colors.red, Icons.error_rounded);
      } else if (_company.isEmpty) {
        _snack('Company not selected', Colors.red, Icons.error_rounded);
      } else {
        final result = await MachineService.submitLineMachine(
          lineQr: _line!.qr,
          machineOid: oid,
          appUserId: _appUserId!,
          company: _company,
        );
        if (!mounted) {
          _busy = false;
          return;
        }
        if (result['success'] == true) {
          setState(() => _machines.insert(
              0,
              _MachineEntry(
                  qr: code, oid: oid, name: name, time: TimeOfDay.now())));
          final msg = result['message']?.toString();
          _snack(
              msg != null && msg.isNotEmpty ? '✓ $name — $msg' : '✓ $name added',
              const Color(0xFF0F9D58),
              Icons.check_circle_rounded);
        } else {
          _snack(result['message']?.toString() ?? 'Submission failed',
              Colors.red, Icons.error_rounded);
        }
      }
    } else {
      _snack('Cancelled', Colors.grey, Icons.cancel_rounded);
    }

    _busy = false;
    setState(() => _phase = _Phase.lineReady);
  }

  // ── Dialog / snack ─────────────────────────────────────────────────

  Future<bool?> _showConfirm(
      {required String lineName, required String machineName}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF1E3A5F), width: 1.2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF1A73E8).withValues(alpha: 0.45),
                    width: 1.5),
              ),
              child: const Icon(Icons.precision_manufacturing_rounded,
                  color: Color(0xFF60A5FA), size: 30),
            ),
            const SizedBox(height: 18),
            const Text('Confirm Scan',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Please verify the details below',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12)),
            const SizedBox(height: 22),
            _InfoRow(
                icon: Icons.view_timeline_rounded,
                label: 'Line',
                value: lineName,
                color: const Color(0xFF60A5FA)),
            const SizedBox(height: 10),
            _InfoRow(
                icon: Icons.precision_manufacturing_rounded,
                label: 'Machine',
                value: machineName,
                color: const Color(0xFF34D399)),
            const SizedBox(height: 26),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF0F9D58), Color(0xFF0B8043)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Confirm',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _snack(String msg, Color color, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: color,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(14),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: Column(children: [
        const TopMenuBar(),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                        phase: _phase,
                        line: _line,
                        machineCount: _machines.length),
                    const SizedBox(height: 14),
                    if (_camVisible) ...[
                      _Viewport(
                        controller: _ctrl,
                        onDetect: _onDetect,
                        pulseAnim: _pulseAnim,
                        label: _phase == _Phase.scanningLine
                            ? 'Point at Line QR Code'
                            : 'Point at Machine QR Code',
                      ),
                      const SizedBox(height: 14),
                    ],
                    Row(children: [
                      Expanded(
                        child: _MainBtn(
                          phase: _phase,
                          onStartScan: _startLineScan,
                          onScanMachine: _startMachineScan,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _ResetBtn(onTap: _reset),
                    ]),
                    const SizedBox(height: 20),
                    if (_machines.isNotEmpty) ...[
                      _ListHeader(count: _machines.length),
                      const SizedBox(height: 10),
                      ..._machines.asMap().entries.map(
                          (e) => _Tile(entry: e.value, index: e.key + 1)),
                    ],
                    if (_phase == _Phase.idle && _machines.isEmpty)
                      const _Hint(
                          icon: Icons.qr_code_2_rounded,
                          text: 'Tap Start Scan to begin'),
                    if (_phase == _Phase.lineReady && _machines.isEmpty)
                      const _Hint(
                          icon: Icons.precision_manufacturing_outlined,
                          text: 'Tap Scan Machine to scan machine QR'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// =====================================================================
// WIDGETS
// =====================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6)),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.3)),
          ]),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  final _Phase phase;
  final _LineInfo? line;
  final int machineCount;
  const _Header(
      {required this.phase, this.line, required this.machineCount});

  String get _status => switch (phase) {
        _Phase.idle => 'Ready — tap Start Scan to begin',
        _Phase.scanningLine => 'Scanning for Line QR code...',
        _Phase.lineReady => 'Line confirmed — scan machine QR',
        _Phase.scanningMachine => 'Scanning for machine QR...',
      };

  Color get _dotColor => switch (phase) {
        _Phase.idle => Colors.white38,
        _Phase.scanningLine => const Color(0xFFFBBF24),
        _Phase.lineReady => const Color(0xFF34D399),
        _Phase.scanningMachine => const Color(0xFF34D399),
      };

  String get _dotLabel => switch (phase) {
        _Phase.idle => 'IDLE',
        _Phase.scanningLine => 'SCANNING',
        _Phase.lineReady => 'READY',
        _Phase.scanningMachine => 'SCANNING',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1A73E8), Color(0xFF1557B0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.25))),
            child: const Icon(Icons.qr_code_scanner_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Line Wise Machine Scan',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text(_status,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w500)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _dotColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _dotColor.withValues(alpha: 0.45)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: _dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(_dotLabel,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _dotColor,
                      letterSpacing: 0.8)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
        const SizedBox(height: 14),
        Row(children: [
          _Chip(
              icon: Icons.view_timeline_rounded,
              label: 'Line',
              value: line?.lineName ?? '—',
              active: line != null),
          const SizedBox(width: 10),
          _Chip(
              icon: Icons.precision_manufacturing_rounded,
              label: 'Scanned',
              value: '$machineCount machines',
              active: machineCount > 0),
        ]),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool active;
  const _Chip(
      {required this.icon,
      required this.label,
      required this.value,
      required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: active ? 0.20 : 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.white.withValues(alpha: active ? 0.38 : 0.15)),
        ),
        child: Row(children: [
          Icon(icon, color: active ? Colors.white : Colors.white38, size: 15),
          const SizedBox(width: 7),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
              const SizedBox(height: 1),
              Text(value,
                  style: TextStyle(
                      fontSize: 11,
                      color: active ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Viewport extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture)? onDetect;
  final Animation<double> pulseAnim;
  final String label;
  const _Viewport(
      {required this.controller,
      required this.onDetect,
      required this.pulseAnim,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Stack(fit: StackFit.expand, children: [
        MobileScanner(controller: controller, onDetect: onDetect),
        IgnorePointer(child: CustomPaint(painter: _OverlayP())),
        IgnorePointer(
          child: Center(
            child: AnimatedBuilder(
              animation: pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: pulseAnim.value,
                child: SizedBox(
                    width: 280,
                    height: 190,
                    child: CustomPaint(painter: _BracketsP())),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.68),
                ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.crop_free_rounded,
                  color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _OverlayP extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withValues(alpha: 0.48);
    final cw = size.width * 0.86;
    final ch = size.height * 0.55;
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(
                (size.width - cw) / 2, (size.height - ch) / 2, cw, ch),
            const Radius.circular(12)))
        ..fillType = PathFillType.evenOdd,
      p,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _BracketsP extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF60A5FA)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const l = 24.0;
    const r = Radius.circular(5);
    canvas.drawPath(
        Path()
          ..moveTo(0, l)
          ..lineTo(0, 5)
          ..arcToPoint(const Offset(5, 0), radius: r)
          ..lineTo(l, 0),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(size.width - l, 0)
          ..lineTo(size.width - 5, 0)
          ..arcToPoint(Offset(size.width, 5), radius: r)
          ..lineTo(size.width, l),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height - l)
          ..lineTo(0, size.height - 5)
          ..arcToPoint(Offset(5, size.height), radius: r)
          ..lineTo(l, size.height),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(size.width - l, size.height)
          ..lineTo(size.width - 5, size.height)
          ..arcToPoint(Offset(size.width, size.height - 5), radius: r)
          ..lineTo(size.width, size.height - l),
        p);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _MainBtn extends StatelessWidget {
  final _Phase phase;
  final VoidCallback onStartScan;
  final VoidCallback onScanMachine;
  const _MainBtn(
      {required this.phase,
      required this.onStartScan,
      required this.onScanMachine});

  @override
  Widget build(BuildContext context) {
    final busy =
        phase == _Phase.scanningLine || phase == _Phase.scanningMachine;
    final String label = switch (phase) {
      _Phase.idle => 'Start Scan',
      _Phase.scanningLine => 'Scanning Line...',
      _Phase.lineReady => 'Scan Machine',
      _Phase.scanningMachine => 'Scanning Machine...',
    };
    final IconData icon = switch (phase) {
      _Phase.idle => Icons.qr_code_rounded,
      _Phase.scanningLine => Icons.hourglass_top_rounded,
      _Phase.lineReady => Icons.precision_manufacturing_rounded,
      _Phase.scanningMachine => Icons.hourglass_top_rounded,
    };
    final List<Color> grad = busy
        ? [Colors.grey.shade400, Colors.grey.shade500]
        : phase == _Phase.lineReady
            ? [const Color(0xFF0F9D58), const Color(0xFF0B8043)]
            : [const Color(0xFF1A73E8), const Color(0xFF1557B0)];

    return GestureDetector(
      onTap: busy ? null : (phase == _Phase.idle ? onStartScan : onScanMachine),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: grad,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          if (busy) ...[
            const SizedBox(width: 10),
            const SizedBox(
              width: 14,
              height: 14,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          ],
        ]),
      ),
    );
  }
}

class _ResetBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _ResetBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  final int count;
  const _ListHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
              color: const Color(0xFF1A73E8),
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      const Text('Scanned Machines',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.black87)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: const Color(0xFF1A73E8),
            borderRadius: BorderRadius.circular(20)),
        child: Text('$count',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ),
    ]);
  }
}

class _Tile extends StatelessWidget {
  final _MachineEntry entry;
  final int index;
  const _Tile({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100, width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF1557B0)]),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text('$index',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.precision_manufacturing_rounded,
                    color: Color(0xFF1A73E8), size: 15),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(entry.name,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.qr_code_rounded,
                    color: Colors.grey.shade400, size: 13),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(entry.qr,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.access_time_rounded,
                    color: Colors.grey.shade400, size: 12),
                const SizedBox(width: 5),
                Text(entry.time.format(context),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black45)),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Hint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100, width: 1.2),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
              color: Color(0xFFEEF4FF), shape: BoxShape.circle),
          child: Icon(icon,
              size: 36, color: const Color(0xFF1A73E8).withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 12),
        Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade400)),
      ]),
    );
  }
}