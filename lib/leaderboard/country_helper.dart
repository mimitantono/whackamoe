import 'dart:ui';

class CountryHelper {
  /// Detects the user's country code from the device locale.
  /// Returns a 2-letter ISO code (e.g. 'US', 'GB', 'VN') or null if unavailable.
  static String? detect() {
    final locales = PlatformDispatcher.instance.locales;
    for (final locale in locales) {
      final code = locale.countryCode;
      if (code != null && code.length == 2) {
        return code.toUpperCase();
      }
    }
    return null;
  }

  /// Converts a 2-letter country code to a flag emoji.
  /// Returns null for invalid input.
  static String? toFlagEmoji(String? countryCode) {
    if (countryCode == null || countryCode.length != 2) return null;
    final upper = countryCode.toUpperCase();
    // Regional indicator symbols start at U+1F1E6 ('A')
    const base = 0x1F1E6;
    final first = upper.codeUnitAt(0);
    final second = upper.codeUnitAt(1);
    if (first < 0x41 || first > 0x5A || second < 0x41 || second > 0x5A) {
      return null;
    }
    return String.fromCharCodes([
      base + (first - 0x41),
      base + (second - 0x41),
    ]);
  }
}
