import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mindra/screens/paper_release_sheet.dart';
import 'package:mindra/state/mindra_state.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets('Paper tap, hold, throw, undo and expiry at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = MindraState(initialEntries: []);
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    PaperReleaseSheet.show(context: context, state: state),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('paper-writing')),
        'Lời viết riêng tư',
      );
      await tester.tap(find.byKey(const ValueKey('paper-primary')));
      await tester.pumpAndSettle();
      final paper = find.byKey(const ValueKey('crumple-paper'));
      await tester.tap(paper);
      await tester.pump();
      final hold = await tester.startGesture(tester.getCenter(paper));
      await tester.pump(const Duration(seconds: 2));
      await hold.up();
      await tester.pump();
      await tester.fling(paper, const Offset(0, -150), 800);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paper-undo')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('paper-undo')));
      await tester.pumpAndSettle();
      expect(find.text('Lời viết riêng tư'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('paper-primary')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paper-primary')));
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paper-undo')), findsNothing);
      expect(find.text('Lời viết đã được xóa.'), findsOneWidget);
      expect(state.entries, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('paper-primary')));
      await tester.pumpAndSettle();
    });
  }
}
