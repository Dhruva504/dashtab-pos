import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/app_widgets.dart';

/// Asks the user where to save [data] via the OS save dialog and writes it.
///
/// Returns the chosen path, or null if the dialog was cancelled.
Future<String?> saveFileToChosenLocation({
  required BuildContext context,
  required String data,
  required String defaultName,
  required String label,
  String? subtitle,
}) async {
  final location = await getSaveLocation(
    suggestedName: defaultName,
    acceptedTypeGroups: [
      XTypeGroup(label: label, extensions: [defaultName.split('.').last]),
    ],
  );
  if (location == null) return null; // user cancelled

  final file = File(location.path);
  await file.writeAsString(data);

  if (context.mounted) {
    showToast(
      context,
      'Saved to ${location.path}',
      subtitle: subtitle,
      icon: AppIcons.download,
    );
  }
  return location.path;
}

/// Turns rows into CSV text. The first row is the header; every cell is
/// quoted and escaped so commas, quotes and newlines are safe.
String buildCsv(List<List<Object?>> rows) {
  String cell(Object? v) {
    final s = (v ?? '').toString();
    return '"${s.replaceAll('"', '""')}"';
  }

  return rows.map((r) => r.map(cell).join(',')).join('\r\n');
}
