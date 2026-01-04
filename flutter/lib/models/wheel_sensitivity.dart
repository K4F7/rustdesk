import 'dart:ui';

import 'package:flutter_hbb/consts.dart';

/// Accumulates wheel deltas based on a sensitivity factor.
class WheelSensitivityFilter {
  WheelSensitivityFilter({int initial = kDefaultMouseWheelSensitivity})
      : _min = kMinMouseWheelSensitivity,
        _max = kMaxMouseWheelSensitivity {
    setValue(initial);
  }

  final int _min;
  final int _max;
  int _value = kDefaultMouseWheelSensitivity;
  double _factor = kDefaultMouseWheelSensitivity / 100.0;
  Offset _remainder = Offset.zero;

  int get value => _value;

  void setValue(int raw) {
    if (raw < _min || raw > _max) {
      _value = kDefaultMouseWheelSensitivity;
    } else {
      _value = raw;
    }
    _factor = _value / 100.0;
    _remainder = Offset.zero;
  }

  Offset apply(Offset delta, {double divisor = 1.0}) {
    if (delta.dx == 0 && delta.dy == 0) return Offset.zero;
    final scaled = delta / divisor * _factor;
    _remainder += scaled;
    final dx = _remainder.dx.truncate();
    final dy = _remainder.dy.truncate();
    if (dx == 0 && dy == 0) return Offset.zero;
    _remainder = Offset(_remainder.dx - dx, _remainder.dy - dy);
    return Offset(dx.toDouble(), dy.toDouble());
  }
}
