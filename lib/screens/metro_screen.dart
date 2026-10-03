import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/metro_controller.dart';
import '../widgets/metro_planner_box.dart';

class MetroScreen extends StatefulWidget {
  const MetroScreen({super.key, required this.networkName});

  final String networkName;

  @override
  State<MetroScreen> createState() => _MetroScreenState();
}

class _MetroScreenState extends State<MetroScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MetroController>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetroController>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Metro Planner',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Network: ${widget.networkName}. Search stations and view route results with quick back/modify options.',
          style: const TextStyle(fontSize: 16),
        ),
        if (controller.isLoading) ...<Widget>[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (controller.error != null) ...<Widget>[
          const SizedBox(height: 12),
          _InlineMessage(
            icon: Icons.error_outline,
            color: Theme.of(context).colorScheme.errorContainer,
            textColor: Theme.of(context).colorScheme.onErrorContainer,
            message: controller.error!,
            onClose: context.read<MetroController>().clearError,
          ),
        ],
        const SizedBox(height: 12),
        const MetroPlannerBox(
          title: 'Plan Journey',
          subtitle: 'Pick your source and destination, then tap Find Route.',
        ),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.color,
    required this.textColor,
    required this.message,
    required this.onClose,
  });

  final IconData icon;
  final Color color;
  final Color textColor;
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontSize: 15),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: textColor),
          ),
        ],
      ),
    );
  }
}
