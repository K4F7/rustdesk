import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/wheel_sensitivity.dart';

void main() {
  test('WheelSensitivityFilter clamps invalid values', () {
    final filter = WheelSensitivityFilter();
    filter.setValue(kMaxMouseWheelSensitivity + 1);
    expect(filter.value, kDefaultMouseWheelSensitivity);
    filter.setValue(kMinMouseWheelSensitivity - 1);
    expect(filter.value, kDefaultMouseWheelSensitivity);
  });

  test('WheelSensitivityFilter accumulates fractional deltas', () {
    final filter = WheelSensitivityFilter();
    filter.setValue(50);
    expect(filter.apply(const Offset(0, 1)), Offset.zero);
    expect(filter.apply(const Offset(0, 1)), const Offset(0, 1));
  });

  test('WheelSensitivityFilter scales deltas', () {
    final filter = WheelSensitivityFilter();
    filter.setValue(200);
    expect(filter.apply(const Offset(0, 1)), const Offset(0, 2));
  });
}
