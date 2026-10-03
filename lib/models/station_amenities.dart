import 'dart:convert';

import 'package:flutter/services.dart';

import 'station.dart';

class StationAmenities {
  const StationAmenities({
    required this.stationName,
    required this.gates,
    required this.platforms,
    required this.hasElevator,
    required this.hasEscalator,
    required this.hasWashroom,
    required this.hasParking,
    required this.hasWheelchairAccess,
    required this.feederService,
    required this.layout,
  });

  final String stationName;
  final List<String> gates;
  final List<String> platforms;
  final bool hasElevator;
  final bool hasEscalator;
  final bool hasWashroom;
  final bool hasParking;
  final bool hasWheelchairAccess;
  final String feederService;
  final String layout;
}

/// Service that resolves station amenities using a combination of:
/// 1. Verified overrides from `assets/station_amenities_overrides.json`
/// 2. Dynamic platform resolution from line terminal stations
/// 3. Smart context-aware rules based on station name patterns
class StationAmenityService {
  StationAmenityService._();

  static StationAmenityService? _instance;
  static StationAmenityService get instance {
    _instance ??= StationAmenityService._();
    return _instance!;
  }

  Map<String, dynamic>? _overrides;
  bool _loaded = false;

  /// Line terminals: maps line key (e.g. 'yellow') to [firstStation, lastStation]
  final Map<String, List<String>> _lineTerminals = <String, List<String>>{};

  /// Call once after MetroRepository has loaded its line data.
  void setLineTerminals(Map<String, List<String>> terminals) {
    _lineTerminals
      ..clear()
      ..addAll(terminals);
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle
          .loadString('assets/station_amenities_overrides.json');
      _overrides = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _overrides = <String, dynamic>{};
    }
    _loaded = true;
  }

  Future<StationAmenities> resolve(Station station) async {
    await _ensureLoaded();
    final normalized = Station.normalizeText(station.name);

    // 1. Check verified overrides
    final override = _findOverride(normalized);
    if (override != null) {
      return _fromOverride(station.name, override);
    }

    // 2. Build from context-aware rules + dynamic terminals
    return _buildFromContext(station);
  }

  Map<String, dynamic>? _findOverride(String normalized) {
    if (_overrides == null) return null;
    // Direct match
    if (_overrides!.containsKey(normalized)) {
      return _overrides![normalized] as Map<String, dynamic>;
    }
    // Try matching by key containment (handles partial names)
    for (final entry in _overrides!.entries) {
      if (normalized == Station.normalizeText(entry.key)) {
        return entry.value as Map<String, dynamic>;
      }
    }
    return null;
  }

  StationAmenities _fromOverride(
    String stationName,
    Map<String, dynamic> data,
  ) {
    return StationAmenities(
      stationName: stationName,
      gates: (data['gates'] as List<dynamic>? ?? <dynamic>[])
          .map((g) => g.toString())
          .toList(),
      platforms: (data['platforms'] as List<dynamic>? ?? <dynamic>[])
          .map((p) => p.toString())
          .toList(),
      hasElevator: data['hasElevator'] as bool? ?? true,
      hasEscalator: data['hasEscalator'] as bool? ?? true,
      hasWashroom: data['hasWashroom'] as bool? ?? true,
      hasParking: data['hasParking'] as bool? ?? false,
      hasWheelchairAccess: data['hasWheelchairAccess'] as bool? ?? true,
      feederService:
          data['feederService'] as String? ?? 'Auto-rickshaws available',
      layout: data['layout'] as String? ?? 'Standard',
    );
  }

  StationAmenities _buildFromContext(Station station) {
    final name = station.name;
    final nameLower = name.toLowerCase();
    final line = station.line;

    // --- Dynamic platforms from loaded line terminals ---
    final platforms = _resolvePlatforms(line);

    // --- Context-aware layout resolution ---
    final layout = _resolveLayout(nameLower, line);

    // --- Context-aware gates ---
    final gates = _resolveGates(name, nameLower, layout);

    // --- Context-aware feeder service ---
    final feederService = _resolveFeederService(nameLower, layout);

    // --- Context-aware facilities ---
    final facilities = _resolveFacilities(nameLower, layout);

    return StationAmenities(
      stationName: name,
      gates: gates,
      platforms: platforms,
      hasElevator: facilities.elevator,
      hasEscalator: facilities.escalator,
      hasWashroom: facilities.washroom,
      hasParking: facilities.parking,
      hasWheelchairAccess: facilities.wheelchair,
      feederService: feederService,
      layout: layout,
    );
  }

  // ---------------------------------------------------------------------------
  // Dynamic platform resolution
  // ---------------------------------------------------------------------------

  List<String> _resolvePlatforms(String line) {
    final terminals = _lineTerminals[line];
    if (terminals == null || terminals.length < 2) {
      return <String>[
        'Platform 1: Towards Terminal A',
        'Platform 2: Towards Terminal B',
      ];
    }
    return <String>[
      'Platform 1: Towards ${terminals.first}',
      'Platform 2: Towards ${terminals.last}',
    ];
  }

  // ---------------------------------------------------------------------------
  // Context-aware layout classification
  // ---------------------------------------------------------------------------

  String _resolveLayout(String nameLower, String line) {
    // Airport stations
    if (_matchesAny(nameLower, _airportKeywords)) {
      return 'Underground Airport Link';
    }
    // Railway / Junction stations
    if (_matchesAny(nameLower, _railwayKeywords)) {
      return 'Underground Railway Hub';
    }
    // ISBT / Bus Terminal stations
    if (_matchesAny(nameLower, _busTerminalKeywords)) {
      return 'Elevated Bus Terminal Interchange';
    }
    // University / College / Institute stations
    if (_matchesAny(nameLower, _educationalKeywords)) {
      return 'Underground Institutional';
    }
    // Stadium / Sports stations
    if (_matchesAny(nameLower, _stadiumKeywords)) {
      return 'Underground Sports Complex';
    }
    // Hospital stations
    if (_matchesAny(nameLower, _hospitalKeywords)) {
      return 'Underground Medical Hub';
    }
    // Market / Bazaar stations
    if (_matchesAny(nameLower, _marketKeywords)) {
      return 'Underground Commercial';
    }
    // Sector-based Noida/Gurugram/Dwarka stations
    if (_matchesAny(nameLower, _sectorKeywords)) {
      return 'Elevated Sector';
    }
    // Temple / Religious site stations
    if (_matchesAny(nameLower, _religiousKeywords)) {
      return 'Underground Heritage';
    }
    // Garden / Park stations
    if (_matchesAny(nameLower, _gardenKeywords)) {
      return 'Elevated Green';
    }

    // Line-based defaults for Mumbai/other cities
    if (line.startsWith('mumbaiaqua')) {
      return 'Underground';
    }
    if (line.startsWith('mumbai')) {
      return 'Elevated';
    }
    if (line.startsWith('patna')) {
      return 'Elevated';
    }
    if (line.startsWith('bengaluru')) {
      return 'Elevated';
    }
    if (line.startsWith('chennai')) {
      return 'Elevated';
    }
    if (line.startsWith('meerut')) {
      return 'Elevated';
    }

    // Delhi defaults based on common elevated/underground split
    return 'Underground';
  }

  // ---------------------------------------------------------------------------
  // Context-aware gate generation
  // ---------------------------------------------------------------------------

  List<String> _resolveGates(
    String name,
    String nameLower,
    String layout,
  ) {
    // Airport
    if (_matchesAny(nameLower, _airportKeywords)) {
      return <String>[
        'Gate 1: Departure Terminal Link',
        'Gate 2: Arrival Terminal Link',
        'Gate 3: Airport Service Road',
      ];
    }

    // Railway / Junction
    if (_matchesAny(nameLower, _railwayKeywords)) {
      return <String>[
        'Gate 1: Railway Station Main Entrance / Platform Link',
        'Gate 2: Station Road / Commercial Area',
        'Gate 3: Residential Colony Side',
      ];
    }

    // ISBT / Bus Terminal
    if (_matchesAny(nameLower, _busTerminalKeywords)) {
      return <String>[
        'Gate 1: Bus Terminal Departure Bays',
        'Gate 2: Bus Terminal Arrival / Pickup Zone',
        'Gate 3: Main Road / Service Road',
      ];
    }

    // University / College
    if (_matchesAny(nameLower, _educationalKeywords)) {
      return <String>[
        'Gate 1: Campus Main Gate / Academic Block',
        'Gate 2: Hostel & Residential Area',
        'Gate 3: Market / Commercial Street',
      ];
    }

    // Sector (Noida/Gurugram/Dwarka)
    if (_matchesAny(nameLower, _sectorKeywords)) {
      final sectorMatch = RegExp(r'sector\s*(\d+)', caseSensitive: false)
          .firstMatch(name);
      final sectorNum = sectorMatch?.group(1) ?? '';
      final sectorLabel = sectorNum.isNotEmpty ? 'Sector $sectorNum' : 'Sector';
      return <String>[
        'Gate 1: $sectorLabel Main Market & Commercial Centre',
        'Gate 2: $sectorLabel Residential Blocks (A/B)',
        'Gate 3: $sectorLabel Service Road / Bus Stand',
      ];
    }

    // Stadium / Sports
    if (_matchesAny(nameLower, _stadiumKeywords)) {
      return <String>[
        'Gate 1: Stadium Main Entrance',
        'Gate 2: Residential / Colony Side',
        'Gate 3: Main Road / Arterial Road',
      ];
    }

    // Hospital
    if (_matchesAny(nameLower, _hospitalKeywords)) {
      return <String>[
        'Gate 1: Hospital Main Entrance / Emergency Wing',
        'Gate 2: Residential Colony',
        'Gate 3: Main Road / Bus Stop',
      ];
    }

    // Market / Bazaar
    if (_matchesAny(nameLower, _marketKeywords)) {
      return <String>[
        'Gate 1: Market Main Entrance / Shopping Area',
        'Gate 2: Residential Colony Side',
        'Gate 3: Main Road / Arterial Road',
      ];
    }

    // Temple / Religious
    if (_matchesAny(nameLower, _religiousKeywords)) {
      return <String>[
        'Gate 1: Temple / Religious Site Entrance',
        'Gate 2: Market / Commercial Area',
        'Gate 3: Residential Area / Main Road',
      ];
    }

    // Garden / Park
    if (_matchesAny(nameLower, _gardenKeywords)) {
      return <String>[
        'Gate 1: Park / Garden Entrance',
        'Gate 2: Residential Colony',
        'Gate 3: Main Road / Bus Stop',
      ];
    }

    // Nagar / Vihar / Puram / Kunj type residential
    if (_matchesAny(nameLower, _residentialKeywords)) {
      return <String>[
        'Gate 1: Main Road / Colony Entrance',
        'Gate 2: Internal Market & Shops',
        'Gate 3: Residential Blocks / Service Lane',
      ];
    }

    // Road / Chowk / Marg type commercial
    if (_matchesAny(nameLower, _roadChowkKeywords)) {
      return <String>[
        'Gate 1: Main Chowk / Junction',
        'Gate 2: Commercial Complex / Shops',
        'Gate 3: Residential Lane',
      ];
    }

    // Default for named areas
    return <String>[
      'Gate 1: $name Main Road Side',
      'Gate 2: $name Residential Area',
    ];
  }

  // ---------------------------------------------------------------------------
  // Context-aware feeder service
  // ---------------------------------------------------------------------------

  String _resolveFeederService(String nameLower, String layout) {
    if (_matchesAny(nameLower, _airportKeywords)) {
      return 'Airport Terminal walkway, Prepaid Taxi, Hotel Shuttle Pickup';
    }
    if (_matchesAny(nameLower, _railwayKeywords)) {
      return 'Railway Station foot-overbridge link, City Bus, Auto-rickshaws';
    }
    if (_matchesAny(nameLower, _busTerminalKeywords)) {
      return 'Bus Terminal direct walkway, State Transport Buses, Auto Stand';
    }
    if (_matchesAny(nameLower, _sectorKeywords)) {
      return 'Sector Bus Route, Shared Auto, E-rickshaws to nearby sectors';
    }
    if (_matchesAny(nameLower, _hospitalKeywords)) {
      return 'Hospital shuttle link, City Bus, Auto-rickshaws';
    }
    if (_matchesAny(nameLower, _educationalKeywords)) {
      return 'Campus shuttle, City Bus, E-rickshaws';
    }
    return 'Auto-rickshaws, E-rickshaws, City Bus Stop nearby';
  }

  // ---------------------------------------------------------------------------
  // Context-aware facility flags
  // ---------------------------------------------------------------------------

  _Facilities _resolveFacilities(String nameLower, String layout) {
    // Major interchanges & terminals
    if (_matchesAny(nameLower, _airportKeywords) ||
        _matchesAny(nameLower, _railwayKeywords) ||
        _matchesAny(nameLower, _busTerminalKeywords)) {
      return const _Facilities(
        elevator: true,
        escalator: true,
        washroom: true,
        parking: true,
        wheelchair: true,
      );
    }

    // Sector-based: usually have parking
    if (_matchesAny(nameLower, _sectorKeywords)) {
      return const _Facilities(
        elevator: true,
        escalator: true,
        washroom: true,
        parking: true,
        wheelchair: true,
      );
    }

    // Default: standard amenities, no parking for urban core stations
    return const _Facilities(
      elevator: true,
      escalator: true,
      washroom: true,
      parking: false,
      wheelchair: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Keyword databases
  // ---------------------------------------------------------------------------

  static const _airportKeywords = <String>[
    'airport', 'aerocity', 'igi', 'csmi airport', 'terminal',
  ];

  static const _railwayKeywords = <String>[
    'junction', 'railway', 'cantt', 'cantonment', 'rail',
  ];

  static const _busTerminalKeywords = <String>[
    'isbt', 'bus terminal', 'bus stand', 'bus depot',
  ];

  static const _educationalKeywords = <String>[
    'university', 'college', 'vidyalaya', 'ignou', 'iit', 'institute',
    'school', 'campus',
  ];

  static const _stadiumKeywords = <String>[
    'stadium', 'sports', 'nehru place', 'moin-ul-haq',
  ];

  static const _hospitalKeywords = <String>[
    'hospital', 'aiims', 'pmch', 'medical', 'health',
  ];

  static const _marketKeywords = <String>[
    'market', 'bazaar', 'bazar', 'mandi', 'haat',
  ];

  static const _sectorKeywords = <String>[
    'sector', 'phase', 'dwarka',
  ];

  static const _religiousKeywords = <String>[
    'temple', 'mandir', 'masjid', 'mosque', 'gurudwara', 'church',
    'dargah', 'chhatarpur',
  ];

  static const _gardenKeywords = <String>[
    'garden', 'park', 'bagh', 'vihar', 'zoo', 'botanical', 'udyan',
  ];

  static const _residentialKeywords = <String>[
    'nagar', 'puram', 'kunj', 'colony', 'enclave', 'vihar',
    'lok', 'niketan',
  ];

  static const _roadChowkKeywords = <String>[
    'chowk', 'marg', 'road', 'sarai', 'gate', 'more',
  ];

  bool _matchesAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) return true;
    }
    return false;
  }
}

class _Facilities {
  const _Facilities({
    required this.elevator,
    required this.escalator,
    required this.washroom,
    required this.parking,
    required this.wheelchair,
  });

  final bool elevator;
  final bool escalator;
  final bool washroom;
  final bool parking;
  final bool wheelchair;
}
