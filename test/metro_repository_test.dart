import 'package:flutter_test/flutter_test.dart';
import 'package:bharat_metro/core/metro/metro_network_registry.dart';
import 'package:bharat_metro/models/route_result.dart';
import 'package:bharat_metro/models/station.dart';
import 'package:bharat_metro/services/metro_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MetroRepository', () {
    test('loads stations from assets', () async {
      final repository = MetroRepository();
      await repository.initialize();
      expect(repository.allStations.length, greaterThan(150));
    });

    test('finds route between common stations', () async {
      final repository = MetroRepository();
      final route = await repository.findRoute('AIIMS', 'Kashmere Gate');

      expect(route.path, isNotEmpty);
      expect(route.path.first.name.toLowerCase(), contains('aiims'));
      expect(route.path.last.name.toLowerCase(), contains('kashmere'));
      expect(route.totalStations, greaterThan(0));
    });

    test('includes Aerocity station and routes on Airport Express', () async {
      final repository = MetroRepository();
      final route = await repository.findRoute('New Delhi', 'Delhi Aerocity');

      expect(route.path, isNotEmpty);
      expect(
        route.path.any(
          (station) => station.name.toLowerCase() == 'delhi aerocity',
        ),
        isTrue,
      );
      expect(route.fare.weekdayTokenFare, greaterThanOrEqualTo(50));
    });

    test('connects Blue line with Aqua line at Noida Sector 52/51', () async {
      final repository = MetroRepository();
      final route = await repository.findRoute(
        'Noida Sector 52',
        'Noida Sector 51',
      );

      expect(route.path, isNotEmpty);
      expect(route.path.first.name.toLowerCase(), contains('noida sector 52'));
      expect(route.path.last.name.toLowerCase(), contains('noida sector 51'));
      expect(route.interchangeCount, greaterThanOrEqualTo(1));
    });

    test('returns de-duplicated route options', () async {
      final repository = MetroRepository();
      final routes = await repository.findRoutes('Rajiv Chowk', 'Moti Nagar');

      expect(routes.length, greaterThanOrEqualTo(1));
      expect(routes.length, lessThanOrEqualTo(3));
      final signatures = routes
          .map(
            (route) => route.path.map((s) => '${s.line}:${s.name}').join('>'),
          )
          .toSet();
      expect(signatures.length, routes.length);
      expect(routes.first.path, isNotEmpty);
    });

    test('applies selected route preference to all generated options', () async {
      final repository = MetroRepository();
      final routes = await repository.findRoutes(
        'Mayur Vihar - I',
        'Sikandarpur',
        preferredPreference: RoutePreference.leastInterchanges,
      );

      expect(routes, isNotEmpty);
      expect(
        routes.every(
          (route) => route.preference == RoutePreference.leastInterchanges,
        ),
        isTrue,
      );
    });

    test(
      'returns multiple valid options for Mayur Vihar - I to Sikandarpur',
      () async {
        final repository = MetroRepository();
        final routes = await repository.findRoutes(
          'Mayur Vihar - I',
          'Sikandarpur',
        );

        expect(routes.length, greaterThanOrEqualTo(2));
        final signatures = routes
            .map(
              (route) => route.path.map((s) => '${s.line}:${s.name}').join('>'),
            )
            .toSet();
        expect(signatures.length, routes.length);
      },
    );

    test('supports station synonym search', () async {
      final repository = MetroRepository();
      final results = await repository.searchStations('ISBT');
      final stationNames = results.map((station) => station.name).toSet();

      expect(stationNames.isNotEmpty, isTrue);
      expect(
        stationNames.any((name) => name.toLowerCase().contains('anand vihar')),
        isTrue,
      );
    });

    test('merges duplicate-like station names in station list', () async {
      final repository = MetroRepository();
      await repository.initialize();
      final names = repository.stationNames;
      final mayurCandidates = names.where((name) {
        return Station.normalizeText(name) == 'mayur vihar i';
      }).toList();
      expect(mayurCandidates.length, lessThanOrEqualTo(1));
    });

    test('loads full Chennai Blue and Green line datasets', () async {
      final repository = MetroRepository(network: MetroNetworkRegistry.chennai);
      await repository.initialize();

      expect(repository.allStations.length, greaterThanOrEqualTo(40));

      final route = await repository.findRoute('Egmore', 'Chennai Airport');
      expect(route.path, isNotEmpty);
      expect(route.interchangeCount, greaterThanOrEqualTo(1));
    });

    test('loads full Bengaluru Purple, Green and Yellow datasets', () async {
      final repository = MetroRepository(
        network: MetroNetworkRegistry.bengaluru,
      );
      await repository.initialize();

      expect(repository.allStations.length, greaterThanOrEqualTo(80));

      final route = await repository.findRoute('Madavara', 'Bommasandra');
      expect(route.path, isNotEmpty);
      expect(route.interchangeCount, greaterThanOrEqualTo(1));
    });

    test('loads full Patna corridor datasets with interchange routing', () async {
      final repository = MetroRepository(network: MetroNetworkRegistry.bihar);
      await repository.initialize();

      expect(repository.allStations.length, greaterThanOrEqualTo(20));

      final route = await repository.findRoute(
        'Danapur Cantonment',
        'Patliputra Bus Terminal',
      );
      expect(route.path, isNotEmpty);
      expect(route.interchangeCount, greaterThanOrEqualTo(1));
    });
  });
}
