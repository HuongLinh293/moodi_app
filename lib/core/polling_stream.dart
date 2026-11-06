import 'dart:async';

import 'package:flutter/widgets.dart';

/// Fetch immediately, refresh on resume, and never overlap requests or poll
/// while the application is in the background. A failed fetch keeps the stream
/// alive so a later refresh can recover.
Stream<T> pollingStream<T>(
  Future<T> Function() fetch, {
  Duration interval = const Duration(seconds: 45),
}) => Stream<T>.multi((sink) {
  var cancelled = false;
  var busy = false;
  WidgetsBinding? binding;
  try {
    binding = WidgetsBinding.instance;
  } catch (_) {
    /* pure Dart tests */
  }
  Future<void> refresh() async {
    final lifecycle = binding?.lifecycleState;
    if (cancelled ||
        busy ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      return;
    }
    busy = true;
    try {
      final value = await fetch();
      if (!cancelled) sink.add(value);
    } catch (error, stack) {
      if (!cancelled) sink.addError(error, stack);
    } finally {
      busy = false;
    }
  }

  final observer = _RefreshOnResume(refresh);
  binding?.addObserver(observer);
  final timer = Timer.periodic(interval, (_) => unawaited(refresh()));
  unawaited(refresh());
  sink.onCancel = () {
    cancelled = true;
    timer.cancel();
    binding?.removeObserver(observer);
  };
});

class _RefreshOnResume extends WidgetsBindingObserver {
  _RefreshOnResume(this.refresh);
  final Future<void> Function() refresh;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }
}
