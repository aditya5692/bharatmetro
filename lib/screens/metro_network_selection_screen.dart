import 'package:flutter/material.dart';

import '../core/metro/metro_network_registry.dart';

class MetroNetworkSelectionScreen extends StatefulWidget {
  const MetroNetworkSelectionScreen({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  State<MetroNetworkSelectionScreen> createState() =>
      _MetroNetworkSelectionScreenState();
}

class _MetroNetworkSelectionScreenState
    extends State<MetroNetworkSelectionScreen> {
  String _selectedNetworkId = MetroNetworkRegistry.delhi.id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const SizedBox(height: 12),
            const Text(
              'Choose Metro Network',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is shown only on first app start. You can change it later from Settings.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 14),
            for (final network in MetroNetworkRegistry.all)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NetworkCard(
                  network: network,
                  selected: network.id == _selectedNetworkId,
                  onTap: () {
                    setState(() {
                      _selectedNetworkId = network.id;
                    });
                  },
                ),
              ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => widget.onSelected(_selectedNetworkId),
              child: const Text('Continue', style: TextStyle(fontSize: 17)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({
    required this.network,
    required this.selected,
    required this.onTap,
  });

  final MetroNetworkDefinition network;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    network.displayName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: selected ? scheme.onPrimaryContainer : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    network.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
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
