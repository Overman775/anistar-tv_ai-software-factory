/// A transport-independent cancellation signal for one operation.
final class RequestCancellation {
  final _listeners = <void Function()>{};
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  /// Registers a listener and returns the function that removes it.
  void Function() onCancel(void Function() listener) {
    if (_isCancelled) {
      listener();

      return () => _listeners.remove(listener);
    }
    _listeners.add(listener);

    return () => _listeners.remove(listener);
  }

  void cancel() {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    final listeners = List<void Function()>.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }
}
