import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

extension BuildContextExtensions on BuildContext {
  AppLocalizations get loc => AppLocalizations.of(this)!;

  String t(String key) => AppLocalizations.of(this)!.t(key);
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
