import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/top_menu_bar.dart';
import 'package:trackall_app/services/approval_lov.dart';

// ─────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────
const _pageBg       = Color(0xFFF0F4FF);
const _surface      = Colors.white;
const _surfaceAlt   = Color(0xFFF8FAFF);
const _borderLight  = Color(0xFFDDE3F0);
const _accent       = Color(0xFF3B82F6);
const _accentLight  = Color(0xFFEFF6FF);
const _cyan         = Color(0xFF06B6D4);
const _textPri      = Color(0xFF0F172A);
const _textSec      = Color(0xFF334155); // ✅ darkened from 0xFF475569
const _textHint     = Color(0xFF4B5563); // ✅ darkened from 0xFF6B7280
const _success      = Color(0xFF16A34A);
const _successLight = Color(0xFFF0FDF4);
const _danger       = Color(0xFFDC2626);
const _dangerLight  = Color(0xFFFEF2F2);
const _warning      = Color(0xFFD97706);
const _warningLight = Color(0xFFFFFBEB);

// ─────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────
class PocViewPage extends StatefulWidget {
  final int            pchId;
  final String         pocNo;
  final bool           canApprove;
  final ApprovalStage? stage;

  const PocViewPage({
    super.key,
    required this.pchId,
    required this.pocNo,
    this.canApprove = true,
    this.stage,
  });

  @override
  State<PocViewPage> createState() => _PocViewPageState();
}

class _PocViewPageState extends State<PocViewPage> {

  final _svc = ApprovalLovService();

  String _company = '5';
  String _appUser = '';

  PocInfo?          _info;
  List<PocCostLine> _lines   = [];
  bool              _loading = true;
  String?           _error;

  Map<String, List<PocCostLine>> get _grouped {
    final map = <String, List<PocCostLine>>{};
    for (final l in _lines) {
      map.putIfAbsent(l.category, () => []).add(l);
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _appUser = prefs.getString('userId') ?? '';
    _company = prefs.getString('selected_company_id') ?? '5';

    debugPrint('👤 staffCode: $_appUser');
    debugPrint('🏢 company: $_company');
    debugPrint('🔑 userId: ${prefs.getString('userId')}');
    debugPrint('🔑 empCode: ${prefs.getString('empCode')}');
    debugPrint('🔑 all keys: ${prefs.getKeys()}');

    await _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });

    final result = await _svc.fetchPocInfo(
      company: _company,
      pchId:   widget.pchId,
      stage:   widget.stage,
    );

    if (!mounted) return;
    if (result.info == null) {
      setState(() { _loading = false; _error = 'Failed to load POC data'; });
    } else {
      setState(() {
        _info    = result.info;
        _lines   = result.lines;
        _loading = false;
      });
    }
  }

  // ── Approve / Reject ──────────────────────────────────────────────
  Future<void> _handleAction(String action) async {
    String remarks = '';

    if (action == 'Rejected') {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RemarksDialog(ctrl: ctrl),
      );
      if (ok != true) return;
      remarks = ctrl.text.trim();
    } else {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ConfirmDialog(
            action: action,
            pocNo:  _info?.pocNo ?? widget.pocNo),
      );
      if (ok != true) return;
    }

    _showLoading();

    final result = await _svc.submitApproval(
      pchId:   widget.pchId,
      action:  action,
      appUser: _appUser,
      company: _company,
      stage:   widget.stage,
      remarks: remarks,
    );

    if (!mounted) return;
    Navigator.pop(context); // close spinner

    if (result['success'] == true) {
      _snack(
        result['message']?.toString() ?? '$action successfully',
        action == 'Approved' ? _success : _danger,
        action == 'Approved'
            ? Icons.check_circle_rounded
            : Icons.cancel_rounded,
      );
      await _load();
    } else {
      _snack(result['message']?.toString() ?? 'Action failed',
          _danger, Icons.error_rounded);
    }
  }

  void _showLoading() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_accent)),
        ),
      );

  void _snack(String msg, Color color, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(14),
      ));
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Column(
        children: [
          const TopMenuBar(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_accent)))
                : _error != null
                    ? _buildError()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _dangerLight,
                shape: BoxShape.circle,
                border: Border.all(color: _danger.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: _danger, size: 36),
            ),
            const SizedBox(height: 14),
            Text(_error!,
                style: const TextStyle(
                    color: _textPri,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _load,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _accentLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accent.withValues(alpha: 0.3)),
                ),
                child: const Text("Retry",
                    style: TextStyle(
                        color: _accent, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );

  Widget _buildContent() {
    final info      = _info!;
    final isPending = info.flagIe.toLowerCase() == 'pending' ||
        info.flagIe.isEmpty;
    final canAct = widget.canApprove && isPending;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildPageHeader(info)),
        SliverToBoxAdapter(child: _buildSummaryGrid(info)),
        SliverToBoxAdapter(child: _buildFinancialRow(info)),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 3, height: 16,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_accent, _cyan],
                      begin: Alignment.topCenter,
                      end:   Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text("Pre Costing Details",
                    style: TextStyle(
                        color: _textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2)),
                const Spacer(),
                _buildTotalBadge(),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(child: _buildTableHeader()),

        ..._grouped.entries.map((e) =>
            SliverToBoxAdapter(
                child: _buildCategoryGroup(e.key, e.value))),

        SliverToBoxAdapter(child: _buildOverallSum()),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: canAct
                ? _buildActionButtons()
                : _buildAlreadyActed(info),
          ),
        ),
      ],
    );
  }

  Widget _buildPageHeader(PocInfo info) {
    final stageLabel = widget.stage?.label ?? 'POC Detail';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(
          bottom: BorderSide(color: _borderLight, width: 1),
          left:   const BorderSide(color: _accent, width: 4),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _accentLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accent.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _accent, size: 15),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_accent, _cyan],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: _accent.withValues(alpha: 0.28),
                    blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Icon(
              widget.stage?.icon ?? Icons.description_rounded,
              color: Colors.white, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.pocNo,
                    style: const TextStyle(
                        color: _textPri,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1)),
                Text(stageLabel,
                    style: const TextStyle(
                        color: _textSec,        // ✅ was _textSec (now darker)
                        fontSize: 11,
                        fontWeight: FontWeight.w600), // ✅ bumped from w500
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: info.statusBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: info.statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(info.statusIcon,
                  color: info.statusColor, size: 12),
              const SizedBox(width: 5),
              Text(info.flagIe,
                  style: TextStyle(
                      color: info.statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _load,
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: _accentLight,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _accent.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: _accent, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(PocInfo info) {
    final fmt = DateFormat('dd MMM yyyy');
    final cells = [
      _InfoCell(label: 'Costing No',    value: info.pocNo,                                             icon: Icons.tag_rounded),
      _InfoCell(label: 'Date',          value: info.pocDate != null ? fmt.format(info.pocDate!) : '—', icon: Icons.calendar_today_rounded),
      _InfoCell(label: 'Buyer',         value: info.buyerName.isNotEmpty ? info.buyerName : '—',       icon: Icons.storefront_rounded),
      _InfoCell(label: 'Inquiry No',    value: info.inquiryNo.isNotEmpty ? info.inquiryNo : '—',       icon: Icons.search_rounded),
      _InfoCell(label: 'Item',          value: info.itemName.isNotEmpty  ? info.itemName  : '—',       icon: Icons.category_rounded),
      _InfoCell(label: 'Total Qty',     value: _n(info.qty.toDouble(), 0),                             icon: Icons.inventory_rounded),
      _InfoCell(label: 'Version',       value: 'v${info.version}',                                     icon: Icons.layers_rounded),
      _InfoCell(label: 'Generate Type', value: _formatCalType(info.calType),                           icon: Icons.settings_rounded),
      _InfoCell(label: 'Currency',      value: info.currency.isNotEmpty  ? info.currency  : '—',       icon: Icons.currency_exchange_rounded),
      _InfoCell(label: 'Final',         value: info.isFinal ? 'Yes' : 'No',                            icon: Icons.flag_rounded,
                valueColor: info.isFinal ? _success : _textSec),
      _InfoCell(label: 'Cost Unit',     value: info.costUnit  != 0 ? _n(info.costUnit, 0)                   : '', icon: Icons.straighten_rounded),
      _InfoCell(label: 'SMV',           value: info.smv       != 0 ? info.smv.toStringAsFixed(1)             : '', icon: Icons.timer_rounded),
      _InfoCell(label: 'Margin',        value: info.margin    != 0 ? '${info.margin.toStringAsFixed(2)}%'    : '', icon: Icons.trending_up_rounded),
      _InfoCell(label: 'EPM',           value: info.epm       != 0 ? info.epm.toStringAsFixed(2)             : '', icon: Icons.percent_rounded),
      _InfoCell(label: 'Target FOB',    value: info.targetFob != 0 ? _cur(info.targetFob)                    : '', icon: Icons.track_changes_rounded),
    ];

    return Container(
      color: _surfaceAlt,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: LayoutBuilder(builder: (_, c) {
        final cols = c.maxWidth > 480 ? 3 : 2;
        final w    = (c.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(
          spacing: 8, runSpacing: 8,
          children: cells.map((cell) =>
              SizedBox(width: w, child: _buildInfoCard(cell))).toList(),
        );
      }),
    );
  }

  Widget _buildInfoCard(_InfoCell cell) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderLight),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color: _accentLight,
                  borderRadius: BorderRadius.circular(7)),
              child: Icon(cell.icon, size: 13, color: _accent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cell.label,
                      style: const TextStyle(
                          color: _textSec,         // ✅ was _textHint (too light at 9px)
                          fontSize: 10,            // ✅ bumped from 9
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(cell.value,
                      style: TextStyle(
                          color: cell.valueColor ?? _textPri,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildFinancialRow(PocInfo info) {
    return Container(
      color: _surfaceAlt,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: LayoutBuilder(builder: (_, c) {
        final cols  = c.maxWidth > 480 ? 4 : 2;
        final w     = (c.maxWidth - (cols - 1) * 8) / cols;
        final cards = [
          _FinCard(label: 'FOB',         value: _cur(info.fob),     color: _accent),
          _FinCard(label: 'Ex Works',    value: _cur(info.exWorks), color: _cyan),
          _FinCard(label: 'CM %',        value: '${info.cm.toStringAsFixed(0)}%', color: _success),
          _FinCard(label: 'Mfg Total',   value: _cur(info.mfgTotal), color: _warning),
          _FinCard(label: 'Other Total', value: _cur(info.othTotal), color: _textSec),
          _FinCard(label: 'FG Name',     value: info.fgName.isNotEmpty ? info.fgName : '—',
              color: _textPri, isWide: cols <= 2),
        ];
        return Wrap(
          spacing: 8, runSpacing: 8,
          children: cards.map((card) => SizedBox(
              width: card.isWide ? c.maxWidth : w,
              child: _buildFinCard(card))).toList(),
        );
      }),
    );
  }

  Widget _buildFinCard(_FinCard card) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: card.color == _textPri
              ? _surface
              : card.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: card.color == _textPri
                  ? _borderLight
                  : card.color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.label,
                style: TextStyle(
                    color: card.color == _textPri ? _textSec : card.color, // ✅ was _textHint
                    fontSize: 10,             // ✅ bumped from 9
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4)),
            const SizedBox(height: 4),
            Text(card.value,
                style: TextStyle(
                    color: card.color == _textPri ? _textPri : card.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  Widget _buildTotalBadge() {
    final total = _lines.fold<double>(0, (s, l) => s + l.rate);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _accentLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
      ),
      child: Text('Total: ${_cur(total)}',
          style: const TextStyle(
              color: _accent,
              fontSize: 11,
              fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildTableHeader() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [_accent, _cyan],
              begin: Alignment.centerLeft,
              end:   Alignment.centerRight),
          borderRadius: BorderRadius.only(
            topLeft:  Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: const Row(
          children: [
            SizedBox(width: 32, child: Text('SL',            style: _thStyle)),
            Expanded(flex: 3,   child: Text('Cost Category', style: _thStyle)),
            Expanded(flex: 4,   child: Text('Cost Head',     style: _thStyle)),
            SizedBox(width: 60, child: Text('Source', style: _thStyle, textAlign: TextAlign.center)),
            SizedBox(width: 60, child: Text('Rate',   style: _thStyle, textAlign: TextAlign.right)),
            SizedBox(width: 46, child: Text('Rate%',  style: _thStyle, textAlign: TextAlign.right)),
          ],
        ),
      );

  static const _thStyle = TextStyle(
      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800);

  Widget _buildCategoryGroup(String category, List<PocCostLine> lines) {
    final subtotal = lines.fold<double>(0, (s, l) => s + l.rate);

    Color catColor = _accent;
    if (category.toLowerCase().contains('manufactur')) catColor = _success;
    if (category.toLowerCase().contains('other'))      catColor = _warning;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(
          left:  BorderSide(color: _borderLight),
          right: BorderSide(color: _borderLight),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: catColor.withValues(alpha: 0.07),
            child: Row(
              children: [
                Container(width: 6, height: 6,
                    decoration: BoxDecoration(
                        color: catColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(category,
                    style: TextStyle(
                        color: catColor,
                        fontSize: 11,           // ✅ bumped from 10
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3)),
                const Spacer(),
                Text('Subtotal: ${_cur(subtotal)}',
                    style: TextStyle(
                        color: catColor,
                        fontSize: 11,           // ✅ bumped from 10
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          ...lines.asMap().entries.map((e) =>
              _buildCostRow(e.value, e.key.isEven)),
        ],
      ),
    );
  }

  Widget _buildCostRow(PocCostLine line, bool isEven) {
    Color srcColor = _textSec;
    Color srcBg    = _pageBg;
    if (line.sourceType.toLowerCase() == 'import') {
      srcColor = _accent; srcBg = _accentLight;
    } else if (line.sourceType.toLowerCase() == 'local') {
      srcColor = _success; srcBg = _successLight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      color: isEven ? _surface : _pageBg.withValues(alpha: 0.5),
      child: Row(
        children: [
          SizedBox(width: 32,
              child: Text('${line.sl}',
                  style: const TextStyle(
                      color: _textSec,         // ✅ was _textHint
                      fontSize: 11,
                      fontWeight: FontWeight.w600))),
          Expanded(flex: 3,
              child: Text(line.category,
                  style: const TextStyle(
                      color: _textSec,
                      fontSize: 11,
                      fontWeight: FontWeight.w600))), // ✅ bumped from w500
          Expanded(flex: 4,
              child: Text(line.head,
                  style: const TextStyle(
                      color: _textPri,
                      fontSize: 11,
                      fontWeight: FontWeight.w600))),
          SizedBox(
            width: 60,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                    color: srcBg,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(line.sourceType,
                    style: TextStyle(
                        color: srcColor,
                        fontSize: 10,           // ✅ bumped from 9
                        fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
              ),
            ),
          ),
          SizedBox(width: 60,
              child: Text(_cur(line.rate),
                  style: const TextStyle(
                      color: _textPri, fontSize: 11,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.right)),
          SizedBox(width: 46,
              child: Text(
                  '${line.ratePercent.toStringAsFixed(2)}%',
                  style: const TextStyle(
                      color: _textSec,         // ✅ now darker
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildOverallSum() {
    final total = _lines.fold<double>(0, (s, l) => s + l.rate);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _accentLight,
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Text('Overall Sum',
              style: TextStyle(
                  color: _accent, fontSize: 12,
                  fontWeight: FontWeight.w800, letterSpacing: 0.3)),
          const Spacer(),
          Text(_cur(total),
              style: const TextStyle(
                  color: _accent, fontSize: 14,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() => Row(
        children: [
          Expanded(
            child: _ActionBtn(
              label:   'Approve',
              icon:    Icons.check_circle_outline_rounded,
              color:   _success,
              bgColor: _successLight,
              onTap:   () => _handleAction('Approved'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionBtn(
              label:   'Reject',
              icon:    Icons.cancel_outlined,
              color:   _danger,
              bgColor: _dangerLight,
              onTap:   () => _handleAction('Rejected'),
            ),
          ),
        ],
      );

  Widget _buildAlreadyActed(PocInfo info) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: info.statusBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: info.statusColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(info.statusIcon, color: info.statusColor, size: 18),
            const SizedBox(width: 8),
            Text('Already ${info.flagIe}',
                style: TextStyle(
                    color: info.statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );

  String _cur(double v) => NumberFormat('#,##0.00').format(v);
  String _n(double v, int d) =>
      NumberFormat('#,##0${d > 0 ? '.${'0' * d}' : ''}').format(v);
  String _formatCalType(String raw) {
    if (raw.isEmpty) return '—';
    if (raw.toLowerCase().startsWith('manual')) return raw;
    return 'Manual $raw';
  }
}

// ─────────────────────────────────────────────
// PRIVATE DATA CLASSES
// ─────────────────────────────────────────────
class _InfoCell {
  final String   label;
  final String   value;
  final IconData icon;
  final Color?   valueColor;
  const _InfoCell(
      {required this.label,
      required this.value,
      required this.icon,
      this.valueColor});
}

class _FinCard {
  final String label;
  final String value;
  final Color  color;
  final bool   isWide;
  const _FinCard(
      {required this.label,
      required this.value,
      required this.color,
      this.isWide = false});
}

// ─────────────────────────────────────────────
// ACTION BUTTON
// ─────────────────────────────────────────────
class _ActionBtn extends StatefulWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final Color        bgColor;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withValues(alpha: 0.18)
              : widget.bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _pressed
                  ? widget.color.withValues(alpha: 0.5)
                  : widget.color.withValues(alpha: 0.25),
              width: 1.5),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                      color: widget.color.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3)),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: widget.color, size: 17),
            const SizedBox(width: 7),
            Text(widget.label,
                style: TextStyle(
                    color: widget.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CONFIRM DIALOG
// ─────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String action;
  final String pocNo;
  const _ConfirmDialog({required this.action, required this.pocNo});

  @override
  Widget build(BuildContext context) {
    final isApprove = action == 'Approved';
    final color     = isApprove ? _success : _danger;
    final bg        = isApprove ? _successLight : _dangerLight;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderLight, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 32, offset: const Offset(0, 8)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: bg,
                  border: Border.all(
                      color: color.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Icon(
                  isApprove
                      ? Icons.check_circle_outline_rounded
                      : Icons.cancel_outlined,
                  color: color, size: 32),
              ),
              const SizedBox(height: 16),
              Text('Confirm $action',
                  style: const TextStyle(
                      color: _textPri, fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(pocNo,
                  style: const TextStyle(
                      color: _accent, fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                  'Are you sure you want to ${action.toLowerCase()} this POC?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _textSec, fontSize: 13, height: 1.5)),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _pageBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderLight),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: _textSec, fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(context, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: color.withValues(alpha: 0.3),
                            blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(action,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REMARKS DIALOG
// ─────────────────────────────────────────────
class _RemarksDialog extends StatelessWidget {
  final TextEditingController ctrl;
  const _RemarksDialog({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderLight, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 32, offset: const Offset(0, 8)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _dangerLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _danger.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.cancel_outlined,
                      color: _danger, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Reject POC',
                      style: TextStyle(
                          color: _textPri, fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 18),
              const Text('Remarks (optional)',
                  style: TextStyle(
                      color: _textSec, fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                maxLines: 3,
                style: const TextStyle(
                    color: _textPri, fontSize: 13,
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Enter reason for rejection...',
                  hintStyle: const TextStyle(color: _textHint, fontSize: 13),
                  filled: true,
                  fillColor: _pageBg,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _borderLight, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _borderLight, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: _danger.withValues(alpha: 0.5), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _pageBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderLight),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: _textSec, fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(context, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _danger,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: _danger.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('Confirm Reject',
                        style: TextStyle(
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}