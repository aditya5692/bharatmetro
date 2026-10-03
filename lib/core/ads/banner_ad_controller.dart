import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';

enum BannerPlacement { home, results }

/// Cached banner slot — keeps the previous ad visible while a reload is in flight.
class _BannerSlot {
  BannerAd? ad;
  bool isLoaded = false;
  bool isLoading = false;
  String? debugError;
  int loadGeneration = 0;
  Orientation? lastOrientation;
  double? lastWidthDp;
}

/// Singleton that owns banner ad lifecycles and prevents reload flicker.
class BannerAdController extends ChangeNotifier {
  BannerAdController._();
  static final BannerAdController instance = BannerAdController._();

  final Map<BannerPlacement, _BannerSlot> _slots = <BannerPlacement, _BannerSlot>{
    BannerPlacement.home: _BannerSlot(),
    BannerPlacement.results: _BannerSlot(),
  };

  bool _sdkReady = false;
  Timer? _metricsDebounce;

  bool get sdkReady => _sdkReady;

  Future<void> ensureInitialized() async {
    if (_sdkReady || kIsWeb || !AdsConfig.enabled) return;
    try {
      await MobileAds.instance.initialize();
      _sdkReady = true;
      notifyListeners();
    } catch (e) {
      debugPrint('BannerAdController SDK init failed: $e');
    }
  }

  String? _unitIdFor(BannerPlacement placement) {
    switch (placement) {
      case BannerPlacement.home:
        return AdsConfig.homeBannerAdUnitId();
      case BannerPlacement.results:
        return AdsConfig.resultsBannerAdUnitId();
    }
  }

  BannerAd? adFor(BannerPlacement placement) {
    final slot = _slots[placement]!;
    return slot.isLoaded ? slot.ad : null;
  }

  String? debugErrorFor(BannerPlacement placement) => _slots[placement]!.debugError;

  bool isLoaded(BannerPlacement placement) => _slots[placement]!.isLoaded;

  /// Typical anchored adaptive banner height — reserves space to prevent layout jump.
  static const double reservedHeight = 60;

  Future<void> loadIfNeeded(
    BannerPlacement placement,
    BuildContext context, {
    bool force = false,
  }) async {
    if (kIsWeb || !AdsConfig.enabled) return;

    await ensureInitialized();
    if (!_sdkReady || !context.mounted) return;

    final slot = _slots[placement]!;
    if (slot.isLoading) return;

    final mediaQuery = MediaQuery.of(context);
    final orientation = mediaQuery.orientation;
    final rawWidth = mediaQuery.size.width - mediaQuery.padding.horizontal;
    final widthDp = rawWidth.truncate().clamp(320, 1200).toDouble();

    final orientationChanged = slot.lastOrientation != null &&
        slot.lastOrientation != orientation;
    final widthChanged = slot.lastWidthDp != null &&
        (slot.lastWidthDp! - widthDp).abs() > 48;

    if (slot.isLoaded && !force && !orientationChanged && !widthChanged) {
      return;
    }

    slot.lastOrientation = orientation;
    slot.lastWidthDp = widthDp;

    final adUnitId = _unitIdFor(placement);
    if (adUnitId == null) return;

    slot.isLoading = true;
    slot.loadGeneration++;
    final generation = slot.loadGeneration;

    AdSize adSize;
    try {
      final adaptiveSize = await AdSize
          .getCurrentOrientationAnchoredAdaptiveBannerAdSize(widthDp.truncate());
      adSize = adaptiveSize ?? AdSize.banner;
    } catch (_) {
      adSize = AdSize.banner;
    }

    if (generation != slot.loadGeneration) return;

    final banner = BannerAd(
      size: adSize,
      adUnitId: adUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (generation != slot.loadGeneration) {
            ad.dispose();
            return;
          }
          final previous = slot.ad;
          slot.ad = ad as BannerAd;
          slot.isLoaded = true;
          slot.isLoading = false;
          slot.debugError = null;
          if (previous != null) {
            Future.delayed(const Duration(milliseconds: 500), () => previous.dispose());
          }
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (generation != slot.loadGeneration) return;
          slot.isLoading = false;
          slot.debugError = 'Ad failed [${error.code}]: ${error.message}';
          if (!slot.isLoaded) {
            notifyListeners();
          }
        },
      ),
    );

    try {
      await banner.load();
    } catch (e) {
      if (generation != slot.loadGeneration) return;
      slot.isLoading = false;
      slot.debugError = 'Banner.load exception: $e';
      if (!slot.isLoaded) {
        notifyListeners();
      }
    }
  }

  void onMetricsChanged(BuildContext context, BannerPlacement placement) {
    _metricsDebounce?.cancel();
    _metricsDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!context.mounted) return;
      unawaited(loadIfNeeded(placement, context));
    });
  }

  void disposeAll() {
    _metricsDebounce?.cancel();
    for (final slot in _slots.values) {
      slot.ad?.dispose();
      slot.ad = null;
      slot.isLoaded = false;
    }
  }
}
