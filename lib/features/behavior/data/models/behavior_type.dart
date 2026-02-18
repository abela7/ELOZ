class BehaviorType {
  static const String good = 'good';
  static const String bad = 'bad';

  static const List<String> supported = <String>[good, bad];

  static bool isValid(String value) {
    return value == good || value == bad;
  }
}
