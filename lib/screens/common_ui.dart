
import 'package:flutter/material.dart';

String fmtDate(String? isoOrNull) {
  if (isoOrNull == null) return '-';
  try {
    final cleaned = isoOrNull.split('.').first; // handle 'YYYY-MM-DD HH:MM:SS.SSS'
    final d = DateTime.tryParse(cleaned);
    if (d == null) return isoOrNull;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  } catch (_) {
    return isoOrNull;
  }
}

Widget blueCard({required String title, required Widget child}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Color(0xFFBFDBFE)),
      boxShadow: [
        BoxShadow(
          color: Color(0xFF93C5FD).withOpacity(0.35),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A))),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}
