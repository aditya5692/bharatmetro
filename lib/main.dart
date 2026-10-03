import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import 'controllers/metro_controller.dart';
import 'core/ads/banner_ad_controller.dart';
import 'core/config/app_preferences.dart';
import 'core/metro/metro_network_registry.dart';
import 'core/theme/app_theme.dart';
import 'screens/metro_network_selection_screen.dart';
import 'screens/root_shell.dart';
import 'screens/splash_screen.dart';
import 'services/metro_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start ads in background — UI renders immediately, banners preload when ready.
  unawaited(_initializeAds());

  runApp(const OpenDelhiTransitFlutterApp());
}

Future<void> _initializeAds() async {
  if (kIsWeb) return;

  try {
    await BannerAdController.instance.ensureInitialized();

    // Configures test devices for debugging if passed via --dart-define
    const testDeviceId = String.fromEnvironment('ADMOB_TEST_DEVICE_ID');
    if (kDebugMode && testDeviceId.isNotEmpty) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: <String>[testDeviceId]),
      );
    }
  } catch (e) {
    // AdMob failed to initialize — app runs gracefully without ads.
    debugPrint('AdMob initialization error: $e');
  }
}

class OpenDelhiTransitFlutterApp extends StatefulWidget {
  const OpenDelhiTransitFlutterApp({super.key});

  @override
  State<OpenDelhiTransitFlutterApp> createState() =>
      _OpenDelhiTransitFlutterAppState();
}

class _OpenDelhiTransitFlutterAppState
    extends State<OpenDelhiTransitFlutterApp> {
  String? _selectedNetworkId;
  bool _isBootstrapping = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final selected = await AppPreferences.getSelectedMetroNetwork();
    if (!mounted) return;
    setState(() {
      _selectedNetworkId = selected;
      _isBootstrapping = false;
    });
  }

  Future<void> _onNetworkSelected(String networkId) async {
    if (networkId == _selectedNetworkId) {
      return;
    }
    await AppPreferences.setSelectedMetroNetwork(networkId);
    if (!mounted) return;
    setState(() {
      _selectedNetworkId = networkId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.light();

    if (_isBootstrapping) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const SplashScreen(),
      );
    }

    if (_selectedNetworkId == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: MetroNetworkSelectionScreen(onSelected: _onNetworkSelected),
      );
    }

    final selectedNetwork = MetroNetworkRegistry.byId(_selectedNetworkId!);
    return MultiProvider(
      providers: <ChangeNotifierProvider<dynamic>>[
        ChangeNotifierProvider<MetroController>(
          key: ValueKey<String>('metro-controller-${selectedNetwork.id}'),
          create: (_) => MetroController(
            repository: MetroRepository(network: selectedNetwork),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Bharat Metro: The Travelers Guide',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: RootShell(
          key: ValueKey<String>('root-shell-${selectedNetwork.id}'),
          selectedNetwork: selectedNetwork,
          onNetworkSelected: _onNetworkSelected,
        ),
      ),
    );
  }
}