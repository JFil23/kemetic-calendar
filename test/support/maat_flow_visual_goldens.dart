import 'dart:ffi';
import 'dart:io';

const _maatFlowGoldenRoot = '../../visual_reference/maat_flows/goldens';

/// Keeps pixel-golden comparisons exact on each renderer used by this build.
///
/// The approved macOS captures remain the visual acceptance authority. Linux
/// CI uses separately reviewed, exact-pixel captures because Skia text and
/// image rasterization differ by host platform and CPU architecture even under
/// the same pinned Flutter and engine revisions. No tolerance or image
/// normalization is used.
String get maatFlowVisualGoldenRoot =>
    platformVisualGoldenRoot(_maatFlowGoldenRoot);

String platformVisualGoldenRoot(String root) {
  if (!Platform.isLinux) {
    return root;
  }
  return switch (Abi.current()) {
    Abi.linuxX64 => '$root/linux-x64',
    Abi.linuxArm64 => '$root/linux',
    final abi => throw UnsupportedError(
      'No exact visual golden authority is registered for $abi.',
    ),
  };
}
