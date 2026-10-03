import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedRoute {
  const SavedRoute({
    required this.source,
    required this.destination,
    required this.savedAt,
  });

  final String source;
  final String destination;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'source': source,
        'destination': destination,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedRoute.fromJson(Map<String, dynamic> json) {
    return SavedRoute(
      source: json['source'] as String,
      destination: json['destination'] as String,
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AppPreferences {
  static const String selectedMetroNetworkKey = 'selected_metro_network';
  static const String recentRoutesKey = 'recent_routes';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String compactJourneyKey = 'compact_journey';
  static const String interchangeAlertsKey = 'interchange_alerts';
  static const int maxRecentRoutes = 6;
  static Future<SharedPreferences>? _prefsFuture;

  static Future<SharedPreferences> _prefs() {
    return _prefsFuture ??= SharedPreferences.getInstance();
  }

  static Future<bool> getNotificationsEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(notificationsEnabledKey) ?? true;
  }

  static Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(notificationsEnabledKey, value);
  }

  static Future<bool> getCompactJourneyDetails() async {
    final prefs = await _prefs();
    return prefs.getBool(compactJourneyKey) ?? false;
  }

  static Future<void> setCompactJourneyDetails(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(compactJourneyKey, value);
  }

  static Future<bool> getShowInterchangeAlerts() async {
    final prefs = await _prefs();
    return prefs.getBool(interchangeAlertsKey) ?? true;
  }

  static Future<void> setShowInterchangeAlerts(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(interchangeAlertsKey, value);
  }

  static Future<String?> getSelectedMetroNetwork() async {
    final prefs = await _prefs();
    return prefs.getString(selectedMetroNetworkKey);
  }

  static Future<void> setSelectedMetroNetwork(String networkId) async {
    final prefs = await _prefs();
    await prefs.setString(selectedMetroNetworkKey, networkId);
  }

  static Future<List<SavedRoute>> getRecentRoutes() async {
    final prefs = await _prefs();
    final raw = prefs.getStringList(recentRoutesKey);
    if (raw == null || raw.isEmpty) {
      return <SavedRoute>[];
    }

    return raw
        .map((entry) {
          try {
            return SavedRoute.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedRoute>()
        .toList();
  }

  static Future<void> addRecentRoute({
    required String source,
    required String destination,
  }) async {
    final from = source.trim();
    final to = destination.trim();
    if (from.isEmpty || to.isEmpty) return;

    final prefs = await _prefs();
    final existing = await getRecentRoutes();
    final updated = <SavedRoute>[
      SavedRoute(source: from, destination: to, savedAt: DateTime.now()),
      ...existing.where(
        (route) =>
            route.source.toLowerCase() != from.toLowerCase() ||
            route.destination.toLowerCase() != to.toLowerCase(),
      ),
    ].take(maxRecentRoutes);

    await prefs.setStringList(
      recentRoutesKey,
      updated.map((route) => jsonEncode(route.toJson())).toList(),
    );
  }
}
