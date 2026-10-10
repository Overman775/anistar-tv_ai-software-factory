/// One automatic refresh per user-selected source; manual retry resets it.
final class PlaybackRefreshBudget {
  bool _used = false;

  void reset() => _used = false;

  bool take() {
    if (_used) {
      return false;
    }
    _used = true;

    return true;
  }
}
