// Ensures a 24-bit DB color (0xRRGGBB) is converted to ARGB for Flutter Color()
int rgbToArgb(int rgb) => 0xFF000000 | (rgb & 0x00FFFFFF);


