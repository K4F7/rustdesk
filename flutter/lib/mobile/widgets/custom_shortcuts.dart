import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';

const Size _kShortcutButtonSize = Size(88, 44);
const double _kShortcutFontSize = 13;
const double _kShortcutBorderRadius = 10;
const double _kCircleDiameter = 56;
const double _kCircleElevation = 6;
const int _kMaxShortcutCount = 30;
const Duration _kTapShortcutReleaseDelay = Duration(milliseconds: 40);
final Uuid _uuid = Uuid();

List<String> parseShortcutKeyString(String raw) {
  final items = raw.split('+').map((e) => e.trim()).where((e) => e.isNotEmpty);
  final mapped = <String>[];
  for (final item in items) {
    final mappedKey = _mapShortcutTokenToKey(item);
    if (mappedKey == null) {
      showToast('Unsupported key: $item');
      return [];
    }
    mapped.add(mappedKey);
  }
  if (mapped.length > 6) {
    showToast('Too many keys in shortcut');
    return [];
  }
  return mapped;
}

String describeShortcutKeys(List<String> keys) =>
    keys.map((e) => _displayNameForKey(e)).join('+');

String? _mapShortcutTokenToKey(String tokenRaw) {
  final token = tokenRaw.toUpperCase();
  switch (token) {
    case 'CTRL':
    case 'CONTROL':
    case 'CTL':
      return 'VK_CONTROL';
    case 'ALT':
    case 'OPTION':
      return 'VK_MENU';
    case 'SHIFT':
      return 'VK_SHIFT';
    case 'CMD':
    case 'WIN':
    case 'META':
    case 'WINDOWS':
      return 'Meta';
    case 'ESC':
    case 'ESCAPE':
      return 'VK_ESCAPE';
    case 'DEL':
    case 'DELETE':
      return 'VK_DELETE';
    case 'INS':
    case 'INSERT':
      return 'VK_INSERT';
    case 'BKSP':
    case 'BACKSPACE':
      return 'VK_BACK';
    case 'TAB':
      return 'VK_TAB';
    case 'SPACE':
    case 'SPACEBAR':
      return 'VK_SPACE';
    case 'ENTER':
    case 'RETURN':
      return 'VK_ENTER';
    case 'HOME':
      return 'VK_HOME';
    case 'END':
      return 'VK_END';
    case 'PGUP':
    case 'PAGEUP':
      return 'VK_PRIOR';
    case 'PGDN':
    case 'PAGEDOWN':
      return 'VK_NEXT';
    case 'UP':
    case 'ARROWUP':
      return 'VK_UP';
    case 'DOWN':
    case 'ARROWDOWN':
      return 'VK_DOWN';
    case 'LEFT':
    case 'ARROWLEFT':
      return 'VK_LEFT';
    case 'RIGHT':
    case 'ARROWRIGHT':
      return 'VK_RIGHT';
    case 'CAPS':
    case 'CAPSLOCK':
      return 'VK_CAPITAL';
    case 'PRTSCR':
    case 'PRTSC':
    case 'PRINTSCREEN':
      return 'VK_SNAPSHOT';
    case 'PAUSE':
      return 'VK_PAUSE';
  }
  if (token.length == 1) {
    final char = token.codeUnitAt(0);
    if (char >= 65 && char <= 90) {
      return 'VK_$token';
    }
    if (char >= 48 && char <= 57) {
      return 'VK_$token';
    }
  }
  if (token.startsWith('F')) {
    final number = int.tryParse(token.substring(1));
    if (number != null && number >= 1 && number <= 24) {
      return 'VK_$token';
    }
  }
  return null;
}

String _displayNameForKey(String key) {
  switch (key) {
    case 'VK_CONTROL':
      return 'Ctrl';
    case 'VK_MENU':
      return 'Alt';
    case 'VK_SHIFT':
      return 'Shift';
    case 'Meta':
      return 'Cmd';
    case 'VK_ESCAPE':
      return 'Esc';
    case 'VK_DELETE':
      return 'Del';
    case 'VK_INSERT':
      return 'Ins';
    case 'VK_BACK':
      return 'Backspace';
    case 'VK_TAB':
      return 'Tab';
    case 'VK_SPACE':
      return 'Space';
    case 'VK_ENTER':
      return 'Enter';
    case 'VK_HOME':
      return 'Home';
    case 'VK_END':
      return 'End';
    case 'VK_PRIOR':
      return 'PgUp';
    case 'VK_NEXT':
      return 'PgDn';
    case 'VK_UP':
      return '↑';
    case 'VK_DOWN':
      return '↓';
    case 'VK_LEFT':
      return '←';
    case 'VK_RIGHT':
      return '→';
    case 'VK_CAPITAL':
      return 'Caps';
    case 'VK_SNAPSHOT':
      return 'PrtScr';
    case 'VK_PAUSE':
      return 'Pause';
  }
  if (key.startsWith('VK_')) {
    return key.substring(3);
  }
  return key;
}

class ShortcutButtonConfig {
  ShortcutButtonConfig({
    required this.id,
    required this.label,
    required this.keys,
    required this.positionRatio,
  });

  final String id;
  final String label;
  final List<String> keys;
  final Offset positionRatio; // relative to the canvas size

  ShortcutButtonConfig copyWith({
    String? label,
    List<String>? keys,
    Offset? positionRatio,
  }) =>
      ShortcutButtonConfig(
        id: id,
        label: label ?? this.label,
        keys: keys ?? this.keys,
        positionRatio: positionRatio ?? this.positionRatio,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'keys': keys,
        'dx': positionRatio.dx,
        'dy': positionRatio.dy,
      };

  factory ShortcutButtonConfig.fromJson(Map<String, dynamic> json) {
    final keys = (json['keys'] as List?)?.cast<String>().where((e) => e.isNotEmpty).toList() ?? [];
    final dx = (json['dx'] as num?)?.toDouble() ?? 0.1;
    final dy = (json['dy'] as num?)?.toDouble() ?? 0.2;
    return ShortcutButtonConfig(
        id: json['id'] as String? ?? _uuid.v4(),
        label: (json['label'] as String?) ?? '',
        keys: keys,
        positionRatio: Offset(dx, dy));
  }
}

class CustomShortcutOverlay extends StatefulWidget {
  const CustomShortcutOverlay({
    super.key,
    required this.inputModel,
    required this.onOpenKeyboard,
    required this.onCloseKeyboard,
    required this.keyboardIsVisible,
  });

  final InputModel inputModel;
  final VoidCallback onOpenKeyboard;
  final VoidCallback onCloseKeyboard;
  final bool keyboardIsVisible;

  @override
  State<CustomShortcutOverlay> createState() => _CustomShortcutOverlayState();
}

class _CustomShortcutOverlayState extends State<CustomShortcutOverlay> {
  List<ShortcutButtonConfig> _shortcuts = [];
  bool _panelVisible = true;
  Offset _panelToggleRatio = const Offset(0.85, 0.2);
  Offset _keyboardToggleRatio = const Offset(0.85, 0.35);
  String? _heldShortcutId;
  _ModifierSnapshot? _heldModifierSnapshot;
  bool _loading = true;
  bool _sendingShortcut = false;
  final List<Rect> _blockedRects = [];

  @override
  void initState() {
    super.initState();
    _loadStoredState();
  }

  @override
  void dispose() {
    _clearBlockedRects();
    super.dispose();
  }

  void _clearBlockedRects() {
    final cursorModel = widget.inputModel.parent.target?.cursorModel;
    if (cursorModel == null) return;
    for (final rect in _blockedRects) {
      cursorModel.removeBlockedRect(rect);
    }
    _blockedRects.clear();
  }

  Future<void> _loadStoredState() async {
    List<ShortcutButtonConfig> parsedShortcuts = [];
    bool visible = true;
    try {
      final stored = bind.mainGetLocalOption(key: kOptionMobileShortcutConfig);
      if (stored.isNotEmpty) {
        final decoded = jsonDecode(stored);
        if (decoded is Map<String, dynamic>) {
          final buttons = decoded['buttons'] as List?;
          if (buttons != null) {
            parsedShortcuts = buttons
                .map((e) => ShortcutButtonConfig.fromJson(
                    (e as Map).cast<String, dynamic>()))
                .toList();
          }
          final v = decoded['visible'];
          if (v is bool) {
            visible = v;
          }
        }
      }
      if (parsedShortcuts.isEmpty) {
        parsedShortcuts = _defaultShortcuts();
      }
    } catch (e) {
      parsedShortcuts = _defaultShortcuts();
    }
    final toggleRaw =
        bind.mainGetLocalOption(key: kOptionMobileShortcutTogglePosition);
    final keyboardRaw =
        bind.mainGetLocalOption(key: kOptionMobileKeyboardTogglePosition);
    setState(() {
      _shortcuts = parsedShortcuts;
      _panelVisible = visible;
      _panelToggleRatio = _parseOffset(toggleRaw) ?? _panelToggleRatio;
      _keyboardToggleRatio = _parseOffset(keyboardRaw) ?? _keyboardToggleRatio;
      _loading = false;
    });
  }

  List<ShortcutButtonConfig> _defaultShortcuts() {
    return [
      ShortcutButtonConfig(
        id: _uuid.v4(),
        label: 'Ctrl+C',
        keys: const ['VK_CONTROL', 'VK_C'],
        positionRatio: const Offset(0.05, 0.4),
      ),
      ShortcutButtonConfig(
        id: _uuid.v4(),
        label: 'Ctrl+V',
        keys: const ['VK_CONTROL', 'VK_V'],
        positionRatio: const Offset(0.05, 0.5),
      ),
      ShortcutButtonConfig(
        id: _uuid.v4(),
        label: 'Ctrl+Alt+Del',
        keys: const ['VK_CONTROL', 'VK_MENU', 'VK_DELETE'],
        positionRatio: const Offset(0.05, 0.6),
      ),
    ];
  }

  Offset? _parseOffset(String raw) {
    if (raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        final dx = (data['x'] as num?)?.toDouble();
        final dy = (data['y'] as num?)?.toDouble();
        if (dx != null && dy != null) {
          return Offset(dx, dy);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _storeOffsets() async {
    await bind.mainSetLocalOption(
        key: kOptionMobileShortcutTogglePosition,
        value: jsonEncode({'x': _panelToggleRatio.dx, 'y': _panelToggleRatio.dy}));
    await bind.mainSetLocalOption(
        key: kOptionMobileKeyboardTogglePosition,
        value:
            jsonEncode({'x': _keyboardToggleRatio.dx, 'y': _keyboardToggleRatio.dy}));
  }

  Future<void> _storeShortcuts() async {
    final payload = {
      'visible': _panelVisible,
      'buttons': _shortcuts.map((e) => e.toJson()).toList(),
    };
    await bind.mainSetLocalOption(
        key: kOptionMobileShortcutConfig, value: jsonEncode(payload));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final List<Widget> children = [];

    final List<Rect> nextBlockedRects = [];

    if (_panelVisible) {
      for (final config in _shortcuts) {
        final position = _ratioToOffset(
            config.positionRatio, size, _kShortcutButtonSize, padding);
        nextBlockedRects.add(Rect.fromLTWH(
            position.dx, position.dy, _kShortcutButtonSize.width, _kShortcutButtonSize.height));
        children.add(Positioned(
          left: position.dx,
          top: position.dy,
          child: _ShortcutButton(
            label: config.label.isEmpty ? describeShortcutKeys(config.keys) : config.label,
            isHeld: _heldShortcutId == config.id,
            onTap: () => _triggerShortcut(config),
            onDoubleTap: () => _toggleHold(config),
            onLongPress: () => _editShortcut(config),
            onPanUpdate: (details) =>
                _updateShortcutPosition(config.id, details.delta, size, padding),
            onPanEnd: () => unawaited(_storeShortcuts()),
          ),
        ));
      }
    }

    final panelTogglePosition = _ratioToOffset(
        _panelToggleRatio, size, const Size(_kCircleDiameter, _kCircleDiameter), padding);
    nextBlockedRects.add(Rect.fromLTWH(panelTogglePosition.dx, panelTogglePosition.dy,
        _kCircleDiameter, _kCircleDiameter));
    children.add(Positioned(
      left: panelTogglePosition.dx,
      top: panelTogglePosition.dy,
      child: _DraggableCircleButton(
        icon: Icons.view_module,
        active: _panelVisible,
        onTap: () {
          setState(() {
            _panelVisible = !_panelVisible;
          });
          unawaited(_storeShortcuts());
        },
        onLongPress: _createShortcut,
        onPanUpdate: (details) {
          setState(() {
            _panelToggleRatio = _deltaToRatio(
                details.delta,
                _panelToggleRatio,
                size,
                const Size(_kCircleDiameter, _kCircleDiameter),
                padding);
          });
        },
        onPanEnd: () => unawaited(_storeOffsets()),
      ),
    ));

    final keyboardPosition = _ratioToOffset(_keyboardToggleRatio, size,
        const Size(_kCircleDiameter, _kCircleDiameter), padding);
    nextBlockedRects.add(Rect.fromLTWH(
        keyboardPosition.dx, keyboardPosition.dy, _kCircleDiameter, _kCircleDiameter));
    children.add(Positioned(
      left: keyboardPosition.dx,
      top: keyboardPosition.dy,
      child: _DraggableCircleButton(
        icon: Icons.keyboard,
        active: widget.keyboardIsVisible,
        onTap: () {
          if (widget.keyboardIsVisible) {
            widget.onCloseKeyboard();
          } else {
            widget.onOpenKeyboard();
          }
        },
        onPanUpdate: (details) {
          setState(() {
            _keyboardToggleRatio = _deltaToRatio(
                details.delta,
                _keyboardToggleRatio,
                size,
                const Size(_kCircleDiameter, _kCircleDiameter),
                padding);
          });
        },
        onPanEnd: () => unawaited(_storeOffsets()),
      ),
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncBlockedRects(nextBlockedRects);
    });

    return IgnorePointer(
      ignoring: false,
      child: SizedBox.expand(child: Stack(children: children)),
    );
  }

  void _syncBlockedRects(List<Rect> rects) {
    final cursorModel = widget.inputModel.parent.target?.cursorModel;
    if (cursorModel == null) return;
    for (final rect in _blockedRects) {
      cursorModel.removeBlockedRect(rect);
    }
    _blockedRects
      ..clear()
      ..addAll(rects);
    for (final rect in _blockedRects) {
      cursorModel.addBlockedRect(rect);
    }
  }

  Future<void> _createShortcut() async {
    if (_shortcuts.length >= _kMaxShortcutCount) {
      showToast('Maximum of $_kMaxShortcutCount shortcuts reached');
      return;
    }
    final result = await _showShortcutDialog();
    if (result == null || result.keys.isEmpty) {
      return;
    }
    final newShortcut = ShortcutButtonConfig(
      id: _uuid.v4(),
      label: result.label,
      keys: result.keys,
      positionRatio: _defaultPositionRatio(),
    );
    setState(() {
      _shortcuts.add(newShortcut);
    });
    unawaited(_storeShortcuts());
  }

  Offset _defaultPositionRatio() {
    final lane = (_shortcuts.length % 5);
    final baseY = 0.25 + lane * 0.1;
    return Offset(0.05, baseY.clamp(0.05, 0.85));
  }

  Future<void> _editShortcut(ShortcutButtonConfig config) async {
    final result = await _showShortcutDialog(existing: config);
    if (result == null) {
      return;
    }
    if (result.delete) {
      setState(() {
        _shortcuts.removeWhere((element) => element.id == config.id);
        if (_heldShortcutId == config.id) {
          _heldShortcutId = null;
        }
      });
      unawaited(_storeShortcuts());
      return;
    }
    if (result.keys.isEmpty) {
      showToast('Shortcut must contain at least one key');
      return;
    }
    setState(() {
      final index =
          _shortcuts.indexWhere((element) => element.id == config.id);
      if (index != -1) {
        _shortcuts[index] = config.copyWith(
          label: result.label,
          keys: result.keys,
        );
      }
    });
    unawaited(_storeShortcuts());
  }

  Future<_ShortcutDialogResult?> _showShortcutDialog(
      {ShortcutButtonConfig? existing}) async {
    final labelController =
        TextEditingController(text: existing?.label ?? '');
    final keysController = TextEditingController(
        text: existing == null ? '' : describeShortcutKeys(existing.keys));
    final isMac = widget.inputModel.peerPlatform == kPeerPlatformMacOS;

    void insertToken(String token) {
      final current = keysController.text.trim();
      final next = current.isEmpty ? token : '$current+$token';
      keysController.text = next;
      keysController.selection =
          TextSelection.collapsed(offset: keysController.text.length);
    }

    return showDialog<_ShortcutDialogResult>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Add shortcut' : 'Edit shortcut'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Shortcut name',
                  hintText: 'Ctrl+V',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keysController,
                decoration: const InputDecoration(
                  labelText: 'Key combination',
                  hintText: 'Ctrl+Alt+Delete',
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => insertToken('Ctrl'),
                    child: const Text('Ctrl'),
                  ),
                  TextButton(
                    onPressed: () => insertToken('Alt'),
                    child: const Text('Alt'),
                  ),
                  TextButton(
                    onPressed: () => insertToken('Shift'),
                    child: const Text('Shift'),
                  ),
                  TextButton(
                    onPressed: () => insertToken(isMac ? 'Cmd' : 'Win'),
                    child: Text(isMac ? 'Cmd' : 'Win'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Use + to separate keys, e.g. Ctrl+Shift+Esc',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(translate('Cancel')),
            ),
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.of(context)
                    .pop(_ShortcutDialogResult.deleteResult()),
                child: Text(
                  translate('Delete'),
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            TextButton(
              onPressed: () {
                final parsedKeys = parseShortcutKeyString(keysController.text);
                if (parsedKeys.isEmpty) {
                  showToast('Please enter a valid key combination');
                  return;
                }
                Navigator.of(context).pop(_ShortcutDialogResult.saveResult(
                    labelController.text.trim(), parsedKeys));
              },
              child: Text(translate('Save')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _triggerShortcut(ShortcutButtonConfig config) async {
    if (_sendingShortcut || config.keys.isEmpty) {
      return;
    }
    _sendingShortcut = true;
    try {
      final snapshot = _captureModifiers();
      _applyModifiersFromKeys(config.keys, snapshot, true);
      _pressShortcut(config.keys, snapshot: snapshot);
      await Future.delayed(_kTapShortcutReleaseDelay);
      _releaseShortcut(config.keys, snapshot: snapshot);
      _restoreModifiers(snapshot);
    } finally {
      _sendingShortcut = false;
    }
  }

  Future<void> _toggleHold(ShortcutButtonConfig config) async {
    if (_heldShortcutId == config.id) {
      _releaseShortcut(config.keys, snapshot: _heldModifierSnapshot);
      _restoreModifiers(_heldModifierSnapshot ?? _captureModifiers());
      setState(() {
        _heldShortcutId = null;
        _heldModifierSnapshot = null;
      });
      return;
    }
    if (_heldShortcutId != null) {
      final existing =
          _shortcuts.firstWhereOrNull((element) => element.id == _heldShortcutId);
      if (existing != null) {
        _releaseShortcut(existing.keys, snapshot: _heldModifierSnapshot);
      }
      if (_heldModifierSnapshot != null) {
        _restoreModifiers(_heldModifierSnapshot!);
      }
    }
    _heldModifierSnapshot = _captureModifiers();
    _applyModifiersFromKeys(config.keys, _heldModifierSnapshot!, true);
    _pressShortcut(config.keys, snapshot: _heldModifierSnapshot);
    setState(() {
      _heldShortcutId = config.id;
    });
  }

  _ModifierSnapshot _captureModifiers() => _ModifierSnapshot(
      widget.inputModel.ctrl,
      widget.inputModel.alt,
      widget.inputModel.shift,
      widget.inputModel.command);

  void _restoreModifiers(_ModifierSnapshot snapshot) {
    widget.inputModel.ctrl = snapshot.ctrl;
    widget.inputModel.alt = snapshot.alt;
    widget.inputModel.shift = snapshot.shift;
    widget.inputModel.command = snapshot.command;
  }

  bool _isModifierKey(String key) {
    switch (key) {
      case 'VK_CONTROL':
      case 'VK_MENU':
      case 'VK_SHIFT':
      case 'Meta':
        return true;
    }
    return false;
  }

  List<String> _sortedKeys(List<String> keys) {
    final modifiers = <String>[];
    final others = <String>[];
    for (final key in keys) {
      if (_isModifierKey(key)) {
        modifiers.add(key);
      } else {
        others.add(key);
      }
    }
    return [...modifiers, ...others];
  }

  void _applyModifiersFromKeys(
      List<String> keys, _ModifierSnapshot snapshot, bool pressed) {
    final hasCtrl = keys.contains('VK_CONTROL');
    final hasAlt = keys.contains('VK_MENU');
    final hasShift = keys.contains('VK_SHIFT');
    final hasCommand = keys.contains('Meta');
    if (hasCtrl) {
      widget.inputModel.ctrl = pressed ? true : snapshot.ctrl;
    }
    if (hasAlt) {
      widget.inputModel.alt = pressed ? true : snapshot.alt;
    }
    if (hasShift) {
      widget.inputModel.shift = pressed ? true : snapshot.shift;
    }
    if (hasCommand) {
      widget.inputModel.command = pressed ? true : snapshot.command;
    }
  }

  bool _modifierActiveForKey(String key, _ModifierSnapshot snapshot) {
    switch (key) {
      case 'VK_CONTROL':
        return snapshot.ctrl;
      case 'VK_MENU':
        return snapshot.alt;
      case 'VK_SHIFT':
        return snapshot.shift;
      case 'Meta':
        return snapshot.command;
    }
    return false;
  }

  void _pressShortcut(List<String> keys, {_ModifierSnapshot? snapshot}) {
    final ordered = _sortedKeys(keys);
    for (final key in ordered) {
      if (snapshot != null &&
          _isModifierKey(key) &&
          _modifierActiveForKey(key, snapshot)) {
        continue;
      }
      widget.inputModel.inputKey(key, down: true, press: false);
    }
  }

  void _releaseShortcut(List<String> keys, {_ModifierSnapshot? snapshot}) {
    final ordered = _sortedKeys(keys);
    for (final key in ordered.reversed) {
      if (snapshot != null &&
          _isModifierKey(key) &&
          _modifierActiveForKey(key, snapshot)) {
        continue;
      }
      widget.inputModel.inputKey(key, down: false, press: false);
    }
  }

  void _updateShortcutPosition(String id, Offset delta, Size screenSize,
      EdgeInsets padding) {
    setState(() {
      final index = _shortcuts.indexWhere((element) => element.id == id);
      if (index == -1) return;
      final current = _shortcuts[index];
      final ratio = _deltaToRatio(delta, current.positionRatio, screenSize,
          _kShortcutButtonSize, padding);
      _shortcuts[index] = current.copyWith(positionRatio: ratio);
    });
  }

  Offset _ratioToOffset(
      Offset ratio, Size screenSize, Size widgetSize, EdgeInsets padding) {
    final dx = ratio.dx * screenSize.width;
    final dy = ratio.dy * screenSize.height;
    return _clampOffset(Offset(dx, dy), screenSize, widgetSize, padding);
  }

  Offset _deltaToRatio(Offset delta, Offset ratio, Size screenSize,
      Size widgetSize, EdgeInsets padding) {
    final current = _ratioToOffset(ratio, screenSize, widgetSize, padding);
    final updated =
        _clampOffset(current + delta, screenSize, widgetSize, padding);
    final rx = (updated.dx / screenSize.width).clamp(0.0, 1.0);
    final ry = (updated.dy / screenSize.height).clamp(0.0, 1.0);
    return Offset(rx, ry);
  }

  Offset _clampOffset(Offset offset, Size screenSize, Size widgetSize,
      EdgeInsets padding) {
    final minX = padding.left;
    final minY = padding.top;
    final maxX = max(minX, screenSize.width - widgetSize.width - padding.right);
    final maxY =
        max(minY, screenSize.height - widgetSize.height - padding.bottom);
    final dx = offset.dx.clamp(minX, maxX);
    final dy = offset.dy.clamp(minY, maxY);
    return Offset(dx, dy);
  }

}

class _ModifierSnapshot {
  final bool ctrl;
  final bool alt;
  final bool shift;
  final bool command;

  const _ModifierSnapshot(this.ctrl, this.alt, this.shift, this.command);
}

class _ShortcutDialogResult {
  _ShortcutDialogResult._(this.delete, this.label, this.keys);

  final bool delete;
  final String label;
  final List<String> keys;

  factory _ShortcutDialogResult.saveResult(
          String label, List<String> keys) =>
      _ShortcutDialogResult._(false, label, keys);

  factory _ShortcutDialogResult.deleteResult() =>
      _ShortcutDialogResult._(true, '', const []);
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.label,
    required this.isHeld,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final String label;
  final bool isHeld;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final ValueChanged<DragUpdateDetails> onPanUpdate;
  final VoidCallback onPanEnd;

  @override
  Widget build(BuildContext context) {
    final color = isHeld
        ? Colors.blueAccent.withOpacity(0.8)
        : Colors.black.withOpacity(0.4);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onPanUpdate: onPanUpdate,
      onPanEnd: (_) => onPanEnd(),
      onPanCancel: onPanEnd,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: _kShortcutButtonSize.width,
          height: _kShortcutButtonSize.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(_kShortcutBorderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.7)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: _kShortcutFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _DraggableCircleButton extends StatelessWidget {
  const _DraggableCircleButton({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.onPanUpdate,
    required this.onPanEnd,
    this.onLongPress,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final ValueChanged<DragUpdateDetails> onPanUpdate;
  final VoidCallback onPanEnd;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final color =
        active ? Colors.blueAccent : Colors.black.withOpacity(0.45);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      onPanUpdate: onPanUpdate,
      onPanEnd: (_) => onPanEnd(),
      onPanCancel: onPanEnd,
      child: Material(
        color: Colors.transparent,
        elevation: _kCircleElevation,
        shape: const CircleBorder(),
        child: Container(
          width: _kCircleDiameter,
          height: _kCircleDiameter,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

extension _FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final value in this) {
      if (test(value)) return value;
    }
    return null;
  }
}
