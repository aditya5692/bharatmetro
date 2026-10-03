import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/metro_controller.dart';
import '../core/config/app_preferences.dart';
import '../models/route_result.dart';
import '../models/station.dart';

class MetroPlannerBox extends StatefulWidget {
  const MetroPlannerBox({
    super.key,
    this.title = 'Plan Journey',
    this.subtitle,
    this.onRouteFound,
    this.initialSource,
    this.initialDestination,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onRouteFound;
  final String? initialSource;
  final String? initialDestination;

  @override
  State<MetroPlannerBox> createState() => _MetroPlannerBoxState();
}

class _MetroPlannerBoxState extends State<MetroPlannerBox> {
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _sourceFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  RoutePreference? _routePreference;

  @override
  void initState() {
    super.initState();
    if (widget.initialSource != null) {
      _sourceController.text = widget.initialSource!;
    }
    if (widget.initialDestination != null) {
      _destinationController.text = widget.initialDestination!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MetroController>().initialize();
    });
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _destinationController.dispose();
    _sourceFocusNode.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _findRoute(BuildContext context) async {
    final controller = context.read<MetroController>();
    final messenger = ScaffoldMessenger.of(context);
    await controller.findRoute(
      _sourceController.text,
      _destinationController.text,
      preference: _routePreference,
    );

    if (!mounted) return;
    if (controller.route == null) {
      final message =
          controller.error ?? 'Route not found. Please try different stations.';
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    await AppPreferences.addRecentRoute(
      source: _sourceController.text,
      destination: _destinationController.text,
    );
    controller.showResultsView();
    widget.onRouteFound?.call();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetroController>();
    final stationNames = controller.stationNames;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.title,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            if (widget.subtitle != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(widget.subtitle!, style: const TextStyle(fontSize: 15)),
            ],
            const SizedBox(height: 14),
            _StationAutocompleteField(
              label: 'From station',
              hintText: 'Search source station',
              icon: Icons.trip_origin,
              controller: _sourceController,
              focusNode: _sourceFocusNode,
              stationNames: stationNames,
            ),
            if (stationNames.isEmpty && !controller.isLoading) ...<Widget>[
              const SizedBox(height: 6),
              const Text(
                'No stations loaded yet. If network was changed, restart app from Settings.',
                style: TextStyle(fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            _StationAutocompleteField(
              label: 'To station',
              hintText: 'Search destination station',
              icon: Icons.location_on_outlined,
              controller: _destinationController,
              focusNode: _destinationFocusNode,
              stationNames: stationNames,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  final source = _sourceController.text;
                  _sourceController.text = _destinationController.text;
                  _destinationController.text = source;
                },
                icon: const Icon(Icons.swap_vert),
                label: const Text('Swap'),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Route Preference',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _routePreference == null
                  ? 'No preference selected. All route comparisons will be shown.'
                  : 'Selected: ${_routePreference!.shortLabel}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            _RoutePreferenceTickSelector(
              selected: _routePreference,
              onChanged: (value) {
                setState(() {
                  _routePreference = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: controller.isLoading
                        ? null
                        : () => _findRoute(context),
                    icon: const Icon(Icons.alt_route),
                    label: const Text(
                      'Find Route',
                      style: TextStyle(fontSize: 17),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    _sourceController.clear();
                    _destinationController.clear();
                    context.read<MetroController>().clearRoute();
                  },
                  child: const Text('Clear', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePreferenceTickSelector extends StatelessWidget {
  const _RoutePreferenceTickSelector({
    required this.selected,
    required this.onChanged,
  });

  final RoutePreference? selected;
  final ValueChanged<RoutePreference?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: RoutePreference.values.map((preference) {
        final isSelected = preference == selected;
        return InkWell(
          onTap: () => onChanged(isSelected ? null : preference),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            child: Row(
              children: <Widget>[
                Icon(
                  isSelected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${preference.shortLabel} - ${preference.description}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StationAutocompleteField extends StatelessWidget {
  const _StationAutocompleteField({
    required this.label,
    required this.hintText,
    required this.icon,
    required this.controller,
    required this.focusNode,
    required this.stationNames,
  });

  final String label;
  final String hintText;
  final IconData icon;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> stationNames;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (option) => option,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = Station.normalizeText(textEditingValue.text);
        if (query.isEmpty) {
          return stationNames.take(40);
        }

        final startsWith = <String>[];
        final contains = <String>[];
        for (final station in stationNames) {
          final normalizedStation = Station.normalizeText(station);
          if (normalizedStation.startsWith(query)) {
            startsWith.add(station);
          } else if (normalizedStation.contains(query)) {
            contains.add(station);
          }
        }
        return <String>[...startsWith, ...contains].take(80);
      },
      onSelected: (selection) {
        controller
          ..text = selection
          ..selection = TextSelection.collapsed(offset: selection.length);
        focusNode.unfocus();
      },
      fieldViewBuilder:
          (context, textEditingController, fieldFocusNode, onFieldSubmitted) {
            return TextField(
              controller: textEditingController,
              focusNode: fieldFocusNode,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                labelText: label,
                hintText: hintText,
                prefixIcon: Icon(icon),
              ),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        if (options.isEmpty) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 540),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.train, size: 18),
                    title: Text(option, style: const TextStyle(fontSize: 16)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
