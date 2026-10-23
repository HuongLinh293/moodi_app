import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/widgets/crumpled_paper.dart';

void main() {
  testWidgets('Paper surface renders through folding stages', (tester) async {
    tester.view.physicalSize = const Size(960, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: const ColoredBox(
            color: Color(0xFFF8F3EA),
            child: Row(
              children: [
                SizedBox(
                  width: 240,
                  height: 230,
                  child: CrumpledPaper(
                    amount: 0,
                    text: 'A note',
                    reducedMotion: true,
                  ),
                ),
                SizedBox(
                  width: 240,
                  height: 230,
                  child: CrumpledPaper(
                    amount: .32,
                    text: 'A note',
                    reducedMotion: true,
                  ),
                ),
                SizedBox(
                  width: 240,
                  height: 230,
                  child: CrumpledPaper(
                    amount: .64,
                    text: 'A note',
                    reducedMotion: true,
                  ),
                ),
                SizedBox(
                  width: 240,
                  height: 230,
                  child: CrumpledPaper(
                    amount: 1,
                    text: 'A note',
                    reducedMotion: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage(CrumpledPaper.assetPath),
        tester.element(find.byType(CrumpledPaper).first),
      );
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (Platform.environment['PAPER_PREVIEW'] == '1') {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final preview = await boundary.toImage(pixelRatio: 2);
        final bytes = await preview.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/mindra-paper-stages.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        preview.dispose();
      });
    }
  });
}
