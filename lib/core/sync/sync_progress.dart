class SyncProgress {
  const SyncProgress({
    required this.step,
    required this.totalSteps,
    required this.message,
  });

  final int step;
  final int totalSteps;
  final String message;
}

class SyncCancelledException implements Exception {
  const SyncCancelledException();
}
