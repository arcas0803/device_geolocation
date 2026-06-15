import 'dart:async';

/// Web fallback for [runInIsolate].
///
/// Isolates are not available on the web, so the computation is run
/// synchronously on the main thread.
Future<T> runInIsolate<T>(FutureOr<T> Function() computation) async {
  return computation();
}
