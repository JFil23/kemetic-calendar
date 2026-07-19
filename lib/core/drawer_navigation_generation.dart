/// Monotonically orders drawer navigation work.
///
/// A drawer selection owns one generation. Delayed callbacks must call
/// [runIfCurrent] before they mutate route or drawer state, so an older tap
/// cannot overtake a newer explicit selection.
class DrawerNavigationGeneration {
  int _current = 0;

  int get current => _current;

  int issue() => ++_current;

  bool isCurrent(int generation) => generation == _current;

  bool runIfCurrent(int generation, void Function() callback) {
    if (!isCurrent(generation)) return false;
    callback();
    return true;
  }
}
