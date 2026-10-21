import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/ai_chat/widgets/mantra_mandala_background.dart';

Widget _host({required bool reduceMotion, ThemeData? theme}) =>
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Builder(
        builder:
            (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: const Scaffold(body: MantraMandalaBackground()),
            ),
      ),
    );

bool _ticking(WidgetTester tester) => tester.binding.hasScheduledFrame;

void main() {
  testWidgets('animates and is hidden from accessibility', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(reduceMotion: false));
    await tester.pump(const Duration(seconds: 1));
    expect(_ticking(tester), isTrue);
    expect(find.bySemanticsLabel(RegExp('ॐ')), findsNothing);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('holds still when reduced motion is requested', (tester) async {
    await tester.pumpWidget(_host(reduceMotion: true));
    await tester.pump(const Duration(seconds: 1));
    expect(_ticking(tester), isFalse);
  });

  testWidgets('paints in dark theme and at wide sizes', (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(reduceMotion: true, theme: AppTheme.dark));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
