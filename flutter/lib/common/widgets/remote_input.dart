import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/wheel_reverse.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/common/remote_input_event_log.dart';

import './gestures.dart';

class RawKeyFocusScope extends StatelessWidget {
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;
  final InputModel inputModel;
  final Widget child;

  RawKeyFocusScope({
    this.focusNode,
    this.onFocusChange,
    required this.inputModel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // https://github.com/flutter/flutter/issues/154053
    final useRawKeyEvents = isLinux && !isWeb;
    // FIXME: On Windows, `AltGr` will generate `Alt` and `Control` key events,
    // while `Alt` and `Control` are seperated key events for en-US input method.
    return FocusScope(
        autofocus: true,
        child: Focus(
            autofocus: true,
            canRequestFocus: true,
            focusNode: focusNode,
            onFocusChange: onFocusChange,
            onKey: useRawKeyEvents
                ? (FocusNode data, RawKeyEvent event) =>
                    inputModel.handleRawKeyEvent(event)
                : null,
            onKeyEvent: useRawKeyEvents
                ? null
                : (FocusNode node, KeyEvent event) =>
                    inputModel.handleKeyEvent(event),
            child: child));
  }
}

// For virtual mouse when using the mouse mode on mobile.
// Special hold-drag mode: one finger holds a button (left/right button), another finger pans.
// This flag is to override the scale gesture to a pan gesture.
bool isSpecialHoldDragActive = false;
// Cache the last focal point to calculate deltas in special hold-drag mode.
Offset _lastSpecialHoldDragFocalPoint = Offset.zero;

enum _TwoFingerRemoteGestureMode {
  undecided,
  wheel,
  ctrlWheel,
}

class RawTouchGestureDetectorRegion extends StatefulWidget {
  final Widget child;
  final FFI ffi;
  final bool isCamera;
  late final InputModel inputModel = ffi.inputModel;
  late final FfiModel ffiModel = ffi.ffiModel;

  RawTouchGestureDetectorRegion({
    required this.child,
    required this.ffi,
    this.isCamera = false,
  });

  @override
  State<RawTouchGestureDetectorRegion> createState() =>
      _RawTouchGestureDetectorRegionState();
}

/// touchMode only:
///   LongPress -> right click
///   OneFingerPan -> start/end -> left down start/end
///   onDoubleTapDown -> move to
///   onLongPressDown => move to
///
/// mouseMode only:
///   DoubleFiner -> right click
///   HoldDrag -> left drag
class _RawTouchGestureDetectorRegionState
    extends State<RawTouchGestureDetectorRegion> {
  // Note: DoubleFinerTapGestureRecognizer resolves on a timeout, so callback
  // timestamps are delayed; keep this generous to still feel like a "double tap".
  static const int _twoFingerDoubleTapTimeoutMs = 900;
  static const int _twoFingerCtrlWheelArmTimeoutMs = 3000;

  Offset _cacheLongPressPosition = Offset(0, 0);
  // Timestamp of the last long press event.
  int _cacheLongPressPositionTs = 0;
  double _mouseScrollIntegral = 0; // mouse scroll speed controller
  double _scale = 1;
  bool _twoFingerWheelActive = false;
  _TwoFingerRemoteGestureMode _twoFingerGestureMode =
      _TwoFingerRemoteGestureMode.undecided;
  Offset _twoFingerWheelLockedPos = Offset.zero;
  Offset _twoFingerWheelLastFocal = Offset.zero;
  double _twoFingerWheelIntegral = 0.0;
  Offset _twoFingerCtrlWheelAnchorPos = Offset.zero;
  double _twoFingerCtrlWheelIntegral = 0.0;
  int _twoFingerTapTs = 0;
  int _twoFingerCtrlWheelArmedUntilTs = 0;
  bool _twoFingerCtrlWheelPendingConsume = false;

  int _suppressSingleTouchUntilTs = 0;

  bool _leftDragActive = false;
  bool _leftDragMoved = false;

  bool _rightHoldActive = false;
  bool _rightDragMoved = false;
  bool _rightDragLoggedDown = false;
  Offset _rightDragLastPos = Offset.zero;

  // Workaround tap down event when two fingers are used to scale(mobile)
  TapDownDetails? _lastTapDownDetails;

  PointerDeviceKind? lastDeviceKind;

  // For touch mode, onDoubleTap
  // `onDoubleTap()` does not provide the position of the tap event.
  Offset _lastPosOfDoubleTapDown = Offset.zero;
  bool _touchModePanStarted = false;
  bool _canvasEditOneFingerPanStarted = false;
  bool _canvasEditTwoFingerActive = false;
  Offset _doubleFinerTapPosition = Offset.zero;

  // For mouse mode, we need to block the events when the cursor is in a blocked area.
  // So we need to cache the last tap down position.
  Offset? _lastTapDownPositionForMouseMode;

  FFI get ffi => widget.ffi;
  FfiModel get ffiModel => widget.ffiModel;
  InputModel get inputModel => widget.inputModel;
  bool get isCanvasEditMode => ffiModel.canvasEditMode;
  bool get handleTouch =>
      (isDesktop || isWebDesktop) || (ffiModel.touchMode && !isCanvasEditMode);
  SessionID get sessionId => ffi.sessionId;

  bool _isSingleTouchSuppressed() =>
      DateTime.now().millisecondsSinceEpoch < _suppressSingleTouchUntilTs;

  void _suppressSingleTouch([int ms = 150]) {
    final until = DateTime.now().millisecondsSinceEpoch + ms;
    if (until > _suppressSingleTouchUntilTs) {
      _suppressSingleTouchUntilTs = until;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      child: widget.child,
      gestures: makeGestures(context),
    );
  }

  bool isNotTouchBasedDevice() {
    return !kTouchBasedDeviceKinds.contains(lastDeviceKind);
  }

  // Mobile, mouse mode.
  // Check if should block the mouse tap event (`_lastTapDownPositionForMouseMode`).
  bool shouldBlockMouseModeEvent() {
    return _lastTapDownPositionForMouseMode != null &&
        ffi.cursorModel.shouldBlock(_lastTapDownPositionForMouseMode!.dx,
            _lastTapDownPositionForMouseMode!.dy);
  }

  onTapDown(TapDownDetails d) async {
    lastDeviceKind = d.kind;
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (_isSingleTouchSuppressed()) {
      return;
    }
    if (isCanvasEditMode) {
      return;
    }
    if (handleTouch) {
      _lastPosOfDoubleTapDown = d.localPosition;
      // Desktop or mobile "Touch mode"
      _lastTapDownDetails = d;
    } else {
      _lastTapDownPositionForMouseMode = d.localPosition;
    }
  }

  onTapUp(TapUpDetails d) async {
    final TapDownDetails? lastTapDownDetails = _lastTapDownDetails;
    _lastTapDownDetails = null;
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (_isSingleTouchSuppressed()) {
      return;
    }
    if (isCanvasEditMode) {
      return;
    }
    if (handleTouch) {
      final isMoved =
          await ffi.cursorModel.move(d.localPosition.dx, d.localPosition.dy);
      if (isMoved) {
        if (lastTapDownDetails != null) {
          await inputModel.tapDown(MouseButtons.left);
        }
        await inputModel.tapUp(MouseButtons.left);
        RemoteInputEventLog.add(
          'left_click',
          data: {
            'x': d.localPosition.dx.round(),
            'y': d.localPosition.dy.round(),
          },
        );
      }
    }
  }

  onTap() async {
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (_isSingleTouchSuppressed()) {
      return;
    }
    if (isCanvasEditMode) {
      return;
    }
    if (!handleTouch) {
      // Cannot use `_lastTapDownDetails` because Flutter calls `onTapUp` before `onTap`, clearing the cached details.
      // Using `_lastTapDownPositionForMouseMode` instead.
      if (shouldBlockMouseModeEvent()) {
        return;
      }
      // Mobile, "Mouse mode"
      await inputModel.tap(MouseButtons.left);
    }
  }

  onDoubleTapDown(TapDownDetails d) async {
    lastDeviceKind = d.kind;
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (isCanvasEditMode) {
      return;
    }
    if (handleTouch) {
      _lastPosOfDoubleTapDown = d.localPosition;
      await ffi.cursorModel.move(d.localPosition.dx, d.localPosition.dy);
    } else {
      _lastTapDownPositionForMouseMode = d.localPosition;
    }
  }

  onDoubleTap() async {
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (isCanvasEditMode) {
      return;
    }
    if (ffiModel.touchMode && ffi.cursorModel.lastIsBlocked) {
      return;
    }
    if (handleTouch &&
        !ffi.cursorModel.isInRemoteRect(_lastPosOfDoubleTapDown)) {
      return;
    }
    // Check if the position is in a blocked area when using the mouse mode.
    if (!handleTouch) {
      if (shouldBlockMouseModeEvent()) {
        return;
      }
    }
    await inputModel.tap(MouseButtons.left);
    await inputModel.tap(MouseButtons.left);
  }

  onLongPressDown(LongPressDownDetails d) async {
    lastDeviceKind = d.kind;
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (isCanvasEditMode) {
      return;
    }
    if (handleTouch) {
      _lastPosOfDoubleTapDown = d.localPosition;
      _cacheLongPressPosition = d.localPosition;
      if (!ffi.cursorModel.isInRemoteRect(d.localPosition)) {
        return;
      }
      _cacheLongPressPositionTs = DateTime.now().millisecondsSinceEpoch;
      if (ffiModel.isPeerMobile) {
        await ffi.cursorModel
            .move(_cacheLongPressPosition.dx, _cacheLongPressPosition.dy);
        await inputModel.tapDown(MouseButtons.left);
      }
    } else {
      _lastTapDownPositionForMouseMode = d.localPosition;
    }
  }

  onLongPressUp() async {
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (isCanvasEditMode) {
      return;
    }
    if (handleTouch) {
      if (_rightHoldActive) {
        await inputModel.sendMouse('up', MouseButtons.right);
        if (_rightDragMoved) {
          RemoteInputEventLog.add(
            'right_drag',
            data: {
              'phase': 'up',
              'x': _rightDragLastPos.dx.round(),
              'y': _rightDragLastPos.dy.round(),
            },
          );
        } else {
          RemoteInputEventLog.add(
            'right_click',
            data: {
              'x': _cacheLongPressPosition.dx.round(),
              'y': _cacheLongPressPosition.dy.round(),
            },
          );
        }
        _rightHoldActive = false;
        _rightDragMoved = false;
        _rightDragLoggedDown = false;
        return;
      }
      await inputModel.tapUp(MouseButtons.left);
    }
  }

  // for mobiles
  onLongPress() async {
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (isCanvasEditMode) {
      return;
    }
    if (!ffi.ffiModel.isPeerMobile) {
      if (handleTouch) {
        final isMoved = await ffi.cursorModel
            .move(_cacheLongPressPosition.dx, _cacheLongPressPosition.dy);
        if (!isMoved) {
          return;
        }
      } else {
        if (shouldBlockMouseModeEvent()) {
          return;
        }
      }
      if (handleTouch) {
        await inputModel.sendMouse('down', MouseButtons.right);
        _rightHoldActive = true;
        _rightDragMoved = false;
        _rightDragLoggedDown = false;
        _rightDragLastPos = _cacheLongPressPosition;
        return;
      }
      await inputModel.tap(MouseButtons.right);
      RemoteInputEventLog.add(
        'right_click',
        data: {
          'x': _cacheLongPressPosition.dx.round(),
          'y': _cacheLongPressPosition.dy.round(),
        },
      );
    } else {
      // It's better to send a message to tell the controlled device that the long press event is triggered.
      // We're now using a `TimerTask` in `InputService.kt` to decide whether to trigger the long press event.
      // It's not accurate and it's better to use the same detection logic in the controlling side.
    }
  }

  onLongPressMoveUpdate(LongPressMoveUpdateDetails d) async {
    if (!ffiModel.isPeerMobile || isNotTouchBasedDevice()) {
      if (isNotTouchBasedDevice()) {
        return;
      }
      if (isCanvasEditMode) {
        return;
      }
      if (!handleTouch || !_rightHoldActive) {
        return;
      }
      if (ffi.cursorModel.shouldBlock(d.localPosition.dx, d.localPosition.dy)) {
        return;
      }
      if (!ffi.cursorModel.isInRemoteRect(d.localPosition)) {
        return;
      }

      final delta = d.localPosition - _rightDragLastPos;
      _rightDragLastPos = d.localPosition;
      await ffi.cursorModel.updatePan(delta, d.localPosition, handleTouch);

      if (!_rightDragMoved) {
        _rightDragMoved = true;
      }
      if (!_rightDragLoggedDown) {
        _rightDragLoggedDown = true;
        RemoteInputEventLog.add(
          'right_drag',
          data: {
            'phase': 'down',
            'x': _cacheLongPressPosition.dx.round(),
            'y': _cacheLongPressPosition.dy.round(),
          },
        );
      }
      RemoteInputEventLog.add(
        'right_drag',
        data: {
          'phase': 'move',
          'x': d.localPosition.dx.round(),
          'y': d.localPosition.dy.round(),
        },
      );
      return;
    }
    if (handleTouch) {
      if (!ffi.cursorModel.isInRemoteRect(d.localPosition)) {
        return;
      }
      await ffi.cursorModel.move(d.localPosition.dx, d.localPosition.dy);
    }
  }

  onDoubleFinerTapDown(TapDownDetails d) async {
    lastDeviceKind = d.kind;
    if (isNotTouchBasedDevice()) {
      return;
    }
    _doubleFinerTapPosition = d.localPosition;
    // ignore for desktop and mobile
  }

  onDoubleFinerTap(TapDownDetails d) async {
    lastDeviceKind = d.kind;
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (isCanvasEditMode) {
      return;
    }

    final isMobileTouchMode = isMobile && ffiModel.touchMode;
    if (isMobileTouchMode && _shouldUseTwoFingerRemoteWheelOrZoom()) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final isDouble = (now - _twoFingerTapTs) <= _twoFingerDoubleTapTimeoutMs;
      _twoFingerTapTs = now;
      if (isDouble) {
        _twoFingerCtrlWheelArmedUntilTs = now + _twoFingerCtrlWheelArmTimeoutMs;
        RemoteInputEventLog.add(
          'two_finger_arm_ctrl_wheel',
          data: {'timeout_ms': _twoFingerCtrlWheelArmTimeoutMs},
        );
      }
      return;
    }

    // mobile mouse mode or desktop touch screen
    final isMobileMouseMode = isMobile && !ffiModel.touchMode;
    // We can't use `d.localPosition` here because it's always (0, 0) on desktop.
    final isDesktopInRemoteRect = (isDesktop || isWebDesktop) &&
        ffi.cursorModel.isInRemoteRect(_doubleFinerTapPosition);
    if (isMobileMouseMode || isDesktopInRemoteRect) {
      await inputModel.tap(MouseButtons.right);
    }
  }

  onHoldDragStart(DragStartDetails d) async {
    lastDeviceKind = d.kind;
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (isCanvasEditMode) {
      return;
    }
    if (!handleTouch) {
      if (isSpecialHoldDragActive) return;
      await inputModel.sendMouse('down', MouseButtons.left);
    }
  }

  onHoldDragUpdate(DragUpdateDetails d) async {
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (isCanvasEditMode) {
      return;
    }
    if (!handleTouch) {
      if (isSpecialHoldDragActive) return;
      await ffi.cursorModel.updatePan(d.delta, d.localPosition, handleTouch);
    }
  }

  onHoldDragEnd(DragEndDetails d) async {
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (isCanvasEditMode) {
      return;
    }
    if (!handleTouch) {
      await inputModel.sendMouse('up', MouseButtons.left);
    }
  }

  onOneFingerPanStart(BuildContext context, DragStartDetails d) async {
    final TapDownDetails? lastTapDownDetails = _lastTapDownDetails;
    _lastTapDownDetails = null;
    lastDeviceKind = d.kind ?? lastDeviceKind;
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (_isSingleTouchSuppressed()) {
      return;
    }
    if (isCanvasEditMode) {
      if (ffi.cursorModel.shouldBlock(d.localPosition.dx, d.localPosition.dy)) {
        _canvasEditOneFingerPanStarted = false;
        return;
      }
      if (!ffi.cursorModel.isInRemoteRect(d.localPosition)) {
        _canvasEditOneFingerPanStarted = false;
        return;
      }
      _canvasEditOneFingerPanStarted = true;
      return;
    }
    if (handleTouch) {
      if (_rightHoldActive) {
        return;
      }
      if (lastTapDownDetails != null) {
        await ffi.cursorModel.move(lastTapDownDetails.localPosition.dx,
            lastTapDownDetails.localPosition.dy);
      }
      if (ffi.cursorModel.shouldBlock(d.localPosition.dx, d.localPosition.dy)) {
        return;
      }
      if (!ffi.cursorModel.isInRemoteRect(d.localPosition)) {
        return;
      }

      _touchModePanStarted = true;
      if (isDesktop || isWebDesktop) {
        ffi.cursorModel.trySetRemoteWindowCoords();
      }

      // Workaround for the issue that the first pan event is sent a long time after the start event.
      // If the time interval between the start event and the first pan event is less than 500ms,
      // we consider to use the long press position as the start position.
      //
      // TODO: We should find a better way to send the first pan event as soon as possible.
      if (DateTime.now().millisecondsSinceEpoch - _cacheLongPressPositionTs <
          500) {
        await ffi.cursorModel
            .move(_cacheLongPressPosition.dx, _cacheLongPressPosition.dy);
      }
      // In relative mouse mode, skip mouse down - only send movement via sendMobileRelativeMouseMove
      if (!inputModel.relativeMouseMode.value) {
        await inputModel.sendMouse('down', MouseButtons.left);
        _leftDragActive = true;
        _leftDragMoved = false;
        RemoteInputEventLog.add(
          'left_drag',
          data: {
            'phase': 'down',
            'x': d.localPosition.dx.round(),
            'y': d.localPosition.dy.round(),
          },
        );
      }
      await ffi.cursorModel.move(d.localPosition.dx, d.localPosition.dy);
    } else {
      final offset = ffi.cursorModel.offset;
      final cursorX = offset.dx;
      final cursorY = offset.dy;
      final visible =
          ffi.cursorModel.getVisibleRect().inflate(1); // extend edges
      final size = MediaQueryData.fromView(View.of(context)).size;
      if (!visible.contains(Offset(cursorX, cursorY))) {
        await ffi.cursorModel.move(size.width / 2, size.height / 2);
      }
    }
  }

  onOneFingerPanUpdate(DragUpdateDetails d) async {
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (isCanvasEditMode) {
      if (!_canvasEditOneFingerPanStarted) {
        return;
      }
      if (ffi.cursorModel.shouldBlock(d.localPosition.dx, d.localPosition.dy)) {
        return;
      }
      ffi.canvasModel.panX(d.delta.dx);
      ffi.canvasModel.panY(d.delta.dy);
      return;
    }
    if (ffi.cursorModel.shouldBlock(d.localPosition.dx, d.localPosition.dy)) {
      return;
    }
    if (handleTouch && !_touchModePanStarted) {
      return;
    }
    // In relative mouse mode, send delta directly without position tracking.
    if (inputModel.relativeMouseMode.value) {
      await inputModel.sendMobileRelativeMouseMove(d.delta.dx, d.delta.dy);
    } else {
      await ffi.cursorModel.updatePan(d.delta, d.localPosition, handleTouch);
      if (_leftDragActive && !_leftDragMoved) {
        _leftDragMoved = true;
        RemoteInputEventLog.add(
          'left_drag',
          data: {
            'phase': 'move',
            'x': d.localPosition.dx.round(),
            'y': d.localPosition.dy.round(),
          },
        );
      }
    }
  }

  onOneFingerPanEnd(DragEndDetails d) async {
    _touchModePanStarted = false;
    _canvasEditOneFingerPanStarted = false;
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (isCanvasEditMode) {
      return;
    }
    if (isDesktop || isWebDesktop) {
      ffi.cursorModel.clearRemoteWindowCoords();
    }
    if (handleTouch) {
      // In relative mouse mode, skip mouse up - matches the skipped mouse down in onOneFingerPanStart
      if (!inputModel.relativeMouseMode.value) {
        await inputModel.sendMouse('up', MouseButtons.left);
        if (_leftDragActive) {
          RemoteInputEventLog.add(
            'left_drag',
            data: {'phase': 'up'},
          );
        }
      }
    }
    _leftDragActive = false;
    _leftDragMoved = false;
  }

  // scale + pan event
  double _getAndroidTwoFingerWheelSensitivity() {
    final raw =
        bind.mainGetLocalOption(key: kAndroidTwoFingerScrollSensitivity);
    final parsed = double.tryParse(raw);
    final v = parsed ?? 1.0;
    if (v.isNaN || v.isInfinite) return 1.0;
    return v.clamp(0.01, 5.0);
  }

  bool _shouldUseTwoFingerRemoteWheelOrZoom() {
    // Prefer mapping two-finger pinch to remote wheel/zoom (Ctrl+wheel) when we
    // are controlling a non-mobile peer. This is useful both on mobile touch
    // mode and on desktop touchscreens.
    return handleTouch && !ffiModel.isPeerMobile && !widget.isCamera;
  }

  bool _getReverseMouseWheel() {
    var optionValue =
        bind.sessionGetReverseMouseWheelSync(sessionId: inputModel.sessionId) ??
            '';
    if (optionValue.isEmpty) {
      optionValue = bind.mainGetUserDefaultOption(key: kKeyReverseMouseWheel);
    }
    return optionValue == 'Y';
  }

  bool _getReverseTwoFingerScroll() {
    var optionValue =
        bind.mainGetUserDefaultOption(key: kKeyReverseTwoFingerScroll);
    if (optionValue.isEmpty) {
      // Backward compatible: default to the existing reverse mouse wheel option.
      return _getReverseMouseWheel();
    }
    return optionValue == 'Y';
  }

  int _getTwoFingerWheelReverseFactor() {
    final reverseWheel = _getReverseMouseWheel();
    final reverseTwoFinger = _getReverseTwoFingerScroll();
    return wheelStepWithReverseCompensation(
      step: 1,
      globalReverse: reverseWheel,
      sourceReverse: reverseTwoFinger,
    );
  }

  Future<void> _twoFingerWheelScrollByDelta(double deltaDy) async {
    final sensitivity = _getAndroidTwoFingerWheelSensitivity();
    _twoFingerWheelIntegral += (-deltaDy) / 4 * sensitivity;
    // Read reverse options dynamically so changes take effect immediately
    // without requiring the user to lift and re-start a two-finger gesture.
    final reverseFactor = _getTwoFingerWheelReverseFactor();

    final lockedPos = _twoFingerWheelLockedPos;
    if (!ffi.cursorModel.shouldBlock(lockedPos.dx, lockedPos.dy) &&
        ffi.cursorModel.isInRemoteRect(lockedPos)) {
      await ffi.cursorModel.move(lockedPos.dx, lockedPos.dy);
    }
    while (_twoFingerWheelIntegral >= 1) {
      final step = 1 * reverseFactor;
      await inputModel.scroll(step);
      _twoFingerWheelIntegral -= 1;
      RemoteInputEventLog.add(
        'wheel_v',
        data: {
          'x': _twoFingerWheelLockedPos.dx.round(),
          'y': _twoFingerWheelLockedPos.dy.round(),
          'dir': step > 0 ? 'down' : 'up',
          'step': step,
        },
      );
    }
    while (_twoFingerWheelIntegral <= -1) {
      final step = -1 * reverseFactor;
      await inputModel.scroll(step);
      _twoFingerWheelIntegral += 1;
      RemoteInputEventLog.add(
        'wheel_v',
        data: {
          'x': _twoFingerWheelLockedPos.dx.round(),
          'y': _twoFingerWheelLockedPos.dy.round(),
          'dir': step > 0 ? 'down' : 'up',
          'step': step,
        },
      );
    }
  }

  Future<void> _twoFingerCtrlWheelByDeltaDy(double deltaDy) async {
    final sensitivity = _getAndroidTwoFingerWheelSensitivity();
    final reverseFactor = _getTwoFingerWheelReverseFactor();
    // Convert continuous finger motion into discrete wheel steps.
    const pixelsPerStep = 12.0;
    _twoFingerCtrlWheelIntegral += (-deltaDy) / pixelsPerStep * sensitivity;
    final anchor = _twoFingerCtrlWheelAnchorPos;
    while (_twoFingerCtrlWheelIntegral >= 1) {
      final prevCtrl = inputModel.ctrl;
      inputModel.ctrl = true;
      try {
        final step = 1 * reverseFactor;
        await inputModel.scroll(step);
      } finally {
        inputModel.ctrl = prevCtrl;
      }
      _twoFingerCtrlWheelIntegral -= 1;
      RemoteInputEventLog.add(
        'ctrl_wheel_v',
        data: {
          'x': anchor.dx.round(),
          'y': anchor.dy.round(),
          'dir': (1 * reverseFactor) > 0 ? 'down' : 'up',
          'step': step,
        },
      );
    }
    while (_twoFingerCtrlWheelIntegral <= -1) {
      final prevCtrl = inputModel.ctrl;
      inputModel.ctrl = true;
      try {
        final step = -1 * reverseFactor;
        await inputModel.scroll(step);
      } finally {
        inputModel.ctrl = prevCtrl;
      }
      _twoFingerCtrlWheelIntegral += 1;
      RemoteInputEventLog.add(
        'ctrl_wheel_v',
        data: {
          'x': anchor.dx.round(),
          'y': anchor.dy.round(),
          'dir': step > 0 ? 'down' : 'up',
          'step': step,
        },
      );
    }
  }

  onTwoFingerScaleStartEx(TwoFingerScaleStartDetails d) async {
    _lastTapDownDetails = null;
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (isCanvasEditMode) {
      _suppressSingleTouch();
      _scale = 1;
      _canvasEditTwoFingerActive =
          ffi.cursorModel.isInRemoteRect(d.localFocalPoint) &&
              !ffi.cursorModel
                  .shouldBlock(d.localFocalPoint.dx, d.localFocalPoint.dy);
      return;
    }
    if (isSpecialHoldDragActive) {
      // Initialize the last focal point to calculate deltas manually.
      _lastSpecialHoldDragFocalPoint = d.focalPoint;
      return;
    }

    if (_shouldUseTwoFingerRemoteWheelOrZoom()) {
      _suppressSingleTouch();
      _twoFingerWheelActive = true;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_twoFingerCtrlWheelArmedUntilTs != 0 &&
          now > _twoFingerCtrlWheelArmedUntilTs) {
        _twoFingerCtrlWheelArmedUntilTs = 0;
      }
      final armed = now <= _twoFingerCtrlWheelArmedUntilTs;
      _twoFingerGestureMode = armed
          ? _TwoFingerRemoteGestureMode.ctrlWheel
          : _TwoFingerRemoteGestureMode.wheel;
      _twoFingerWheelIntegral = 0.0;
      _twoFingerCtrlWheelAnchorPos = Offset.zero;
      _twoFingerCtrlWheelIntegral = 0.0;
      _twoFingerCtrlWheelPendingConsume = armed;
      _twoFingerWheelLockedPos = d.localFocalPoint;
      _twoFingerWheelLastFocal = d.localFocalPoint;
      if (!ffi.cursorModel.isInRemoteRect(_twoFingerWheelLockedPos)) {
        _twoFingerWheelActive = false;
        return;
      }
      // If the start point is blocked by an overlay (e.g. wheel slider), still
      // allow two-finger scroll to work; just avoid moving the cursor there.
      if (!ffi.cursorModel.shouldBlock(
          _twoFingerWheelLockedPos.dx, _twoFingerWheelLockedPos.dy)) {
        await ffi.cursorModel
            .move(_twoFingerWheelLockedPos.dx, _twoFingerWheelLockedPos.dy);
      }
      if (armed) {
        // Anchor Ctrl+wheel to the initial two-finger touch point (A).
        _twoFingerCtrlWheelAnchorPos = _twoFingerWheelLockedPos;
      }
    }
  }

  onTwoFingerScaleUpdateEx(TwoFingerScaleUpdateDetails d) async {
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (isCanvasEditMode) {
      if (!_canvasEditTwoFingerActive) {
        return;
      }
      // mobile
      ffi.canvasModel.updateScale(d.scale / _scale, d.focalPoint);
      _scale = d.scale;
      ffi.canvasModel.panX(d.focalPointDelta.dx);
      ffi.canvasModel.panY(d.focalPointDelta.dy);
      return;
    }

    // Mobile remote session: two-finger wheel; when armed -> Ctrl+wheel.
    if (_shouldUseTwoFingerRemoteWheelOrZoom() && _twoFingerWheelActive) {
      final delta = d.localFocalPoint - _twoFingerWheelLastFocal;
      _twoFingerWheelLastFocal = d.localFocalPoint;

      if (_twoFingerGestureMode == _TwoFingerRemoteGestureMode.wheel) {
        await _twoFingerWheelScrollByDelta(delta.dy);
        return;
      }

      // Ctrl+wheel mode: if no scroll happened within the arm timeout, fall back
      // to normal wheel.
      if (_twoFingerCtrlWheelPendingConsume) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (_twoFingerCtrlWheelArmedUntilTs != 0 &&
            now > _twoFingerCtrlWheelArmedUntilTs) {
          _twoFingerGestureMode = _TwoFingerRemoteGestureMode.wheel;
          _twoFingerCtrlWheelPendingConsume = false;
          await _twoFingerWheelScrollByDelta(delta.dy);
          return;
        }
        if (delta.dy != 0) {
          // Consume Ctrl mode on the first scroll movement.
          _twoFingerCtrlWheelPendingConsume = false;
          _twoFingerCtrlWheelArmedUntilTs = 0;
        }
      }

      final anchor = _twoFingerCtrlWheelAnchorPos;
      if (!ffi.cursorModel.shouldBlock(anchor.dx, anchor.dy) &&
          ffi.cursorModel.isInRemoteRect(anchor)) {
        await ffi.cursorModel.move(anchor.dx, anchor.dy);
      }
      if (delta.dy != 0) {
        await _twoFingerCtrlWheelByDeltaDy(delta.dy);
      }
      return;
    }
    // Android: keep two-finger gestures reserved for remote wheel/zoom above.
    if (isAndroid && !widget.isCamera && !isSpecialHoldDragActive) {
      return;
    }

    // If in special drag mode, perform a pan instead of a scale.
    if (isSpecialHoldDragActive) {
      // Calculate delta manually to avoid the jumpy behavior.
      final delta = d.focalPoint - _lastSpecialHoldDragFocalPoint;
      _lastSpecialHoldDragFocalPoint = d.focalPoint;
      await ffi.cursorModel.updatePan(delta * 2.0, d.focalPoint, handleTouch);
      return;
    }

    if ((isDesktop || isWebDesktop)) {
      final scale = ((d.scale - _scale) * 1000).toInt();
      _scale = d.scale;

      if (scale != 0) {
        if (widget.isCamera) return;
        await bind.sessionSendPointer(
            sessionId: sessionId,
            msg: json.encode(
                PointerEventToRust(kPointerEventKindTouch, 'scale', scale)
                    .toJson()));
      }
    } else {
      // mobile
      ffi.canvasModel.updateScale(d.scale / _scale, d.focalPoint);
      _scale = d.scale;
      ffi.canvasModel.panX(d.focalPointDelta.dx);
      ffi.canvasModel.panY(d.focalPointDelta.dy);
    }
  }

  onTwoFingerScaleEndEx(TwoFingerScaleEndDetails d) async {
    if (isNotTouchBasedDevice()) {
      return;
    }
    if (isCanvasEditMode) {
      _suppressSingleTouch();
      _canvasEditTwoFingerActive = false;
      _scale = 1;
      return;
    }
    if (_shouldUseTwoFingerRemoteWheelOrZoom()) {
      _suppressSingleTouch();
      _twoFingerWheelActive = false;
      _twoFingerGestureMode = _TwoFingerRemoteGestureMode.undecided;
      _twoFingerWheelIntegral = 0.0;
      _twoFingerCtrlWheelAnchorPos = Offset.zero;
      _twoFingerCtrlWheelIntegral = 0.0;
      _twoFingerCtrlWheelPendingConsume = false;
      _scale = 1;
      return;
    }
    if ((isDesktop || isWebDesktop)) {
      if (widget.isCamera) return;
      await bind.sessionSendPointer(
          sessionId: sessionId,
          msg: json.encode(
              PointerEventToRust(kPointerEventKindTouch, 'scale', 0).toJson()));
    } else {
      // mobile
      _scale = 1;
      // No idea why we need to set the view style to "" here.
      // bind.sessionSetViewStyle(sessionId: sessionId, value: "");
    }
    if (!isSpecialHoldDragActive) {
      await inputModel.sendMouse('up', MouseButtons.left);
    }
  }

  get onHoldDragCancel => null;
  get onThreeFingerVerticalDragUpdate => ffi.ffiModel.isPeerAndroid
      ? null
      : (d) {
          if (isCanvasEditMode) {
            return;
          }
          _mouseScrollIntegral += d.delta.dy / 4;
          if (_mouseScrollIntegral > 1) {
            inputModel.scroll(1);
            _mouseScrollIntegral = 0;
          } else if (_mouseScrollIntegral < -1) {
            inputModel.scroll(-1);
            _mouseScrollIntegral = 0;
          }
        };

  makeGestures(BuildContext context) {
    return <Type, GestureRecognizerFactory>{
      // Official
      TapGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(), (instance) {
        instance
          ..onTapDown = onTapDown
          ..onTapUp = onTapUp
          ..onTap = onTap;
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
          ..onLongPressUp = onLongPressUp
          ..onLongPress = onLongPress
          ..onLongPressMoveUpdate = onLongPressMoveUpdate;
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
      DoubleFinerTapGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<DoubleFinerTapGestureRecognizer>(
              () => DoubleFinerTapGestureRecognizer(), (instance) {
        instance
          ..onDoubleFinerTap = onDoubleFinerTap
          ..onDoubleFinerTapDown = onDoubleFinerTapDown;
      }),
      CustomTouchGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<CustomTouchGestureRecognizer>(
              () => CustomTouchGestureRecognizer(), (instance) {
        instance.onOneFingerPanStart =
            (DragStartDetails d) => onOneFingerPanStart(context, d);
        instance
          ..onOneFingerPanUpdate = onOneFingerPanUpdate
          ..onOneFingerPanEnd = onOneFingerPanEnd
          ..onTwoFingerScaleStartEx = onTwoFingerScaleStartEx
          ..onTwoFingerScaleUpdateEx = onTwoFingerScaleUpdateEx
          ..onTwoFingerScaleEndEx = onTwoFingerScaleEndEx
          ..onThreeFingerVerticalDragUpdate = onThreeFingerVerticalDragUpdate;
      }),
    };
  }
}

class RawPointerMouseRegion extends StatelessWidget {
  final InputModel inputModel;
  final Widget child;
  final MouseCursor? cursor;
  final PointerEnterEventListener? onEnter;
  final PointerExitEventListener? onExit;
  final PointerDownEventListener? onPointerDown;
  final PointerUpEventListener? onPointerUp;

  RawPointerMouseRegion({
    this.onEnter,
    this.onExit,
    this.cursor,
    this.onPointerDown,
    this.onPointerUp,
    required this.inputModel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: inputModel.onPointHoverImage,
      onPointerDown: (evt) {
        onPointerDown?.call(evt);
        inputModel.onPointDownImage(evt);
      },
      onPointerUp: (evt) {
        onPointerUp?.call(evt);
        inputModel.onPointUpImage(evt);
      },
      onPointerMove: inputModel.onPointMoveImage,
      onPointerSignal: inputModel.onPointerSignalImage,
      onPointerPanZoomStart: inputModel.onPointerPanZoomStart,
      onPointerPanZoomUpdate: inputModel.onPointerPanZoomUpdate,
      onPointerPanZoomEnd: inputModel.onPointerPanZoomEnd,
      child: MouseRegion(
        cursor: inputModel.isViewOnly
            ? MouseCursor.defer
            : (cursor ?? MouseCursor.defer),
        onEnter: onEnter,
        onExit: onExit,
        child: child,
      ),
    );
  }
}

class CameraRawPointerMouseRegion extends StatelessWidget {
  final InputModel inputModel;
  final Widget child;
  final PointerEnterEventListener? onEnter;
  final PointerExitEventListener? onExit;
  final PointerDownEventListener? onPointerDown;
  final PointerUpEventListener? onPointerUp;

  CameraRawPointerMouseRegion({
    this.onEnter,
    this.onExit,
    this.onPointerDown,
    this.onPointerUp,
    required this.inputModel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (evt) {
        final offset = evt.position;
        double x = offset.dx;
        double y = max(0.0, offset.dy);
        inputModel.handlePointerDevicePos(
            kPointerEventKindMouse, x, y, true, kMouseEventTypeDefault);
      },
      onPointerDown: (evt) {
        onPointerDown?.call(evt);
      },
      onPointerUp: (evt) {
        onPointerUp?.call(evt);
      },
      child: MouseRegion(
        cursor: MouseCursor.defer,
        onEnter: onEnter,
        onExit: onExit,
        child: child,
      ),
    );
  }
}
