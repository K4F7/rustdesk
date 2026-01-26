import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/remote_input_event_log.dart';
import 'package:flutter_hbb/common/widgets/overlay.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';

const double _kRemoteShortcutScale = 0.7;

class RemoteShortcut {
  RemoteShortcut({
    required this.id,
    required this.name,
    required this.keys,
  });

  final String id;
  final String name;
  final List<String> keys;

  factory RemoteShortcut.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final name = (json['name'] ?? '').toString();
    final rawKeys = json['keys'];
    final keys = (rawKeys is List)
        ? rawKeys.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    return RemoteShortcut(id: id, name: name, keys: keys);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'keys': keys,
      };
}

class RemoteShortcutsStore {
  static List<RemoteShortcut> load() {
    final raw = bind.mainGetLocalOption(key: kAndroidRemoteShortcuts);
    if (raw.isEmpty) return <RemoteShortcut>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <RemoteShortcut>[];
      return decoded
          .whereType<Map>()
          .map((e) => RemoteShortcut.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return <RemoteShortcut>[];
    }
  }

  static Future<void> save(List<RemoteShortcut> shortcuts) async {
    final raw = jsonEncode(shortcuts.map((e) => e.toJson()).toList());
    await bind.mainSetLocalOption(key: kAndroidRemoteShortcuts, value: raw);
  }
}

String formatShortcutKeys(List<String> keys, {required bool isMacPeer}) {
  String mapOne(String k) {
    switch (k) {
      case 'VK_CONTROL':
        return 'Ctrl';
      case 'RControl':
        return 'R-Ctrl';
      case 'VK_SHIFT':
        return 'Shift';
      case 'RShift':
        return 'R-Shift';
      case 'VK_MENU':
        return 'Alt';
      case 'RAlt':
        return 'R-Alt';
      case 'VK_LWIN':
      case 'VK_RWIN':
      case 'Meta':
      case 'RWin':
        return isMacPeer ? 'Cmd' : 'Win';
      case 'VK_RETURN':
      case 'VK_ENTER':
        return 'Enter';
      case 'VK_CAPITAL':
        return 'CapsLock';
      default:
        if (k.startsWith('VK_')) return k.substring(3);
        return k;
    }
  }

  return keys.map(mapOne).join(' + ');
}

bool _isCtrlKey(String k) =>
    k == 'VK_CONTROL' ||
    k == 'RControl' ||
    k == 'Control' ||
    k == 'Ctrl' ||
    k == 'CONTROL';

bool _isShiftKey(String k) =>
    k == 'VK_SHIFT' || k == 'RShift' || k == 'Shift' || k == 'SHIFT';

bool _isAltKey(String k) =>
    k == 'VK_MENU' || k == 'RAlt' || k == 'Alt' || k == 'MENU';

bool _isCmdKey(String k) =>
    k == 'VK_LWIN' ||
    k == 'VK_RWIN' ||
    k == 'Meta' ||
    k == 'LWin' ||
    k == 'RWin' ||
    k == 'Command' ||
    k == 'Cmd';

({List<String> modifierKeys, List<String> normalKeys}) _splitShortcutKeys(
    List<String> keys) {
  final modifierKeys = <String>[];
  final normalKeys = <String>[];
  for (final k in keys) {
    if (k.isEmpty) continue;
    if (_isCtrlKey(k) || _isShiftKey(k) || _isAltKey(k) || _isCmdKey(k)) {
      modifierKeys.add(k);
    } else {
      normalKeys.add(k);
    }
  }
  return (modifierKeys: modifierKeys, normalKeys: normalKeys);
}

void _applyShortcutModifiers(InputModel inputModel, List<String> keys) {
  inputModel.ctrl = keys.any(_isCtrlKey);
  inputModel.shift = keys.any(_isShiftKey);
  inputModel.alt = keys.any(_isAltKey);
  inputModel.command = keys.any(_isCmdKey);
}

Future<void> sendShortcutOnce(InputModel inputModel, List<String> keys,
    {required bool isMacPeer}) async {
  if (keys.isEmpty) return;
  final split = _splitShortcutKeys(keys);
  final savedCtrl = inputModel.ctrl;
  final savedShift = inputModel.shift;
  final savedAlt = inputModel.alt;
  final savedCmd = inputModel.command;
  inputModel.resetModifiers();
  _applyShortcutModifiers(inputModel, keys);

  final toPress = split.normalKeys.isEmpty ? keys : split.normalKeys;
  for (final k in toPress) {
    inputModel.inputKey(k, press: true);
  }

  inputModel.ctrl = savedCtrl;
  inputModel.shift = savedShift;
  inputModel.alt = savedAlt;
  inputModel.command = savedCmd;

  RemoteInputEventLog.add('shortcut_key_press', data: {
    'keys': formatShortcutKeys(keys, isMacPeer: isMacPeer),
  });
}

Future<void> setShortcutHold(InputModel inputModel, List<String> keys,
    {required bool hold, required bool isMacPeer}) async {
  if (keys.isEmpty) return;
  final split = _splitShortcutKeys(keys);
  final savedCtrl = inputModel.ctrl;
  final savedShift = inputModel.shift;
  final savedAlt = inputModel.alt;
  final savedCmd = inputModel.command;
  inputModel.resetModifiers();
  _applyShortcutModifiers(inputModel, keys);
  if (hold) {
    for (final k in split.modifierKeys) {
      inputModel.inputKey(k, down: true, press: false);
    }
    for (final k in split.normalKeys) {
      inputModel.inputKey(k, down: true, press: false);
    }
    RemoteInputEventLog.add('shortcut_key_hold_on', data: {
      'keys': formatShortcutKeys(keys, isMacPeer: isMacPeer),
    });
  } else {
    for (final k in split.normalKeys.reversed) {
      inputModel.inputKey(k, down: false, press: false);
    }
    for (final k in split.modifierKeys.reversed) {
      inputModel.inputKey(k, down: false, press: false);
    }
    RemoteInputEventLog.add('shortcut_key_hold_off', data: {
      'keys': formatShortcutKeys(keys, isMacPeer: isMacPeer),
    });
  }
  inputModel.ctrl = savedCtrl;
  inputModel.shift = savedShift;
  inputModel.alt = savedAlt;
  inputModel.command = savedCmd;
}

class RemoteShortcutsPanel extends StatefulWidget {
  const RemoteShortcutsPanel({
    super.key,
    required this.visible,
    required this.cursorModel,
    required this.inputModel,
    required this.shortcuts,
    required this.heldShortcutIds,
    required this.onDelete,
    required this.onToggleHold,
  });

  final bool visible;
  final CursorModel cursorModel;
  final InputModel inputModel;
  final List<RemoteShortcut> shortcuts;
  final Set<String> heldShortcutIds;
  final ValueChanged<RemoteShortcut> onDelete;
  final ValueChanged<RemoteShortcut> onToggleHold;

  @override
  State<RemoteShortcutsPanel> createState() => _RemoteShortcutsPanelState();
}

class _RemoteShortcutsPanelState extends State<RemoteShortcutsPanel> {
  static const double _gap = 8;
  static const double _defaultRight = 10;
  static const double _defaultTop = 86;

  static double _cmToDp(double cm) => cm * 160 / 2.54;

  final Map<String, DraggableKeyPosition> _positions = {};

  DraggableKeyPosition _positionFor(RemoteShortcut shortcut) {
    final cached = _positions[shortcut.id];
    if (cached != null) return cached;
    final p = DraggableKeyPosition(
        '${DraggablePositions.kRemoteShortcutButtonPrefix}${shortcut.id}');
    p.load();
    _positions[shortcut.id] = p;
    return p;
  }

  @override
  void didUpdateWidget(covariant RemoteShortcutsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.shortcuts.map((e) => e.id).toSet();
    _positions.removeWhere((id, _) => !ids.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) {
      return const Offstage();
    }

    final pi = gFFI.ffiModel.pi;
    final isMacPeer = pi.platform == kPeerPlatformMacOS;

    final btnH = _cmToDp(1.0) * _kRemoteShortcutScale;
    final btnW = _cmToDp(2.0) * _kRemoteShortcutScale;

    return Positioned.fill(
      child: Semantics(
        label: 'u2_remote_shortcuts_panel',
        container: true,
        excludeSemantics: true,
        child: Stack(
          children: [
            for (var i = 0; i < widget.shortcuts.length; i++)
              _RemoteShortcutFloatingButton(
                cursorModel: widget.cursorModel,
                inputModel: widget.inputModel,
                position: _positionFor(widget.shortcuts[i]),
                shortcut: widget.shortcuts[i],
                index: i,
                btnW: btnW,
                btnH: btnH,
                gap: _gap * _kRemoteShortcutScale,
                defaultRight: _defaultRight * _kRemoteShortcutScale,
                defaultTop: _defaultTop * _kRemoteShortcutScale,
                held: widget.heldShortcutIds.contains(widget.shortcuts[i].id),
                isMacPeer: isMacPeer,
                onDelete: widget.onDelete,
                onToggleHold: widget.onToggleHold,
              ),
          ],
        ),
      ),
    );
  }
}

class _RemoteShortcutFloatingButton extends StatefulWidget {
  const _RemoteShortcutFloatingButton({
    required this.cursorModel,
    required this.inputModel,
    required this.position,
    required this.shortcut,
    required this.index,
    required this.btnW,
    required this.btnH,
    required this.gap,
    required this.defaultRight,
    required this.defaultTop,
    required this.held,
    required this.isMacPeer,
    required this.onDelete,
    required this.onToggleHold,
  });

  final CursorModel cursorModel;
  final InputModel inputModel;
  final DraggableKeyPosition position;
  final RemoteShortcut shortcut;
  final int index;
  final double btnW;
  final double btnH;
  final double gap;
  final double defaultRight;
  final double defaultTop;
  final bool held;
  final bool isMacPeer;
  final ValueChanged<RemoteShortcut> onDelete;
  final ValueChanged<RemoteShortcut> onToggleHold;

  @override
  State<_RemoteShortcutFloatingButton> createState() =>
      _RemoteShortcutFloatingButtonState();
}

class _RemoteShortcutFloatingButtonState
    extends State<_RemoteShortcutFloatingButton> {
  Rect? _blockedRect;

  void _ensureDefaultPosition(Size screenSize) {
    if (!widget.position.isInvalid()) return;
    final x = (screenSize.width - widget.defaultRight - widget.btnW)
        .clamp(0.0, screenSize.width);
    final y = (widget.defaultTop + widget.index * (widget.btnH + widget.gap))
        .clamp(0.0, screenSize.height);
    widget.position.update(Offset(x.toDouble(), y.toDouble()));
  }

  void _syncBlockedRect() {
    final pos = widget.position.pos;
    final newRect = Rect.fromLTWH(pos.dx, pos.dy, widget.btnW, widget.btnH);
    if (_blockedRect != null) {
      widget.cursorModel.removeBlockedRect(_blockedRect!);
    }
    widget.cursorModel.addBlockedRect(newRect);
    _blockedRect = newRect;
  }

  void _moveBy(Offset delta, Size screenSize) {
    final pos = widget.position.pos;
    final maxX = (screenSize.width - widget.btnW).clamp(0.0, screenSize.width);
    final maxY =
        (screenSize.height - widget.btnH).clamp(0.0, screenSize.height);
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

    final label = widget.shortcut.name.isNotEmpty
        ? widget.shortcut.name
        : formatShortcutKeys(widget.shortcut.keys, isMacPeer: widget.isMacPeer);

    return Positioned(
      left: widget.position.pos.dx,
      top: widget.position.pos.dy,
      width: widget.btnW,
      height: widget.btnH,
      child: Semantics(
        label: 'u2_remote_shortcut_button',
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => _moveBy(d.delta, screenSize),
          onTap: () => sendShortcutOnce(
            widget.inputModel,
            widget.shortcut.keys,
            isMacPeer: widget.isMacPeer,
          ),
          onDoubleTap: () => widget.onToggleHold(widget.shortcut),
          onLongPress: () async {
            final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('删除快捷键？'),
                    content: Text(label),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                ) ??
                false;
            if (ok) widget.onDelete(widget.shortcut);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10 * _kRemoteShortcutScale),
              border: Border.all(
                color: widget.held ? MyTheme.accent : Colors.white38,
                width: widget.held ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: 10 * _kRemoteShortcutScale,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12 * _kRemoteShortcutScale,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
