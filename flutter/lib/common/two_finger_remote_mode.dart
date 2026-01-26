import 'dart:math';

enum TwoFingerRemoteMode {
  undecided,
  wheel,
  zoom,
}

double updateTwoFingerScaleDeviationMax({
  required double previousMax,
  required double currentScale,
}) {
  return max(previousMax, (currentScale - 1.0).abs());
}

TwoFingerRemoteMode decideTwoFingerRemoteMode({
  required double scaleDeviationMax,
  required double translationDistanceSum,
  double zoomThreshold = 0.015,
  double wheelThreshold = 2.5,
}) {
  if (scaleDeviationMax >= zoomThreshold) {
    return TwoFingerRemoteMode.zoom;
  }
  if (translationDistanceSum >= wheelThreshold) {
    return TwoFingerRemoteMode.wheel;
  }
  return TwoFingerRemoteMode.undecided;
}
