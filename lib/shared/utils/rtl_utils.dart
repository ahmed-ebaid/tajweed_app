import 'package:flutter/material.dart';

/// Helpers for managing text direction in a multilingual app
/// that supports both RTL (Arabic, Urdu) and LTR languages.
class RtlUtils {
  /// Returns the appropriate TextDirection for a given language code.
  static TextDirection directionFor(String langCode) {
    const rtl = {'ar', 'ur', 'fa', 'he'};
    return rtl.contains(langCode) ? TextDirection.rtl : TextDirection.ltr;
  }

  /// Wraps a widget in a [Directionality] for the given language code.
  static Widget withDirection({
    required String langCode,
    required Widget child,
  }) {
    return Directionality(
      textDirection: directionFor(langCode),
      child: child,
    );
  }

  /// Arabic Quranic text is always RTL regardless of the app's UI language.
  static const quranDirection = TextDirection.rtl;

  /// Returns edge insets that swap start/end based on direction.
  static EdgeInsets symmetricInsets({
    required bool isRtl,
    double start = 0,
    double end = 0,
    double top = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.fromLTRB(
      isRtl ? end : start,
      top,
      isRtl ? start : end,
      bottom,
    );
  }
}
