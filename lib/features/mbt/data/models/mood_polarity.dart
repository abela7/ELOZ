class MoodPolarity {
  static const String good = 'good';
  static const String bad = 'bad';

  static const Set<String> supported = <String>{good, bad};

  static bool isValid(String value) {
    return supported.contains(value);
  }
}
