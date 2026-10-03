import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/metro_controller.dart';
import '../core/ads/banner_ad_controller.dart';
import '../core/metro/metro_network_registry.dart';
import '../widgets/home_banner_ad.dart';
import 'fare_calculator_screen.dart';
import 'home_screen.dart';
import 'metro_results_screen.dart';
import 'settings_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({
    super.key,
    required this.selectedNetwork,
    required this.onNetworkSelected,
  });

  final MetroNetworkDefinition selectedNetwork;
  final Future<void> Function(String) onNetworkSelected;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _selectedIndex = 0;
  bool _allowRootPop = false;
  Timer? _backPressTimer;

  @override
  void dispose() {
    _backPressTimer?.cancel();
    super.dispose();
  }

  void _clearBackPressState() {
    _backPressTimer?.cancel();
    _backPressTimer = null;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (_allowRootPop) {
      setState(() {
        _allowRootPop = false;
      });
    }
  }

  Future<void> _handleBackPress(bool showMetroResults) async {
    if (showMetroResults) {
      context.read<MetroController>().hideResultsView();
      _clearBackPressState();
      return;
    }

    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      _clearBackPressState();
      return;
    }

    if (_allowRootPop) {
      return;
    }

    setState(() {
      _allowRootPop = true;
    });
    _backPressTimer?.cancel();
    _backPressTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _allowRootPop = false;
      });
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final showMetroResults = context.watch<MetroController>().showResults;
    final showHomeAppBar = _selectedIndex == 0 && !showMetroResults;
    final firstTabPage = showMetroResults
        ? const MetroResultsScreen()
        : HomeScreen(
            currentNetworkName: widget.selectedNetwork.displayName,
            onOpenTab: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          );
    final pages = <Widget>[
      firstTabPage,
      FareCalculatorScreen(networkName: widget.selectedNetwork.displayName),
    ];

    return PopScope<void>(
      canPop: _allowRootPop && _selectedIndex == 0 && !showMetroResults,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        unawaited(_handleBackPress(showMetroResults));
      },
      child: Scaffold(
        appBar: showHomeAppBar
            ? AppBar(
                title: const Text('Home', style: TextStyle(fontSize: 22)),
                actions: <Widget>[
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SettingsScreen(
                            currentNetworkId: widget.selectedNetwork.id,
                            onNetworkSelected: widget.onNetworkSelected,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              )
            : null,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: IndexedStack(index: _selectedIndex, children: pages),
              ),
              PersistentBannerAd(
                placement: _bannerPlacement(showMetroResults),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          height: 60,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            if (index == 0 && showMetroResults) {
              context.read<MetroController>().hideResultsView();
            }
            setState(() {
              _selectedIndex = index;
            });
            _clearBackPressState();
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.currency_rupee_outlined),
              label: 'Fare',
            ),
          ],
        ),
      ),
    );
  }

  BannerPlacement _bannerPlacement(bool showMetroResults) {
    if (_selectedIndex == 1 || showMetroResults) {
      return BannerPlacement.results;
    }
    return BannerPlacement.home;
  }
}
