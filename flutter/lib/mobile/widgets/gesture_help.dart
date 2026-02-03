import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:toggle_switch/toggle_switch.dart';

class GestureIcons {
  static const String _family = 'gestureicons';

  GestureIcons._();

  static const IconData iconMouse = IconData(0xe65c, fontFamily: _family);
  static const IconData iconTabletTouch = IconData(0xe9ce, fontFamily: _family);
  static const IconData iconGestureFDrag =
      IconData(0xe686, fontFamily: _family);
  static const IconData iconMobileTouch = IconData(0xe9cd, fontFamily: _family);
  static const IconData iconGesturePress =
      IconData(0xe66c, fontFamily: _family);
  static const IconData iconGestureTap = IconData(0xe66f, fontFamily: _family);
  static const IconData iconGesturePinch =
      IconData(0xe66a, fontFamily: _family);
  static const IconData iconGesturePressHold =
      IconData(0xe66b, fontFamily: _family);
  static const IconData iconGestureFDragUpDown_ =
      IconData(0xe685, fontFamily: _family);
  static const IconData iconGestureFTap_ =
      IconData(0xe68e, fontFamily: _family);
  static const IconData iconGestureFSwipeRight =
      IconData(0xe68f, fontFamily: _family);
  static const IconData iconGestureFdoubleTap =
      IconData(0xe691, fontFamily: _family);
  static const IconData iconGestureFThreeFingers =
      IconData(0xe687, fontFamily: _family);
}

typedef OnTouchModeChange = void Function(bool);
typedef OnCanvasEditModeChange = void Function(bool);

String _gestureHelpCanvasEditModeLabel() {
  final label = translate("Canvas edit mode");
  if (label != "Canvas edit mode") {
    return label;
  }
  final l = localeName.toLowerCase();
  if (!l.startsWith('zh')) {
    return label;
  }
  if (l.contains('tw') || l.contains('hant') || l.contains('hk')) {
    return '畫布編輯模式';
  }
  return '画布编辑模式';
}

class GestureHelp extends StatefulWidget {
  GestureHelp(
      {Key? key,
      required this.touchMode,
      required this.onTouchModeChange,
      required this.canvasEditMode,
      required this.onCanvasEditModeChange,
      required this.virtualMouseMode,
      this.inputModel})
      : super(key: key);
  final bool touchMode;
  final OnTouchModeChange onTouchModeChange;
  final bool canvasEditMode;
  final OnCanvasEditModeChange onCanvasEditModeChange;
  final VirtualMouseMode virtualMouseMode;
  final InputModel? inputModel;

  @override
  State<StatefulWidget> createState() =>
      _GestureHelpState(touchMode, canvasEditMode, virtualMouseMode);
}

class _GestureHelpState extends State<GestureHelp> {
  late int _selectedIndex;
  late bool _touchMode;
  late bool _canvasEditMode;
  final VirtualMouseMode _virtualMouseMode;
  double _twoFingerScrollSensitivity = 1.0;
  double _wheelScrollSensitivity = 1.0;
  bool _reverseMouseWheel = false;
  bool _reverseTwoFingerScroll = false;
  bool _enableTwoFingerEdgeCtrlWheelZoom = true;
  bool _enableThreeFingerSwipeCtrlWheelZoom = false;

  _GestureHelpState(
      bool touchMode, bool canvasEditMode, VirtualMouseMode virtualMouseMode)
      : _virtualMouseMode = virtualMouseMode {
    _touchMode = touchMode;
    _canvasEditMode = canvasEditMode;
    if (_canvasEditMode) {
      _selectedIndex = 2;
    } else {
      _selectedIndex = _touchMode ? 1 : 0;
    }
  }

  static const double _minTwoFingerSensitivity = 0.01;
  static const double _maxTwoFingerSensitivity = 5.00;
  static const double _twoFingerSensitivityStep = 0.01;

  double _clampSensitivity(double v) {
    if (v.isNaN || v.isInfinite) return 1.0;
    return v.clamp(_minTwoFingerSensitivity, _maxTwoFingerSensitivity);
  }

  double _roundSensitivity(double v) => (v * 100).roundToDouble() / 100;

  void _loadTwoFingerSensitivity() {
    final raw =
        bind.mainGetLocalOption(key: kAndroidTwoFingerScrollSensitivity);
    final parsed = double.tryParse(raw);
    setState(() {
      _twoFingerScrollSensitivity =
          _roundSensitivity(_clampSensitivity(parsed ?? 1.0));
    });
  }

  Future<void> _storeTwoFingerSensitivity(double v) async {
    final next = _roundSensitivity(_clampSensitivity(v));
    setState(() => _twoFingerScrollSensitivity = next);
    await bind.mainSetLocalOption(
      key: kAndroidTwoFingerScrollSensitivity,
      value: next.toStringAsFixed(2),
    );
  }

  void _loadWheelSensitivity() {
    final raw = bind.mainGetLocalOption(key: kAndroidWheelScrollSensitivity);
    final parsed = double.tryParse(raw.isEmpty
        ? bind.mainGetLocalOption(key: kAndroidTwoFingerScrollSensitivity)
        : raw);
    setState(() {
      _wheelScrollSensitivity =
          _roundSensitivity(_clampSensitivity(parsed ?? 1.0));
    });
  }

  Future<void> _storeWheelSensitivity(double v) async {
    final next = _roundSensitivity(_clampSensitivity(v));
    setState(() => _wheelScrollSensitivity = next);
    await bind.mainSetLocalOption(
      key: kAndroidWheelScrollSensitivity,
      value: next.toStringAsFixed(2),
    );
  }

  void _loadReverseMouseWheel() {
    var optionValue = '';
    final sessionId = widget.inputModel?.sessionId;
    if (sessionId != null) {
      optionValue =
          bind.sessionGetReverseMouseWheelSync(sessionId: sessionId) ?? '';
    }
    if (optionValue.isEmpty) {
      optionValue = bind.mainGetUserDefaultOption(key: kKeyReverseMouseWheel);
    }
    setState(() => _reverseMouseWheel = optionValue == 'Y');
  }

  Future<void> _storeReverseMouseWheel(bool value) async {
    setState(() => _reverseMouseWheel = value);
    final v = value ? 'Y' : 'N';
    await bind.mainSetUserDefaultOption(key: kKeyReverseMouseWheel, value: v);
    final sessionId = widget.inputModel?.sessionId;
    if (sessionId != null) {
      await bind.sessionSetReverseMouseWheel(sessionId: sessionId, value: v);
    }
    // If the per-source two-finger option is unset, it inherits the mouse wheel
    // option for backward compatibility. Keep the UI state in sync.
    final twoFingerRaw =
        bind.mainGetUserDefaultOption(key: kKeyReverseTwoFingerScroll);
    if (twoFingerRaw.isEmpty) {
      setState(() => _reverseTwoFingerScroll = value);
    }
  }

  void _loadReverseTwoFingerScroll() {
    var optionValue =
        bind.mainGetUserDefaultOption(key: kKeyReverseTwoFingerScroll);
    if (optionValue.isEmpty) {
      // Backward compatible: default to the existing reverse mouse wheel option.
      optionValue = _reverseMouseWheel ? 'Y' : 'N';
    }
    setState(() => _reverseTwoFingerScroll = optionValue == 'Y');
  }

  Future<void> _storeReverseTwoFingerScroll(bool value) async {
    setState(() => _reverseTwoFingerScroll = value);
    final v = value ? 'Y' : 'N';
    await bind.mainSetUserDefaultOption(
        key: kKeyReverseTwoFingerScroll, value: v);
  }

  void _loadCtrlWheelZoomGestures() {
    final edgeRaw = bind.mainGetUserDefaultOption(
        key: kKeyEnableTwoFingerEdgeCtrlWheelZoom);
    final threeRaw = bind.mainGetUserDefaultOption(
        key: kKeyEnableThreeFingerSwipeCtrlWheelZoom);
    setState(() {
      _enableTwoFingerEdgeCtrlWheelZoom =
          edgeRaw.isEmpty ? true : edgeRaw == 'Y';
      _enableThreeFingerSwipeCtrlWheelZoom =
          threeRaw.isEmpty ? false : threeRaw == 'Y';
    });
  }

  Future<void> _storeEnableTwoFingerEdgeCtrlWheelZoom(bool v) async {
    await bind.mainSetUserDefaultOption(
        key: kKeyEnableTwoFingerEdgeCtrlWheelZoom, value: v ? 'Y' : 'N');
    setState(() => _enableTwoFingerEdgeCtrlWheelZoom = v);
  }

  Future<void> _storeEnableThreeFingerSwipeCtrlWheelZoom(bool v) async {
    await bind.mainSetUserDefaultOption(
        key: kKeyEnableThreeFingerSwipeCtrlWheelZoom, value: v ? 'Y' : 'N');
    setState(() => _enableThreeFingerSwipeCtrlWheelZoom = v);
  }

  @override
  void initState() {
    super.initState();
    _loadTwoFingerSensitivity();
    _loadWheelSensitivity();
    _loadReverseMouseWheel();
    _loadReverseTwoFingerScroll();
    _loadCtrlWheelZoomGestures();
  }

  /// Helper to exit relative mouse mode when certain conditions are met.
  /// This reduces code duplication across multiple UI callbacks.
  void _exitRelativeMouseModeIf(bool condition) {
    if (condition) {
      widget.inputModel?.setRelativeMouseMode(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final space = 12.0;
    var width = size.width - 2 * space;
    final minWidth = 90;
    if (size.width > minWidth + 2 * space) {
      final n = (size.width / (minWidth + 2 * space)).floor();
      width = size.width / n - 2 * space;
    }
    return Center(
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ToggleSwitch(
                        initialLabelIndex: _selectedIndex,
                        activeFgColor: Colors.white,
                        inactiveFgColor: Colors.white60,
                        activeBgColor: [MyTheme.accent],
                        inactiveBgColor: Theme.of(context).hintColor,
                        totalSwitches: 3,
                        minWidth: 150,
                        fontSize: 15,
                        iconSize: 18,
                        labels: [
                          translate("Mouse mode"),
                          translate("Touch mode"),
                          _gestureHelpCanvasEditModeLabel(),
                        ],
                        icons: [Icons.mouse, Icons.touch_app, Icons.crop_free],
                        onToggle: (index) {
                          setState(() {
                            if (_selectedIndex != index) {
                              _selectedIndex = index ?? 0;
                              if (_selectedIndex == 2) {
                                _canvasEditMode = true;
                                widget.onCanvasEditModeChange(true);
                                // Exit relative mouse mode when entering canvas edit mode
                                _exitRelativeMouseModeIf(true);
                              } else {
                                _canvasEditMode = false;
                                widget.onCanvasEditModeChange(false);
                                final nextTouchMode = _selectedIndex == 1;
                                if (_touchMode != nextTouchMode) {
                                  _touchMode = nextTouchMode;
                                  widget.onTouchModeChange(_touchMode);
                                  // Exit relative mouse mode when switching to touch mode
                                  _exitRelativeMouseModeIf(_touchMode);
                                }
                              }
                            }
                          });
                        },
                      ),
                      if (_touchMode && !_canvasEditMode)
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: SizedBox(
                            width: 320,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('双指灵敏度'),
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip:
                                          '-${_twoFingerSensitivityStep.toStringAsFixed(2)}',
                                      icon: const Icon(Icons.chevron_left),
                                      onPressed: () =>
                                          _storeTwoFingerSensitivity(
                                              _twoFingerScrollSensitivity -
                                                  _twoFingerSensitivityStep),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: _twoFingerScrollSensitivity,
                                        min: _minTwoFingerSensitivity,
                                        max: _maxTwoFingerSensitivity,
                                        divisions: ((_maxTwoFingerSensitivity -
                                                    _minTwoFingerSensitivity) /
                                                _twoFingerSensitivityStep)
                                            .round(),
                                        label:
                                            '${_twoFingerScrollSensitivity.toStringAsFixed(2)}x',
                                        onChanged: (value) {
                                          setState(() {
                                            _twoFingerScrollSensitivity =
                                                _roundSensitivity(
                                                    _clampSensitivity(value));
                                          });
                                        },
                                        onChangeEnd: (value) =>
                                            _storeTwoFingerSensitivity(value),
                                      ),
                                    ),
                                    Text(
                                      '${_twoFingerScrollSensitivity.toStringAsFixed(2)}x',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    IconButton(
                                      tooltip:
                                          '+${_twoFingerSensitivityStep.toStringAsFixed(2)}',
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed: () =>
                                          _storeTwoFingerSensitivity(
                                              _twoFingerScrollSensitivity +
                                                  _twoFingerSensitivityStep),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text('滚轮灵敏度'),
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip:
                                          '-${_twoFingerSensitivityStep.toStringAsFixed(2)}',
                                      icon: const Icon(Icons.chevron_left),
                                      onPressed: () => _storeWheelSensitivity(
                                          _wheelScrollSensitivity -
                                              _twoFingerSensitivityStep),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: _wheelScrollSensitivity,
                                        min: _minTwoFingerSensitivity,
                                        max: _maxTwoFingerSensitivity,
                                        divisions: ((_maxTwoFingerSensitivity -
                                                    _minTwoFingerSensitivity) /
                                                _twoFingerSensitivityStep)
                                            .round(),
                                        label:
                                            '${_wheelScrollSensitivity.toStringAsFixed(2)}x',
                                        onChanged: (value) {
                                          setState(() {
                                            _wheelScrollSensitivity =
                                                _roundSensitivity(
                                                    _clampSensitivity(value));
                                          });
                                        },
                                        onChangeEnd: (value) =>
                                            _storeWheelSensitivity(value),
                                      ),
                                    ),
                                    Text(
                                      '${_wheelScrollSensitivity.toStringAsFixed(2)}x',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    IconButton(
                                      tooltip:
                                          '+${_twoFingerSensitivityStep.toStringAsFixed(2)}',
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed: () => _storeWheelSensitivity(
                                          _wheelScrollSensitivity +
                                              _twoFingerSensitivityStep),
                                    ),
                                  ],
                                ),
                                Transform.translate(
                                  offset: const Offset(-10.0, 0.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: _reverseTwoFingerScroll,
                                        onChanged: (widget.inputModel != null &&
                                                widget
                                                    .inputModel!.keyboardPerm &&
                                                !widget.inputModel!.isViewOnly)
                                            ? (value) {
                                                if (value == null) return;
                                                _storeReverseTwoFingerScroll(
                                                    value);
                                              }
                                            : null,
                                      ),
                                      InkWell(
                                        onTap: (widget.inputModel != null &&
                                                widget
                                                    .inputModel!.keyboardPerm &&
                                                !widget.inputModel!.isViewOnly)
                                            ? () =>
                                                _storeReverseTwoFingerScroll(
                                                    !_reverseTwoFingerScroll)
                                            : null,
                                        child: const Text('双指滚动反向'),
                                      ),
                                    ],
                                  ),
                                ),
                                Transform.translate(
                                  offset: const Offset(-10.0, 0.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: _reverseMouseWheel,
                                        onChanged: (widget.inputModel != null &&
                                                widget
                                                    .inputModel!.keyboardPerm &&
                                                !widget.inputModel!.isViewOnly)
                                            ? (value) {
                                                if (value == null) return;
                                                _storeReverseMouseWheel(value);
                                              }
                                            : null,
                                      ),
                                      InkWell(
                                        onTap: (widget.inputModel != null &&
                                                widget
                                                    .inputModel!.keyboardPerm &&
                                                !widget.inputModel!.isViewOnly)
                                            ? () => _storeReverseMouseWheel(
                                                !_reverseMouseWheel)
                                            : null,
                                        child: const Text('滑轮条反向'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Transform.translate(
                                  offset: const Offset(-10.0, 0.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value:
                                            _enableTwoFingerEdgeCtrlWheelZoom,
                                        onChanged: (widget.inputModel != null &&
                                                widget
                                                    .inputModel!.keyboardPerm &&
                                                !widget.inputModel!.isViewOnly)
                                            ? (value) {
                                                if (value == null) return;
                                                _storeEnableTwoFingerEdgeCtrlWheelZoom(
                                                    value);
                                              }
                                            : null,
                                      ),
                                      InkWell(
                                        onTap: (widget.inputModel != null &&
                                                widget
                                                    .inputModel!.keyboardPerm &&
                                                !widget.inputModel!.isViewOnly)
                                            ? () => _storeEnableTwoFingerEdgeCtrlWheelZoom(
                                                !_enableTwoFingerEdgeCtrlWheelZoom)
                                            : null,
                                        child: const Text('双指边缘缩放 (Ctrl+滚轮)'),
                                      ),
                                    ],
                                  ),
                                ),
                                Transform.translate(
                                  offset: const Offset(-10.0, 0.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value:
                                            _enableThreeFingerSwipeCtrlWheelZoom,
                                        onChanged: (widget.inputModel != null &&
                                                widget
                                                    .inputModel!.keyboardPerm &&
                                                !widget.inputModel!.isViewOnly)
                                            ? (value) {
                                                if (value == null) return;
                                                _storeEnableThreeFingerSwipeCtrlWheelZoom(
                                                    value);
                                              }
                                            : null,
                                      ),
                                      InkWell(
                                        onTap: (widget.inputModel != null &&
                                                widget
                                                    .inputModel!.keyboardPerm &&
                                                !widget.inputModel!.isViewOnly)
                                            ? () => _storeEnableThreeFingerSwipeCtrlWheelZoom(
                                                !_enableThreeFingerSwipeCtrlWheelZoom)
                                            : null,
                                        child: const Text('三指上下滑缩放 (Ctrl+滚轮)'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Transform.translate(
                        offset: const Offset(-10.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _virtualMouseMode.showVirtualMouse,
                              onChanged: (value) async {
                                if (value == null) return;
                                await _virtualMouseMode.toggleVirtualMouse();
                                // Exit relative mouse mode when virtual mouse is hidden
                                _exitRelativeMouseModeIf(
                                    !_virtualMouseMode.showVirtualMouse);
                                setState(() {});
                              },
                            ),
                            InkWell(
                              onTap: () async {
                                await _virtualMouseMode.toggleVirtualMouse();
                                // Exit relative mouse mode when virtual mouse is hidden
                                _exitRelativeMouseModeIf(
                                    !_virtualMouseMode.showVirtualMouse);
                                setState(() {});
                              },
                              child: Text(translate('Show virtual mouse')),
                            ),
                          ],
                        ),
                      ),
                      if (_touchMode &&
                          !_canvasEditMode &&
                          _virtualMouseMode.showVirtualMouse)
                        Padding(
                          // Indent "Virtual mouse size"
                          padding: const EdgeInsets.only(left: 24.0),
                          child: SizedBox(
                            width: 260,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 0.0, bottom: 0),
                                  child: Text(translate('Virtual mouse size')),
                                ),
                                Transform.translate(
                                  offset: Offset(-0.0, -6.0),
                                  child: Row(
                                    children: [
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 0.0),
                                        child: Text(translate('Small')),
                                      ),
                                      Expanded(
                                        child: Slider(
                                          value: _virtualMouseMode
                                              .virtualMouseScale,
                                          min: 0.8,
                                          max: 1.8,
                                          divisions: 10,
                                          onChanged: (value) {
                                            _virtualMouseMode
                                                .setVirtualMouseScale(value);
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 16.0),
                                        child: Text(translate('Large')),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (!_touchMode &&
                          !_canvasEditMode &&
                          _virtualMouseMode.showVirtualMouse)
                        Transform.translate(
                          offset: const Offset(-10.0, -12.0),
                          child: Padding(
                              // Indent "Show virtual joystick"
                              padding: const EdgeInsets.only(left: 24.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value:
                                        _virtualMouseMode.showVirtualJoystick,
                                    onChanged: (value) async {
                                      if (value == null) return;
                                      await _virtualMouseMode
                                          .toggleVirtualJoystick();
                                      // Exit relative mouse mode when joystick is hidden
                                      _exitRelativeMouseModeIf(
                                          !_virtualMouseMode
                                              .showVirtualJoystick);
                                      setState(() {});
                                    },
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      await _virtualMouseMode
                                          .toggleVirtualJoystick();
                                      // Exit relative mouse mode when joystick is hidden
                                      _exitRelativeMouseModeIf(
                                          !_virtualMouseMode
                                              .showVirtualJoystick);
                                      setState(() {});
                                    },
                                    child: Text(
                                        translate("Show virtual joystick")),
                                  ),
                                ],
                              )),
                        ),
                      // Relative mouse mode option - only visible when joystick is shown
                      if (!_touchMode &&
                          !_canvasEditMode &&
                          _virtualMouseMode.showVirtualMouse &&
                          _virtualMouseMode.showVirtualJoystick &&
                          widget.inputModel != null)
                        Obx(() => Transform.translate(
                              offset: const Offset(-10.0, -24.0),
                              child: Padding(
                                  // Indent further for 'Relative mouse mode'
                                  padding: const EdgeInsets.only(left: 48.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: widget.inputModel!
                                            .relativeMouseMode.value,
                                        onChanged: (value) {
                                          if (value == null) return;
                                          widget.inputModel!
                                              .setRelativeMouseMode(value);
                                        },
                                      ),
                                      InkWell(
                                        onTap: () {
                                          widget.inputModel!
                                              .toggleRelativeMouseMode();
                                        },
                                        child: Text(
                                            translate('Relative mouse mode')),
                                      ),
                                    ],
                                  )),
                            )),
                    ],
                  ),
                ),
                Container(
                    child: Wrap(
                  spacing: space,
                  runSpacing: 2 * space,
                  children: _canvasEditMode
                      ? [
                          GestureInfo(
                              width,
                              GestureIcons.iconGestureFDrag,
                              translate("One-Finger Move"),
                              translate("Canvas Move")),
                          GestureInfo(
                              width,
                              GestureIcons.iconGesturePinch,
                              translate("Pinch to Zoom"),
                              translate("Canvas Zoom")),
                        ]
                      : _touchMode
                          ? [
                              GestureInfo(
                                  width,
                                  GestureIcons.iconMobileTouch,
                                  translate("One-Finger Tap"),
                                  translate("Left Mouse")),
                              GestureInfo(
                                  width,
                                  GestureIcons.iconGesturePressHold,
                                  translate("One-Long Tap"),
                                  translate("Right Mouse")),
                              GestureInfo(
                                  width,
                                  GestureIcons.iconGestureFSwipeRight,
                                  translate("One-Finger Move"),
                                  translate("Mouse Drag")),
                              GestureInfo(
                                  width,
                                  GestureIcons.iconGestureFThreeFingers,
                                  translate("Three-Finger vertically"),
                                  translate("Mouse Wheel")),
                              GestureInfo(
                                  width,
                                  GestureIcons.iconGestureFDrag,
                                  translate("Two-Finger Move"),
                                  translate("Canvas Move")),
                              GestureInfo(
                                  width,
                                  GestureIcons.iconGesturePinch,
                                  translate("Pinch to Zoom"),
                                  translate("Canvas Zoom")),
                            ]
                          : [
                              GestureInfo(
                                  width,
                                  GestureIcons.iconMobileTouch,
                                  translate("One-Finger Tap"),
                                  translate("Left Mouse")),
                              GestureInfo(
                                  width,
                                  GestureIcons.iconGesturePressHold,
                                  translate("One-Long Tap"),
                                  translate("Right Mouse")),
                              GestureInfo(
                                  width,
                                  GestureIcons.iconGestureFSwipeRight,
                                  translate("Double Tap & Move"),
                                  translate("Mouse Drag")),
                              GestureInfo(
                                  width,
                                  GestureIcons.iconGestureFThreeFingers,
                                  translate("Three-Finger vertically"),
                                  translate("Mouse Wheel")),
                              GestureInfo(
                                  width,
                                  GestureIcons.iconGestureFDrag,
                                  translate("Two-Finger Move"),
                                  translate("Canvas Move")),
                              GestureInfo(
                                  width,
                                  GestureIcons.iconGesturePinch,
                                  translate("Pinch to Zoom"),
                                  translate("Canvas Zoom")),
                            ],
                )),
              ],
            )));
  }
}

class GestureInfo extends StatelessWidget {
  const GestureInfo(this.width, this.icon, this.fromText, this.toText,
      {Key? key})
      : super(key: key);

  final String fromText;
  final String toText;
  final IconData icon;
  final double width;

  final iconSize = 35.0;
  final iconColor = MyTheme.accent;

  @override
  Widget build(BuildContext context) {
    return Container(
        width: width,
        child: Column(
          children: [
            Icon(
              icon,
              size: iconSize,
              color: iconColor,
            ),
            SizedBox(height: 6),
            Text(fromText,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 9, color: Theme.of(context).hintColor)),
            SizedBox(height: 3),
            Text(toText,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color))
          ],
        ));
  }
}
