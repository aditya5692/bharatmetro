class MetroNetworkDefinition {
  const MetroNetworkDefinition({
    required this.id,
    required this.displayName,
    required this.description,
    required this.assetLineDirectory,
    required this.lineFiles,
    this.synonymsAssetPath,
    this.coordinatesAssetPath,
    this.manualInterchanges = const <ManualInterchangeDefinition>[],
  });

  final String id;
  final String displayName;
  final String description;
  final String assetLineDirectory;
  final List<String> lineFiles;
  final String? synonymsAssetPath;
  final String? coordinatesAssetPath;
  final List<ManualInterchangeDefinition> manualInterchanges;
}

class ManualInterchangeDefinition {
  const ManualInterchangeDefinition({
    required this.firstStation,
    required this.firstLine,
    required this.secondStation,
    required this.secondLine,
  });

  final String firstStation;
  final String firstLine;
  final String secondStation;
  final String secondLine;
}

class MetroNetworkRegistry {
  static const MetroNetworkDefinition delhi = MetroNetworkDefinition(
    id: 'delhi',
    displayName: 'Delhi NCR Metro',
    description: 'Delhi Metro + Airport Express + Aqua + branch lines.',
    assetLineDirectory: 'assets/lines',
    lineFiles: <String>[
      'yellow',
      'blue',
      'red',
      'green',
      'violet',
      'orange',
      'magenta',
      'pink',
      'aqua',
      'grey',
      'rapid',
      'rapidloop',
      'greenbranch',
      'bluebranch',
      'pinkbranch',
      'pitampura',
      'golden',
    ],
    synonymsAssetPath: 'assets/lines/station_entity.json',
    coordinatesAssetPath: 'assets/DELHI_METRO_DATA.csv',
    manualInterchanges: <ManualInterchangeDefinition>[
      ManualInterchangeDefinition(
        firstStation: 'Noida Sector 52',
        firstLine: 'blue',
        secondStation: 'Noida Sector 51',
        secondLine: 'aqua',
      ),
    ],
  );

  static const MetroNetworkDefinition mumbai = MetroNetworkDefinition(
    id: 'mumbai',
    displayName: 'Mumbai Metro',
    description: 'Mumbai Blue, Yellow, Red, and Aqua lines (full station dataset).',
    assetLineDirectory: 'assets/networks/mumbai/lines',
    lineFiles: <String>[
      'mumbaiblue',
      'mumbaiyellow',
      'mumbaired',
      'mumbaiaqua',
    ],
    manualInterchanges: <ManualInterchangeDefinition>[
      ManualInterchangeDefinition(
        firstStation: 'D.N. Nagar',
        firstLine: 'mumbaiblue',
        secondStation: 'Andheri (West)',
        secondLine: 'mumbaiyellow',
      ),
      ManualInterchangeDefinition(
        firstStation: 'Western Express Highway',
        firstLine: 'mumbaiblue',
        secondStation: 'Gundavali',
        secondLine: 'mumbaired',
      ),
    ],
  );

  static const MetroNetworkDefinition meerut = MetroNetworkDefinition(
    id: 'meerut',
    displayName: 'Meerut Metro',
    description: 'Meerut Metro corridor dataset.',
    assetLineDirectory: 'assets/networks/meerut/lines',
    lineFiles: <String>['meerutblue'],
  );

  static const MetroNetworkDefinition chennai = MetroNetworkDefinition(
    id: 'chennai',
    displayName: 'Chennai Metro',
    description: 'Chennai Blue + Green lines (full station dataset).',
    assetLineDirectory: 'assets/networks/chennai/lines',
    lineFiles: <String>['chennaiblue', 'chennaigreen'],
  );

  static const MetroNetworkDefinition bengaluru = MetroNetworkDefinition(
    id: 'bengaluru',
    displayName: 'Bengaluru Metro',
    description: 'Bengaluru Purple + Green + Yellow lines.',
    assetLineDirectory: 'assets/networks/bengaluru/lines',
    lineFiles: <String>[
      'bengalurupurple',
      'bengalurugreen',
      'bengaluruyellow',
    ],
  );

  static const MetroNetworkDefinition bihar = MetroNetworkDefinition(
    id: 'bihar',
    displayName: 'Bihar Metro (Patna)',
    description: 'Patna Metro Corridor 1 + Corridor 2 station dataset.',
    assetLineDirectory: 'assets/networks/bihar/lines',
    lineFiles: <String>['patnablue', 'patnared'],
  );

  static const List<MetroNetworkDefinition> all = <MetroNetworkDefinition>[
    delhi,
    mumbai,
    meerut,
    chennai,
    bengaluru,
    bihar,
  ];

  static MetroNetworkDefinition byId(String id) {
    return all.firstWhere((network) => network.id == id, orElse: () => delhi);
  }
}
