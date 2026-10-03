import 'package:flutter/foundation.dart';

/// Ad unit IDs for Bharat Metro Traveler Guide
class AdsConfig {
  const AdsConfig._();

  static const bool enabled = bool.fromEnvironment(
    'ADS_ENABLED',
    defaultValue: true,
  );

  // ── Production Ad Unit IDs ────────────────────────────────────────────────
  static const String androidHomeBannerId = String.fromEnvironment(
    'ADMOB_ANDROID_HOME_BANNER_ID',
    defaultValue: 'ca-app-pub-5798949394190815/1131133008',
  );
  
  static const String androidResultsBannerId = String.fromEnvironment(
    'ADMOB_ANDROID_RESULTS_BANNER_ID',
    defaultValue: 'ca-app-pub-5798949394190815/1010582882',
  );

  // Official Google Test Banner Ad Unit IDs
  static const String _androidTestBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosTestBannerId =
      'ca-app-pub-3940256099942544/2934735716';

  /// Returns the ad unit ID for the home-page banner placement.
  static String? homeBannerAdUnitId() =>
      _resolve(androidId: androidHomeBannerId, iosId: _iosTestBannerId);

  /// Returns the ad unit ID for the results / fare banner placement.
  static String? resultsBannerAdUnitId() =>
      _resolve(androidId: androidResultsBannerId, iosId: _iosTestBannerId);

  static String? _resolve({
    required String androidId,
    required String iosId,
  }) {
    if (kIsWeb || !enabled) return null;

    // Production environment
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidId;
      case TargetPlatform.iOS:
        return iosId;
      default:
        return null;
    }
  }
}