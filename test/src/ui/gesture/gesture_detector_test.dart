import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalGestureDetector long-press-select vs scroll', () {
    testWidgets(
      'a touch drag that starts with a brief near-still pause still scrolls',
      (tester) async {
        final terminal = Terminal(maxLines: 10000);
        for (var i = 0; i < 300; i++) {
          terminal.write('line $i\r\n');
        }

        final scrollController = ScrollController();

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              scrollController: scrollController,
              autofocus: true,
            ),
          ),
        ));
        await tester.pump();

        final startPixels = scrollController.position.pixels;

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(TerminalView)),
          kind: PointerDeviceKind.touch,
        );

        // A brief, near-still pause at the start of the drag, lasting past
        // the 500ms long-press deadline: 0.6px every 30ms (600ms total,
        // ~12px cumulative). That stays under the platform's default touch
        // slop (18px) for the whole pause, but crosses this widget's
        // tighter long-press-select tolerance (8px) partway through.
        for (var i = 0; i < 20; i++) {
          await gesture.moveBy(const Offset(0, 0.6));
          await tester.pump(const Duration(milliseconds: 30));
        }

        // Now drag for real, well past the long-press deadline (600ms so
        // far).
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, 20));
          await tester.pump(const Duration(milliseconds: 16));
        }

        await gesture.up();
        await tester.pumpAndSettle();

        final endPixels = scrollController.position.pixels;

        // The drag should have scrolled away from the bottom. Before the
        // fix, the long press wins the gesture arena outright at its 500ms
        // deadline (the initial ~12px drift never exceeds the ambient 18px
        // touch slop), permanently starving the Scrollable's drag
        // recognizer for the rest of this touch -- so endPixels would
        // equal startPixels.
        expect(endPixels, lessThan(startPixels));
      },
    );
  });
}
