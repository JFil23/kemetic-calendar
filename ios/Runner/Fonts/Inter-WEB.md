# Web UI Inter compatibility face

Inter-Regular.ttf is generated from the adjacent Inter-Variable.ttf at its
original defaults: optical size 14, weight 400. Both are covered by Inter-OFL.txt.
All glyph outlines, outline flags, advance widths and Unicode mappings are
preserved. Generate with `fonttools==4.60.1` and
`python3 tool/build_inter_web_font.py`; the script verifies the source checksum
and equivalence before writing the font. No font download is required at runtime.

AppFonts.ui selects InterWeb on web and the original Inter face on native.
Keep consumers on this shared selector. Do not replace native Inter: its implicit
fallback rendering differs slightly with a static face. Web comparison of the
actual Pages and PostedFlowArtifact widgets was pixel-identical to the original
at 390 × 844, including UI weights 400/500/600/700. Native visual references must
remain unchanged. Keep the web family before native Inter in the manifest and
visual-test loader to preserve existing implicit native fallback selection.

The September 29 recording shows missing letters across Inter consumers. The
static web face removes the variable-font path from those consumers. It is a
compatibility mitigation, not proof that every intermittent GPU fault is fixed.
The source variable face stays bundled for native and existing fallback behavior.
Warm caches and account persistence are independent and unchanged.

The pixel-ink tests exercise the actual static font. The diagnostic entry point
`tool/text_rendering_probe.dart` uses production widgets with static content,
without account access. It is never the application release entry point.
