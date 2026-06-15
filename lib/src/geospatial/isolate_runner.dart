import 'dart:async';
import 'dart:isolate';

/// Runs [computation] in a separate isolate on native platforms.
Future<T> runInIsolate<T>(FutureOr<T> Function() computation) {
  return Isolate.run(computation);
}
