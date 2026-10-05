import 'dart:convert';
import 'package:mobile/core/theme/app_theme.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';
import 'package:mobile/features/nodes/kemetic_node_list_page.dart';
import 'package:mobile/features/nodes/kemetic_node_reader_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      anonKey: 'anon-key-0123456789012345678901234567890123456789',
    );
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final f in fonts) {
      final loader = FontLoader(f['family']);
      for (final a in f['fonts']) {
        loader.addFont(rootBundle.load(a['asset']));
      }
      await loader.load();
    }
  });
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final id in [
      'list',
      'cosmic_order',
      'human_emergence',
      'rise_of_kush_and_kemet',
      'maat',
      'djehuty',
      'esna_temple',
      'nile',
      'rekh_wer',
      'epagomenal_days',
    ]) {
      testWidgets('$id supplied copy fits ${size.width}x${size.height}', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: AppTheme.dark,
              debugShowCheckedModeBanner: false,
              home: id == 'list'
                  ? const KemeticNodeListPage()
                  : KemeticNodeReaderPage(
                      node: KemeticNodeLibrary.resolve(id)!,
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final captureDir = Platform.environment['HAW_LIBRARY_CAPTURE_DIR'];
        if (captureDir != null) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('$captureDir/$id-${size.width.toInt()}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        final expectedTables = switch (id) {
          'cosmic_order' => 3,
          'human_emergence' => 8,
          'rise_of_kush_and_kemet' => 1,
          _ => 0,
        };
        final tables = find.byType(Table);
        expect(tables, findsNWidgets(expectedTables));
        if (expectedTables > 0) {
          final expectedRows = KemeticNodeLibrary.resolve(id)!.body
              .split('\n\n')
              .where((b) => b.startsWith('|'))
              .map((b) => b.split('\n').length - 1)
              .toList();
          for (var index = 0; index < expectedTables; index++) {
            final tableFinder = tables.at(index);
            final table = tester.widget<Table>(tableFinder);
            for (final width in table.columnWidths!.values) {
              expect(
                (width as FixedColumnWidth).value,
                lessThanOrEqualTo(size.width - 40),
              );
            }
            expect(
              tester.widget<Table>(tableFinder).children.length,
              expectedRows[index],
            );
            await Scrollable.ensureVisible(
              tester.element(tableFinder),
              alignment: 0.05,
            );
            await tester.pumpAndSettle();
            final horizontal = find
                .ancestor(
                  of: tableFinder,
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is SingleChildScrollView &&
                        w.scrollDirection == Axis.horizontal,
                  ),
                )
                .first;
            final position = tester
                .state<ScrollableState>(
                  find
                      .descendant(
                        of: horizontal,
                        matching: find.byType(Scrollable),
                      )
                      .first,
                )
                .position;
            if (position.maxScrollExtent > 0) {
              position.jumpTo(position.maxScrollExtent);
              await tester.pumpAndSettle();
              expect(position.pixels, position.maxScrollExtent);
            }
            if (captureDir != null) {
              await tester.runAsync(() async {
                final boundary =
                    key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 2);
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '$captureDir/$id-table-$index-${size.width.toInt()}.png',
                ).writeAsBytes(data!.buffer.asUint8List());
                image.dispose();
              });
            }
            expect(tester.takeException(), isNull);
          }
        }
        if (id != 'list') {
          final scroll = find.byWidgetPredicate(
            (w) => w is SingleChildScrollView && w.controller != null,
          );
          await tester.drag(scroll.first, const Offset(0, -600));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
