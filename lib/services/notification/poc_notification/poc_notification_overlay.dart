// lib/services/notification/poc_notification/poc_notification_overlay.dart
//
// Exports:
//   • PocNotificationOverlay  — root Stack widget (wrap your MaterialApp child)
//   • pocOverlayKey           — GlobalKey to trigger banners
//   • showPocBanners()        — called from TopMenuBar after polling
//   • PocBellIcon             — bell + badge widget for TopMenuBar

library poc_notification_overlay;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:trackall_app/services/approval_lov.dart';
import 'package:trackall_app/pages/Approval/POC%20Approval/ie_poc_approval.dart';
import 'package:trackall_app/pages/Approval/POC%20Approval/coaster_poc_approval.dart';
import 'package:trackall_app/pages/Approval/POC%20Approval/fc_poc_approval.dart';
import 'poc_notification_service.dart';

// ─────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────
const _accent      = Color(0xFF3B82F6);
const _cyan        = Color(0xFF06B6D4);
const _success     = Color(0xFF16A34A);
const _warning     = Color(0xFFD97706);
const _danger      = Color(0xFFEF4444);
const _navy        = Color(0xFF060D1F);
const _textPri     = Color(0xFF0F172A);
const _textSec     = Color(0xFF64748B);
const _textHint    = Color(0xFFADB5BD);
const _pageBg      = Color(0xFFF0F4FF);
const _borderLight = Color(0xFFDDE3F0);

// ─────────────────────────────────────────────
// STAGE META
// ─────────────────────────────────────────────
class _StageMeta {
  final String label;
  final String subtitle;
  final Color color;
  final IconData icon;
  final Widget Function() pageBuilder;

  const _StageMeta({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.pageBuilder,
  });
}

final _stageMeta = {
  ApprovalStage.ie: _StageMeta(
    label:       'IE POC Approval',
    subtitle:    '1st Approval — Industrial Engineering',
    color:       _accent,
    icon:        Icons.engineering_rounded,
    pageBuilder: () => const IEPocApprovalPage(),
  ),
  ApprovalStage.coaster: _StageMeta(
    label:       'Coaster POC Approval',
    subtitle:    '2nd Approval — Coaster',
    color:       _cyan,
    icon:        Icons.price_check_rounded,
    pageBuilder: () => const CoasterPocApprovalPage(),
  ),
  ApprovalStage.fc: _StageMeta(
    label:       'FC POC Approval',
    subtitle:    '3rd Approval — FC',
    color:       _success,
    icon:        Icons.account_balance_rounded,
    pageBuilder: () => const FcPocApprovalPage(),
  ),
};

// ─────────────────────────────────────────────
// GLOBAL KEY + HELPER
// ─────────────────────────────────────────────
final pocOverlayKey = GlobalKey<PocNotificationOverlayState>();

void showPocBanners(
    List<ApprovalStage> alerts, Map<ApprovalStage, int> counts) {
  pocOverlayKey.currentState?.showBanners(alerts, counts);
}

// ─────────────────────────────────────────────
// ROOT OVERLAY WIDGET
// ─────────────────────────────────────────────
class PocNotificationOverlay extends StatefulWidget {
  final Widget child;
  const PocNotificationOverlay({super.key, required this.child});

  @override
  State<PocNotificationOverlay> createState() => PocNotificationOverlayState();
}

class PocNotificationOverlayState extends State<PocNotificationOverlay> {
  final List<_BannerEntry> _banners = [];

  void showBanners(
      List<ApprovalStage> alerts, Map<ApprovalStage, int> counts) {
    for (int i = 0; i < alerts.length; i++) {
      Future.delayed(Duration(milliseconds: i * 320), () {
        if (!mounted) return;
        final stage = alerts[i];
        final count = counts[stage] ?? 0;
        if (count == 0) return;
        setState(() {
          _banners.add(_BannerEntry(
            key:   UniqueKey(),
            stage: stage,
            count: count,
          ));
        });
      });
    }
  }

  void _dismiss(_BannerEntry entry) {
    if (!mounted) return;
    setState(() => _banners.remove(entry));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top:   MediaQuery.of(context).padding.top + 62,
          left:  0,
          right: 0,
          child: Column(
            children: _banners
                .map((e) => _BannerCard(
                      key:       e.key,
                      stage:     e.stage,
                      count:     e.count,
                      onDismiss: () => _dismiss(e),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _BannerEntry {
  final Key           key;
  final ApprovalStage stage;
  final int           count;
  _BannerEntry({required this.key, required this.stage, required this.count});
}

// ─────────────────────────────────────────────
// BANNER CARD  (slide-down, auto-dismiss 5 s)
// ─────────────────────────────────────────────
class _BannerCard extends StatefulWidget {
  final ApprovalStage stage;
  final int           count;
  final VoidCallback  onDismiss;

  const _BannerCard({
    super.key,
    required this.stage,
    required this.count,
    required this.onDismiss,
  });

  @override
  State<_BannerCard> createState() => _BannerCardState();
}

class _BannerCardState extends State<_BannerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset>   _slide;
  late Animation<double>   _fade;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
    _autoTimer = Timer(const Duration(seconds: 5), _dismiss);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    _autoTimer?.cancel();
    if (mounted) await _ctrl.reverse();
    widget.onDismiss();
  }

  void _onTap() {
    _autoTimer?.cancel();
    PocNotificationService().markSeen(widget.stage, widget.count);
    widget.onDismiss();

    final meta = _stageMeta[widget.stage]!;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => meta.pageBuilder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = _stageMeta[widget.stage]!;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => SlideTransition(
        position: _slide,
        child: FadeTransition(opacity: _fade, child: child),
      ),
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: meta.color.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color:      meta.color.withValues(alpha: 0.18),
                blurRadius: 20,
                offset:     const Offset(0, 6),
              ),
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset:     const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Coloured top strip ──────────────────────────────
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        meta.color,
                        meta.color.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),

                // ── Main content row ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 13),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              meta.color,
                              meta.color.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end:   Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color:      meta.color.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset:     const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(meta.icon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: meta.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Pending Approval',
                                style: TextStyle(
                                  color:         meta.color,
                                  fontSize:      9,
                                  fontWeight:    FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              meta.label,
                              style: const TextStyle(
                                color:      _textPri,
                                fontSize:   13,
                                fontWeight: FontWeight.w800,
                                height:     1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.count} item${widget.count == 1 ? '' : 's'} '
                              'awaiting your approval',
                              style: const TextStyle(
                                color:      _textSec,
                                fontSize:   11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      Column(
                        children: [
                          GestureDetector(
                            onTap: _dismiss,
                            child: Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  size: 13, color: _textSec),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 12, color: meta.color),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Footer ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  color: meta.color.withValues(alpha: 0.05),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  child: Row(children: [
                    Icon(Icons.touch_app_rounded,
                        size: 11,
                        color: meta.color.withValues(alpha: 0.7)),
                    const SizedBox(width: 5),
                    Text(
                      'Tap to open approval page',
                      style: TextStyle(
                        color:      meta.color.withValues(alpha: 0.8),
                        fontSize:   10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    _CountdownBar(color: meta.color),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// COUNTDOWN BAR
// ─────────────────────────────────────────────
class _CountdownBar extends StatefulWidget {
  final Color color;
  const _CountdownBar({required this.color});

  @override
  State<_CountdownBar> createState() => _CountdownBarState();
}

class _CountdownBarState extends State<_CountdownBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => SizedBox(
        width: 56, height: 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: 1 - _ctrl.value,
            backgroundColor:  widget.color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(
                widget.color.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BELL ICON WITH BADGE
// ─────────────────────────────────────────────
class PocBellIcon extends StatefulWidget {
  final bool isMobile;
  const PocBellIcon({super.key, this.isMobile = true});

  @override
  State<PocBellIcon> createState() => _PocBellIconState();
}

class _PocBellIconState extends State<PocBellIcon>
    with SingleTickerProviderStateMixin {
  final _svc = PocNotificationService();
  late AnimationController _shake;
  late Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(begin: -0.06, end: 0.06).animate(
      CurvedAnimation(parent: _shake, curve: Curves.elasticIn),
    );
    _svc.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _svc.removeListener(_onUpdate);
    _shake.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (!mounted) return;
    setState(() {});
    if (_svc.totalPending > 0) {
      _shake.forward(from: 0).then((_) => _shake.reverse());
    }
  }

  // ✅ FIXED: no longer passes stale snapshot maps
  void _openPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _NotifPanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _svc.totalPending;
    final size  = widget.isMobile ? 36.0 : 40.0;

    return GestureDetector(
      onTap: _openPanel,
      child: AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) => Transform.rotate(
          angle: total > 0 ? _shakeAnim.value : 0,
          child: child,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size, height: size,
              decoration: BoxDecoration(
                color: total > 0
                    ? _accent.withValues(alpha: 0.15)
                    : const Color(0xFF0D1B35).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: total > 0
                      ? _accent.withValues(alpha: 0.4)
                      : const Color(0xFF1E3A5F),
                  width: 1,
                ),
              ),
              child: Icon(
                total > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: total > 0
                    ? const Color(0xFF60A5FA)
                    : const Color(0xFF94A3B8),
                size: widget.isMobile ? 17 : 19,
              ),
            ),
            if (total > 0)
              Positioned(
                top: -5, right: -5,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _danger,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color:      _danger.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    total > 99 ? '99+' : '$total',
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   9,
                      fontWeight: FontWeight.w900,
                      height:     1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION PANEL  (bottom sheet)
// ✅ FIXED: StatefulWidget that listens to service live
//    — panel rebuilds when markStageAsSeen() fires
//    — items stay visible until API returns 0
// ─────────────────────────────────────────────
class _NotifPanel extends StatefulWidget {
  const _NotifPanel();

  @override
  State<_NotifPanel> createState() => _NotifPanelState();
}

class _NotifPanelState extends State<_NotifPanel> {
  final _svc = PocNotificationService();

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _svc.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Always read live from service — never stale snapshots
    final rawCounts = _svc.rawCounts;
    final counts    = _svc.counts;

    // ✅ Only rawCounts controls visibility — badge (counts) is separate
    final stages = ApprovalStage.values
        .where((s) => (rawCounts[s] ?? 0) > 0)
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: _borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_accent, _cyan]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color:      _accent.withValues(alpha: 0.3),
                        blurRadius: 8),
                  ],
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pending Approvals',
                        style: TextStyle(
                            color:      _textPri,
                            fontSize:   16,
                            fontWeight: FontWeight.w800)),
                    Text(
                      stages.isEmpty
                          ? 'No pending items'
                          : '${rawCounts.values.fold(0, (s, v) => s + v)} item(s) need your attention',
                      style: const TextStyle(
                          color:      _textSec,
                          fontSize:   11,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: _textSec),
                ),
              ),
            ]),
          ),

          const Divider(height: 1, color: _borderLight),

          // Empty state
          if (stages.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 48,
                    color: _success.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text('All caught up!',
                    style: TextStyle(
                        color:      _textPri,
                        fontSize:   15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('No pending approvals right now.',
                    style: TextStyle(color: _textSec, fontSize: 12)),
              ]),
            )
          else
            ...stages.map((stage) {
              final meta        = _stageMeta[stage]!;
              final rawCount    = rawCounts[stage] ?? 0;
              final unseenCount = counts[stage]    ?? 0;

              return _PanelRow(
                meta:        meta,
                rawCount:    rawCount,
                unseenCount: unseenCount,
                onTap: () {
                  // ✅ Zero badge only — row stays until API returns 0
                  _svc.markStageAsSeen(stage);
                  Navigator.pop(context);
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => meta.pageBuilder()),
                  );
                },
              );
            }),

          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PANEL ROW
// ─────────────────────────────────────────────
class _PanelRow extends StatelessWidget {
  final _StageMeta   meta;
  final int          rawCount;
  final int          unseenCount;
  final VoidCallback onTap;

  const _PanelRow({
    required this.meta,
    required this.rawCount,
    required this.unseenCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: meta.color.withValues(alpha: 0.25)),
            ),
            child: Icon(meta.icon, color: meta.color, size: 20),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meta.label,
                    style: const TextStyle(
                        color:      _textPri,
                        fontSize:   13,
                        fontWeight: FontWeight.w700)),
                Text(meta.subtitle,
                    style: const TextStyle(
                        color:      _textSec,
                        fontSize:   11,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: meta.color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$rawCount pending',
                  style: TextStyle(
                      color:      meta.color,
                      fontSize:   11,
                      fontWeight: FontWeight.w800),
                ),
              ),
              if (unseenCount > 0) ...[
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                        color: _danger, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$unseenCount new',
                    style: const TextStyle(
                        color:      _danger,
                        fontSize:   10,
                        fontWeight: FontWeight.w700),
                  ),
                ]),
              ],
            ],
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 13, color: meta.color),
        ]),
      ),
    );
  }
}