import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xterm/xterm.dart';

import '../_fixture/_fixture.dart';

@GenerateNiceMocks([MockSpec<TerminalInputHandler>()])
import 'terminal_view_test.mocks.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'htop golden test',
    (tester) async {
      final terminal = Terminal();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal),
        ),
      ));

      terminal.write(TestFixtures.htop_80x25_3s());
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/htop_80x25_3s.png'),
      );
    },
    skip: !Platform.isMacOS,
  );

  testWidgets(
    'color golden test',
    (tester) async {
      final terminal = Terminal();

      // terminal.lineFeedMode = true;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            textStyle: TerminalStyle(fontSize: 8),
          ),
        ),
      ));

      terminal.write(TestFixtures.colors().replaceAll('\n', '\r\n'));
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/colors.png'),
      );
    },
    skip: !Platform.isMacOS,
  );

  group('TerminalView.readOnly', () {
    testWidgets('works', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, readOnly: true, autofocus: true),
        ),
      ));

      // https://github.com/flutter/flutter/issues/11181#issuecomment-314936646
      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      binding.testTextInput.enterText('ls -al');
      await binding.idle();

      expect(terminalOutput.join(), isEmpty);
    });

    testWidgets('does not block input when false', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, readOnly: false, autofocus: true),
        ),
      ));

      // https://github.com/flutter/flutter/issues/11181#issuecomment-314936646
      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      binding.testTextInput.enterText('ls -al');
      await binding.idle();

      expect(terminalOutput.join(), 'ls -al');
    });
  });

  group('TerminalView.focusNode', () {
    testWidgets('is not listened when terminal is disposed', (tester) async {
      final terminal = Terminal();

      final focusNode = FocusNode();

      final isActive = ValueNotifier(true);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: isActive,
            builder: (context, isActive, child) {
              if (!isActive) {
                return Container();
              }
              return TerminalView(
                terminal,
                focusNode: focusNode,
                autofocus: true,
              );
            },
          ),
        ),
      ));

      // ignore: invalid_use_of_protected_member
      expect(focusNode.hasListeners, isTrue);

      isActive.value = false;
      await tester.pumpAndSettle();

      // ignore: invalid_use_of_protected_member
      expect(focusNode.hasListeners, isFalse);
    });

    testWidgets('does not dispose external focus node', (tester) async {
      final terminal = Terminal();

      final focusNode = FocusNode();

      final isActive = ValueNotifier(true);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: isActive,
            builder: (context, isActive, child) {
              if (!isActive) {
                return Container();
              }
              return TerminalView(
                terminal,
                focusNode: focusNode,
                autofocus: true,
              );
            },
          ),
        ),
      ));

      isActive.value = false;
      await tester.pumpAndSettle();

      expect(() => focusNode.addListener(() {}), returnsNormally);
    });
  });

  group('TerminalController.pointerInputs', () {
    testWidgets('works', (tester) async {
      final output = <String>[];

      final terminal = Terminal(onOutput: output.add);

      // enable mouse reporting
      terminal.write('\x1b[?1000h');

      final terminalView = TerminalController(
        pointerInputs: PointerInputs.all(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: terminalView,
            ),
          ),
        ),
      );

      final pointer = TestPointer(1, PointerDeviceKind.mouse);

      await tester.sendEventToBinding(pointer.down(Offset(1, 1)));

      await tester.pumpAndSettle();

      expect(output, isNotEmpty);
    });

    testWidgets('does not respond when disabled', (tester) async {
      final output = <String>[];

      final terminal = Terminal(onOutput: output.add);

      // enable mouse reporting
      terminal.write('\x1b[?1000h');

      final terminalView = TerminalController(
        pointerInputs: PointerInputs.none(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: terminalView,
            ),
          ),
        ),
      );

      final pointer = TestPointer(1, PointerDeviceKind.mouse);

      await tester.sendEventToBinding(pointer.down(Offset(1, 1)));

      await tester.pumpAndSettle();

      expect(output, isEmpty);
    });
  });

  group('TerminalView.autofocus', () {
    testWidgets('works', (tester) async {
      final terminal = Terminal();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              autofocus: true,
              focusNode: focusNode,
            ),
          ),
        ),
      );

      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('works in hardwareKeyboardOnly mode', (tester) async {
      final terminal = Terminal();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              autofocus: true,
              focusNode: focusNode,
              hardwareKeyboardOnly: true,
            ),
          ),
        ),
      );

      expect(focusNode.hasFocus, isTrue);
    });
  });

  group('TerminalView.hardwareKeyboardOnly', () {
    testWidgets('works', (tester) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              autofocus: true,
              hardwareKeyboardOnly: true,
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);

      expect(output.join(), 'abc');
    });
  });

  group('TerminalView.textScaler', () {
    testWidgets('works', (tester) async {
      final terminal = Terminal();

      final textScaler = ValueNotifier(TextScaler.linear(1.0));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<TextScaler>(
              valueListenable: textScaler,
              builder: (context, textScaler, child) {
                return TerminalView(
                  terminal,
                  textScaler: textScaler,
                );
              },
            ),
          ),
        ),
      );

      terminal.write('Hello World');
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/text_scale_factor@1x.png'),
      );

      textScaler.value = TextScaler.linear(2.0);
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/text_scale_factor@2x.png'),
      );
    });

    testWidgets('can obtain textScaler from parent', (tester) async {
      final terminal = Terminal();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: TerminalView(
                terminal,
              ),
            ),
          ),
        ),
      );

      terminal.write('Hello World');
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/text_scale_factor@2x.png'),
      );
    });
  });

  group('TerminalView.inputHandler', () {
    testWidgets('works', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true),
      ));

      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);

      await tester.pumpAndSettle();

      expect(terminalOutput.join(), '\x04');
    });

    testWidgets('can convert text input to key events', (tester) async {
      final inputHandler = MockTerminalInputHandler();
      when(inputHandler.call(any)).thenAnswer((invocation) => 'AAA');

      final terminalOutput = <String>[];
      final terminal = Terminal(
        inputHandler: inputHandler,
        onOutput: terminalOutput.add,
      );

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true),
      ));

      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      binding.testTextInput.enterText('c');
      await binding.idle();

      await tester.pumpAndSettle();

      verify(inputHandler.call(any));
      expect(terminalOutput.join(), 'AAA');
    });
  });

  group('TerminalView IME composing', () {
    testWidgets('streams composing text to the terminal instead of buffering it',
        (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true),
      ));

      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      // Simulate Gboard's word-prediction composing region growing
      // character by character, the way it reports "c" then "co" while
      // suggesting "cool" above the keyboard.
      binding.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'c',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ));
      await binding.idle();

      // Before the composing region commits, the character must already be
      // at the terminal -- a raw shell should never silently swallow
      // keystrokes while a word is being predicted.
      expect(terminalOutput.join(), 'c');

      binding.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'co',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ));
      await binding.idle();

      expect(terminalOutput.join(), 'co');

      // Composing commits with a trailing space; only the new character
      // should be sent, not the whole word again.
      binding.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'co ',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange.empty,
      ));
      await binding.idle();

      expect(terminalOutput.join(), 'co ');
    });

    testWidgets('reconciles a composing correction instead of duplicating it',
        (tester) async {
      final inputHandler = MockTerminalInputHandler();
      when(inputHandler.call(any)).thenAnswer((invocation) {
        final event =
            invocation.positionalArguments[0] as TerminalKeyboardEvent;
        return event.key == TerminalKey.backspace ? '<BS>' : null;
      });

      final terminalOutput = <String>[];
      final terminal = Terminal(
        inputHandler: inputHandler,
        onOutput: terminalOutput.add,
      );

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true),
      ));

      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      binding.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'coo',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      ));
      await binding.idle();

      expect(terminalOutput.join(), 'coo');

      // Gboard swaps the candidate to a shorter correction ("co") rather
      // than extending it -- the already-sent trailing "o" must be deleted,
      // not left to silently diverge from the remote's copy.
      binding.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'co',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ));
      await binding.idle();

      expect(terminalOutput.join(), 'coo<BS>');
    });
  });

  group('TerminalView.onSingleTapConfirmed', () {
    testWidgets('fires for a plain tap, after the double-tap window',
        (tester) async {
      final terminal = Terminal();

      final tapUpCells = <int>[];
      final confirmedCells = <int>[];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            autofocus: true,
            onTapUp: (details, offset) => tapUpCells.add(offset.x),
            onSingleTapConfirmed: (details, offset) =>
                confirmedCells.add(offset.x),
          ),
        ),
      ));
      await tester.pump();

      await tester.tapAt(tester.getCenter(find.byType(TerminalView)));
      await tester.pump();

      // onTapUp fires immediately -- onSingleTapConfirmed does not, yet.
      expect(tapUpCells, hasLength(1));
      expect(confirmedCells, isEmpty);

      await tester.pump(kDoubleTapTimeout);

      expect(confirmedCells, hasLength(1));
    });

    testWidgets('never fires for either tap of a double-tap', (tester) async {
      final terminal = Terminal();

      final tapUpCells = <int>[];
      final confirmedCells = <int>[];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            autofocus: true,
            onTapUp: (details, offset) => tapUpCells.add(offset.x),
            onSingleTapConfirmed: (details, offset) =>
                confirmedCells.add(offset.x),
          ),
        ),
      ));
      await tester.pump();

      final position = tester.getCenter(find.byType(TerminalView));

      await tester.tapAt(position);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(position);
      await tester.pump();

      // Both taps of the double-tap still reach onTapUp...
      expect(tapUpCells, hasLength(2));

      // ...but neither is ever confirmed as a single tap, even once the
      // double-tap window has fully elapsed.
      await tester.pump(kDoubleTapTimeout);

      expect(confirmedCells, isEmpty);
    });
  });

  group('TerminalView selection-aware delete', () {
    testWidgets('deletes the whole selection when it is on the cursor row',
        (tester) async {
      final inputHandler = MockTerminalInputHandler();
      when(inputHandler.call(any)).thenAnswer((invocation) {
        final event =
            invocation.positionalArguments[0] as TerminalKeyboardEvent;
        switch (event.key) {
          case TerminalKey.arrowLeft:
            return '<L>';
          case TerminalKey.arrowRight:
            return '<R>';
          case TerminalKey.backspace:
            return '<BS>';
          default:
            return null;
        }
      });

      final terminalOutput = <String>[];
      final terminal = Terminal(
        inputHandler: inputHandler,
        onOutput: terminalOutput.add,
      );
      terminal.write('hello world');

      final controller = TerminalController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            controller: controller,
            autofocus: true,
            deleteDetection: true,
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      // Selects "hello" (columns 0-4) the same way double-tap-to-select
      // does, while the real cursor sits at column 11 (end of "world").
      final boundary = terminal.buffer.getWordBoundary(const CellOffset(0, 0))!;
      controller.setSelection(
        terminal.buffer.createAnchorFromOffset(boundary.begin),
        terminal.buffer.createAnchorFromOffset(boundary.end),
        mode: SelectionMode.line,
      );

      // The software keyboard's backspace glyph, via deleteDetection.
      binding.testTextInput.updateEditingValue(const TextEditingValue(
        text: ' ',
        selection: TextSelection.collapsed(offset: 1),
      ));
      await binding.idle();
      await tester.pump();

      // Cursor moves from column 11 to column 5 (6 lefts), then 5
      // backspaces remove "hello" (columns 0-4).
      expect(terminalOutput.join(), '<L>' * 6 + '<BS>' * 5);
      expect(controller.selection, isNull);
    });

    testWidgets('only clears the selection when it is on a different row',
        (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.write('hello\r\nworld');

      final controller = TerminalController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            controller: controller,
            autofocus: true,
            deleteDetection: true,
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      // "hello" is on row 0; the real cursor is on row 1, after "world".
      final boundary = terminal.buffer.getWordBoundary(const CellOffset(0, 0))!;
      controller.setSelection(
        terminal.buffer.createAnchorFromOffset(boundary.begin),
        terminal.buffer.createAnchorFromOffset(boundary.end),
        mode: SelectionMode.line,
      );

      binding.testTextInput.updateEditingValue(const TextEditingValue(
        text: ' ',
        selection: TextSelection.collapsed(offset: 1),
      ));
      await binding.idle();
      await tester.pump();

      // Nothing live to delete on the cursor's own line -- no arrow keys,
      // no backspace, just the selection clearing.
      expect(terminalOutput, isEmpty);
      expect(controller.selection, isNull);
    });

    testWidgets('sends a single backspace when there is no selection',
        (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.write('hi');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, autofocus: true, deleteDetection: true),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      binding.testTextInput.updateEditingValue(const TextEditingValue(
        text: ' ',
        selection: TextSelection.collapsed(offset: 1),
      ));
      await binding.idle();
      await tester.pump();

      expect(terminalOutput.join().codeUnits, [0x7f]);
    });

    testWidgets(
        'also deletes the whole selection via a hardware backspace key event',
        (tester) async {
      final inputHandler = MockTerminalInputHandler();
      when(inputHandler.call(any)).thenAnswer((invocation) {
        final event =
            invocation.positionalArguments[0] as TerminalKeyboardEvent;
        switch (event.key) {
          case TerminalKey.arrowLeft:
            return '<L>';
          case TerminalKey.arrowRight:
            return '<R>';
          case TerminalKey.backspace:
            return '<BS>';
          default:
            return null;
        }
      });

      final terminalOutput = <String>[];
      final terminal = Terminal(
        inputHandler: inputHandler,
        onOutput: terminalOutput.add,
      );
      terminal.write('hello world');

      final controller = TerminalController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            controller: controller,
            autofocus: true,
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(seconds: 1));

      final boundary = terminal.buffer.getWordBoundary(const CellOffset(0, 0))!;
      controller.setSelection(
        terminal.buffer.createAnchorFromOffset(boundary.begin),
        terminal.buffer.createAnchorFromOffset(boundary.end),
        mode: SelectionMode.line,
      );

      // Backspace delivered as a genuine hardware-style KeyEvent, bypassing
      // CustomTextEdit.onDelete entirely -- the path a real Android
      // keyboard's on-screen backspace glyph can (and per a real-device
      // report, does) take instead of the deleteDetection editingValue
      // shrink the other test in this group exercises.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(terminalOutput.join(), '<L>' * 6 + '<BS>' * 5);
      expect(controller.selection, isNull);
    });
  });

  group('TerminalView.simulateScroll', () {
    testWidgets('works', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.useAltBuffer();

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true, simulateScroll: true),
      ));

      await tester.drag(find.byType(TerminalView), const Offset(0, -100));

      expect(terminalOutput.join(), contains('\x1B[B'));
    });

    testWidgets('does nothing when disabled', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.useAltBuffer();

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true, simulateScroll: false),
      ));

      await tester.drag(find.byType(TerminalView), const Offset(0, -100));

      expect(terminalOutput.join(), isEmpty);
    });
  });
}
