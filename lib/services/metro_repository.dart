import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../core/metro/metro_network_registry.dart';
import '../models/route_result.dart';
import '../models/station.dart';

class MetroRepository {
  MetroRepository({MetroNetworkDefinition? network})
    : _network = network ?? MetroNetworkRegistry.delhi;

  final MetroNetworkDefinition _network;

  final List<Station> _stations = <Station>[];
  final Map<String, List<Station>> _lines = <String, List<Station>>{};
  final Map<Station, Set<Station>> _graph = <Station, Set<Station>>{};
  final Map<String, List<Station>> _stationsByName = <String, List<Station>>{};
  final Map<String, String> _synonymToCanonical = <String, String>{};
  final Map<String, _GeoPoint> _coordinatesByLineAndName =
      <String, _GeoPoint>{};
  final Map<String, _GeoPoint> _coordinatesByName = <String, _GeoPoint>{};
  List<String> _stationNames = const <String>[];

  bool _initialized = false;

  bool get isInitialized => _initialized;

  List<Station> get allStations => List<Station>.unmodifiable(_stations);

  List<String> get stationNames => _stationNames;

  /// Returns terminal station names for each line, keyed by line identifier.
  Map<String, List<String>> get lineTerminals {
    final result = <String, List<String>>{};
    for (final entry in _lines.entries) {
      final stations = entry.value;
      if (stations.length >= 2) {
        result[entry.key] = <String>[
          stations.first.name,
          stations.last.name,
        ];
      }
    }
    return result;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _stations.clear();
    _lines.clear();
    _graph.clear();
    _stationsByName.clear();
    _synonymToCanonical.clear();
    _coordinatesByLineAndName.clear();
    _coordinatesByName.clear();
    _stationNames = const <String>[];

    await _loadStationEntitySynonyms();
    await _loadStationsFromAssets();
    await _loadStationCoordinates();
    _buildGraph();
    _stationNames = _buildStationNames();
    _initialized = true;
  }

  Future<List<Station>> searchStations(String query) async {
    await initialize();
    final normalizedQuery = Station.normalizeText(query);
    if (normalizedQuery.isEmpty) {
      return const <Station>[];
    }

    final canonicalQuery =
        _synonymToCanonical[normalizedQuery] ?? normalizedQuery;
    final normalizedCanonical = Station.normalizeText(canonicalQuery);

    final exactMatches = _stations.where((station) {
      return station.normalizedName == normalizedCanonical;
    }).toList();

    if (exactMatches.isNotEmpty) {
      return _sortStations(_dedupeStations(exactMatches));
    }

    var containsMatches = _stations.where((station) {
      return station.normalizedName.contains(normalizedCanonical);
    }).toList();

    if (containsMatches.isEmpty && normalizedCanonical.contains(' ')) {
      final queryWords = normalizedCanonical
          .split(' ')
          .map((word) => word.trim())
          .where((word) => word.length > 1)
          .toList();
      containsMatches = _stations.where((station) {
        return queryWords.any(station.normalizedName.contains);
      }).toList();
    }

    final sorted = _sortStations(_dedupeStations(containsMatches));
    return sorted.take(60).toList();
  }

  Future<RouteResult> findRoute(
    String sourceName,
    String destinationName, {
    RoutePreference preference = RoutePreference.shortestStations,
    FareRequest fareRequest = const FareRequest(),
  }) async {
    final routes = await findRoutes(
      sourceName,
      destinationName,
      preferredPreference: preference,
      fareRequest: fareRequest,
      maxRoutes: 1,
    );
    return routes.first;
  }

  Future<List<RouteResult>> findRoutes(
    String sourceName,
    String destinationName, {
    RoutePreference? preferredPreference,
    FareRequest fareRequest = const FareRequest(),
    int maxRoutes = 3,
  }) async {
    await initialize();
    final normalizedSource = Station.normalizeText(sourceName);
    final normalizedDestination = Station.normalizeText(destinationName);
    if (normalizedSource.isEmpty || normalizedDestination.isEmpty) {
      throw ArgumentError('Source and destination are required.');
    }

    if (normalizedSource == normalizedDestination) {
      final station = _resolveCandidates(sourceName).firstOrNull;
      if (station == null) {
        throw StateError('Could not find station "$sourceName".');
      }
      final path = <Station>[station];
      return <RouteResult>[
        RouteResult(
          source: station,
          destination: station,
          path: path,
          totalStations: 0,
          interchangeCount: 0,
          estimatedMinutes: 2,
          weight: 0,
          preference: preferredPreference ?? RoutePreference.shortestStations,
          fare: _buildFareBreakdown(path, fareRequest),
        ),
      ];
    }

    final sourceCandidates = _resolveCandidates(sourceName);
    final destinationCandidates = _resolveCandidates(destinationName);

    if (sourceCandidates.isEmpty) {
      throw StateError('Could not find source station "$sourceName".');
    }
    if (destinationCandidates.isEmpty) {
      throw StateError(
        'Could not find destination station "$destinationName".',
      );
    }

    final routes = <RouteResult>[];
    final routeSignatures = <String>{};
    final preferenceOrder = _orderedPreferences(preferredPreference);

    for (final preference in preferenceOrder) {
      final best = _bestPathForPreference(
        sourceCandidates,
        destinationCandidates,
        preference,
      );
      if (best == null) {
        continue;
      }
      _addUniqueRoute(
        routes: routes,
        signatures: routeSignatures,
        candidate: best,
        fareRequest: fareRequest,
      );
      if (routes.length >= maxRoutes) {
        return routes;
      }
    }

    if (routes.isEmpty) {
      throw StateError(
        'No route found between "$sourceName" and "$destinationName".',
      );
    }

    if (routes.length < maxRoutes) {
      final baselineStations = routes.first.totalStations;
      final baselineWeight = routes.first.weight == 0 ? 1 : routes.first.weight;
      final exploredBlockedEdges = <String>{};
      final seedRoutes = List<RouteResult>.from(routes);

      for (final seedRoute in seedRoutes) {
        final blockedEdgeCandidates = _pathEdgeKeys(seedRoute.path);
        for (final blockedEdge in blockedEdgeCandidates) {
          if (!exploredBlockedEdges.add(blockedEdge)) {
            continue;
          }

          for (final preference in preferenceOrder) {
            final detour = _bestPathForPreference(
              sourceCandidates,
              destinationCandidates,
              preference,
              blockedEdges: <String>{blockedEdge},
            );
            if (detour == null) continue;

            final detourStations = detour.path.length > 1
                ? detour.path.length - 1
                : 0;
            if (detourStations > baselineStations + 35) {
              continue;
            }
            if (detour.weight > baselineWeight * 3) {
              continue;
            }
            if (_isNearDuplicatePath(
              detour.path,
              routes.map((route) => route.path).toList(),
            )) {
              continue;
            }

            _addUniqueRoute(
              routes: routes,
              signatures: routeSignatures,
              candidate: detour,
              fareRequest: fareRequest,
            );

            if (routes.length >= maxRoutes) {
              return _sortRouteOptions(routes, preferredPreference);
            }
            break;
          }
        }
      }
    }

    return _sortRouteOptions(routes, preferredPreference);
  }

  Future<void> _loadStationEntitySynonyms() async {
    _registerDynamicSynonyms();

    final synonymPath = _network.synonymsAssetPath;
    if (synonymPath == null || synonymPath.isEmpty) {
      return;
    }

    try {
      final rawJson = await rootBundle.loadString(synonymPath);
      final decoded = jsonDecode(rawJson);
      if (decoded is! List<dynamic>) return;

      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        final canonicalName = _cleanName(entry['value']?.toString());
        if (canonicalName == null) continue;
        final normalizedCanonical = Station.normalizeText(canonicalName);
        _synonymToCanonical[normalizedCanonical] = canonicalName;

        final synonyms = entry['synonyms'];
        if (synonyms is! List<dynamic>) continue;
        for (final synonym in synonyms) {
          final normalizedSynonym = _cleanName(synonym?.toString());
          if (normalizedSynonym == null) continue;
          _synonymToCanonical[Station.normalizeText(normalizedSynonym)] =
              canonicalName;
        }
      }
    } catch (_) {
      // Synonym data is optional and should not block route calculations.
    }
  }

  void _registerDynamicSynonyms() {
    final networkId = _network.id;
    if (networkId == 'mumbai') {
      _addSynonym('csmt', 'Chhatrapati Shivaji Maharaj Terminus');
      _addSynonym('chhatrapati shivaji', 'Chhatrapati Shivaji Maharaj Terminus');
      _addSynonym('weh', 'Western Express Highway');
      _addSynonym('dn nagar', 'D.N. Nagar');
    } else if (networkId == 'bengaluru') {
      _addSynonym('majestic', 'Nadaprabhu Kempegowda Station, Majestic');
      _addSynonym('kempegowda', 'Nadaprabhu Kempegowda Station, Majestic');
      _addSynonym('mgn', 'Mahatma Gandhi Road');
      _addSynonym('mg road', 'Mahatma Gandhi Road');
    } else if (networkId == 'chennai') {
      _addSynonym('central', 'Puratchi Thalaivar Dr. M.G. Ramachandran Central');
      _addSynonym('mgr central', 'Puratchi Thalaivar Dr. M.G. Ramachandran Central');
      _addSynonym('egmore', 'Chennai Egmore');
    }
  }

  void _addSynonym(String short, String canonical) {
    _synonymToCanonical[Station.normalizeText(short)] = canonical;
  }

  Future<void> _loadStationsFromAssets() async {
    for (final line in _network.lineFiles) {
      final path = '${_network.assetLineDirectory}/$line.json';
      List<dynamic> decoded;
      try {
        final rawJson = await rootBundle.loadString(path);
        final parsed = jsonDecode(rawJson);
        if (parsed is! List<dynamic>) {
          continue;
        }
        decoded = parsed;
      } catch (_) {
        continue;
      }

      for (var index = 0; index < decoded.length; index++) {
        final item = decoded[index];
        if (item is! Map<String, dynamic>) continue;
        final stationName = _extractStationName(line, item);
        if (stationName == null) continue;
        _stations.add(Station(name: stationName, line: line, index: index));
      }
    }

    final seen = <String>{};
    final uniqueStations = <Station>[];
    for (final station in _stations) {
      final key = '${station.line}|${station.index}|${station.name}';
      if (seen.add(key)) {
        uniqueStations.add(station);
      }
    }
    _stations
      ..clear()
      ..addAll(uniqueStations);

    for (final station in _stations) {
      _lines.putIfAbsent(station.line, () => <Station>[]).add(station);
      _stationsByName
          .putIfAbsent(station.normalizedName, () => <Station>[])
          .add(station);
    }

    for (final lineStations in _lines.values) {
      lineStations.sort((a, b) => a.index.compareTo(b.index));
    }
  }

  Future<void> _loadStationCoordinates() async {
    final coordinatesPath = _network.coordinatesAssetPath;
    if (coordinatesPath == null || coordinatesPath.isEmpty) {
      return;
    }

    try {
      final rawCsv = await rootBundle.loadString(coordinatesPath);
      final rows = const LineSplitter().convert(rawCsv);
      if (rows.length < 2) {
        return;
      }

      for (final row in rows.skip(1)) {
        final columns = _parseCsvRow(row);
        if (columns.length < 4) {
          continue;
        }

        final stationName = _cleanName(columns[0]);
        final line = _normalizeCsvLine(columns[1]);
        final latitude = double.tryParse(columns[2].trim());
        final longitude = double.tryParse(columns[3].trim());
        if (stationName == null || latitude == null || longitude == null) {
          continue;
        }

        final point = _GeoPoint(latitude, longitude);
        final normalizedName = Station.normalizeText(stationName);

        _coordinatesByName.putIfAbsent(normalizedName, () => point);
        if (line != null) {
          _coordinatesByLineAndName['$line|$normalizedName'] = point;
        }
      }
    } catch (_) {
      // Coordinates are optional and only used for fare-distance estimation.
    }
  }

  String? _extractStationName(String line, Map<String, dynamic> item) {
    if (line == 'magenta') {
      final special = _cleanName(item['25']?.toString());
      if (special != null) {
        return _canonicalizeName(special);
      }
    }

    final english = _cleanName(item['English']?.toString());
    if (english != null && !_looksNumeric(english)) {
      return _canonicalizeName(english);
    }

    final hindi = _cleanName(item['Hindi']?.toString());
    if (hindi != null && !_looksCorrupted(hindi)) {
      return _canonicalizeName(hindi);
    }

    final phase = _cleanName(item['Phase']?.toString());
    if (phase != null && !_looksNumeric(phase)) {
      return _canonicalizeName(phase);
    }

    return null;
  }

  String _canonicalizeName(String name) {
    final normalized = Station.normalizeText(name);
    return _synonymToCanonical[normalized] ?? name;
  }

  void _buildGraph() {
    _graph.clear();

    for (final lineStations in _lines.values) {
      if (lineStations.length < 2) continue;
      for (var i = 0; i < lineStations.length - 1; i++) {
        _addEdge(lineStations[i], lineStations[i + 1]);
      }
    }

    final stationsByName = <String, List<Station>>{};
    for (final station in _stations) {
      stationsByName
          .putIfAbsent(station.normalizedName, () => <Station>[])
          .add(station);
    }

    for (final sameNameStations in stationsByName.values) {
      if (sameNameStations.length < 2) continue;
      for (var i = 0; i < sameNameStations.length; i++) {
        for (var j = i + 1; j < sameNameStations.length; j++) {
          _addEdge(sameNameStations[i], sameNameStations[j]);
        }
      }
    }

    _addManualInterchanges();
  }

  void _addManualInterchanges() {
    for (final interchange in _network.manualInterchanges) {
      final firstStations = _findStationsByLineAndName(
        interchange.firstLine,
        interchange.firstStation,
      );
      final secondStations = _findStationsByLineAndName(
        interchange.secondLine,
        interchange.secondStation,
      );
      for (final first in firstStations) {
        for (final second in secondStations) {
          _addEdge(first, second);
        }
      }
    }
  }

  List<Station> _findStationsByLineAndName(String line, String stationName) {
    final normalizedName = Station.normalizeText(stationName);
    return _stations.where((station) {
      if (station.line != line) return false;
      return station.normalizedName == normalizedName;
    }).toList();
  }

  void _addEdge(Station first, Station second) {
    _graph.putIfAbsent(first, () => <Station>{}).add(second);
    _graph.putIfAbsent(second, () => <Station>{}).add(first);
  }

  List<Station> _resolveCandidates(String stationName) {
    final normalized = Station.normalizeText(stationName);
    final canonical = _synonymToCanonical[normalized] ?? stationName;
    final normalizedCanonical = Station.normalizeText(canonical);

    final exact = _stationsByName[normalizedCanonical];
    if (exact != null && exact.isNotEmpty) {
      return exact;
    }

    final partialMatches = _stations.where((station) {
      return station.normalizedName.contains(normalizedCanonical);
    }).toList();
    if (partialMatches.isNotEmpty) {
      return _sortStations(_dedupeStations(partialMatches));
    }

    return const <Station>[];
  }

  _PathCandidate? _bestPathForPreference(
    List<Station> sourceCandidates,
    List<Station> destinationCandidates,
    RoutePreference preference, {
    Set<String> blockedEdges = const <String>{},
  }) {
    _PathCandidate? bestPath;
    for (final source in sourceCandidates) {
      for (final destination in destinationCandidates) {
        final candidate = _dijkstra(
          source,
          destination,
          preference: preference,
          blockedEdges: blockedEdges,
        );
        if (candidate == null) continue;
        if (bestPath == null || _isBetterCandidate(candidate, bestPath)) {
          bestPath = candidate;
        }
      }
    }
    return bestPath;
  }

  bool _isBetterCandidate(_PathCandidate current, _PathCandidate previous) {
    if (current.weight != previous.weight) {
      return current.weight < previous.weight;
    }

    final currentInterchanges = _calculateInterchangeCount(current.path);
    final previousInterchanges = _calculateInterchangeCount(previous.path);
    if (currentInterchanges != previousInterchanges) {
      return currentInterchanges < previousInterchanges;
    }

    return current.path.length < previous.path.length;
  }

  _PathCandidate? _dijkstra(
    Station source,
    Station destination, {
    required RoutePreference preference,
    Set<String> blockedEdges = const <String>{},
  }) {
    if (source == destination) {
      return _PathCandidate(
        path: <Station>[source],
        weight: 0,
        preference: preference,
      );
    }

    const inf = 1 << 30;
    final distances = <Station, int>{
      for (final station in _stations) station: inf,
    };
    final previous = <Station, Station?>{};
    final visited = <Station>{};
    final frontier = <Station>[source];
    distances[source] = 0;

    while (frontier.isNotEmpty) {
      frontier.sort((a, b) => distances[a]!.compareTo(distances[b]!));
      final current = frontier.removeAt(0);

      if (!visited.add(current)) {
        continue;
      }

      if (current == destination) {
        break;
      }

      final neighbors = _graph[current];
      if (neighbors == null) continue;

      for (final neighbor in neighbors) {
        if (visited.contains(neighbor)) continue;
        if (blockedEdges.contains(_edgeKey(current, neighbor))) {
          continue;
        }

        final edgeWeight = _edgeWeight(current, neighbor, preference);
        final newDistance = distances[current]! + edgeWeight;
        if (newDistance < (distances[neighbor] ?? inf)) {
          distances[neighbor] = newDistance;
          previous[neighbor] = current;
          frontier.add(neighbor);
        }
      }
    }

    final finalWeight = distances[destination] ?? inf;
    if (finalWeight >= inf) return null;

    final path = <Station>[];
    Station? current = destination;
    while (current != null) {
      path.insert(0, current);
      if (current == source) {
        break;
      }
      current = previous[current];
    }

    if (path.isEmpty || path.first != source) {
      return null;
    }

    return _PathCandidate(
      path: path,
      weight: finalWeight,
      preference: preference,
    );
  }

  int _transferWalkTimeMinutes(String station1, String line1, String station2, String line2) {
    final s1 = Station.normalizeText(station1);
    final s2 = Station.normalizeText(station2);

    // Noida Sector 52/51 Out-of-station interchange
    if ((s1 == 'noida sector 52' && s2 == 'noida sector 51') ||
        (s1 == 'noida sector 51' && s2 == 'noida sector 52')) {
      return 10;
    }

    // Mumbai Metro: D.N. Nagar to Andheri (West)
    if ((s1 == 'dn nagar' && s2 == 'andheri west') ||
        (s1 == 'andheri west' && s2 == 'dn nagar')) {
      return 6;
    }

    // Mumbai Metro: Western Express Highway to Gundavali
    if ((s1 == 'western express highway' && s2 == 'gundavali') ||
        (s1 == 'gundavali' && s2 == 'western express highway')) {
      return 5;
    }

    // Default transfer walk time for standard platform changes
    return 3;
  }

  int _calculatePathMinutes(List<Station> path) {
    if (path.length < 2) return 2;
    var minutes = 0;
    for (var i = 1; i < path.length; i++) {
      final prev = path[i - 1];
      final curr = path[i];
      if (prev.line == curr.line) {
        minutes += 2; // 2 minutes per station transit on average
      } else {
        minutes += _transferWalkTimeMinutes(prev.name, prev.line, curr.name, curr.line);
      }
    }
    return minutes.clamp(2, 320);
  }

  int _edgeWeight(Station first, Station second, RoutePreference preference) {
    final interchange = first.line != second.line;
    if (!interchange) return 1;
    final walkTime = _transferWalkTimeMinutes(first.name, first.line, second.name, second.line);
    switch (preference) {
      case RoutePreference.shortestStations:
        return 1;
      case RoutePreference.leastInterchanges:
        return 15 + walkTime;
      case RoutePreference.balanced:
        return 3 + walkTime;
    }
  }

  void _addUniqueRoute({
    required List<RouteResult> routes,
    required Set<String> signatures,
    required _PathCandidate candidate,
    required FareRequest fareRequest,
  }) {
    final signature = _pathSignature(candidate.path);
    if (!signatures.add(signature)) {
      return;
    }

    final path = candidate.path;
    final interchanges = _calculateInterchangeCount(path);
    final totalStations = path.length > 1 ? path.length - 1 : 0;
    final estimatedMinutes = _calculatePathMinutes(path);

    routes.add(
      RouteResult(
        source: path.first,
        destination: path.last,
        path: path,
        totalStations: totalStations,
        interchangeCount: interchanges,
        estimatedMinutes: estimatedMinutes,
        weight: candidate.weight,
        preference: candidate.preference,
        fare: _buildFareBreakdown(path, fareRequest),
      ),
    );
  }

  Map<String, String> getOperatingTimingsForRoute(List<Station> path) {
    if (path.isEmpty) return const {};
    final firstLine = path.first.line;
    final lastLine = path.last.line;

    // First/last timing database: line -> [first train, last train]
    const timingDb = <String, List<String>>{
      // Delhi
      'yellow': ['05:30 AM', '11:30 PM'],
      'blue': ['05:45 AM', '11:15 PM'],
      'red': ['05:30 AM', '11:00 PM'],
      'green': ['06:00 AM', '11:00 PM'],
      'violet': ['06:00 AM', '11:05 PM'],
      'orange': ['04:45 AM', '11:30 PM'],
      'magenta': ['06:00 AM', '11:00 PM'],
      'pink': ['06:00 AM', '11:00 PM'],
      'aqua': ['06:00 AM', '10:00 PM'],
      // Mumbai
      'mumbaiblue': ['05:30 AM', '11:20 PM'],
      'mumbaiyellow': ['06:00 AM', '10:30 PM'],
      'mumbaired': ['06:00 AM', '10:30 PM'],
      'mumbaiaqua': ['06:30 AM', '10:00 PM'],
      // Bengaluru
      'bengalurupurple': ['05:00 AM', '11:00 PM'],
      'bengalurugreen': ['05:00 AM', '11:00 PM'],
      'bengaluruyellow': ['05:00 AM', '11:00 PM'],
      // Chennai
      'chennaiblue': ['05:00 AM', '11:00 PM'],
      'chennaigreen': ['05:00 AM', '11:00 PM'],
    };

    final startTimings = timingDb[firstLine] ?? ['06:00 AM', '11:00 PM'];
    final endTimings = timingDb[lastLine] ?? ['06:00 AM', '11:00 PM'];

    return {
      'firstTrainSource': startTimings[0],
      'lastTrainSource': startTimings[1],
      'firstTrainDest': endTimings[0],
      'lastTrainDest': endTimings[1],
    };
  }

  FareBreakdown _buildFareBreakdown(List<Station> path, FareRequest request) {
    final distanceKm = _estimateDistanceKm(path);
    var weekdayTokenFare = _weekdayTokenFareForDistance(distanceKm);
    var holidayTokenFare = _holidayTokenFareForDistance(distanceKm);

    final airportFareFloor = _airportExpressMinimumFare(path);
    if (airportFareFloor > 0) {
      weekdayTokenFare = math.max(weekdayTokenFare, airportFareFloor);
      holidayTokenFare = math.max(holidayTokenFare, airportFareFloor - 10);
    }

    final baseFare = request.dayType == FareDayType.sundayOrHoliday
        ? holidayTokenFare
        : weekdayTokenFare;

    final paymentDiscountPercent =
        request.paymentMode == FarePaymentMode.smartCard ? 10 : 0;
    final paymentDiscountAmount = ((baseFare * paymentDiscountPercent) / 100)
        .round();

    final offPeakDiscountPercent = request.qualifiesForOffPeakDiscount ? 10 : 0;
    final offPeakDiscountAmount = ((baseFare * offPeakDiscountPercent) / 100)
        .round();

    final afterOfficialDiscounts =
        baseFare - paymentDiscountAmount - offPeakDiscountAmount;
    final additionalPercent = request.clampedAdditionalDiscountPercent;
    final additionalDiscountAmount =
        ((afterOfficialDiscounts * additionalPercent) / 100).round();

    final payableFare = (afterOfficialDiscounts - additionalDiscountAmount)
        .clamp(0, 10000)
        .toInt();

    final notes = <String>[
      'Updated fare slabs used: 2/5/12/21/32+ km bands (DMRC revision effective 25 Aug 2025).',
      'Smart Card discount: 10%. Additional 10% off-peak applies on weekdays only.',
    ];
    if (airportFareFloor > 0) {
      notes.add(
        'Airport Express segment detected; minimum Airport Express fare floor applied.',
      );
    }
    if (request.timeBand == FareTimeBand.offPeak &&
        !request.qualifiesForOffPeakDiscount) {
      notes.add(
        'Off-peak discount is ignored for Token/QR or Sunday/Holiday journeys.',
      );
    }
    if (additionalPercent > 0) {
      notes.add(
        'Additional concession ($additionalPercent%) treated as planner custom discount.',
      );
    }

    return FareBreakdown(
      estimatedDistanceKm: double.parse(distanceKm.toStringAsFixed(1)),
      weekdayTokenFare: weekdayTokenFare,
      holidayTokenFare: holidayTokenFare,
      baseFare: baseFare,
      paymentDiscountPercent: paymentDiscountPercent,
      paymentDiscountAmount: paymentDiscountAmount,
      offPeakDiscountPercent: offPeakDiscountPercent,
      offPeakDiscountAmount: offPeakDiscountAmount,
      additionalDiscountPercent: additionalPercent,
      additionalDiscountAmount: additionalDiscountAmount,
      payableFare: payableFare,
      notes: notes,
    );
  }

  double _estimateDistanceKm(List<Station> path) {
    if (path.length < 2) {
      return 0;
    }

    var distanceKm = 0.0;
    for (var i = 1; i < path.length; i++) {
      final previous = path[i - 1];
      final current = path[i];
      if (previous.line == current.line) {
        distanceKm += _lineSegmentDistanceKm(previous, current);
      } else if (previous.normalizedName == current.normalizedName) {
        distanceKm += 0.25;
      } else {
        distanceKm += 0.8;
      }
    }

    return distanceKm.clamp(0, 500);
  }

  double _lineSegmentDistanceKm(Station first, Station second) {
    final firstCoord = _coordinateForStation(first);
    final secondCoord = _coordinateForStation(second);
    if (firstCoord != null && secondCoord != null) {
      final km = _haversineKm(firstCoord, secondCoord);
      if (km > 0.05 && km < 10.0) {
        return km;
      }
    }
    return 1.2;
  }

  _GeoPoint? _coordinateForStation(Station station) {
    final normalizedName = station.normalizedName;
    return _coordinatesByLineAndName['${station.line}|$normalizedName'] ??
        _coordinatesByName[normalizedName];
  }

  double _haversineKm(_GeoPoint first, _GeoPoint second) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(second.latitude - first.latitude);
    final dLon = _toRadians(second.longitude - first.longitude);

    final lat1 = _toRadians(first.latitude);
    final lat2 = _toRadians(second.latitude);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degree) => degree * (math.pi / 180.0);

  int _weekdayTokenFareForDistance(double km) {
    final networkId = _network.id;
    if (networkId == 'mumbai') {
      if (km <= 3) return 10;
      if (km <= 12) return 20;
      if (km <= 18) return 30;
      if (km <= 24) return 40;
      if (km <= 30) return 50;
      return 60;
    } else if (networkId == 'chennai') {
      if (km <= 2) return 10;
      if (km <= 5) return 20;
      if (km <= 9) return 30;
      if (km <= 21) return 40;
      return 50;
    } else if (networkId == 'bengaluru') {
      if (km <= 2) return 10;
      final calculated = 10 + ((km - 2) * 1.5).round();
      return calculated.clamp(10, 60);
    }

    // Delhi Default
    if (km <= 2) return 20;
    if (km <= 5) return 30;
    if (km <= 12) return 40;
    if (km <= 21) return 50;
    if (km <= 32) return 60;
    return 70;
  }

  int _holidayTokenFareForDistance(double km) {
    final networkId = _network.id;
    // Holiday discount only officially applies to Delhi Metro
    if (networkId != 'delhi') {
      return _weekdayTokenFareForDistance(km);
    }

    if (km <= 2) return 10;
    if (km <= 5) return 20;
    if (km <= 12) return 30;
    if (km <= 21) return 40;
    if (km <= 32) return 50;
    return 60;
  }

  int _airportExpressMinimumFare(List<Station> path) {
    final orangePath = path
        .where((station) => station.line == 'orange')
        .toList();
    if (orangePath.length < 2) {
      return 0;
    }

    final first = orangePath.first.name;
    final last = orangePath.last.name;
    final byName = _airportExpressFareByName(first, last);
    if (byName != null) {
      return byName;
    }

    final stopCount = (orangePath.last.index - orangePath.first.index).abs();
    if (stopCount <= 0) return 0;
    if (stopCount == 1) return 21;
    if (stopCount == 2) return 32;
    if (stopCount == 3) return 54;
    return 64;
  }

  int? _airportExpressFareByName(String first, String second) {
    final a = Station.normalizeText(first);
    final b = Station.normalizeText(second);
    if (a == b) return 0;

    const airportFares = <String, int>{
      'new delhi|shivaji stadium': 21,
      'new delhi|dhaula kuan': 43,
      'new delhi|delhi aerocity': 54,
      'new delhi|igi airport': 64,
      'new delhi|airport': 64,
      'new delhi|dwarka sector 21': 64,
      'new delhi|yashobhoomi dwarka sector - 25': 75,
      'shivaji stadium|dhaula kuan': 21,
      'shivaji stadium|delhi aerocity': 32,
      'shivaji stadium|igi airport': 54,
      'shivaji stadium|airport': 54,
      'shivaji stadium|dwarka sector 21': 64,
      'shivaji stadium|yashobhoomi dwarka sector - 25': 75,
      'dhaula kuan|delhi aerocity': 21,
      'dhaula kuan|igi airport': 32,
      'dhaula kuan|airport': 32,
      'dhaula kuan|dwarka sector 21': 54,
      'dhaula kuan|yashobhoomi dwarka sector - 25': 64,
      'delhi aerocity|igi airport': 21,
      'delhi aerocity|airport': 21,
      'delhi aerocity|dwarka sector 21': 32,
      'delhi aerocity|yashobhoomi dwarka sector - 25': 43,
      'igi airport|dwarka sector 21': 21,
      'igi airport|yashobhoomi dwarka sector - 25': 32,
      'airport|dwarka sector 21': 21,
      'airport|yashobhoomi dwarka sector - 25': 32,
      'dwarka sector 21|yashobhoomi dwarka sector - 25': 21,
    };

    return airportFares['$a|$b'] ?? airportFares['$b|$a'];
  }

  int _calculateInterchangeCount(List<Station> path) {
    var interchanges = 0;
    for (var i = 1; i < path.length; i++) {
      if (path[i].line != path[i - 1].line) {
        interchanges++;
      }
    }
    return interchanges;
  }

  String _pathSignature(List<Station> path) {
    return path
        .map((station) => '${station.line}:${station.index}:${station.name}')
        .join(' -> ');
  }

  List<String> _pathEdgeKeys(List<Station> path) {
    final keys = <String>[];
    for (var i = 1; i < path.length; i++) {
      keys.add(_edgeKey(path[i - 1], path[i]));
    }
    return keys;
  }

  bool _isNearDuplicatePath(
    List<Station> candidatePath,
    List<List<Station>> existingPaths,
  ) {
    final candidateSignature = _pathSignature(candidatePath);
    final candidateInterchanges = _calculateInterchangeCount(candidatePath);

    for (final existingPath in existingPaths) {
      if (_pathSignature(existingPath) == candidateSignature) {
        return true;
      }

      final overlapRatio = _pathOverlapRatio(candidatePath, existingPath);
      final stationGap = (candidatePath.length - existingPath.length).abs();
      final interchangeGap =
          (candidateInterchanges - _calculateInterchangeCount(existingPath))
              .abs();
      if (overlapRatio >= 0.9 && stationGap <= 2 && interchangeGap <= 1) {
        return true;
      }
    }

    return false;
  }

  double _pathOverlapRatio(List<Station> firstPath, List<Station> secondPath) {
    final firstEdges = _pathEdgeKeys(firstPath).toSet();
    final secondEdges = _pathEdgeKeys(secondPath).toSet();
    if (firstEdges.isEmpty && secondEdges.isEmpty) {
      return 1.0;
    }
    final unionSize = firstEdges.union(secondEdges).length;
    if (unionSize == 0) {
      return 0;
    }
    final intersectionSize = firstEdges.intersection(secondEdges).length;
    return intersectionSize / unionSize;
  }

  List<RouteResult> _sortRouteOptions(
    List<RouteResult> routes,
    RoutePreference? preferredPreference,
  ) {
    routes.sort((a, b) {
      final aPreferred = preferredPreference == null
          ? 0
          : (a.preference == preferredPreference ? 0 : 1);
      final bPreferred = preferredPreference == null
          ? 0
          : (b.preference == preferredPreference ? 0 : 1);
      if (aPreferred != bPreferred) {
        return aPreferred.compareTo(bPreferred);
      }
      final byInterchanges = a.interchangeCount.compareTo(b.interchangeCount);
      if (byInterchanges != 0) return byInterchanges;
      final byStations = a.totalStations.compareTo(b.totalStations);
      if (byStations != 0) return byStations;
      return a.weight.compareTo(b.weight);
    });
    return routes;
  }

  String _edgeKey(Station first, Station second) {
    final firstKey = '${first.line}:${first.index}:${first.name}';
    final secondKey = '${second.line}:${second.index}:${second.name}';
    if (firstKey.compareTo(secondKey) <= 0) {
      return '$firstKey|$secondKey';
    }
    return '$secondKey|$firstKey';
  }

  List<RoutePreference> _orderedPreferences(RoutePreference? preferred) {
    if (preferred == null) {
      return List<RoutePreference>.from(RoutePreference.values);
    }
    return <RoutePreference>[preferred];
  }

  String? _cleanName(String? value) {
    if (value == null) return null;
    final normalized = value
        .replaceAll(RegExp(r'^\d+\s*'), '')
        .replaceAll('*', '')
        .trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  bool _looksNumeric(String value) {
    return RegExp(r'^\d+$').hasMatch(value.trim());
  }

  bool _looksCorrupted(String value) {
    return value.contains('à¤') || value.contains('Â');
  }

  bool _isPreferredDisplayName(String candidate, String existing) {
    final candidateCorrupted = _looksCorrupted(candidate);
    final existingCorrupted = _looksCorrupted(existing);
    if (candidateCorrupted != existingCorrupted) {
      return !candidateCorrupted;
    }
    if (candidate.length != existing.length) {
      return candidate.length < existing.length;
    }
    return candidate.compareTo(existing) < 0;
  }

  List<String> _buildStationNames() {
    final namesByNormalized = <String, String>{};
    for (final station in _stations) {
      final normalized = station.normalizedName;
      final existing = namesByNormalized[normalized];
      if (existing == null || _isPreferredDisplayName(station.name, existing)) {
        namesByNormalized[normalized] = station.name;
      }
    }
    final names = namesByNormalized.values.toList()..sort();
    return List<String>.unmodifiable(names);
  }

  List<Station> _dedupeStations(List<Station> stations) {
    final seen = <String>{};
    final result = <Station>[];
    for (final station in stations) {
      final key = '${station.name}|${station.line}|${station.index}';
      if (seen.add(key)) {
        result.add(station);
      }
    }
    return result;
  }

  List<Station> _sortStations(List<Station> stations) {
    stations.sort((a, b) {
      final byName = a.name.compareTo(b.name);
      if (byName != 0) return byName;
      final byLine = a.line.compareTo(b.line);
      if (byLine != 0) return byLine;
      return a.index.compareTo(b.index);
    });
    return stations;
  }

  List<String> _parseCsvRow(String row) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < row.length; i++) {
      final char = row[i];
      if (char == '"') {
        if (inQuotes && i + 1 < row.length && row[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    values.add(buffer.toString());
    return values;
  }

  String? _normalizeCsvLine(String rawLine) {
    final normalized = Station.normalizeText(rawLine);
    if (normalized.isEmpty) return null;

    if (normalized == 'yellow line') return 'yellow';
    if (normalized == 'blue line') return 'blue';
    if (normalized == 'red line') return 'red';
    if (normalized == 'green line') return 'green';
    if (normalized == 'violet line') return 'violet';
    if (normalized == 'orange line') return 'orange';
    if (normalized == 'magenta line') return 'magenta';
    if (normalized == 'pink line') return 'pink';
    if (normalized == 'aqua line') return 'aqua';
    if (normalized == 'grey line') return 'grey';
    if (normalized == 'rapid metro') return 'rapid';
    if (normalized == 'green line branch') return 'greenbranch';
    if (normalized == 'blue line branch') return 'bluebranch';
    if (normalized == 'pink line branch') return 'pinkbranch';

    return null;
  }
}

class _PathCandidate {
  const _PathCandidate({
    required this.path,
    required this.weight,
    required this.preference,
  });

  final List<Station> path;
  final int weight;
  final RoutePreference preference;
}

class _GeoPoint {
  const _GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

extension on List<Station> {
  Station? get firstOrNull => isEmpty ? null : first;
}
