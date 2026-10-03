import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/metro_controller.dart';
import '../core/metro/line_meta.dart';
import '../models/route_result.dart';
import '../models/station.dart';
import '../models/station_amenities.dart';

class MetroResultsScreen extends StatefulWidget {
  const MetroResultsScreen({super.key});

  @override
  State<MetroResultsScreen> createState() => _MetroResultsScreenState();
}

class _MetroResultsScreenState extends State<MetroResultsScreen> {
  bool _showFullFare = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetroController>();
    final route = controller.route;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Back',
              onPressed: context.read<MetroController>().hideResultsView,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Your Route',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ),
            OutlinedButton.icon(
              onPressed: context.read<MetroController>().hideResultsView,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modify Search', style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (route == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No route found yet.', style: TextStyle(fontSize: 18)),
            ),
          )
        else ...<Widget>[
          _ResultHeroCard(route: route),
          const SizedBox(height: 12),
          if (controller.routes.length > 1) ...<Widget>[
            _RouteOptionsCard(
              routes: controller.routes,
              selectedRoute: route,
              onSelected: (index) {
                context.read<MetroController>().selectRoute(index);
                setState(() {
                  _showFullFare = false;
                });
              },
            ),
            const SizedBox(height: 12),
          ],
          _RouteGuideCard(route: route),
          const SizedBox(height: 12),
          _FareFocusCard(
            route: route,
            showFullFare: _showFullFare,
            onToggleFare: () {
              setState(() {
                _showFullFare = !_showFullFare;
              });
            },
          ),
        ],
      ],
    );
  }
}

class _ResultHeroCard extends StatelessWidget {
  const _ResultHeroCard({required this.route});

  final RouteResult route;

  @override
  Widget build(BuildContext context) {
    final autoFare = _buildAutoFare(route.fare);
    final repository = context.read<MetroController>().repository;
    final timings = repository.getOperatingTimingsForRoute(route.path);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${route.source.name} -> ${route.destination.name}',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _SummaryChip(
                  icon: Icons.schedule_outlined,
                  label: '~${route.estimatedMinutes} min',
                ),
                _SummaryChip(
                  icon: Icons.train_outlined,
                  label: '${route.totalStations} stations',
                ),
                _SummaryChip(
                  icon: Icons.sync_alt,
                  label: '${route.interchangeCount} line changes',
                ),
                _SummaryChip(
                  icon: Icons.tune,
                  label: route.preference.shortLabel,
                ),
                _SummaryChip(
                  icon: Icons.currency_rupee,
                  label: 'Now ~ Rs ${autoFare.recommendedFare}',
                ),
              ],
            ),
            if (timings.isNotEmpty) ...[
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Text(
                    'First & Last Train Timings',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Source (${route.source.name}):',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'First: ${timings['firstTrainSource']} • Last: ${timings['lastTrainSource']}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Destination (${route.destination.name}):',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'First: ${timings['firstTrainDest']} • Last: ${timings['lastTrainDest']}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteOptionsCard extends StatelessWidget {
  const _RouteOptionsCard({
    required this.routes,
    required this.selectedRoute,
    required this.onSelected,
  });

  final List<RouteResult> routes;
  final RouteResult selectedRoute;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Compare Route Options',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < routes.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RouteOptionTile(
                  index: index,
                  route: routes[index],
                  selected: identical(selectedRoute, routes[index]),
                  onTap: () => onSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteOptionTile extends StatelessWidget {
  const _RouteOptionTile({
    required this.index,
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final RouteResult route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected
        ? scheme.primaryContainer
        : scheme.surfaceContainerLow;
    final textColor = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    final autoFare = _buildAutoFare(route.fare);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: textColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Option ${index + 1} - ${route.preference.shortLabel}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '~${route.estimatedMinutes} min | ${route.totalStations} stations | ${route.interchangeCount} changes | Now ~ Rs ${autoFare.recommendedFare}',
              style: TextStyle(fontSize: 14, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteGuideCard extends StatelessWidget {
  const _RouteGuideCard({required this.route});

  final RouteResult route;

  @override
  Widget build(BuildContext context) {
    final visibleStopCount = _visibleStops(route.path).length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Route Guide',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Follow these stations in order.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < route.path.length; index++) ...<Widget>[
              if (index == 0 ||
                  route.path[index].normalizedName !=
                      route.path[index - 1].normalizedName)
                _TimelineStopRow(
                  stopNumber: _displayIndex(route.path, index),
                  totalStops: visibleStopCount,
                  station: route.path[index],
                ),
              if (index < route.path.length - 1 &&
                  route.path[index].line != route.path[index + 1].line)
                _TimelineChangeRow(
                  stationName: route.path[index].name,
                  from: route.path[index].line,
                  to: route.path[index + 1].line,
                ),
            ],
            const SizedBox(height: 4),
            Text(
              'Total stops shown: $visibleStopCount',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FareFocusCard extends StatelessWidget {
  const _FareFocusCard({
    required this.route,
    required this.showFullFare,
    required this.onToggleFare,
  });

  final RouteResult route;
  final bool showFullFare;
  final VoidCallback onToggleFare;

  @override
  Widget build(BuildContext context) {
    final fare = route.fare;
    final autoFare = _buildAutoFare(fare);
    final weekdaySmartPeak = _discountedFare(fare.weekdayTokenFare, 10);
    final weekdaySmartOffPeak = _discountedFare(fare.weekdayTokenFare, 20);
    final holidaySmart = _discountedFare(fare.holidayTokenFare, 10);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Fare',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Now (${autoFare.contextLabel})',
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Token Rs ${autoFare.tokenFare} | Smart Card Rs ${autoFare.smartCardFare}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onToggleFare,
              icon: Icon(showFullFare ? Icons.expand_less : Icons.expand_more),
              label: Text(
                showFullFare ? 'Hide detailed fare' : 'Show detailed fare',
              ),
            ),
            if (showFullFare) ...<Widget>[
              const SizedBox(height: 4),
              _FareRow(
                label: 'Estimated route distance',
                value: '${fare.estimatedDistanceKm} km',
              ),
              _FareRow(
                label: 'Weekday Token/QR',
                value: 'Rs ${fare.weekdayTokenFare}',
              ),
              _FareRow(
                label: 'Weekday Smart Card (Peak)',
                value: 'Rs $weekdaySmartPeak',
              ),
              _FareRow(
                label: 'Weekday Smart Card (Off-peak)',
                value: 'Rs $weekdaySmartOffPeak',
              ),
              _FareRow(
                label: 'Sunday/Holiday Token/QR',
                value: 'Rs ${fare.holidayTokenFare}',
              ),
              _FareRow(
                label: 'Sunday/Holiday Smart Card',
                value: 'Rs $holidaySmart',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStopRow extends StatelessWidget {
  const _TimelineStopRow({
    required this.stopNumber,
    required this.totalStops,
    required this.station,
  });

  final int stopNumber;
  final int totalStops;
  final Station station;

  void _showAmenities(BuildContext context) {
    final future = StationAmenityService.instance.resolve(station);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<StationAmenities>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Text('Error loading amenities'),
                    ),
                  );
                }
                final amenities = snapshot.data!;
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: lineColor(station.line),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              station.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${lineName(station.line)} • ${amenities.layout} Station',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Divider(height: 24),
                      const Text(
                        'Amenities Quick Info',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: <Widget>[
                          _AmenityIcon(
                            icon: Icons.elevator_outlined,
                            label: 'Lift / Elevator',
                            available: amenities.hasElevator,
                          ),
                          _AmenityIcon(
                            icon: Icons.wc_outlined,
                            label: 'Washroom',
                            available: amenities.hasWashroom,
                          ),
                          _AmenityIcon(
                            icon: Icons.local_parking_outlined,
                            label: 'Parking',
                            available: amenities.hasParking,
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text(
                        'Platforms & Directions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      ...amenities.platforms.map((platform) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Icon(Icons.directions_train, size: 18, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Expanded(child: Text(platform, style: const TextStyle(fontSize: 15))),
                              ],
                            ),
                          )),
                      const Divider(height: 24),
                      const Text(
                        'Station Exit Gates',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      ...amenities.gates.map((gate) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Icon(Icons.door_sliding_outlined, size: 18, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Expanded(child: Text(gate, style: const TextStyle(fontSize: 15))),
                              ],
                            ),
                          )),
                      const Divider(height: 24),
                      const Text(
                        'Feeder & Connectivity',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(Icons.directions_bus_outlined, size: 18, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              amenities.feederService,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectorColor = lineColor(station.line).withValues(alpha: 0.6);
    final isStart = stopNumber == 1;
    final isEnd = stopNumber == totalStops;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 42,
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 10,
                  child: isStart
                      ? const SizedBox.shrink()
                      : Container(width: 3, color: connectorColor),
                ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: lineColor(station.line),
                  child: Text(
                    '$stopNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  height: 22,
                  child: isEnd
                      ? const SizedBox.shrink()
                      : Container(width: 3, color: connectorColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(top: 2),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.8),
                ),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _showAmenities(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    station.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.info_outline,
                                  size: 15,
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (isStart || isEnd)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isStart
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isStart ? 'Start' : 'End',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isStart
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lineName(station.line),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmenityIcon extends StatelessWidget {
  const _AmenityIcon({
    required this.icon,
    required this.label,
    required this.available,
  });

  final IconData icon;
  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        CircleAvatar(
          radius: 24,
          backgroundColor: available
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          child: Icon(
            icon,
            color: available
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: available
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
        Text(
          available ? 'Available' : 'Not Available',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: available ? Colors.green[700] : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _TimelineChangeRow extends StatelessWidget {
  const _TimelineChangeRow({
    required this.stationName,
    required this.from,
    required this.to,
  });

  final String stationName;
  final String from;
  final String to;

  int _transferWalkTime(String station, String from, String to) {
    final s = station.toLowerCase();
    if (s.contains('noida sector 52') || s.contains('noida sector 51')) {
      return 10;
    }
    if (s.contains('d.n. nagar') || s.contains('andheri (west)')) {
      return 6;
    }
    if (s.contains('western express highway') || s.contains('gundavali')) {
      return 5;
    }
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final fromColor = lineColor(from).withValues(alpha: 0.6);
    final toColor = lineColor(to).withValues(alpha: 0.6);
    final walkTime = _transferWalkTime(stationName, from, to);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 42,
            child: Column(
              children: <Widget>[
                Container(width: 3, height: 8, color: fromColor),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sync_alt,
                    size: 16,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                Container(width: 3, height: 10, color: toColor),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Change at $stationName to ${lineName(to)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.directions_walk,
                        size: 13,
                        color: Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Walk transfer: ~$walkTime mins',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FareRow extends StatelessWidget {
  const _FareRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _AutoFareInfo {
  const _AutoFareInfo({
    required this.contextLabel,
    required this.tokenFare,
    required this.smartCardFare,
  });

  final String contextLabel;
  final int tokenFare;
  final int smartCardFare;

  int get recommendedFare =>
      smartCardFare < tokenFare ? smartCardFare : tokenFare;
}

_AutoFareInfo _buildAutoFare(FareBreakdown fare) {
  final now = DateTime.now();
  final isSunday = now.weekday == DateTime.sunday;
  final isPeak = !isSunday && _isWeekdayPeak(now);

  if (isSunday) {
    final token = fare.holidayTokenFare;
    final smart = _discountedFare(token, 10);
    return _AutoFareInfo(
      contextLabel: 'Sunday/Holiday',
      tokenFare: token,
      smartCardFare: smart,
    );
  }

  final token = fare.weekdayTokenFare;
  final smart = isPeak
      ? _discountedFare(token, 10)
      : _discountedFare(token, 20);
  final contextLabel = isPeak ? 'Weekday peak' : 'Weekday off-peak';
  return _AutoFareInfo(
    contextLabel: contextLabel,
    tokenFare: token,
    smartCardFare: smart,
  );
}

bool _isWeekdayPeak(DateTime dateTime) {
  final minutes = dateTime.hour * 60 + dateTime.minute;
  final morningPeak = minutes >= 8 * 60 && minutes < 12 * 60;
  final eveningPeak = minutes >= 17 * 60 && minutes < 21 * 60;
  return morningPeak || eveningPeak;
}

int _displayIndex(List<Station> path, int uptoIndex) {
  var count = 0;
  for (var i = 0; i <= uptoIndex; i++) {
    if (i == 0 || path[i].normalizedName != path[i - 1].normalizedName) {
      count++;
    }
  }
  return count;
}

List<Station> _visibleStops(List<Station> path) {
  final visible = <Station>[];
  for (var i = 0; i < path.length; i++) {
    if (i == 0 || path[i].normalizedName != path[i - 1].normalizedName) {
      visible.add(path[i]);
    }
  }
  return visible;
}

int _discountedFare(int baseFare, int discountPercent) {
  final discount = ((baseFare * discountPercent) / 100).round();
  return (baseFare - discount).clamp(0, 10000).toInt();
}
