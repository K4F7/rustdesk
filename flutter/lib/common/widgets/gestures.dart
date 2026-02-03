import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hbb/common/widgets/remote_input.dart';

enum GestureState {
  none,
  oneFingerPan,
  twoFingerScale,
  threeFingerVerticalDrag
}

class TwoFingerScaleStartDetails {
  final Offset localFocalPoint;
  final Offset focalPoint;
  final int pointerA;
  final int pointerB;
  final Offset pointerALocalPosition;
  final Offset pointerBLocalPosition;

  const TwoFingerScaleStartDetails({
    required this.localFocalPoint,
    required this.focalPoint,
    required this.pointerA,
    required this.pointerB,
    required this.pointerALocalPosition,
    required this.pointerBLocalPosition,
  });
}

class TwoFingerScaleUpdateDetails {
  final Offset localFocalPoint;
  final Offset focalPoint;
  final Offset focalPointDelta;
  final double scale;
  final int pointerA;
  final int pointerB;
  final Offset pointerALocalPosition;
  final Offset pointerBLocalPosition;
  final Offset pointerADelta;
  final Offset pointerBDelta;

  const TwoFingerScaleUpdateDetails({
    required this.localFocalPoint,
    required this.focalPoint,
    required this.focalPointDelta,
    required this.scale,
    required this.pointerA,
    required this.pointerB,
    required this.pointerALocalPosition,
    required this.pointerBLocalPosition,
    required this.pointerADelta,
    required this.pointerBDelta,
  });
}

class TwoFingerScaleEndDetails {
  final Velocity velocity;

  const TwoFingerScaleEndDetails({
    required this.velocity,
  });
}

typedef TwoFingerScaleStartCallback = void Function(
    TwoFingerScaleStartDetails details);
typedef TwoFingerScaleUpdateCallback = void Function(
    TwoFingerScaleUpdateDetails details);
typedef TwoFingerScaleEndCallback = void Function(
    TwoFingerScaleEndDetails details);

class CustomTouchGestureRecognizer extends ScaleGestureRecognizer {
  CustomTouchGestureRecognizer({
    Object? debugOwner,
    Set<PointerDeviceKind>? supportedDevices,
  }) : super(
          debugOwner: debugOwner,
          supportedDevices: supportedDevices,
        ) {
    _init();
  }

  // oneFingerPan
  GestureDragStartCallback? onOneFingerPanStart;
  GestureDragUpdateCallback? onOneFingerPanUpdate;
  GestureDragEndCallback? onOneFingerPanEnd;

  // twoFingerScale : scale + pan event
  GestureScaleStartCallback? onTwoFingerScaleStart;
  GestureScaleUpdateCallback? onTwoFingerScaleUpdate;
  GestureScaleEndCallback? onTwoFingerScaleEnd;

  // twoFingerScale with per-pointer deltas/positions
  TwoFingerScaleStartCallback? onTwoFingerScaleStartEx;
  TwoFingerScaleUpdateCallback? onTwoFingerScaleUpdateEx;
  TwoFingerScaleEndCallback? onTwoFingerScaleEndEx;

  // threeFingerVerticalDrag
  GestureDragStartCallback? onThreeFingerVerticalDragStart;
  GestureDragUpdateCallback? onThreeFingerVerticalDragUpdate;
  GestureDragEndCallback? onThreeFingerVerticalDragEnd;

  var _currentState = GestureState.none;

  final Map<int, Offset> _pointerLocalPositions = {};
  final Map<int, Offset> _pointerLocalDeltas = {};

  @override
  void addPointer(PointerDownEvent event) {
    super.addPointer(event);
    _pointerLocalPositions[event.pointer] = event.localPosition;
    _pointerLocalDeltas[event.pointer] = Offset.zero;
  }

  @override
  void rejectGesture(int pointer) {
    // If this recognizer loses the gesture arena, it may stop receiving
    // PointerUp/Cancel events for that pointer. Ensure we don't leak
    // per-pointer bookkeeping, otherwise subsequent two-finger gestures can
    // fail (e.g. pointers length != 2 forever) until the widget is rebuilt.
    _pointerLocalPositions.remove(pointer);
    _pointerLocalDeltas.remove(pointer);
    super.rejectGesture(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (event is PointerMoveEvent) {
      final prev = _pointerLocalPositions[event.pointer];
      if (prev != null) {
        _pointerLocalDeltas[event.pointer] = event.localPosition - prev;
      } else {
        _pointerLocalDeltas[event.pointer] = Offset.zero;
      }
      _pointerLocalPositions[event.pointer] = event.localPosition;
      return;
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerLocalPositions.remove(event.pointer);
      _pointerLocalDeltas.remove(event.pointer);
    }
  }

  @override
  void dispose() {
    _pointerLocalPositions.clear();
    _pointerLocalDeltas.clear();
    super.dispose();
  }

  void _init() {
    debugPrint("CustomTouchGestureRecognizer init");
    // onStart = (d) {};
    onUpdate = (d) {
      if (d.pointerCount == 1 && _currentState != GestureState.oneFingerPan) {
        _currentState = GestureState.oneFingerPan;
        if (onOneFingerPanStart != null) {
          onOneFingerPanStart!(DragStartDetails(
              localPosition: d.localFocalPoint, globalPosition: d.focalPoint));
        }
      } else if (d.pointerCount == 2 &&
          _currentState != GestureState.twoFingerScale) {
        _currentState = GestureState.twoFingerScale;
        if (onTwoFingerScaleStart != null) {
          onTwoFingerScaleStart!(ScaleStartDetails(
              localFocalPoint: d.localFocalPoint, focalPoint: d.focalPoint));
        }
        final ex = _buildTwoFingerStartDetails(ScaleStartDetails(
            localFocalPoint: d.localFocalPoint, focalPoint: d.focalPoint));
        if (ex != null && onTwoFingerScaleStartEx != null) {
          onTwoFingerScaleStartEx!(ex);
        }
      } else if (d.pointerCount == 3 &&
          _currentState != GestureState.threeFingerVerticalDrag) {
        _currentState = GestureState.threeFingerVerticalDrag;
        if (onThreeFingerVerticalDragStart != null) {
          onThreeFingerVerticalDragStart!(
              DragStartDetails(globalPosition: d.localFocalPoint));
        }
        debugPrint("start threeFingerScale");
      }
      if (_currentState != GestureState.none) {
        switch (_currentState) {
          case GestureState.oneFingerPan:
            if (onOneFingerPanUpdate != null) {
              onOneFingerPanUpdate!(_getDragUpdateDetails(d));
            }
            break;
          case GestureState.twoFingerScale:
            if (onTwoFingerScaleUpdate != null) {
              onTwoFingerScaleUpdate!(d);
            }
            final ex = _buildTwoFingerUpdateDetails(d);
            if (ex != null && onTwoFingerScaleUpdateEx != null) {
              onTwoFingerScaleUpdateEx!(ex);
            }
            break;
          case GestureState.threeFingerVerticalDrag:
            if (onThreeFingerVerticalDragUpdate != null) {
              onThreeFingerVerticalDragUpdate!(_getDragUpdateDetails(d));
            }
            break;
          default:
            break;
        }
        return;
      }
    };
    onEnd = (d) {
      debugPrint("ScaleGestureRecognizer onEnd");
      // end
      switch (_currentState) {
        case GestureState.oneFingerPan:
          debugPrint("OneFingerState.pan onEnd");
          if (onOneFingerPanEnd != null) {
            onOneFingerPanEnd!(_getDragEndDetails(d));
          }
          break;
        case GestureState.twoFingerScale:
          debugPrint("TwoFingerState.scale onEnd");
          if (onTwoFingerScaleEnd != null) {
            onTwoFingerScaleEnd!(d);
          }
          if (onTwoFingerScaleEndEx != null) {
            onTwoFingerScaleEndEx!(
                TwoFingerScaleEndDetails(velocity: d.velocity));
          }
          if (isSpecialHoldDragActive) {
            // If we are in special drag mode, we need to reset the state.
            // Otherwise, the next `onTwoFingerScaleUpdate()` will handle a wrong `focalPoint`.
            _currentState = GestureState.none;
            return;
          }
          break;
        case GestureState.threeFingerVerticalDrag:
          debugPrint("ThreeFingerState.vertical onEnd");
          if (onThreeFingerVerticalDragEnd != null) {
            onThreeFingerVerticalDragEnd!(_getDragEndDetails(d));
          }
          break;
        default:
          break;
      }
      _currentState = GestureState.none;
    };
  }

  DragUpdateDetails _getDragUpdateDetails(ScaleUpdateDetails d) =>
      DragUpdateDetails(
          globalPosition: d.focalPoint,
          localPosition: d.localFocalPoint,
          delta: d.focalPointDelta);

  DragEndDetails _getDragEndDetails(ScaleEndDetails d) =>
      DragEndDetails(velocity: d.velocity);

  TwoFingerScaleStartDetails? _buildTwoFingerStartDetails(ScaleStartDetails d) {
    final pointers = _pointerLocalPositions.keys.toList()..sort();
    if (pointers.length != 2) return null;
    final a = pointers[0];
    final b = pointers[1];
    final aPos = _pointerLocalPositions[a];
    final bPos = _pointerLocalPositions[b];
    if (aPos == null || bPos == null) return null;
    return TwoFingerScaleStartDetails(
      localFocalPoint: d.localFocalPoint,
      focalPoint: d.focalPoint,
      pointerA: a,
      pointerB: b,
      pointerALocalPosition: aPos,
      pointerBLocalPosition: bPos,
    );
  }

  TwoFingerScaleUpdateDetails? _buildTwoFingerUpdateDetails(
      ScaleUpdateDetails d) {
    final pointers = _pointerLocalPositions.keys.toList()..sort();
    if (pointers.length != 2) return null;
    final a = pointers[0];
    final b = pointers[1];
    final aPos = _pointerLocalPositions[a];
    final bPos = _pointerLocalPositions[b];
    if (aPos == null || bPos == null) return null;
    final aDelta = _pointerLocalDeltas[a] ?? Offset.zero;
    final bDelta = _pointerLocalDeltas[b] ?? Offset.zero;
    // Consume the deltas to ensure the next update sees 0 movement unless there
    // is a new PointerMoveEvent for that pointer.
    _pointerLocalDeltas[a] = Offset.zero;
    _pointerLocalDeltas[b] = Offset.zero;
    return TwoFingerScaleUpdateDetails(
      localFocalPoint: d.localFocalPoint,
      focalPoint: d.focalPoint,
      focalPointDelta: d.focalPointDelta,
      scale: d.scale,
      pointerA: a,
      pointerB: b,
      pointerALocalPosition: aPos,
      pointerBLocalPosition: bPos,
      pointerADelta: aDelta,
      pointerBDelta: bDelta,
    );
  }
}

class HoldTapMoveGestureRecognizer extends GestureRecognizer {
  HoldTapMoveGestureRecognizer({
    Object? debugOwner,
    Set<PointerDeviceKind>? supportedDevices,
  }) : super(
          debugOwner: debugOwner,
          supportedDevices: supportedDevices,
        );

  GestureDragStartCallback? onHoldDragStart;
  GestureDragUpdateCallback? onHoldDragUpdate;
  GestureDragDownCallback? onHoldDragDown;
  GestureDragCancelCallback? onHoldDragCancel;
  GestureDragEndCallback? onHoldDragEnd;

  bool _isStart = false;
  bool _isResetting = false;

  Timer? _firstTapUpTimer;
  Timer? _secondTapDownTimer;
  _TapTracker? _firstTap;
  _TapTracker? _secondTap;

  PointerDownEvent? _lastPointerDownEvent;

  final Map<int, _TapTracker> _trackers = <int, _TapTracker>{};

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_firstTap == null) {
      switch (event.buttons) {
        case kPrimaryButton:
          if (onHoldDragStart == null &&
              onHoldDragUpdate == null &&
              onHoldDragCancel == null &&
              onHoldDragEnd == null) {
            return false;
          }
          break;
        default:
          return false;
      }
    }
    return super.isPointerAllowed(event);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_firstTap != null) {
      if (!_firstTap!.isWithinGlobalTolerance(event, kDoubleTapSlop)) {
        // Ignore out-of-bounds second taps.
        return;
      } else if (!_firstTap!.hasElapsedMinTime() ||
          !_firstTap!.hasSameButton(event)) {
        // Restart when the second tap is too close to the first (touch screens
        // often detect touches intermittently), or when buttons mismatch.
        _reset();
        return _trackTap(event);
      } else if (onHoldDragDown != null) {
        invokeCallback<void>(
            'onHoldDragDown',
            () => onHoldDragDown!(DragDownDetails(
                globalPosition: event.position,
                localPosition: event.localPosition)));
      }
    }
    _trackTap(event);
  }

  void _trackTap(PointerDownEvent event) {
    _stopFirstTapUpTimer();
    _stopSecondTapDownTimer();
    final _TapTracker tracker = _TapTracker(
      event: event,
      entry: GestureBinding.instance.gestureArena.add(event.pointer, this),
      doubleTapMinTime: kDoubleTapMinTime,
      gestureSettings: gestureSettings,
    );
    _trackers[event.pointer] = tracker;
    _lastPointerDownEvent = event;
    tracker.startTrackingPointer(_handleEvent, event.transform);
  }

  void _handleEvent(PointerEvent event) {
    final _TapTracker tracker = _trackers[event.pointer]!;
    if (event is PointerUpEvent) {
      if (_firstTap == null && _secondTap == null) {
        _registerFirstTap(tracker);
      } else if (_secondTap != null) {
        if (event.pointer == _secondTap!.pointer) {
          if (onHoldDragEnd != null) {
            onHoldDragEnd!(DragEndDetails());
            _secondTap = null;
            _isStart = false;
          }
        }
      } else {
        _rejectTracker(tracker);
        _reset();
      }
    } else if (event is PointerDownEvent) {
      if (_firstTap != null && _secondTap == null) {
        _registerSecondTap(tracker);
      }
    } else if (event is PointerMoveEvent) {
      if (!tracker.isWithinGlobalTolerance(event, kDoubleTapTouchSlop)) {
        if (_firstTap != null && _firstTap!.pointer == event.pointer) {
          // first tap move
          _rejectTracker(tracker);
          _reset();
        } else if (_secondTap != null && _secondTap!.pointer == event.pointer) {
          // debugPrint("_secondTap move");
          // second tap move
          if (!_isStart) {
            _resolve();
          }
          if (onHoldDragUpdate != null) {
            onHoldDragUpdate!(DragUpdateDetails(
                globalPosition: event.position,
                localPosition: event.localPosition,
                delta: event.delta));
          }
        }
      }
    } else if (event is PointerCancelEvent) {
      _rejectTracker(tracker);
      _reset();
    }
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    _TapTracker? tracker = _trackers[pointer];
    // If tracker isn't in the list, check if this is the first tap tracker
    if (tracker == null && _firstTap != null && _firstTap!.pointer == pointer) {
      tracker = _firstTap;
    }
    // If tracker is still null, we rejected ourselves already
    if (tracker != null) {
      _rejectTracker(tracker);
      _reset();
    }
  }

  void _resolve() {
    _stopSecondTapDownTimer();
    final first = _firstTap;
    if (first != null && !first.didResolve) {
      first.didResolve = true;
      first.entry.resolve(GestureDisposition.accepted);
    }
    final second = _secondTap;
    if (second != null && !second.didResolve) {
      second.didResolve = true;
      second.entry.resolve(GestureDisposition.accepted);
    }
    _isStart = true;
    // TODO start details
    if (onHoldDragStart != null) {
      onHoldDragStart!(DragStartDetails(
        kind: _lastPointerDownEvent?.kind,
      ));
    }
  }

  void _rejectTracker(_TapTracker tracker) {
    _checkCancel();
    _isStart = false;
    _trackers.remove(tracker.pointer);
    if (!tracker.didResolve) {
      tracker.didResolve = true;
      tracker.entry.resolve(GestureDisposition.rejected);
    }
    _freezeTracker(tracker);
  }

  @override
  void dispose() {
    _reset();
    super.dispose();
  }

  void _reset() {
    if (_isResetting) return;
    _isResetting = true;
    try {
      _isStart = false;
      // debugPrint("reset");
      _stopFirstTapUpTimer();
      _stopSecondTapDownTimer();
      final first = _firstTap;
      _firstTap = null;
      if (first != null) {
        _rejectTracker(first);
        GestureBinding.instance.gestureArena.release(first.pointer);
      }
      final second = _secondTap;
      _secondTap = null;
      if (second != null) {
        _rejectTracker(second);
        GestureBinding.instance.gestureArena.release(second.pointer);
      }
      _clearTrackers();
    } finally {
      _isResetting = false;
    }
  }

  void _registerFirstTap(_TapTracker tracker) {
    _startFirstTapUpTimer();
    GestureBinding.instance.gestureArena.hold(tracker.pointer);
    // Note, order is important below in order for the clear -> reject logic to
    // work properly.
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _firstTap = tracker;
  }

  void _registerSecondTap(_TapTracker tracker) {
    if (_firstTap != null) {
      _stopFirstTapUpTimer();
      _freezeTracker(_firstTap!);
      _firstTap = null;
    }

    _startSecondTapDownTimer();
    GestureBinding.instance.gestureArena.hold(tracker.pointer);

    _secondTap = tracker;

    // TODO
  }

  void _clearTrackers() {
    final trackers = _trackers.values.toList(growable: false);
    for (final tracker in trackers) {
      _rejectTracker(tracker);
    }
    _trackers.clear();
  }

  void _freezeTracker(_TapTracker tracker) {
    tracker.stopTrackingPointer(_handleEvent);
  }

  void _startFirstTapUpTimer() {
    _firstTapUpTimer ??= Timer(kDoubleTapTimeout, _reset);
  }

  void _startSecondTapDownTimer() {
    _secondTapDownTimer ??= Timer(kDoubleTapTimeout, _resolve);
  }

  void _stopFirstTapUpTimer() {
    if (_firstTapUpTimer != null) {
      _firstTapUpTimer!.cancel();
      _firstTapUpTimer = null;
    }
  }

  void _stopSecondTapDownTimer() {
    if (_secondTapDownTimer != null) {
      _secondTapDownTimer!.cancel();
      _secondTapDownTimer = null;
    }
  }

  void _checkCancel() {
    if (onHoldDragCancel != null) {
      invokeCallback<void>('onHoldDragCancel', onHoldDragCancel!);
    }
  }

  @override
  String get debugDescription => 'double tap';
}

class DoubleFinerTapGestureRecognizer extends GestureRecognizer {
  DoubleFinerTapGestureRecognizer({
    Object? debugOwner,
    Set<PointerDeviceKind>? supportedDevices,
  }) : super(
          debugOwner: debugOwner,
          supportedDevices: supportedDevices,
        );

  GestureTapDownCallback? onDoubleFinerTapDown;
  GestureTapDownCallback? onDoubleFinerTap;
  GestureTapCancelCallback? onDoubleFinerTapCancel;

  Timer? _firstTapTimer;
  _TapTracker? _firstTap;

  PointerDownEvent? _lastPointerDownEvent;

  var _isStart = false;

  final Set<int> _upTap = {};

  final Map<int, _TapTracker> _trackers = <int, _TapTracker>{};
  final Set<int> _heldPointers = <int>{};
  bool _didResolve = false;
  bool _isResetting = false;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_firstTap == null) {
      switch (event.buttons) {
        case kPrimaryButton:
          if (onDoubleFinerTapDown == null &&
              onDoubleFinerTap == null &&
              onDoubleFinerTapCancel == null) {
            return false;
          }
          break;
        default:
          return false;
      }
    }
    return super.isPointerAllowed(event);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_isStart) {
      // second
      if (onDoubleFinerTapDown != null) {
        final TapDownDetails details = TapDownDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
          kind: getKindForPointer(event.pointer),
        );
        invokeCallback<void>(
            'onDoubleFinerTapDown', () => onDoubleFinerTapDown!(details));
      }
    } else {
      // first tap
      _isStart = true;
      _lastPointerDownEvent = event;
      _startFirstTapDownTimer();
    }
    _trackTap(event);
  }

  void _trackTap(PointerDownEvent event) {
    final _TapTracker tracker = _TapTracker(
      event: event,
      entry: GestureBinding.instance.gestureArena.add(event.pointer, this),
      doubleTapMinTime: kDoubleTapMinTime,
      gestureSettings: gestureSettings,
    );
    _trackers[event.pointer] = tracker;
    // debugPrint("_trackers:$_trackers");
    tracker.startTrackingPointer(_handleEvent, event.transform);

    _registerTap(tracker);
  }

  void _handleEvent(PointerEvent event) {
    final _TapTracker? tracker = _trackers[event.pointer];
    if (tracker == null) return;
    if (event is PointerUpEvent) {
      _upTap.add(tracker.pointer);
      // Resolve as soon as we have both pointers up.
      if (_upTap.length == 2) {
        _resolve();
      }
    } else if (event is PointerMoveEvent) {
      if (!tracker.isWithinGlobalTolerance(event, kDoubleTapTouchSlop)) {
        // Reject the whole gesture as soon as we detect movement, so that
        // two-finger scroll/scale can win the arena immediately.
        _reset();
      }
    } else if (event is PointerCancelEvent) {
      _reset();
    }
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    // If we lose the arena for any pointer, drop the whole gesture. This avoids
    // leaving stale held pointers which can break subsequent gestures on
    // pointer-id reuse (observed on Android).
    _reset();
  }

  void _reject(_TapTracker tracker) {
    _trackers.remove(tracker.pointer);
    _releaseHeldPointer(tracker.pointer);
    tracker.entry.resolve(GestureDisposition.rejected);
    _freezeTracker(tracker);
    if (_firstTap != null) {
      if (tracker == _firstTap) {
        _reset();
      } else {
        _checkCancel();
        if (_trackers.isEmpty) {
          _reset();
        }
      }
    }
  }

  @override
  void dispose() {
    _reset();
    super.dispose();
  }

  void _reset() {
    if (_isResetting) return;
    _isResetting = true;
    _stopFirstTapUpTimer();
    _firstTap = null;
    _isStart = false;
    _upTap.clear();
    _lastPointerDownEvent = null;
    _clearTrackers();
    _releaseAllHeldPointers();
    _didResolve = false;
    _isResetting = false;
  }

  void _registerTap(_TapTracker tracker) {
    GestureBinding.instance.gestureArena.hold(tracker.pointer);
    _heldPointers.add(tracker.pointer);
    // Note, order is important below in order for the clear -> reject logic to
    // work properly.
  }

  void _clearTrackers() {
    // Copy first: _reject mutates _trackers.
    final trackers = _trackers.values.toList(growable: false);
    for (final tracker in trackers) {
      _reject(tracker);
    }
    assert(_trackers.isEmpty);
  }

  void _freezeTracker(_TapTracker tracker) {
    tracker.stopTrackingPointer(_handleEvent);
  }

  void _startFirstTapDownTimer() {
    _firstTapTimer ??= Timer(kDoubleTapTimeout, _timeoutCheck);
  }

  void _stopFirstTapUpTimer() {
    if (_firstTapTimer != null) {
      _firstTapTimer!.cancel();
      _firstTapTimer = null;
    }
  }

  void _timeoutCheck() {
    _isStart = false;
    if (_upTap.length == 2) {
      _resolve();
    } else {
      _reset();
    }
    _upTap.clear();
  }

  void _resolve() {
    if (_didResolve) return;
    _didResolve = true;
    _stopFirstTapUpTimer();
    // TODO tap down details
    if (onDoubleFinerTap != null) {
      onDoubleFinerTap!(TapDownDetails(
        kind: _lastPointerDownEvent?.kind,
      ));
    }
    final trackers = _trackers.values.toList(growable: false);
    _trackers.clear();
    for (final tracker in trackers) {
      _releaseHeldPointer(tracker.pointer);
      tracker.entry.resolve(GestureDisposition.accepted);
      _freezeTracker(tracker);
    }
    _upTap.clear();
    _isStart = false;
    _firstTap = null;
    _releaseAllHeldPointers();
    _didResolve = false;
  }

  void _releaseHeldPointer(int pointer) {
    if (_heldPointers.remove(pointer)) {
      GestureBinding.instance.gestureArena.release(pointer);
    }
  }

  void _releaseAllHeldPointers() {
    if (_heldPointers.isEmpty) return;
    final toRelease = _heldPointers.toList(growable: false);
    _heldPointers.clear();
    for (final pointer in toRelease) {
      GestureBinding.instance.gestureArena.release(pointer);
    }
  }

  void _checkCancel() {
    if (onDoubleFinerTapCancel != null) {
      invokeCallback<void>('onHoldDragCancel', onDoubleFinerTapCancel!);
    }
  }

  @override
  String get debugDescription => 'double tap';
}

/// TapTracker helps track individual tap sequences as part of a
/// larger gesture.
class _TapTracker {
  _TapTracker({
    required PointerDownEvent event,
    required this.entry,
    required Duration doubleTapMinTime,
    required this.gestureSettings,
  })  : pointer = event.pointer,
        _initialGlobalPosition = event.position,
        initialButtons = event.buttons,
        _doubleTapMinTimeCountdown =
            _CountdownZoned(duration: doubleTapMinTime);

  final DeviceGestureSettings? gestureSettings;
  final int pointer;
  final GestureArenaEntry entry;
  final Offset _initialGlobalPosition;
  final int initialButtons;
  final _CountdownZoned _doubleTapMinTimeCountdown;

  bool _isTrackingPointer = false;
  bool didResolve = false;

  void startTrackingPointer(PointerRoute route, Matrix4? transform) {
    if (!_isTrackingPointer) {
      _isTrackingPointer = true;
      GestureBinding.instance.pointerRouter.addRoute(pointer, route, transform);
    }
  }

  void stopTrackingPointer(PointerRoute route) {
    if (_isTrackingPointer) {
      _isTrackingPointer = false;
      GestureBinding.instance.pointerRouter.removeRoute(pointer, route);
    }
  }

  bool isWithinGlobalTolerance(PointerEvent event, double tolerance) {
    final Offset offset = event.position - _initialGlobalPosition;
    return offset.distance <= tolerance;
  }

  bool hasElapsedMinTime() {
    return _doubleTapMinTimeCountdown.timeout;
  }

  bool hasSameButton(PointerDownEvent event) {
    return event.buttons == initialButtons;
  }
}

/// CountdownZoned tracks whether the specified duration has elapsed since
/// creation, honoring [Zone].
class _CountdownZoned {
  _CountdownZoned({required Duration duration}) {
    Timer(duration, _onTimeout);
  }

  bool _timeout = false;

  bool get timeout => _timeout;

  void _onTimeout() {
    _timeout = true;
  }
}

RawGestureDetector getMixinGestureDetector({
  Widget? child,
  GestureTapUpCallback? onTapUp,
  GestureTapDownCallback? onDoubleTapDown,
  GestureDoubleTapCallback? onDoubleTap,
  GestureLongPressDownCallback? onLongPressDown,
  GestureLongPressCallback? onLongPress,
  GestureDragStartCallback? onHoldDragStart,
  GestureDragUpdateCallback? onHoldDragUpdate,
  GestureDragCancelCallback? onHoldDragCancel,
  GestureDragEndCallback? onHoldDragEnd,
  GestureTapDownCallback? onDoubleFinerTap,
  GestureDragStartCallback? onOneFingerPanStart,
  GestureDragUpdateCallback? onOneFingerPanUpdate,
  GestureDragEndCallback? onOneFingerPanEnd,
  GestureScaleUpdateCallback? onTwoFingerScaleUpdate,
  GestureScaleEndCallback? onTwoFingerScaleEnd,
  GestureDragUpdateCallback? onThreeFingerVerticalDragUpdate,
}) {
  return RawGestureDetector(
      child: child,
      gestures: <Type, GestureRecognizerFactory>{
        // Official
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(), (instance) {
          instance.onTapUp = onTapUp;
        }),
        DoubleTapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
                () => DoubleTapGestureRecognizer(), (instance) {
          instance
            ..onDoubleTapDown = onDoubleTapDown
            ..onDoubleTap = onDoubleTap;
        }),
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(), (instance) {
          instance
            ..onLongPressDown = onLongPressDown
            ..onLongPress = onLongPress;
        }),
        // Customized
        HoldTapMoveGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<HoldTapMoveGestureRecognizer>(
                () => HoldTapMoveGestureRecognizer(),
                (instance) => instance
                  ..onHoldDragStart = onHoldDragStart
                  ..onHoldDragUpdate = onHoldDragUpdate
                  ..onHoldDragCancel = onHoldDragCancel
                  ..onHoldDragEnd = onHoldDragEnd),
        DoubleFinerTapGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                DoubleFinerTapGestureRecognizer>(
            () => DoubleFinerTapGestureRecognizer(), (instance) {
          instance.onDoubleFinerTap = onDoubleFinerTap;
        }),
        CustomTouchGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<CustomTouchGestureRecognizer>(
                () => CustomTouchGestureRecognizer(), (instance) {
          instance
            ..onOneFingerPanStart = onOneFingerPanStart
            ..onOneFingerPanUpdate = onOneFingerPanUpdate
            ..onOneFingerPanEnd = onOneFingerPanEnd
            ..onTwoFingerScaleUpdate = onTwoFingerScaleUpdate
            ..onTwoFingerScaleEnd = onTwoFingerScaleEnd
            ..onThreeFingerVerticalDragUpdate = onThreeFingerVerticalDragUpdate;
        }),
      });
}
