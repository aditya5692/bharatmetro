import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bharat_metro/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'selected_metro_network': 'delhi',
    });
    await tester.pumpWidget(const OpenDelhiTransitFlutterApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Current network: Delhi NCR Metro'), findsOneWidget);
    expect(find.text('Plan Journey'), findsWidgets);
  });
}
