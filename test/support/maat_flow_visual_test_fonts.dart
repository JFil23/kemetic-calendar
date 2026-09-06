import 'package:flutter/services.dart';

/// Loads the production typefaces used by fixture-driven Maat Flow captures.
Future<void> loadMaatFlowVisualTestFonts() async {
  final gentium = FontLoader('GentiumPlus')
    ..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Regular.ttf'))
    ..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Bold.ttf'));
  final cormorant = FontLoader('CormorantGaramond')
    ..addFont(rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Regular.ttf'))
    ..addFont(rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Italic.ttf'))
    ..addFont(rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Medium.ttf'))
    ..addFont(
      rootBundle.load('ios/Runner/Fonts/CormorantGaramond-MediumItalic.ttf'),
    )
    ..addFont(
      rootBundle.load('ios/Runner/Fonts/CormorantGaramond-SemiBold.ttf'),
    );
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  final hieroglyphs = FontLoader('Noto Sans Egyptian Hieroglyphs')
    ..addFont(
      rootBundle.load(
        'ios/Runner/Fonts/NotoSansEgyptianHieroglyphs-Regular.ttf',
      ),
    );

  await Future.wait(<Future<void>>[
    gentium.load(),
    cormorant.load(),
    materialIcons.load(),
    hieroglyphs.load(),
  ]);
}
