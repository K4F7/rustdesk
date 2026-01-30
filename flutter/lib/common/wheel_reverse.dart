int wheelStepWithReverseCompensation({
  required int step,
  required bool globalReverse,
  required bool sourceReverse,
}) {
  final globalFactor = globalReverse ? -1 : 1;
  final sourceFactor = sourceReverse ? -1 : 1;
  // Compensate the global reverse option so per-source reverse works
  // regardless of where the actual reverse is applied (client or server).
  return step * globalFactor * sourceFactor;
}
