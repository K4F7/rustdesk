import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_hbb/common/widgets/gestures.dart';

ScaleUpdateDetails _update({
  required int pointerCount,
  double scale = 1.0,
  Offset focalPoint = Offset.zero,
  Offset localFocalPoint = Offset.zero,
  Offset focalPointDelta = Offset.zero,
}) {
  return ScaleUpdateDetails(
    pointerCount: pointerCount,
    scale: scale,
    horizontalScale: scale,
    verticalScale: scale,
    rotation: 0.0,
    focalPoint: focalPoint,
    localFocalPoint: localFocalPoint,
    focalPointDelta: focalPointDelta,
  );
}

void main() {
  test('gesture recognizer switches state based on pointerCount', () {
    final recognizer = CustomTouchGestureRecognizer();
    addTearDown(recognizer.dispose);

    var oneStart = 0;
    var oneEnd = 0;
    var twoStart = 0;
    var twoEnd = 0;

    recognizer.onOneFingerPanStart = (_) => oneStart++;
    recognizer.onOneFingerPanEnd = (_) => oneEnd++;
    recognizer.onTwoFingerScaleStart = (_) => twoStart++;
    recognizer.onTwoFingerScaleEnd = (_) => twoEnd++;

    recognizer.onUpdate?.call(_update(pointerCount: 1));
    expect(oneStart, 1);
    expect(oneEnd, 0);

    recognizer.onUpdate?.call(_update(pointerCount: 2));
    expect(twoStart, 1);
    // State switches happen on updates; end callbacks are fired on `onEnd`.
    expect(oneEnd, 0);
    expect(twoEnd, 0);

    recognizer.onUpdate?.call(_update(pointerCount: 1));
    expect(oneStart, 2);
    expect(twoEnd, 0);

    recognizer.onEnd?.call(ScaleEndDetails(velocity: Velocity.zero));
    expect(oneEnd, 1);
  });
}
