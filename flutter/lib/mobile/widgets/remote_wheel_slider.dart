import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/remote_input_event_log.dart';
import 'package:flutter_hbb/common/widgets/overlay.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';

class RemoteWheelSlider extends StatefulWidget {
  const RemoteWheelSlider({
    super.key,
    required this.inputModel,
    required this.cursorModel,
    required this.position,
    this.width = 56,
    this.height = 230,
  });

  final InputModel inputModel;
  final CursorModel cursorModel;
  final DraggableKeyPosition position;
  final double width;
  final double height;

  @override
  State<RemoteWheelSlider> createState() => _RemoteWheelSliderState();
}

class _RemoteWheelSliderState extends State<RemoteWheelSlider> {
  bool _moveMode = false;
  bool _vertical = true;
  double _thumbOffset = 0.0; // px, +down / -up
  double _scrollIntegral = 0.0;
  Offset? _lastDoubleTapDownLocal;
  Rect? _blockedRect;
  bool _thumbMoveLogged = false;

  double get _currentWidth => _vertical ? widget.width : widget.height;
  double get _currentHeight => _vertical ? widget.height : widget.width;

  @override
  void initState() {
    super.initState();
    final raw = bind.mainGetLocalOption(key: kAndroidRemoteWheelSliderVertical);
    if (raw == 'Y') {
      _vertical = true;
    } else if (raw == 'N') {
      _vertical = false;
    }
  }

  double _getSensitivity() {
    final raw = bind.mainGetLocalOption(key: kAndroidWheelScrollSensitivity);
    final parsed = double.tryParse(raw.isEmpty
        ? bind.mainGetLocalOption(key: kAndroidTwoFingerScrollSensitivity)
        : raw);
    final v = parsed ?? 1.0;
    if (v.isNaN || v.isInfinite) return 1.0;
    return v.clamp(0.01, 5.0);
  }

  bool _getReverseWheelSlider() {
    var optionValue = bind.sessionGetReverseMouseWheelSync(
            sessionId: widget.inputModel.sessionId) ??
        '';
    if (optionValue.isEmpty) {
      optionValue = bind.mainGetUserDefaultOption(key: kKeyReverseMouseWheel);
    }
    return optionValue == 'Y';
  }

  void _ensureDefaultPosition(Size screenSize) {
    if (!widget.position.isInvalid()) {
      widget.position.tryAdjust(_currentWidth, _currentHeight, 1);
      _updateBlockedRect();
      return;
    }
    final maxX =
        (screenSize.width - _currentWidth).clamp(0.0, screenSize.width);
    final maxY =
        (screenSize.height - _currentHeight).clamp(0.0, screenSize.height);
    final x = (screenSize.width - _currentWidth - 10).clamp(0.0, maxX);
    final y = ((screenSize.height - _currentHeight) / 2).clamp(0.0, maxY);
    widget.position.update(Offset(x.toDouble(), y.toDouble()));
    _updateBlockedRect();
  }

  void _moveBy(Offset delta, Size screenSize) {
    final pos = widget.position.pos;
    var x = pos.dx + delta.dx;
    var y = pos.dy + delta.dy;
    x = x.clamp(0.0, screenSize.width - _currentWidth);
    y = y.clamp(0.0, screenSize.height - _currentHeight);
    widget.position.update(Offset(x, y));
    _updateBlockedRect();
    setState(() {});
  }

  void _updateBlockedRect() {
    final newRect = Rect.fromLTWH(
      widget.position.pos.dx,
      widget.position.pos.dy,
      _currentWidth,
      _currentHeight,
    );
    if (_blockedRect != null) {
      widget.cursorModel.removeBlockedRect(_blockedRect!);
    }
    widget.cursorModel.addBlockedRect(newRect);
    _blockedRect = newRect;
  }

  @override
  void dispose() {
    if (_blockedRect != null) {
      widget.cursorModel.removeBlockedRect(_blockedRect!);
      _blockedRect = null;
    }
    super.dispose();
  }

  void _scrollByDelta(double delta) {
    final sensitivity = _getSensitivity();
    _scrollIntegral += (-delta) / 4 * sensitivity;
    final reverseFactor = _getReverseWheelSlider() ? -1 : 1;
    while (_scrollIntegral >= 1) {
      final step = 1 * reverseFactor;
      widget.inputModel.scrollWheel(y: step);
      _scrollIntegral -= 1;
      RemoteInputEventLog.add(
        'wheel_v',
        data: {'dir': step > 0 ? 'down' : 'up', 'step': step},
      );
    }
    while (_scrollIntegral <= -1) {
      final step = -1 * reverseFactor;
      widget.inputModel.scrollWheel(y: step);
      _scrollIntegral += 1;
      RemoteInputEventLog.add(
        'wheel_v',
        data: {'dir': step > 0 ? 'down' : 'up', 'step': step},
      );
    }
  }

  bool _isDoubleTapCenter() {
    final p = _lastDoubleTapDownLocal;
    if (p == null) return false;
    final center = _vertical ? (_currentHeight / 2) : (_currentWidth / 2);
    final v = _vertical ? p.dy : p.dx;
    return (v - center).abs() <= 18;
  }

  void _toggleOrientation(Size screenSize) {
    setState(() {
      _vertical = !_vertical;
      _thumbOffset = 0.0;
      _scrollIntegral = 0.0;
      if (_moveMode) _moveMode = false;
    });
    bind.mainSetLocalOption(
      key: kAndroidRemoteWheelSliderVertical,
      value: _vertical ? 'Y' : 'N',
    );
    widget.position.tryAdjust(_currentWidth, _currentHeight, 1);
    _updateBlockedRect();
    RemoteInputEventLog.add(
      'wheel_slider_orientation',
      data: {'axis': _vertical ? 'v' : 'h'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    _ensureDefaultPosition(screenSize);

    return Positioned(
      left: widget.position.pos.dx,
      top: widget.position.pos.dy,
      width: _currentWidth,
      height: _currentHeight,
      child: Semantics(
        label: 'u2_remote_wheel_slider',
        container: true,
        child: GestureDetector(
          // Allow underlying remote view to also participate in gesture arenas,
          // so two-finger scrolling can still work even when fingers start on
          // top of the slider.
          behavior: HitTestBehavior.translucent,
          onDoubleTapDown: (d) => _lastDoubleTapDownLocal = d.localPosition,
          onDoubleTap: () {
            if (_moveMode) {
              setState(() => _moveMode = false);
              return;
            }
            if (_isDoubleTapCenter()) {
              widget.inputModel.tap(MouseButtons.wheel);
              RemoteInputEventLog.add('middle_click');
              return;
            }
            setState(() => _moveMode = true);
          },
          onLongPress: () => _toggleOrientation(screenSize),
          onPanUpdate: (details) {
            if (_moveMode) {
              _moveBy(details.delta, screenSize);
              return;
            }

            final delta = _vertical ? details.delta.dy : details.delta.dx;
            setState(() {
              final mainLen = _vertical ? _currentHeight : _currentWidth;
              _thumbOffset = (_thumbOffset + delta).clamp(
                -(mainLen / 2 - 24),
                (mainLen / 2 - 24),
              );
            });
            _scrollByDelta(delta);

            if (!_thumbMoveLogged && _thumbOffset.abs() > 4) {
              _thumbMoveLogged = true;
              RemoteInputEventLog.add(
                'wheel_slider_thumb',
                data: {
                  'phase': 'move',
                  'offset': _thumbOffset.round(),
                },
              );
            }
          },
          onPanStart: (_) {
            if (_moveMode) return;
            _thumbMoveLogged = false;
          },
          onPanEnd: (_) {
            if (_moveMode) return;
            setState(() => _thumbOffset = 0);
            RemoteInputEventLog.add(
              'wheel_slider_thumb',
              data: {
                'phase': 'reset',
                'offset': 0,
              },
            );
          },
          onPanCancel: () {
            if (_moveMode) return;
            setState(() => _thumbOffset = 0);
            RemoteInputEventLog.add(
              'wheel_slider_thumb',
              data: {
                'phase': 'reset',
                'offset': 0,
              },
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xCC000000),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _moveMode ? MyTheme.accent : Colors.white24,
                width: _moveMode ? 1.5 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: _vertical ? 8 : null,
                  left: _vertical ? null : 8,
                  child: Icon(
                    _moveMode
                        ? Icons.open_with
                        : (_vertical ? Icons.swap_vert : Icons.swap_horiz),
                    size: 14,
                    color: _moveMode ? Colors.white : Colors.white70,
                  ),
                ),
                AnimatedAlign(
                  alignment: _vertical
                      ? Alignment(0, _thumbOffset / (_currentHeight / 2 - 24))
                      : Alignment(_thumbOffset / (_currentWidth / 2 - 24), 0),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.elasticOut,
                  child: Semantics(
                    label: 'u2_remote_wheel_slider_thumb',
                    container: true,
                    child: Container(
                      width: _vertical ? (_currentWidth - 16) : 36,
                      height: _vertical ? 36 : (_currentHeight - 16),
                      decoration: BoxDecoration(
                        color: _moveMode
                            ? Colors.white24
                            : Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: _vertical ? 8 : null,
                  right: _vertical ? null : 8,
                  child: Icon(
                    Icons.mouse,
                    size: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
