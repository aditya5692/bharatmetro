import 'package:flutter/material.dart';

import '../core/config/app_preferences.dart';

class TravelDashboard extends StatelessWidget {
  const TravelDashboard({
    super.key,
    required this.networkName,
    required this.onOpenFare,
    required this.onRecentRouteSelected,
  });

  final String networkName;
  final VoidCallback onOpenFare;
  final void Function(String source, String destination) onRecentRouteSelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final peakInfo = _peakStatus(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PeakStatusCard(
          label: peakInfo.label,
          detail: peakInfo.detail,
          icon: peakInfo.icon,
          color: peakInfo.color,
        ),
        const SizedBox(height: 12),
        _QuickActionsRow(onOpenFare: onOpenFare),
        const SizedBox(height: 12),
        FutureBuilder<List<SavedRoute>>(
          future: AppPreferences.getRecentRoutes(),
          builder: (context, snapshot) {
            final routes = snapshot.data ?? <SavedRoute>[];
            if (routes.isEmpty) {
              return _TravelTipsCard(networkName: networkName);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Recent Journeys',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ...routes.map(
                  (route) => _RecentRouteTile(
                    route: route,
                    onTap: () => onRecentRouteSelected(
                      route.source,
                      route.destination,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _TravelTipsCard(networkName: networkName),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PeakStatusCard extends StatelessWidget {
  const _PeakStatusCard({
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(fontSize: 13, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.onOpenFare});

  final VoidCallback onOpenFare;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: _ActionChip(
            icon: Icons.currency_rupee,
            label: 'Quick Fare',
            color: scheme.primaryContainer,
            onTap: onOpenFare,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionChip(
            icon: Icons.accessibility_new_outlined,
            label: 'Station amenities in route guide',
            color: scheme.secondaryContainer,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'After finding a route, tap any station for lifts, gates & parking info.',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: <Widget>[
              Icon(icon, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentRouteTile extends StatelessWidget {
  const _RecentRouteTile({required this.route, required this.onTap});

  final SavedRoute route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.history, size: 20),
        ),
        title: Text(
          '${route.source} → ${route.destination}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _relativeTime(route.savedAt),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _TravelTipsCard extends StatelessWidget {
  const _TravelTipsCard({required this.networkName});

  final String networkName;

  @override
  Widget build(BuildContext context) {
    final tips = <String>[
      'Smart card saves 10–20% vs token — off-peak gets the bigger discount.',
      'Compare route options when multiple lines connect your stations.',
      'Check first & last train times on your route result before you leave.',
      '$networkName data works offline after first load.',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.lightbulb_outline, color: Color(0xFF0B4F8A)),
                SizedBox(width: 8),
                Text(
                  'Traveler Tips',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('•  ', style: TextStyle(fontSize: 15)),
                    Expanded(child: Text(tip, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeakInfo {
  const _PeakInfo({
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String detail;
  final IconData icon;
  final Color color;
}

_PeakInfo _peakStatus(DateTime now) {
  if (now.weekday == DateTime.sunday) {
    return const _PeakInfo(
      label: 'Sunday / Holiday fares',
      detail: 'Flat holiday token fare applies. Smart card gets 10% off.',
      icon: Icons.weekend_outlined,
      color: Color(0xFF6A1B9A),
    );
  }

  final minutes = now.hour * 60 + now.minute;
  final isMorningPeak = minutes >= 8 * 60 && minutes < 12 * 60;
  final isEveningPeak = minutes >= 17 * 60 && minutes < 21 * 60;

  if (isMorningPeak || isEveningPeak) {
    return const _PeakInfo(
      label: 'Peak hours now',
      detail: 'Crowded trains likely. Smart card: 10% off. Allow extra interchange time.',
      icon: Icons.people_alt_outlined,
      color: Color(0xFFC62828),
    );
  }

  return const _PeakInfo(
    label: 'Off-peak hours',
    detail: 'Less crowded. Smart card saves 20% vs token — best time to travel.',
    icon: Icons.eco_outlined,
    color: Color(0xFF2E7D32),
  );
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} hr ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays} days ago';
}
