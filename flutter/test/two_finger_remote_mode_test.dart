import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_hbb/common/two_finger_remote_mode.dart';

void main() {
  test('decides zoom when scale deviation exceeds threshold', () {
    expect(
      decideTwoFingerRemoteMode(
          scaleDeviationMax: 0.016, translationDistanceSum: 0.0),
      TwoFingerRemoteMode.zoom,
    );
  });

  test('decides wheel when translation exceeds threshold', () {
    expect(
      decideTwoFingerRemoteMode(
          scaleDeviationMax: 0.0, translationDistanceSum: 3.0),
      TwoFingerRemoteMode.wheel,
    );
  });

  test('remains undecided for small motion and small scale changes', () {
    expect(
      decideTwoFingerRemoteMode(
          scaleDeviationMax: 0.01, translationDistanceSum: 1.0),
      TwoFingerRemoteMode.undecided,
    );
  });

  test('scale deviation max tracks current scale jitter', () {
    var deviationMax = 0.0;
    for (final scale in [1.003, 0.998, 1.012, 1.007]) {
      deviationMax = updateTwoFingerScaleDeviationMax(
        previousMax: deviationMax,
        currentScale: scale,
      );
    }
    expect(deviationMax, closeTo(0.012, 1e-9));
  });
}
