/// Lightweight cross-screen notifier used to keep friend-related badge
/// counts in sync (nav bar, profile card) after [FriendsScreen] is dismissed.
class BadgeRefreshNotifier {
  BadgeRefreshNotifier._();

  static final _callbacks = <void Function()>[];

  static void addListener(void Function() fn) => _callbacks.add(fn);

  static void removeListener(void Function() fn) => _callbacks.remove(fn);

  static void notifyAll() {
    for (final fn in List.of(_callbacks)) {
      fn();
    }
  }
}
