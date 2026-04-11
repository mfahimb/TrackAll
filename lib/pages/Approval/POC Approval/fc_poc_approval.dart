import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/top_menu_bar.dart';
import 'package:trackall_app/services/approval_lov.dart';
import 'package:trackall_app/pages/Approval/poc_view.dart';
import '../../widgets/poc_approval_widgets.dart';

// ─────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────
const _pageBg       = Color(0xFFF0F4FF);
const _surface      = Colors.white;
const _surfaceAlt   = Color(0xFFF8FAFF);
const _borderLight  = Color(0xFFDDE3F0);
const _borderFocus  = Color(0xFF3B82F6);
const _accent       = Color(0xFF3B82F6);
const _accentLight  = Color(0xFFEFF6FF);
const _cyan         = Color(0xFF06B6D4);
const _textPri      = Color(0xFF0F172A);
const _textSec      = Color(0xFF64748B);
const _textHint     = Color(0xFFADB5BD);
const _success      = Color(0xFF16A34A);
const _successLight = Color(0xFFF0FDF4);
const _danger       = Color(0xFFDC2626);
const _dangerLight  = Color(0xFFFEF2F2);
const _warning      = Color(0xFFD97706);

// ─────────────────────────────────────────────
// PAGE  — 3rd approval stage (FC)
// ─────────────────────────────────────────────
class FcPocApprovalPage extends StatefulWidget {
  const FcPocApprovalPage({super.key});

  @override
  State<FcPocApprovalPage> createState() => _FcPocApprovalPageState();
}

class _FcPocApprovalPageState extends State<FcPocApprovalPage>
    with SingleTickerProviderStateMixin {
  static const _stage = ApprovalStage.fc;

  final _svc = ApprovalLovService();

  String _company = '5';
  String _appUser = '';

  // ── Dropdown lists ─────────────────────────
  List<LovDropItem> _buyers  = [];
  List<LovDropItem> _items   = [];   // populated after buyer selected
  List<LovDropItem> _costNos = [];   // populated after item selected

  // ── Selected values ────────────────────────
  LovDropItem? _selBuyer;
  LovDropItem? _selItem;
  LovDropItem? _selCostNo;
  String       _selStatus = '';

  // ── Loading flags ──────────────────────────
  bool _loadingFilters  = true;
  bool _loadingItems    = false;
  bool _loadingCostNos  = false;
  bool _loadingData     = false;
  bool _filtersExpanded = true;

  // ── Rows ───────────────────────────────────
  List<PocListItem> _allRows = [];
  List<PocListItem> _rows    = [];

  final _searchCtrl = TextEditingController();
  String _searchQ   = '';

  late AnimationController _pulse;

  // ═══════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _init();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════
  // INIT — only load buyers on start
  // ═══════════════════════════════════════════
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _appUser = prefs.getString('userId') ?? '';
    _company = prefs.getString('selected_company_id') ?? '5';

    debugPrint('👤 appUser: $_appUser  🏢 company: $_company');

    final buyers = await _svc.fetchBuyers(_company);
    if (!mounted) return;
    setState(() {
      _buyers         = buyers;
      _items          = [];
      _costNos        = [];
      _loadingFilters = false;
    });
    await _fetchData();
  }

  // ═══════════════════════════════════════════
  // FETCH LIST DATA
  // ═══════════════════════════════════════════
  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _loadingData = true);

    final rows = await _svc.fetchPocList(
      company:  _company,
      stage:    _stage,
      buyerId:  _selBuyer?.id,
      itemId:   _selItem?.id,
      costNoId: _selCostNo?.id,
      status:   _selStatus,  // mapping 'Pending'→'N' done inside service
    );

    if (!mounted) return;
    setState(() {
      _allRows     = rows;
      _loadingData = false;
    });
    _applySearch();
  }

  // ═══════════════════════════════════════════
  // CASCADE — Buyer → Items → CostNos
  // ═══════════════════════════════════════════

  /// Called when buyer dropdown changes.
  /// Resets item + costNo, then loads items for the selected buyer.
  Future<void> _onBuyerChanged(LovDropItem? buyer) async {
    setState(() {
      _selBuyer  = buyer;
      _selItem   = null;
      _selCostNo = null;
      _items     = [];
      _costNos   = [];
    });

    if (buyer == null) return;

    setState(() => _loadingItems = true);
    final items = await _svc.fetchItems(_company, buyerId: buyer.id);
    if (!mounted) return;
    setState(() {
      _items        = items;
      _loadingItems = false;
    });
  }

  /// Called when item dropdown changes.
  /// Resets costNo, then loads cost nos for selected buyer + item.
  Future<void> _onItemChanged(LovDropItem? item) async {
    setState(() {
      _selItem   = item;
      _selCostNo = null;
      _costNos   = [];
    });

    if (item == null) return;

    setState(() => _loadingCostNos = true);
    final costNos = await _svc.fetchCostNos(
      _company,
      buyerId: _selBuyer?.id,
      itemId:  item.id,
    );
    if (!mounted) return;
    setState(() {
      _costNos        = costNos;
      _loadingCostNos = false;
    });
  }

  // ═══════════════════════════════════════════
  // SEARCH / RESET
  // ═══════════════════════════════════════════
  void _applySearch() {
    if (_searchQ.isEmpty) {
      _rows = List.from(_allRows);
    } else {
      final q = _searchQ.toLowerCase().trim();
      _rows = _allRows.where((r) =>
          r.title.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.flagIe.toLowerCase().contains(q)).toList();
    }
    setState(() {});
  }

  void _resetFilters() {
    setState(() {
      _selBuyer  = null;
      _selItem   = null;
      _selCostNo = null;
      _selStatus = '';
      _items     = [];
      _costNos   = [];
      _searchCtrl.clear();
      _searchQ   = '';
    });
    _fetchData();
  }

  // ═══════════════════════════════════════════
  // APPROVE / REJECT
  // ═══════════════════════════════════════════
  Future<void> _handleAction(PocListItem item, String action) async {
    String remarks = '';
    if (action == 'Rejected') {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => RemarksDialog(ctrl: ctrl, title: item.title),
      );
      if (ok != true) return;
      remarks = ctrl.text.trim();
    } else {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ConfirmDialog(action: action, title: item.title),
      );
      if (ok != true) return;
    }

    _showLoading();
    final result = await _svc.submitApproval(
      pchId:   item.pchId,
      action:  action,
      appUser: _appUser,
      company: _company,
      stage:   _stage,
      remarks: remarks,
    );
    if (!mounted) return;
    Navigator.pop(context);

    if (result['success'] == true) {
      _snack(
        result['message']?.toString() ?? '$action successfully',
        action == 'Approved' ? _success : _danger,
        action == 'Approved'
            ? Icons.check_circle_rounded
            : Icons.cancel_rounded,
      );
      _fetchData();
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
          Expanded(child: Text(msg,
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

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Column(children: [
        const TopMenuBar(),
        Expanded(
          child: _loadingFilters
              ? const Center(child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_accent)))
              : Column(children: [
                  _buildPageHeader(),
                  _buildFilterPanel(),
                  _buildSearchBar(),
                  _buildStatusBar(),
                  Expanded(child: _buildList()),
                ]),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  // PAGE HEADER
  // ─────────────────────────────────────────────
  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(
          bottom: BorderSide(color: _borderLight, width: 1),
          left:   const BorderSide(color: _accent, width: 4),
        ),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: _accentLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _accent.withValues(alpha: 0.25))),
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
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(
                color: _accent.withValues(alpha: 0.28),
                blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Icon(_stage.icon, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_stage.label,
                  style: const TextStyle(
                      color: _textPri, fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1)),
              Text(_stage.subtitle,
                  style: const TextStyle(
                      color: _textSec, fontSize: 10,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        GestureDetector(
          onTap: _loadingData ? null : _fetchData,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: _accentLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _accent.withValues(alpha: 0.25))),
            child: _loadingData
                ? const Padding(
                    padding: EdgeInsets.all(9),
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _accent)))
                : const Icon(Icons.refresh_rounded,
                    color: _accent, size: 17),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  // FILTER PANEL — cascading dropdowns
  // ─────────────────────────────────────────────
  Widget _buildFilterPanel() {
    final hasFilter = _selBuyer != null || _selItem != null ||
        _selCostNo != null || _selStatus.isNotEmpty;

    return Container(
      color: _surfaceAlt,
      child: Column(children: [
        // ── Toggle bar ──────────────────────────
        GestureDetector(
          onTap: () =>
              setState(() => _filtersExpanded = !_filtersExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: _filtersExpanded
                            ? _accent.withValues(alpha: 0.2)
                            : _borderLight,
                        width: 1))),
            child: Row(children: [
              Icon(Icons.filter_list_rounded,
                  color: _filtersExpanded ? _accent : _textSec,
                  size: 16),
              const SizedBox(width: 8),
              Text("Filters",
                  style: TextStyle(
                      color:
                          _filtersExpanded ? _textPri : _textSec,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              if (hasFilter) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: _accentLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _accent.withValues(alpha: 0.3))),
                  child: const Text("Active",
                      style: TextStyle(
                          color: _accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4)),
                ),
              ],
              const Spacer(),
              if (hasFilter)
                GestureDetector(
                  onTap: _resetFilters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: _dangerLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                _danger.withValues(alpha: 0.3))),
                    child: const Text("Reset",
                        style: TextStyle(
                            color: _danger,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _filtersExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: _textSec, size: 18),
              ),
            ]),
          ),
        ),

        // ── Collapsible filter content ──────────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _filtersExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(children: [
              // Row 1 — Buyer | Item | Status
              Row(children: [
                // ── Buyer ──────────────────────
                Expanded(
                  child: DropdownField<LovDropItem>(
                    label: "Buyer",
                    icon:  Icons.storefront_rounded,
                    value: _selBuyer,
                    items: _buyers,
                    itemLabel: (e) => e.label,
                    onChanged: _onBuyerChanged, // ✅ cascade
                  ),
                ),
                const SizedBox(width: 6),

                // ── Item (loads after buyer) ────
                Expanded(
                  child: _loadingItems
                      ? _loadingDropdown("Item")
                      : DropdownField<LovDropItem>(
                          label: "Item",
                          icon:  Icons.category_rounded,
                          value: _selItem,
                          items: _items,         // ✅ filtered by buyer
                          itemLabel: (e) => e.label,
                          onChanged: _onItemChanged, // ✅ cascade
                        ),
                ),
                const SizedBox(width: 6),

                // ── Status ──────────────────────
                Expanded(
                  child: StatusDropdown(
                    value: _selStatus,
                    onChanged: (v) =>
                        setState(() => _selStatus = v ?? ''),
                  ),
                ),
              ]),

              const SizedBox(height: 6),

              // Row 2 — POC Cost No | Filter button
              Row(children: [
                // ── Cost No (loads after item) ──
                Expanded(
                  child: _loadingCostNos
                      ? _loadingDropdown("POC Cost No")
                      : DropdownField<LovDropItem>(
                          label: "POC Cost No",
                          icon:  Icons.receipt_long_rounded,
                          value: _selCostNo,
                          items: _costNos,       // ✅ filtered by buyer+item
                          itemLabel: (e) => e.label,
                          onChanged: (v) =>
                              setState(() => _selCostNo = v),
                        ),
                ),
                const SizedBox(width: 6),

                // ── Filter button ───────────────
                GestureDetector(
                  onTap: _fetchData,
                  child: Container(
                    height: 34,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_accent, _cyan],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(
                          color: _accent.withValues(alpha: 0.28),
                          blurRadius: 6,
                          offset: const Offset(0, 3))],
                    ),
                    child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_rounded,
                              color: Colors.white, size: 13),
                          SizedBox(width: 5),
                          Text("Filter",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2)),
                        ]),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  /// Placeholder shown while a dropdown is loading
  Widget _loadingDropdown(String label) => Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderLight),
        ),
        child: Row(children: [
          const SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_accent)),
          ),
          const SizedBox(width: 8),
          Text("Loading $label...",
              style: const TextStyle(
                  color: _textHint,
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
        ]),
      );

  // ─────────────────────────────────────────────
  // SEARCH BAR
  // ─────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) =>
            setState(() { _searchQ = v; _applySearch(); }),
        style: const TextStyle(
            fontSize: 11,
            color: _textPri,
            fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: "Search POC entries...",
          hintStyle:
              const TextStyle(fontSize: 11, color: _textHint),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 13, color: _textHint),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 30, minHeight: 0),
          suffixIcon: _searchQ.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() {
                    _searchCtrl.clear();
                    _searchQ = '';
                    _applySearch();
                  }),
                  child: const Icon(Icons.close_rounded,
                      size: 12, color: _textHint))
              : null,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 26, minHeight: 0),
          filled: true,
          fillColor: _pageBg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide:
                  BorderSide(color: _borderLight, width: 1)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide:
                  BorderSide(color: _borderLight, width: 1)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(
                  color: _borderFocus, width: 1.5)),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STATUS BAR
  // ─────────────────────────────────────────────
  Widget _buildStatusBar() {
    final pending = _rows.where((r) {
      final s = r.flagIe.trim().toLowerCase();
      return s == 'pending' || s.isEmpty || s == 'n';
    }).length;
    final approved = _rows
        .where((r) => r.flagIe.trim().toLowerCase() == 'approved')
        .length;
    final rejected = _rows
        .where((r) => r.flagIe.trim().toLowerCase() == 'rejected')
        .length;

    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(children: [
        StatPill(label: "Total",    count: _rows.length, color: _accent),
        const SizedBox(width: 6),
        StatPill(label: "Pending",  count: pending,      color: _warning),
        const SizedBox(width: 6),
        StatPill(label: "Approved", count: approved,     color: _success),
        const SizedBox(width: 6),
        StatPill(label: "Rejected", count: rejected,     color: _danger),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  // LIST
  // ─────────────────────────────────────────────
  Widget _buildList() {
    if (_loadingData) {
      return const Center(child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_accent)));
    }

    if (_rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  color: _surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _borderLight, width: 1.5),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12)]),
              child: const Icon(Icons.inbox_rounded,
                  size: 40, color: _textHint),
            ),
            const SizedBox(height: 16),
            const Text("No POC entries found",
                style: TextStyle(
                    color: _textPri,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            const Text("Try adjusting your filters",
                style: TextStyle(color: _textSec, fontSize: 13)),
          ],
        ),
      );
    }

    final sortedRows = [..._rows]
      ..sort((a, b) =>
          (b.createdOn ?? DateTime(0))
              .compareTo(a.createdOn ?? DateTime(0)));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
      itemCount: sortedRows.length,
      itemBuilder: (_, i) {
        final item   = sortedRows[i];
        final status = item.flagIe.trim().toLowerCase();
        return PocCard(
          item:  item,
          index: i + 1,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PocViewPage(
                pchId:      item.pchId,
                pocNo:      item.title,
                canApprove: status == 'pending' || status.isEmpty,
                stage:      _stage,
              ),
            ),
          ).then((_) => _fetchData()),
          onApprove: () => _handleAction(item, 'Approved'),
          onReject:  () => _handleAction(item, 'Rejected'),
        );
      },
    );
  }
}