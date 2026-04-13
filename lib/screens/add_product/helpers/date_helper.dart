import 'package:flutter/material.dart';

DateTime? parseStoredDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String formatDateForStorage(DateTime date) => formatDate(date);

DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

Future<DateTime?> pickDate(BuildContext context, DateTime initialDate) async {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
}
