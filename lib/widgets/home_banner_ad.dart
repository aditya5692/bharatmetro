import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ads/ads_config.dart';
import '../core/ads/banner_ad_controller.dart';

/// Persistent bottom banner — single instance, stable height, no scroll flicker.
class PersistentBannerAd extends StatefulWidget {
  const PersistentBannerAd({super.key, required this.placement});

  final BannerPlacement placement;

  @override
  State<PersistentBannerAd> createState() => _PersistentBannerAdState();
}

class _PersistentBannerAdState extends State<PersistentBannerAd>
    with WidgetsBindingObserver {
  final BannerAdController _controller = BannerAdController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestLoad());
  }

  @override
  void didUpdateWidget(covariant PersistentBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestLoad());
    }
  }

  @override
  void didChangeMetrics() {
    _controller.onMetricsChanged(context, widget.placement);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _requestLoad() async {
    if (!mounted) return;
    await _controller.loadIfNeeded(widget.placement, context);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !AdsConfig.enabled) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final banner = _controller.adFor(widget.placement);
        final debugError = _controller.debugErrorFor(widget.placement);
        final isLoaded = _controller.isLoaded(widget.placement);

        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child: isLoaded && banner != null
              ? _BannerChrome(key: ObjectKey(banner), ad: banner)
              : _BannerPlaceholder(
                  key: ValueKey('placeholder-${widget.placement}'),
                  debugError: kDebugMode ? debugError : null,
                ),
        );
      },
    );
  }
}

class _BannerChrome extends StatelessWidget {
  const _BannerChrome({super.key, required this.ad});

  final BannerAd ad;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final adSize = ad.size;

    return Material(
      color: scheme.surfaceContainerLowest,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: adSize.width.toDouble(),
          height: adSize.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder({super.key, this.debugError});

  final String? debugError;

  @override
  Widget build(BuildContext context) {
    if (debugError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          debugError!,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
        ),
      );
    }

    return SizedBox(
      height: BannerAdController.reservedHeight,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

// Legacy aliases kept for any remaining imports — delegate to persistent widget.
class HomeBannerAd extends StatelessWidget {
  const HomeBannerAd({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class ResultsBannerAd extends StatelessWidget {
  const ResultsBannerAd({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
