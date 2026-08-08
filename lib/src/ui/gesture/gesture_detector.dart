import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// How far a touch is allowed to drift, in logical pixels, while still
/// counting as "held still" for long-press-to-select purposes.
///
/// [LongPressGestureRecognizer] defaults this tolerance to the platform's
/// ambient touch slop, which is the same threshold an ancestor [Scrollable]
/// uses to decide a drag has started. That means the two recognizers race
/// the same distance check against a fixed 500ms timeout: a real drag that
/// starts with a brief, natural pause (or that stays under an unusually
/// generous platform touch slop) never breaks that tolerance in time, so the
/// long press wins the gesture arena outright and scrolling is starved for
/// the rest of that touch, no matter how far the finger moves afterward.
/// Using a small, fixed tolerance here -- independent of the platform's
/// (possibly much larger) scroll slop -- makes the long press yield to any
/// real dragging motion well before its deadline can steal the arena.
const _kLongPressSelectSlopTolerance = 8.0;

/// A [LongPressGestureRecognizer] with a small, fixed [preAcceptSlopTolerance]
/// (see [_kLongPressSelectSlopTolerance]) instead of the platform's ambient
/// touch slop. [LongPressGestureRecognizer]'s own constructor doesn't expose
/// [preAcceptSlopTolerance], so it's overridden here as a getter instead.
class _SelectLongPressGestureRecognizer extends LongPressGestureRecognizer {
  _SelectLongPressGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
  });

  @override
  double? get preAcceptSlopTolerance => _kLongPressSelectSlopTolerance;
}

class TerminalGestureDetector extends StatefulWidget {
  const TerminalGestureDetector({
    super.key,
    this.child,
    this.onSingleTapUp,
    this.onSingleTapConfirmed,
    this.onTapUp,
    this.onTapDown,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.onTertiaryTapDown,
    this.onTertiaryTapUp,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressUp,
    this.onDragStart,
    this.onDragUpdate,
    this.onDoubleTapDown,
  });

  final Widget? child;

  final GestureTapUpCallback? onTapUp;

  final GestureTapUpCallback? onSingleTapUp;

  /// Like [onSingleTapUp], but only invoked once it's certain the tap isn't
  /// the first half of a double-tap -- i.e. it's held for [kDoubleTapTimeout]
  /// and discarded if a second tap arrives in that window. Unlike
  /// [onSingleTapUp], which is already skipped for the *second* tap of a
  /// double-tap, this also skips the *first* tap, at the cost of firing
  /// [kDoubleTapTimeout] later than the gesture itself.
  final GestureTapUpCallback? onSingleTapConfirmed;

  final GestureTapDownCallback? onTapDown;

  final GestureTapDownCallback? onSecondaryTapDown;

  final GestureTapUpCallback? onSecondaryTapUp;

  final GestureTapDownCallback? onDoubleTapDown;

  final GestureTapDownCallback? onTertiaryTapDown;

  final GestureTapUpCallback? onTertiaryTapUp;

  final GestureLongPressStartCallback? onLongPressStart;

  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;

  final GestureLongPressUpCallback? onLongPressUp;

  final GestureDragStartCallback? onDragStart;

  final GestureDragUpdateCallback? onDragUpdate;

  @override
  State<TerminalGestureDetector> createState() =>
      _TerminalGestureDetectorState();
}

class _TerminalGestureDetectorState extends State<TerminalGestureDetector> {
  Timer? _doubleTapTimer;

  Offset? _lastTapOffset;

  // True if a second tap down of a double tap is detected. Used to discard
  // subsequent tap up / tap hold of the same tap.
  bool _isDoubleTap = false;

  // The most recent single tap-up, held until [_doubleTapTimer] confirms no
  // second tap arrived, at which point it's reported via
  // [TerminalGestureDetector.onSingleTapConfirmed].
  TapUpDetails? _pendingSingleTapDetails;

  @override
  void dispose() {
    _doubleTapTimer?.cancel();
    super.dispose();
  }

  // The down handler is force-run on success of a single tap and optimistically
  // run before a long press success.
  void _handleTapDown(TapDownDetails details) {
    widget.onTapDown?.call(details);

    if (_doubleTapTimer != null &&
        _isWithinDoubleTapTolerance(details.globalPosition)) {
      // If there was already a previous tap, the second down hold/tap is a
      // double tap down. The pending single tap never gets confirmed -- it
      // was the first half of this double tap, not a tap of its own.
      widget.onDoubleTapDown?.call(details);

      _doubleTapTimer!.cancel();
      _doubleTapTimeout();
      _isDoubleTap = true;
    }
  }

  void _handleTapUp(TapUpDetails details) {
    widget.onTapUp?.call(details);

    if (!_isDoubleTap) {
      widget.onSingleTapUp?.call(details);
      _lastTapOffset = details.globalPosition;
      _pendingSingleTapDetails = details;
      _doubleTapTimer = Timer(kDoubleTapTimeout, _confirmPendingSingleTap);
    }
    _isDoubleTap = false;
  }

  // Only reached when [_doubleTapTimer] elapses on its own -- if a second tap
  // arrived in time, [_handleTapDown] already cancelled it via
  // [_doubleTapTimeout], so this tap is now confirmed to not be part of a
  // double-tap.
  void _confirmPendingSingleTap() {
    final details = _pendingSingleTapDetails;
    _doubleTapTimeout();
    if (details != null) {
      widget.onSingleTapConfirmed?.call(details);
    }
  }

  void _doubleTapTimeout() {
    _doubleTapTimer = null;
    _lastTapOffset = null;
    _pendingSingleTapDetails = null;
  }

  bool _isWithinDoubleTapTolerance(Offset secondTapOffset) {
    if (_lastTapOffset == null) {
      return false;
    }

    final Offset difference = secondTapOffset - _lastTapOffset!;
    return difference.distance <= kDoubleTapSlop;
  }

  @override
  Widget build(BuildContext context) {
    final gestures = <Type, GestureRecognizerFactory>{};

    gestures[TapGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
      () => TapGestureRecognizer(debugOwner: this),
      (TapGestureRecognizer instance) {
        instance
          ..onTapDown = _handleTapDown
          ..onTapUp = _handleTapUp
          ..onSecondaryTapDown = widget.onSecondaryTapDown
          ..onSecondaryTapUp = widget.onSecondaryTapUp
          ..onTertiaryTapDown = widget.onTertiaryTapDown
          ..onTertiaryTapUp = widget.onTertiaryTapUp;
      },
    );

    gestures[_SelectLongPressGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<_SelectLongPressGestureRecognizer>(
      () => _SelectLongPressGestureRecognizer(
        debugOwner: this,
        supportedDevices: {
          PointerDeviceKind.touch,
          // PointerDeviceKind.mouse, // for debugging purposes only
        },
      ),
      (_SelectLongPressGestureRecognizer instance) {
        instance
          ..onLongPressStart = widget.onLongPressStart
          ..onLongPressMoveUpdate = widget.onLongPressMoveUpdate
          ..onLongPressUp = widget.onLongPressUp;
      },
    );

    gestures[PanGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
      () => PanGestureRecognizer(
        debugOwner: this,
        supportedDevices: <PointerDeviceKind>{PointerDeviceKind.mouse},
      ),
      (PanGestureRecognizer instance) {
        instance
          ..dragStartBehavior = DragStartBehavior.down
          ..onStart = widget.onDragStart
          ..onUpdate = widget.onDragUpdate;
      },
    );

    return RawGestureDetector(
      gestures: gestures,
      excludeFromSemantics: true,
      child: widget.child,
    );
  }
}
