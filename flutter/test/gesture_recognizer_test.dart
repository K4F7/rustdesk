import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/widgets/gestures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CustomTouchGestureRecognizer respects shouldAcceptPointer', () {
    final recognizer = CustomTouchGestureRecognizer();
    recognizer.shouldAcceptPointer = (offset) => offset.dx < 10;

    expect(
      recognizer.isPointerAllowed(
          PointerDownEvent(position: const Offset(5, 5))),
      isTrue,
    );
    expect(
      recognizer.isPointerAllowed(
          PointerDownEvent(position: const Offset(50, 5))),
      isFalse,
    );

    recognizer.dispose();
  });
}
