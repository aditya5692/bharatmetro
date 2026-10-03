import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/metro_controller.dart';
import '../models/route_result.dart';
import '../models/station.dart';

class FareCalculatorScreen extends StatefulWidget {
  const FareCalculatorScreen({super.key, required this.networkName});

  final String networkName;

  @override
  State<FareCalculatorScreen> createState() => _FareCalculatorScreenState();
}

class _FareCalculatorScreenState extends State<FareCalculatorScreen> {
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _sourceFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  RouteResult? _fareResult;

  @override
  void initState() {
    super.initState();
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

  Future<void> _calculateFare() async {
    final controller = context.read<MetroController>();
    final result = await controller.calculateFareOnly(
      _sourceController.text,
      _destinationController.text,
    );
    if (!mounted) return;

    if (result == null) {
      final message =
          controller.error ??
          'Fare not available for selected stations. Try different stations.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    setState(() {
      _fareResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetroController>();
    final stationNames = controller.stationNames;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Fare Calculator',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Network: ${widget.networkName}. Enter source and destination to view fare only.',
          style: const TextStyle(fontSize: 16),
        ),
        if (controller.error != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            controller.error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 14,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                _StationAutocompleteField(
                  label: 'From station',
                  hintText: 'Search source station',
                  icon: Icons.trip_origin,
                  controller: _sourceController,
                  focusNode: _sourceFocusNode,
                  stationNames: stationNames,
                ),
                const SizedBox(height: 12),
                _StationAutocompleteField(
                  label: 'To station',
                  hintText: 'Search destination station',
                  icon: Icons.location_on_outlined,
                  controller: _destinationController,
                  focusNode: _destinationFocusNode,
                  stationNames: stationNames,
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: controller.isLoading ? null : _calculateFare,
                        icon: const Icon(Icons.currency_rupee),
                        label: const Text(
                          'Show Fare',
                          style: TextStyle(fontSize: 17),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        _sourceController.clear();
                        _destinationController.clear();
                        setState(() {
                          _fareResult = null;
                        });
                      },
                      child: const Text('Clear', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_fareResult != null) _FareOnlyResultCard(result: _fareResult!),
      ],
    );
  }
}

class _FareOnlyResultCard extends StatelessWidget {
  const _FareOnlyResultCard({required this.result});

  final RouteResult result;

  @override
  Widget build(BuildContext context) {
    final fare = result.fare;
    final weekdaySmartPeak = _discountedFare(fare.weekdayTokenFare, 10);
    final weekdaySmartOffPeak = _discountedFare(fare.weekdayTokenFare, 20);
    final holidaySmart = _discountedFare(fare.holidayTokenFare, 10);
    final now = _autoFare(fare);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${result.source.name} -> ${result.destination.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _FareRow(label: 'Estimated distance', value: '${fare.estimatedDistanceKm} km'),
            _FareRow(label: 'Weekday Token/QR', value: 'Rs ${fare.weekdayTokenFare}'),
            _FareRow(label: 'Weekday Smart Card (Peak)', value: 'Rs $weekdaySmartPeak'),
            _FareRow(
              label: 'Weekday Smart Card (Off-peak)',
              value: 'Rs $weekdaySmartOffPeak',
            ),
            _FareRow(label: 'Sunday/Holiday Token/QR', value: 'Rs ${fare.holidayTokenFare}'),
            _FareRow(label: 'Sunday/Holiday Smart Card', value: 'Rs $holidaySmart'),
            const SizedBox(height: 6),
            _FareRow(
              label: 'Now (${now.contextLabel})',
              value: 'Token Rs ${now.tokenFare} | Smart Card Rs ${now.smartCardFare}',
              emphasize: true,
            ),
          ],
        ),
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
}

_AutoFareInfo _autoFare(FareBreakdown fare) {
  final now = DateTime.now();
  final isSunday = now.weekday == DateTime.sunday;
  if (isSunday) {
    final token = fare.holidayTokenFare;
    return _AutoFareInfo(
      contextLabel: 'Sunday/Holiday',
      tokenFare: token,
      smartCardFare: _discountedFare(token, 10),
    );
  }

  final minutes = now.hour * 60 + now.minute;
  final isPeak =
      (minutes >= 8 * 60 && minutes < 12 * 60) ||
      (minutes >= 17 * 60 && minutes < 21 * 60);
  final token = fare.weekdayTokenFare;
  return _AutoFareInfo(
    contextLabel: isPeak ? 'Weekday peak' : 'Weekday off-peak',
    tokenFare: token,
    smartCardFare: _discountedFare(token, isPeak ? 10 : 20),
  );
}

class _FareRow extends StatelessWidget {
  const _FareRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 16,
      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: baseStyle)),
          Text(value, style: baseStyle),
        ],
      ),
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

int _discountedFare(int baseFare, int discountPercent) {
  final discount = ((baseFare * discountPercent) / 100).round();
  return (baseFare - discount).clamp(0, 10000).toInt();
}
