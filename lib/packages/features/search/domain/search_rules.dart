abstract final class SearchRules {
  static const minimumQueryLength = 4;
  static const maximumQueryLength = 120;
  static const historyLimit = 8;

  static int queryLength(String value) => value.runes.length;

  static bool hasValidQueryLength(String value) {
    final length = queryLength(value);

    return length >= minimumQueryLength && length <= maximumQueryLength;
  }

  static bool hasValidHistoryLength(String value) => value.isNotEmpty && queryLength(value) <= maximumQueryLength;
}
