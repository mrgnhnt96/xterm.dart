import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/src/ui/custom_text_edit.dart';
import 'package:xterm/xterm.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomTextEditState.currentTextEditingValue', () {
    testWidgets('matches the baseline after typing resets the connection',
        (tester) async {
      final terminal = Terminal();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, autofocus: true),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      binding.testTextInput.enterText('hi');
      await binding.idle();
      await tester.pump();

      final state =
          tester.state<CustomTextEditState>(find.byType(CustomTextEdit));

      // The widget already told the platform connection to reset back to
      // baseline (empty, since deleteDetection defaults to false) once "hi"
      // was forwarded to the terminal -- currentTextEditingValue, which the
      // platform can query at any time (e.g. an IME re-syncing its buffer
      // when the input connection is shown again), must reflect that same
      // reset. Before the fix, this stayed stuck on the just-typed "hi",
      // which let a re-sync hand already-sent characters back to the IME
      // to be included again in the next real keystroke.
      expect(
        state.currentTextEditingValue,
        const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        ),
      );
    });

    testWidgets(
        'matches the baseline after typing resets the connection (deleteDetection)',
        (tester) async {
      final terminal = Terminal();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, autofocus: true, deleteDetection: true),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      binding.testTextInput.enterText('  hi');
      await binding.idle();
      await tester.pump();

      final state =
          tester.state<CustomTextEditState>(find.byType(CustomTextEdit));

      expect(
        state.currentTextEditingValue,
        const TextEditingValue(
          text: '  ',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
    });
  });

  group('CustomTextEdit IME re-sync', () {
    testWidgets(
        'typing after the IME re-syncs from currentTextEditingValue does not duplicate characters',
        (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, autofocus: true),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      binding.testTextInput.enterText('hi');
      await binding.idle();
      await tester.pump();

      expect(terminalOutput.join(), 'hi');

      final state =
          tester.state<CustomTextEditState>(find.byType(CustomTextEdit));

      // Simulate a real IME re-syncing its own buffer from
      // currentTextEditingValue -- e.g. Android re-querying existing input
      // state when the connection is shown again, which requestKeyboard()
      // triggers on every tap, including the first tap of a double-tap --
      // then reporting the next keystroke relative to whatever that buffer
      // turned out to be.
      final resynced = state.currentTextEditingValue!;
      binding.testTextInput.updateEditingValue(TextEditingValue(
        text: '${resynced.text}x',
        selection: TextSelection.collapsed(offset: resynced.text.length + 1),
      ));
      await binding.idle();
      await tester.pump();

      // Before the fix, the re-sync picked up the stale "hi" the platform
      // was told to discard, so the next keystroke resent it in full --
      // producing "hi" + "hix" = "hihix" instead of "hi" + "x" = "hix".
      expect(terminalOutput.join(), 'hix');
    });
  });
}
