import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/metro_controller.dart';
import '../widgets/metro_planner_box.dart';
import '../widgets/travel_dashboard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenTab,
    required this.currentNetworkName,
    this.initialSource,
    this.initialDestination,
    this.plannerKey,
  });

  final ValueChanged<int> onOpenTab;
  final String currentNetworkName;
  final String? initialSource;
  final String? initialDestination;
  final Key? plannerKey;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _dashboardVersion = 0;

  void _refreshDashboard() {
    setState(() {
      _dashboardVersion++;
    });
  }

  Future<void> _replayRoute(String source, String destination) async {
    final controller = context.read<MetroController>();
    await controller.findRoute(source, destination);
    if (!mounted) return;
    if (controller.route != null) {
      controller.showResultsView();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.error ?? 'Could not replay this route. Try searching again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.location_city, color: Color(0xFF0B4F8A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Current network: ${widget.currentNetworkName}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onOpenTab(1),
                    child: const Text('Open Fare'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          MetroPlannerBox(
            key: widget.plannerKey,
            title: 'Plan Journey',
            subtitle:
                'Search From and To stations, choose route style, and find route.',
            initialSource: widget.initialSource,
            initialDestination: widget.initialDestination,
            onRouteFound: _refreshDashboard,
          ),
          const SizedBox(height: 14),
          TravelDashboard(
            key: ValueKey<int>(_dashboardVersion),
            networkName: widget.currentNetworkName,
            onOpenFare: () => widget.onOpenTab(1),
            onRecentRouteSelected: _replayRoute,
          ),
        ],
      ),
    );
  }
}
