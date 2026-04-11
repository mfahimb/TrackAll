// lib/services/notification/poc_notification/poc_notification_service.dart

import 'package:flutter/foundation.dart';
import 'package:trackall_app/services/approval_lov.dart';

const _stageMenuIds = {
  ApprovalStage.ie:      149,
  ApprovalStage.coaster: 147,
  ApprovalStage.fc:      148,
};

class PocNotificationService extends ChangeNotifier {
  static final PocNotificationService _instance =
      PocNotificationService._internal();
  factory PocNotificationService() => _instance;
  PocNotificationService._internal();

  final _svc = ApprovalLovService();

  // Raw counts from API
  Map<ApprovalStage, int> _rawCounts = {
    ApprovalStage.ie:      0,
    ApprovalStage.coaster: 0,
    ApprovalStage.fc:      0,
  };

  // How many the user has already "seen" (dismissed/tapped)
  Map<ApprovalStage, int> _seenCounts = {
    ApprovalStage.ie:      0,
    ApprovalStage.coaster: 0,
    ApprovalStage.fc:      0,
  };

  List<ApprovalStage> newAlerts = [];

  bool _loading = false;
  bool get loading => _loading;

  // Unseen badge counts (raw minus seen, floored at 0)
  Map<ApprovalStage, int> get counts => {
    for (final s in ApprovalStage.values)
      s: ((_rawCounts[s] ?? 0) - (_seenCounts[s] ?? 0)).clamp(0, 9999),
  };

  // Full API counts — used for panel visibility (item stays until truly resolved)
  Map<ApprovalStage, int> get rawCounts => Map.from(_rawCounts);

  int get totalPending => counts.values.fold(0, (s, v) => s + v);

  // ── Poll API ──────────────────────────────────────────────────────────────
  Future<void> refresh(String company, List<int> assignedMenuIds) async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    final previousRaw = Map<ApprovalStage, int>.from(_rawCounts);
    final next        = <ApprovalStage, int>{};

    for (final entry in _stageMenuIds.entries) {
      final stage  = entry.key;
      final menuId = entry.value;

      if (!assignedMenuIds.contains(menuId)) {
        next[stage] = 0;
        continue;
      }

      try {
        final rows = await _svc.fetchPocList(
          company: company,
          stage:   stage,
          status:  'Pending',
        );
        next[stage] = rows.length; // ✅ fixed
      } catch (_) {
        next[stage] = previousRaw[stage] ?? 0;
      }
    }

    // Only alert when count genuinely increased vs last raw poll
    final alerts = <ApprovalStage>[];
    for (final stage in ApprovalStage.values) {
      final newCount  = next[stage]        ?? 0;
      final prevCount = previousRaw[stage] ?? 0;

      if (newCount > prevCount) {
        // New items arrived — reset seen so badge shows them
        _seenCounts[stage] = 0;
        alerts.add(stage);
      } else if (newCount < (_seenCounts[stage] ?? 0)) {
        // API count dropped below seen offset — clamp seen down
        _seenCounts[stage] = newCount;
      }
    }

    _rawCounts = next;
    newAlerts  = alerts;
    _loading   = false;
    notifyListeners();
  }

  void clearAlerts() => newAlerts = [];

  /// Reduce badge by [amount] when user taps a banner.
  /// The item stays in the panel — only badge reduces.
  void markSeen(ApprovalStage stage, int amount) {
    final maxSeen = _rawCounts[stage] ?? 0;
    _seenCounts[stage] =
        ((_seenCounts[stage] ?? 0) + amount).clamp(0, maxSeen);
    notifyListeners();
  }

  /// Zero-out badge for one stage (e.g. user opens full list).
  void markStageAsSeen(ApprovalStage stage) {
    _seenCounts[stage] = _rawCounts[stage] ?? 0;
    notifyListeners();
  }

  /// Zero-out all badges.
  void markAllSeen() {
    for (final k in _rawCounts.keys) {
      _seenCounts[k] = _rawCounts[k] ?? 0;
    }
    notifyListeners();
  }
}
