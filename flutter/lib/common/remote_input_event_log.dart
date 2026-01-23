import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';

class RemoteInputEvent {
  final int tsMs;
  final String type;
  final Map<String, Object?> data;

  RemoteInputEvent({
    required this.tsMs,
    required this.type,
    required this.data,
  });

  String toLine() {
    final jsonData = data.isEmpty ? '' : ' ${jsonEncode(data)}';
    return '$tsMs $type$jsonData';
  }
}

class RemoteInputEventLog {
  static const int _maxEvents = 80;
  static const String _logcatPrefix = 'U2E2E';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static final List<RemoteInputEvent> _events = <RemoteInputEvent>[];
  static SemanticsHandle? _semanticsHandle;

  static bool get isEnabled {
    final enabled = isAndroid &&
        kDebugMode &&
        mainGetLocalBoolOptionSync(kOptionEnableAndroidE2eMode);
    if (enabled) {
      _semanticsHandle ??= SemanticsBinding.instance.ensureSemantics();
    } else {
      _semanticsHandle?.dispose();
      _semanticsHandle = null;
    }
    return enabled;
  }

  static void clear() {
    if (!isEnabled) return;
    _events.clear();
    revision.value++;
    debugPrint('$_logcatPrefix CLEAR');
  }

  static void add(String type, {Map<String, Object?> data = const {}}) {
    if (!isEnabled) return;
    final tsMs = DateTime.now().millisecondsSinceEpoch;
    final event = RemoteInputEvent(tsMs: tsMs, type: type, data: data);
    _events.add(event);
    if (_events.length > _maxEvents) {
      _events.removeRange(0, _events.length - _maxEvents);
    }
    revision.value++;
    debugPrint('$_logcatPrefix ${event.toLine()}');
  }

  static List<RemoteInputEvent> snapshot({int? lastN}) {
    final list = List<RemoteInputEvent>.unmodifiable(_events);
    if (lastN == null || lastN <= 0 || lastN >= list.length) return list;
    return List<RemoteInputEvent>.unmodifiable(
        list.sublist(list.length - lastN));
  }

  static String dumpText({int lastN = 40}) {
    final list = snapshot(lastN: lastN);
    return list.map((e) => e.toLine()).join('\n');
  }
}
