import 'dart:ui';

/// OpenType features required for Arabic to shape correctly: contextual
/// alternates and ligatures select the initial/medial/final letter forms that
/// make a word look joined, and the mark features position harakat.
///
/// Apply these to any Arabic [TextStyle] that is built from more than one
/// [TextSpan]. Flutter shapes text per style run, so a word split across spans
/// only stays joined when every run carries the same font, size and weight —
/// vary the colour alone, never the weight.
const arabicShapingFeatures = [
  FontFeature.enable('ccmp'),
  FontFeature.enable('mark'),
  FontFeature.enable('mkmk'),
  FontFeature.enable('rlig'),
  FontFeature.enable('liga'),
  FontFeature.enable('calt'),
];
