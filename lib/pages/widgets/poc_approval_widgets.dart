// poc_approval_widgets.dart
// Shared UI widgets used by IEPocApprovalPage, CoasterPocApprovalPage,
// and FcPocApprovalPage. Import this file in all three pages.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trackall_app/services/approval_lov.dart';

// ─────────────────────────────────────────────
// DESIGN TOKENS  (keep in sync with each page)
// ─────────────────────────────────────────────
const kPageBg       = Color(0xFFF0F4FF);
const kSurface      = Colors.white;
const kBorderLight  = Color(0xFFDDE3F0);
const kAccent       = Color(0xFF3B82F6);
const kAccentLight  = Color(0xFFEFF6FF);
const kCyan         = Color(0xFF06B6D4);
const kTextPri      = Color(0xFF0F172A);
const kTextSec      = Color(0xFF64748B);
const kTextHint     = Color(0xFFADB5BD);
const kSuccess      = Color(0xFF16A34A);
const kSuccessLight = Color(0xFFF0FDF4);
const kDanger       = Color(0xFFDC2626);
const kDangerLight  = Color(0xFFFEF2F2);
const kWarning      = Color(0xFFD97706);

// ─────────────────────────────────────────────
// DROPDOWN FIELD — tappable chip → bottom sheet
// ─────────────────────────────────────────────
class DropdownField<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const DropdownField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SearchableDropdownSheet<T>(
        label:      label,
        icon:       icon,
        items:      items,
        itemLabel:  itemLabel,
        selected:   value,
        onSelected: (v) { onChanged(v); Navigator.pop(context); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = value != null;
    return GestureDetector(
      onTap: () => isActive ? onChanged(null) : _openSheet(context),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? kAccentLight : kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isActive ? kAccent.withValues(alpha: 0.5) : kBorderLight,
              width: 1),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.03), blurRadius: 3)],
        ),
        child: Row(children: [
          Icon(icon, size: 12, color: isActive ? kAccent : kTextHint),
          const SizedBox(width: 5),
          Expanded(child: Text(
            isActive ? itemLabel(value as T) : label,
            style: TextStyle(color: isActive ? kAccent : kTextHint,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400),
            overflow: TextOverflow.ellipsis,
          )),
          Icon(
            isActive ? Icons.cancel_rounded : Icons.keyboard_arrow_down_rounded,
            size: 13,
            color: isActive ? kAccent.withValues(alpha: 0.6) : kTextHint,
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SEARCHABLE DROPDOWN SHEET
// ─────────────────────────────────────────────
class SearchableDropdownSheet<T> extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<T> items;
  final String Function(T) itemLabel;
  final T? selected;
  final ValueChanged<T?> onSelected;

  const SearchableDropdownSheet({
    super.key,
    required this.label,
    required this.icon,
    required this.items,
    required this.itemLabel,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<SearchableDropdownSheet<T>> createState() =>
      _SearchableDropdownSheetState<T>();
}

class _SearchableDropdownSheetState<T>
    extends State<SearchableDropdownSheet<T>> {
  final _ctrl = TextEditingController();
  List<T> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.items);
    _ctrl.addListener(() {
      final q = _ctrl.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? List.from(widget.items)
            : widget.items
                .where((e) => widget.itemLabel(e).toLowerCase().contains(q))
                .toList();
      });
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.65;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(top: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: kBorderLight,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Container(width: 32, height: 32,
                decoration: BoxDecoration(color: kAccentLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kAccent.withValues(alpha: 0.2))),
                child: Icon(widget.icon, size: 14, color: kAccent)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Select ${widget.label}",
                  style: const TextStyle(color: kTextPri, fontSize: 14,
                      fontWeight: FontWeight.w800)),
              Text("${widget.items.length} options",
                  style: const TextStyle(color: kTextHint, fontSize: 10,
                      fontWeight: FontWeight.w500)),
            ])),
            if (widget.selected != null)
              GestureDetector(
                onTap: () => widget.onSelected(null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: kDangerLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kDanger.withValues(alpha: 0.25))),
                  child: const Text("Clear",
                      style: TextStyle(color: kDanger, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(width: 30, height: 30,
                  decoration: BoxDecoration(color: kPageBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorderLight)),
                  child: const Icon(Icons.close_rounded, size: 14, color: kTextSec)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _ctrl, autofocus: true,
            style: const TextStyle(fontSize: 12, color: kTextPri,
                fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: "Search ${widget.label.toLowerCase()}...",
              hintStyle: const TextStyle(fontSize: 12, color: kTextHint),
              prefixIcon: const Icon(Icons.search_rounded, size: 14, color: kTextHint),
              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? GestureDetector(onTap: () => _ctrl.clear(),
                      child: const Icon(Icons.close_rounded, size: 13, color: kTextHint))
                  : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 0),
              filled: true, fillColor: kPageBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: kBorderLight, width: 1)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: kBorderLight, width: 1)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kAccent, width: 1.5)),
            ),
          ),
        ),
        Divider(height: 1, color: kBorderLight),
        InkWell(
          onTap: () => widget.onSelected(null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            color: widget.selected == null ? kAccentLight : Colors.transparent,
            child: Row(children: [
              Container(width: 28, height: 28,
                  decoration: BoxDecoration(
                      color: widget.selected == null ? kAccent : kPageBg,
                      borderRadius: BorderRadius.circular(7)),
                  child: Icon(Icons.select_all_rounded, size: 13,
                      color: widget.selected == null ? Colors.white : kTextHint)),
              const SizedBox(width: 10),
              Expanded(child: Text("All ${widget.label}",
                  style: TextStyle(
                      color: widget.selected == null ? kAccent : kTextSec,
                      fontSize: 12,
                      fontWeight: widget.selected == null
                          ? FontWeight.w700 : FontWeight.w400))),
              if (widget.selected == null)
                const Icon(Icons.check_rounded, size: 14, color: kAccent),
            ]),
          ),
        ),
        Divider(height: 1, color: kBorderLight),
        Flexible(
          child: _filtered.isEmpty
              ? Padding(padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.search_off_rounded, color: kTextHint, size: 28),
                    const SizedBox(height: 8),
                    Text('No results for "${_ctrl.text}"',
                        style: const TextStyle(color: kTextHint, fontSize: 12)),
                  ]))
              : ListView.separated(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16),
                  shrinkWrap: true,
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: kBorderLight),
                  itemBuilder: (_, i) {
                    final item       = _filtered[i];
                    final lbl        = widget.itemLabel(item);
                    final isSelected = widget.selected == item;
                    final q          = _ctrl.text.toLowerCase();
                    return InkWell(
                      onTap: () => widget.onSelected(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        color: isSelected ? kAccentLight : Colors.transparent,
                        child: Row(children: [
                          Container(width: 28, height: 28,
                              decoration: BoxDecoration(
                                  color: isSelected ? kAccent : kPageBg,
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                      color: isSelected ? kAccent : kBorderLight)),
                              child: Center(child: isSelected
                                  ? const Icon(Icons.check_rounded,
                                      size: 13, color: Colors.white)
                                  : Text(lbl[0].toUpperCase(),
                                      style: const TextStyle(color: kTextSec,
                                          fontSize: 10, fontWeight: FontWeight.w700)))),
                          const SizedBox(width: 10),
                          Expanded(child: HighlightText(
                              text: lbl, query: q, isSelected: isSelected)),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: kAccent,
                                  borderRadius: BorderRadius.circular(6)),
                              child: const Text("Selected",
                                  style: TextStyle(color: Colors.white,
                                      fontSize: 9, fontWeight: FontWeight.w700)),
                            ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// HIGHLIGHT TEXT
// ─────────────────────────────────────────────
class HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final bool isSelected;

  const HighlightText({
    super.key,
    required this.text,
    required this.query,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text,
          style: TextStyle(color: isSelected ? kAccent : kTextPri,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
          overflow: TextOverflow.ellipsis);
    }
    final lower = text.toLowerCase();
    final idx   = lower.indexOf(query);
    if (idx == -1) {
      return Text(text,
          style: const TextStyle(color: kTextPri, fontSize: 12,
              fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis);
    }
    return RichText(
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
            color: kTextPri),
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(text: text.substring(idx, idx + query.length),
              style: const TextStyle(color: kAccent, fontWeight: FontWeight.w800,
                  backgroundColor: Color(0xFFEFF6FF))),
          if (idx + query.length < text.length)
            TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STATUS DROPDOWN
// ─────────────────────────────────────────────
class StatusDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const StatusDropdown({super.key, required this.value, required this.onChanged});

  static const _options = [
    {'label': 'Pending',  'value': 'Pending'},
    {'label': 'Approved', 'value': 'Approved'},
    {'label': 'Rejected', 'value': 'Rejected'},
  ];

  Color _colorFor(String v) {
    if (v == 'Approved') return kSuccess;
    if (v == 'Rejected') return kDanger;
    if (v == 'Pending')  return kWarning;
    return kTextHint;
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(color: kBorderLight,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: kAccentLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kAccent.withValues(alpha: 0.2))),
                  child: const Icon(Icons.filter_alt_rounded, size: 14, color: kAccent)),
              const SizedBox(width: 10),
              const Expanded(child: Text("Filter by Status",
                  style: TextStyle(color: kTextPri, fontSize: 14,
                      fontWeight: FontWeight.w800))),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 30, height: 30,
                    decoration: BoxDecoration(color: kPageBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kBorderLight)),
                    child: const Icon(Icons.close_rounded, size: 14, color: kTextSec)),
              ),
            ]),
          ),
          Divider(height: 1, color: kBorderLight),
          InkWell(
            onTap: () { onChanged(''); Navigator.pop(context); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              color: value.isEmpty ? kAccentLight : Colors.transparent,
              child: Row(children: [
                Container(width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: value.isEmpty ? kAccent : kPageBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: value.isEmpty ? kAccent : kBorderLight)),
                    child: Icon(Icons.select_all_rounded, size: 14,
                        color: value.isEmpty ? Colors.white : kTextHint)),
                const SizedBox(width: 12),
                const Expanded(child: Text("All Status",
                    style: TextStyle(color: kTextSec, fontSize: 13,
                        fontWeight: FontWeight.w500))),
                if (value.isEmpty)
                  const Icon(Icons.check_rounded, size: 16, color: kAccent),
              ]),
            ),
          ),
          Divider(height: 1, color: kBorderLight),
          ..._options.map((o) {
            final v          = o['value']!;
            final lbl        = o['label']!;
            final c          = _colorFor(v);
            final isSelected = value == v;
            return Column(children: [
              InkWell(
                onTap: () { onChanged(v); Navigator.pop(context); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  color: isSelected ? c.withValues(alpha: 0.07) : Colors.transparent,
                  child: Row(children: [
                    Container(width: 32, height: 32,
                        decoration: BoxDecoration(
                            color: isSelected ? c : c.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(
                          v == 'Approved' ? Icons.check_circle_rounded
                              : v == 'Rejected' ? Icons.cancel_rounded
                              : Icons.hourglass_empty_rounded,
                          size: 15,
                          color: isSelected ? Colors.white : c,
                        )),
                    const SizedBox(width: 12),
                    Expanded(child: Text(lbl,
                        style: TextStyle(color: isSelected ? c : kTextPri,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w800 : FontWeight.w500))),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: c,
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text("Active",
                            style: TextStyle(color: Colors.white,
                                fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                  ]),
                ),
              ),
              Divider(height: 1, color: kBorderLight),
            ]);
          }),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive    = value.isNotEmpty;
    final activeColor = _colorFor(value);
    return GestureDetector(
      onTap: () => isActive ? onChanged('') : _openSheet(context),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.07) : kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isActive ? activeColor.withValues(alpha: 0.45) : kBorderLight,
              width: 1),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.03), blurRadius: 3)],
        ),
        child: Row(children: [
          Container(width: 6, height: 6,
              decoration: BoxDecoration(
                  color: isActive ? activeColor : kTextHint,
                  shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Expanded(child: Text(isActive ? value : "Status",
              style: TextStyle(color: isActive ? activeColor : kTextHint,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400),
              overflow: TextOverflow.ellipsis)),
          Icon(isActive ? Icons.cancel_rounded : Icons.keyboard_arrow_down_rounded,
              size: 13,
              color: isActive ? activeColor.withValues(alpha: 0.6) : kTextHint),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STAT PILL
// ─────────────────────────────────────────────
class StatPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const StatPill({super.key, required this.label, required this.count,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text("$label: $count",
            style: TextStyle(color: color, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 0.2)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// POC CARD
// ─────────────────────────────────────────────
class PocCard extends StatefulWidget {
  final PocListItem item;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const PocCard({
    super.key,
    required this.item,
    required this.index,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<PocCard> createState() => _PocCardState();
}

class _PocCardState extends State<PocCard> {
  bool _expanded = false;

  Map<String, String> _parseTitleFields() {
    final fields   = <String, String>{};
    final raw      = widget.item.title;
    final patterns = [
      'Buyer Name', 'POC No', 'Item Name', 'FOB', 'CM', 'Order Type',
    ];
    for (int i = 0; i < patterns.length; i++) {
      final key        = patterns[i];
      final start      = raw.indexOf('$key:');
      if (start == -1) continue;
      final valueStart = start + key.length + 1;
      final nextKey    = i + 1 < patterns.length
          ? raw.indexOf('${patterns[i + 1]}:')
          : -1;
      final value = nextKey == -1
          ? raw.substring(valueStart).trim()
          : raw.substring(valueStart, nextKey).trim();
      fields[key] = value;
    }
    return fields;
  }

  @override
  Widget build(BuildContext context) {
    final fields     = _parseTitleFields();
    final isApproved = widget.item.flagIe.toLowerCase() == 'approved';
    final isRejected = widget.item.flagIe.toLowerCase() == 'rejected';
    final isPending  = !isApproved && !isRejected;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorderLight, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8, offset: const Offset(0, 2))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          Container(height: 3,
              decoration: BoxDecoration(gradient: LinearGradient(
                colors: isPending
                    ? [kAccent, kCyan]
                    : [widget.item.statusColor,
                       widget.item.statusColor.withValues(alpha: 0.55)],
                begin: Alignment.centerLeft,
                end:   Alignment.centerRight,
              ))),
          GestureDetector(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 32, height: 32,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [kAccent, kCyan],
                            begin: Alignment.topLeft,
                            end:   Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.center,
                    child: Text("${widget.index}",
                        style: const TextStyle(color: Colors.white,
                            fontSize: 12, fontWeight: FontWeight.w800))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    if (fields['Buyer Name'] != null)
                      FieldChip(label: fields['Buyer Name']!, color: kAccent),
                    const SizedBox(width: 6),
                    if (fields['POC No'] != null)
                      FieldChip(label: fields['POC No']!, color: kCyan),
                  ]),
                  const SizedBox(height: 5),
                  if (fields['Item Name'] != null)
                    Text(fields['Item Name']!,
                        style: const TextStyle(color: kTextPri, fontSize: 13,
                            fontWeight: FontWeight.w700, height: 1.3)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (fields['FOB'] != null)
                      MiniChip(label: "FOB: ${fields['FOB']}", color: kSuccess),
                    if (fields['CM'] != null)
                      MiniChip(label: "CM: ${fields['CM']}", color: kWarning),
                    if (fields['Order Type'] != null)
                      MiniChip(label: fields['Order Type']!, color: kTextSec),
                  ]),
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: widget.item.statusBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: widget.item.statusColor.withValues(alpha: 0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(widget.item.statusIcon,
                          color: widget.item.statusColor, size: 11),
                      const SizedBox(width: 4),
                      Text(widget.item.flagIe,
                          style: TextStyle(color: widget.item.statusColor,
                              fontSize: 10, fontWeight: FontWeight.w800,
                              letterSpacing: 0.3)),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: kTextSec, size: 18),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(children: [
              Divider(height: 1, color: kBorderLight),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: kPageBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kBorderLight)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Icon(Icons.info_outline_rounded,
                          color: kAccent, size: 13),
                      const SizedBox(width: 7),
                      Expanded(child: Text(widget.item.description,
                          style: const TextStyle(color: kTextSec,
                              fontSize: 12, height: 1.5,
                              fontWeight: FontWeight.w500))),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  if (widget.item.createdOn != null)
                    Row(children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: kTextHint, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        "Created: ${DateFormat('dd MMM yyyy').format(widget.item.createdOn!)}",
                        style: const TextStyle(color: kTextSec, fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ]),
                  const SizedBox(height: 10),
                  if (isPending)
                    Row(children: [
                      Expanded(child: ActionBtn(
                        label:   "Approve",
                        icon:    Icons.check_circle_outline_rounded,
                        color:   kSuccess,
                        bgColor: kSuccessLight,
                        onTap:   widget.onApprove,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: ActionBtn(
                        label:   "Reject",
                        icon:    Icons.cancel_outlined,
                        color:   kDanger,
                        bgColor: kDangerLight,
                        onTap:   widget.onReject,
                      )),
                    ])
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: widget.item.statusBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: widget.item.statusColor.withValues(alpha: 0.2))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(widget.item.statusIcon,
                            color: widget.item.statusColor, size: 15),
                        const SizedBox(width: 7),
                        Text("Already ${widget.item.flagIe}",
                            style: TextStyle(color: widget.item.statusColor,
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FIELD CHIP
// ─────────────────────────────────────────────
class FieldChip extends StatelessWidget {
  final String label;
  final Color color;
  const FieldChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25))),
    child: Text(label, style: TextStyle(color: color, fontSize: 10,
        fontWeight: FontWeight.w700, letterSpacing: 0.2)),
  );
}

// ─────────────────────────────────────────────
// MINI CHIP
// ─────────────────────────────────────────────
class MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const MiniChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.15))),
    child: Text(label, style: TextStyle(color: color, fontSize: 10,
        fontWeight: FontWeight.w600)),
  );
}

// ─────────────────────────────────────────────
// ACTION BUTTON
// ─────────────────────────────────────────────
class ActionBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const ActionBtn({super.key, required this.label, required this.icon,
      required this.color, required this.bgColor, required this.onTap});

  @override
  State<ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<ActionBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: _pressed ? widget.color.withValues(alpha: 0.15) : widget.bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _pressed ? widget.color.withValues(alpha: 0.5)
                              : widget.color.withValues(alpha: 0.25),
              width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(widget.icon, color: widget.color, size: 15),
          const SizedBox(width: 6),
          Text(widget.label, style: TextStyle(color: widget.color,
              fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CONFIRM DIALOG
// ─────────────────────────────────────────────
class ConfirmDialog extends StatelessWidget {
  final String action;
  final String title;
  const ConfirmDialog({super.key, required this.action, required this.title});

  @override
  Widget build(BuildContext context) {
    final isApprove = action == 'Approved';
    final color     = isApprove ? kSuccess : kDanger;
    final bgColor   = isApprove ? kSuccessLight : kDangerLight;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(color: kSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorderLight, width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 32, offset: const Offset(0, 8))]),
        child: Padding(padding: const EdgeInsets.all(24), child: Column(
            mainAxisSize: MainAxisSize.min, children: [
          Container(width: 60, height: 60,
              decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor,
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5)),
              child: Icon(isApprove
                  ? Icons.check_circle_outline_rounded
                  : Icons.cancel_outlined,
                  color: color, size: 30)),
          const SizedBox(height: 16),
          Text("Confirm $action",
              style: const TextStyle(color: kTextPri, fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text("Are you sure you want to ${action.toLowerCase()} this POC?",
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextSec, fontSize: 13, height: 1.5)),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(color: kPageBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorderLight)),
                  alignment: Alignment.center,
                  child: const Text("Cancel", style: TextStyle(color: kTextSec,
                      fontSize: 13, fontWeight: FontWeight.w700))),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context, true),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(color: color,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3),
                          blurRadius: 8, offset: const Offset(0, 3))]),
                  alignment: Alignment.center,
                  child: Text(action, style: const TextStyle(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w800))),
            )),
          ]),
        ])),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REMARKS DIALOG
// ─────────────────────────────────────────────
class RemarksDialog extends StatelessWidget {
  final TextEditingController ctrl;
  final String title;

  const RemarksDialog({super.key, required this.ctrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(color: kSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorderLight, width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 32, offset: const Offset(0, 8))]),
        child: Padding(padding: const EdgeInsets.all(24), child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: kDangerLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kDanger.withValues(alpha: 0.3))),
                child: const Icon(Icons.cancel_outlined, color: kDanger, size: 18)),
            const SizedBox(width: 12),
            const Expanded(child: Text("Reject POC",
                style: TextStyle(color: kTextPri, fontSize: 17,
                    fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 18),
          const Text("Remarks (optional)",
              style: TextStyle(color: kTextSec, fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(controller: ctrl, maxLines: 3,
              style: const TextStyle(color: kTextPri, fontSize: 13,
                  fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Enter reason for rejection...",
                hintStyle: const TextStyle(color: kTextHint, fontSize: 13),
                filled: true, fillColor: kPageBg,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: kBorderLight, width: 1)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: kBorderLight, width: 1)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: kDanger.withValues(alpha: 0.5),
                        width: 1.5)),
              )),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(color: kPageBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorderLight)),
                  alignment: Alignment.center,
                  child: const Text("Cancel", style: TextStyle(color: kTextSec,
                      fontSize: 13, fontWeight: FontWeight.w700))),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context, true),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(color: kDanger,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: kDanger.withValues(alpha: 0.3),
                          blurRadius: 8, offset: const Offset(0, 3))]),
                  alignment: Alignment.center,
                  child: const Text("Confirm Reject",
                      style: TextStyle(color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w800))),
            )),
          ]),
        ])),
      ),
    );
  }
}