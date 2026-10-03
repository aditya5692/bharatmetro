import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/route_result.dart';
import '../models/station.dart';
import '../services/metro_repository.dart';

class MetroController extends ChangeNotifier {
  MetroController({required MetroRepository repository})
    : _repository = repository {
    unawaited(initialize());
  }

  final MetroRepository _repository;

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  List<Station> _allStations = <Station>[];
  List<Station> _searchResults = <Station>[];
  List<RouteResult> _routes = <RouteResult>[];
  int _selectedRouteIndex = 0;
  bool _showResults = false;
  bool _isDisposed = false;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Station> get allStations => _allStations;
  List<Station> get searchResults => _searchResults;
  List<RouteResult> get routes => _routes;
  bool get showResults => _showResults;
  RouteResult? get route {
    if (_routes.isEmpty) {
      return null;
    }
    final index = _selectedRouteIndex.clamp(0, _routes.length - 1).toInt();
    return _routes[index];
  }

  MetroRepository get repository => _repository;

  List<String> get stationNames {
    return _repository.stationNames;
  }

  void _notifySafely() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;
    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      await _repository.initialize();
      _allStations = _repository.allStations;
      _isInitialized = true;
    } catch (error) {
      _error = 'Failed to load metro data: $error';
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> searchStations(String query) async {
    if (!_isInitialized) {
      await initialize();
    }
    if (query.trim().isEmpty) {
      _searchResults = <Station>[];
      _notifySafely();
      return;
    }

    try {
      _searchResults = await _repository.searchStations(query);
      _error = null;
    } catch (error) {
      _error = 'Search failed: $error';
      _searchResults = <Station>[];
    }
    _notifySafely();
  }

  Future<void> findRoute(
    String source,
    String destination, {
    RoutePreference? preference,
    FareRequest fareRequest = const FareRequest(),
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (source.trim().isEmpty || destination.trim().isEmpty) {
      _error = 'Please provide both source and destination.';
      _routes = <RouteResult>[];
      _selectedRouteIndex = 0;
      _showResults = false;
      _notifySafely();
      return;
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      _routes = await _repository.findRoutes(
        source,
        destination,
        preferredPreference: preference,
        fareRequest: fareRequest,
      );
      _selectedRouteIndex = 0;
      _showResults = _routes.isNotEmpty;
    } catch (error) {
      _error = 'Could not find route: $error';
      _routes = <RouteResult>[];
      _selectedRouteIndex = 0;
      _showResults = false;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<RouteResult?> calculateFareOnly(
    String source,
    String destination, {
    FareRequest fareRequest = const FareRequest(),
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (source.trim().isEmpty || destination.trim().isEmpty) {
      _error = 'Please provide both source and destination.';
      _notifySafely();
      return null;
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      final result = await _repository.findRoute(
        source,
        destination,
        preference: RoutePreference.shortestStations,
        fareRequest: fareRequest,
      );
      return result;
    } catch (error) {
      _error = 'Could not calculate fare: $error';
      return null;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void clearRoute() {
    _routes = <RouteResult>[];
    _selectedRouteIndex = 0;
    _showResults = false;
    _notifySafely();
  }

  void selectRoute(int index) {
    if (_routes.isEmpty) {
      return;
    }
    final clamped = index.clamp(0, _routes.length - 1).toInt();
    if (clamped == _selectedRouteIndex) {
      return;
    }
    _selectedRouteIndex = clamped;
    _notifySafely();
  }

  void clearSearchResults() {
    if (_searchResults.isEmpty) {
      return;
    }
    _searchResults = <Station>[];
    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  void showResultsView() {
    if (_routes.isEmpty) {
      return;
    }
    if (_showResults) {
      return;
    }
    _showResults = true;
    _notifySafely();
  }

  void hideResultsView() {
    if (!_showResults) {
      return;
    }
    _showResults = false;
    _notifySafely();
  }
}
