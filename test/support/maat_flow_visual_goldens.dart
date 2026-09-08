import 'dart:io';

const _maatFlowGoldenRoot = '../../visual_reference/maat_flows/goldens';

/// Keeps pixel-golden comparisons exact on each renderer used by this build.
///
/// The approved macOS captures remain the visual acceptance authority. Linux
/// CI uses separately reviewed, exact-pixel captures because Skia text and
/// image rasterization differ by host platform even under the same pinned
/// Flutter and engine revisions. No tolerance or image normalization is used.
String get maatFlowVisualGoldenRoot =>
    Platform.isLinux ? '$_maatFlowGoldenRoot/linux' : _maatFlowGoldenRoot;
