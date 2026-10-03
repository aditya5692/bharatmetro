# Open Delhi Transit Flutter

Flutter migration of the original Android Kotlin app.

## Included Features

- Metro route planner using bundled Delhi Metro JSON assets
- Station search with synonym support (`station_entity.json`)
- Live transit list and map view (OpenStreetMap)
- Nearby fuel station lookup
- Step tracker with stride estimate and compass direction

## Run

```bash
flutter pub get
flutter run
```

## Optional API Keys

The app runs without keys using fallback sample data.  
To enable live online data, pass keys via `--dart-define`:

```bash
flutter run \
  --dart-define=OTD_API_KEY=your_delhi_transit_key \
  --dart-define=GOMAPS_API_KEY=your_gomaps_key
```

## Stability Notes

- Build is independent of Android `local.properties` and secrets-gradle plugin.
- Metro route logic has unit coverage in `test/metro_repository_test.dart`.
- Network-backed screens degrade gracefully to sample data when API or key fails.
