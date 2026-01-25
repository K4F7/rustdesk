import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_hbb/common/wheel_reverse.dart';

void main() {
  test('wheelStepWithReverseCompensation applies global + per-source reverse',
      () {
    // Desired final direction after any global reverse is applied.
    // We pre-compensate the step sent to make per-source behavior consistent.
    expect(
      wheelStepWithReverseCompensation(
        step: 1,
        globalReverse: false,
        sourceReverse: false,
      ),
      1,
    );
    expect(
      wheelStepWithReverseCompensation(
        step: 1,
        globalReverse: false,
        sourceReverse: true,
      ),
      -1,
    );
    expect(
      wheelStepWithReverseCompensation(
        step: 1,
        globalReverse: true,
        sourceReverse: false,
      ),
      -1,
    );
    expect(
      wheelStepWithReverseCompensation(
        step: 1,
        globalReverse: true,
        sourceReverse: true,
      ),
      1,
    );
  });
}
