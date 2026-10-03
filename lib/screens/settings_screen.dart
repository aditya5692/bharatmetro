import 'package:flutter/material.dart';

import '../core/config/app_preferences.dart';
import '../core/metro/metro_network_registry.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.currentNetworkId,
    required this.onNetworkSelected,
  });

  final String currentNetworkId;
  final Future<void> Function(String) onNetworkSelected;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedNetworkId;
  bool _notificationsEnabled = true;
  bool _compactJourneyDetails = false;
  bool _showInterchangeAlerts = true;

  @override
  void initState() {
    super.initState();
    _selectedNetworkId = widget.currentNetworkId;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notifications = await AppPreferences.getNotificationsEnabled();
    final compact = await AppPreferences.getCompactJourneyDetails();
    final alerts = await AppPreferences.getShowInterchangeAlerts();
    if (mounted) {
      setState(() {
        _notificationsEnabled = notifications;
        _compactJourneyDetails = compact;
        _showInterchangeAlerts = alerts;
      });
    }
  }

  Future<void> _saveMetroNetwork() async {
    if (_selectedNetworkId == widget.currentNetworkId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No metro network change detected.')),
      );
      return;
    }

    await AppPreferences.setSelectedMetroNetwork(_selectedNetworkId);
    if (!mounted) return;

    final selected = MetroNetworkRegistry.byId(_selectedNetworkId);
    await widget.onNetworkSelected(_selectedNetworkId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Switched to ${selected.displayName}.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            'Metro Network',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Current active network: ${MetroNetworkRegistry.byId(widget.currentNetworkId).displayName}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Select network (applies immediately)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedNetworkId,
                    decoration: const InputDecoration(
                      labelText: 'Metro network',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                    items: MetroNetworkRegistry.all
                        .map(
                          (network) => DropdownMenuItem<String>(
                            value: network.id,
                            child: Text(network.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedNetworkId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _saveMetroNetwork,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text(
                      'Save Metro Network',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  title: const Text('Enable notifications'),
                  subtitle: const Text(
                    'Receive journey reminders and basic app alerts.',
                  ),
                  value: _notificationsEnabled,
                  onChanged: (value) async {
                    await AppPreferences.setNotificationsEnabled(value);
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                ),
                const Divider(height: 0),
                SwitchListTile(
                  title: const Text('Compact journey details'),
                  subtitle: const Text(
                    'Show reduced spacing in route result sections.',
                  ),
                  value: _compactJourneyDetails,
                  onChanged: (value) async {
                    await AppPreferences.setCompactJourneyDetails(value);
                    setState(() {
                      _compactJourneyDetails = value;
                    });
                  },
                ),
                const Divider(height: 0),
                SwitchListTile(
                  title: const Text('Interchange alerts'),
                  subtitle: const Text(
                    'Highlight line changes while viewing routes.',
                  ),
                  value: _showInterchangeAlerts,
                  onChanged: (value) async {
                    await AppPreferences.setShowInterchangeAlerts(value);
                    setState(() {
                      _showInterchangeAlerts = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
