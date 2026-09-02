import 'package:flutter/material.dart';

/// Shared governance UI helpers used across panels.
/// Extracted from _DashboardScreenState so multiple widget files can reuse them.

/// Card container used by every governance panel (Sessions / Memory / Security / System).
Widget govCard({required String title, required List<Widget> children}) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B).withAlpha(100),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF38BDF8).withAlpha(30)),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Color(0xFFC4E7FF),
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
}

/// Key-value row used across governance panels.
Widget govKV(String key, String value, {Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 190,
          child: SelectableText(
            key,
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 11, color: Color(0xFF87929A)),
          ),
        ),
        Expanded(
          child: SelectableText(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: valueColor ?? const Color(0xFFD4E4FA),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Color-coded status indicator used by session rows.
Color govStatusColor(String status) {
  switch (status) {
    case 'completed':
      return const Color(0xFF34D399);
    case 'awaiting_ceo_decision':
    case 'pending_ceo_review':
      return const Color(0xFFFBBF24);
    case 'processing_in_background':
      return const Color(0xFF38BDF8);
    case 'skipped':
      return const Color(0xFFF87171);
    default:
      return const Color(0xFFBDC8D1);
  }
}

/// Shows a loading spinner when [loading] is true, otherwise [child].
Widget govLoadingOr(bool loading, Widget child) {
  if (loading) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
      ),
    );
  }
  return child;
}

/// Chip-wrap section used by Security and System panels.
Widget govChipSection({
  required String label,
  required List<String> items,
  required Color borderColor,
  required Color textColor,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SelectableText(
        label,
        style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 0.8,
            color: Color(0xFF87929A)),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: items
            .map((item) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF020617),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: borderColor),
                  ),
                  child: SelectableText(
                    item,
                    style: TextStyle(
                        fontFamily: 'monospace', fontSize: 10, color: textColor),
                  ),
                ))
            .toList(),
      ),
    ],
  );
}

/// Input decoration helper for governance text fields.
InputDecoration govInputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF87929A)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFF3E484F)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFF3E484F)),
    ),
    isDense: true,
  );
}

// ---------------------------------------------------------------------------
// WASM-safe JSON coercion helpers.
// dart2wasm enforces `as` casts strictly at runtime. JSON-decoded values may
// arrive as Map<Object?, Object?> or List<Object?> variants that fail direct
// casts to Map<String, dynamic> / List<dynamic>. These helpers tolerate all
// shapes without throwing.
// ---------------------------------------------------------------------------

/// Safely coerces [value] to a `Map<String, dynamic>` without throwing.
Map<String, dynamic> govSafeMap(dynamic value) {
  if (value == null) return {};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return {};
}

/// Safely coerces [value] to a `List<dynamic>` without throwing.
List<dynamic> govSafeList(dynamic value) {
  if (value == null) return const [];
  if (value is List) return value;
  return const [];
}

/// Safely coerces [value] to a `List<String>` without throwing.
List<String> govSafeStringList(dynamic value) {
  final list = govSafeList(value);
  return list
      .map((e) => e?.toString() ?? '')
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Extracts theme display names from a themes field that may be a list of
/// maps (each with a 'name' key) or a plain list of strings.
List<String> govThemeNames(dynamic themes) {
  final list = govSafeList(themes);
  final names = <String>[];
  for (final t in list) {
    if (t is Map) {
      final name = (t['name'] ?? '').toString();
      if (name.isNotEmpty) names.add(name);
    } else if (t != null) {
      final name = t.toString();
      if (name.isNotEmpty) names.add(name);
    }
  }
  return names;
}

/// Safely coerces [value] to an int without throwing.
int govSafeInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
