class Station {
  const Station({required this.name, required this.line, required this.index});

  final String name;
  final String line;
  final int index;

  String get normalizedName => normalizeText(name);

  static String normalizeText(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll('*', '')
        .replaceAll(RegExp(r'[–—−]'), '-')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Station &&
        other.name == name &&
        other.line == line &&
        other.index == index;
  }

  @override
  int get hashCode => Object.hash(name, line, index);
}
