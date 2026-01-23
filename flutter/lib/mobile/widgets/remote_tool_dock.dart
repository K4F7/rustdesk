import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/overlay.dart';
import 'package:flutter_hbb/models/model.dart';

class RemoteToolDock extends StatefulWidget {
  const RemoteToolDock({
    super.key,
    required this.cursorModel,
    required this.showArrowButton,
    required this.shortcutsVisible,
    required this.keyboardVisible,
    required this.onToggleKeyboard,
    required this.onToggleShortcuts,
    required this.onAddShortcut,
    required this.onArrowPressed,
    required this.shortcutsPosition,
    required this.keyboardPosition,
    required this.arrowPosition,
  });

  final CursorModel cursorModel;
  final bool showArrowButton;
  final bool shortcutsVisible;
  final bool keyboardVisible;
  final VoidCallback onToggleKeyboard;
  final VoidCallback onToggleShortcuts;
  final VoidCallback onAddShortcut;
  final VoidCallback onArrowPressed;
  final DraggableKeyPosition shortcutsPosition;
  final DraggableKeyPosition keyboardPosition;
  final DraggableKeyPosition arrowPosition;

  @override
  State<RemoteToolDock> createState() => _RemoteToolDockState();
}

class _RemoteToolDockState extends State<RemoteToolDock> {
  static const double _btn = 46;
  static const double _gap = 10;
  static const double _margin = 10;

  Widget _circleButton({
    required String semanticsLabel,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    bool active = false,
  }) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: _btn,
          height: _btn,
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withOpacity(0.90),
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? Colors.white : Colors.white70,
              width: active ? 2 : 1,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          _RemoteToolDockFloatingButton(
            cursorModel: widget.cursorModel,
            position: widget.shortcutsPosition,
            btnSize: _btn,
            margin: _margin,
            defaultIndex: 0,
            gap: _gap,
            child: _circleButton(
              semanticsLabel: 'u2_remote_shortcuts_toggle',
              icon: widget.shortcutsVisible
                  ? Icons.view_list
                  : Icons.view_list_outlined,
              onTap: widget.onToggleShortcuts,
              onLongPress: widget.onAddShortcut,
              active: widget.shortcutsVisible,
            ),
          ),
          _RemoteToolDockFloatingButton(
            cursorModel: widget.cursorModel,
            position: widget.keyboardPosition,
            btnSize: _btn,
            margin: _margin,
            defaultIndex: 1,
            gap: _gap,
            child: _circleButton(
              semanticsLabel: 'u2_remote_keyboard_button',
              icon:
                  widget.keyboardVisible ? Icons.keyboard_hide : Icons.keyboard,
              onTap: widget.onToggleKeyboard,
              active: widget.keyboardVisible,
            ),
          ),
          if (widget.showArrowButton)
            _RemoteToolDockFloatingButton(
              cursorModel: widget.cursorModel,
              position: widget.arrowPosition,
              btnSize: _btn,
              margin: _margin,
              defaultIndex: 2,
              gap: _gap,
              child: _circleButton(
                semanticsLabel: 'u2_remote_floating_arrow',
                icon: Icons.keyboard_arrow_up,
                onTap: widget.onArrowPressed,
              ),
            ),
        ],
      ),
    );
  }
}

class _RemoteToolDockFloatingButton extends StatefulWidget {
  const _RemoteToolDockFloatingButton({
    required this.cursorModel,
    required this.position,
    required this.btnSize,
    required this.margin,
    required this.defaultIndex,
    required this.gap,
    required this.child,
  });

  final CursorModel cursorModel;
  final DraggableKeyPosition position;
  final double btnSize;
  final double margin;
  final int defaultIndex;
  final double gap;
  final Widget child;

  @override
  State<_RemoteToolDockFloatingButton> createState() =>
      _RemoteToolDockFloatingButtonState();
}

class _RemoteToolDockFloatingButtonState
    extends State<_RemoteToolDockFloatingButton> {
  Rect? _blockedRect;

  void _ensureDefaultPosition(Size screenSize) {
    if (!widget.position.isInvalid()) return;
    final x = (screenSize.width - widget.btnSize - widget.margin)
        .clamp(0.0, screenSize.width);
    final y = (screenSize.height * 0.35 +
            widget.defaultIndex * (widget.btnSize + widget.gap))
        .clamp(0.0, screenSize.height);
    widget.position.update(Offset(x.toDouble(), y.toDouble()));
  }

  void _syncBlockedRect() {
    final pos = widget.position.pos;
    final newRect =
        Rect.fromLTWH(pos.dx, pos.dy, widget.btnSize, widget.btnSize);
    if (_blockedRect != null) {
      widget.cursorModel.removeBlockedRect(_blockedRect!);
    }
    widget.cursorModel.addBlockedRect(newRect);
    _blockedRect = newRect;
  }

  void _moveBy(Offset delta, Size screenSize) {
    final pos = widget.position.pos;
    final maxX =
        (screenSize.width - widget.btnSize).clamp(0.0, screenSize.width);
    final maxY =
        (screenSize.height - widget.btnSize).clamp(0.0, screenSize.height);
    final x = (pos.dx + delta.dx).clamp(0.0, maxX);
    final y = (pos.dy + delta.dy).clamp(0.0, maxY);
    widget.position.update(Offset(x.toDouble(), y.toDouble()));
    _syncBlockedRect();
    setState(() {});
  }

  @override
  void dispose() {
    if (_blockedRect != null) {
      widget.cursorModel.removeBlockedRect(_blockedRect!);
      _blockedRect = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    _ensureDefaultPosition(screenSize);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncBlockedRect();
    });

    return Positioned(
      left: widget.position.pos.dx,
      top: widget.position.pos.dy,
      width: widget.btnSize,
      height: widget.btnSize,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (d) => _moveBy(d.delta, screenSize),
        child: widget.child,
      ),
    );
  }
}
