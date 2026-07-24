import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dashtab_pos/main.dart';

void main() {
  testWidgets('App loads and shows login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: DashTabApp(),
      ),
    );

    // Verify that the login title or tenant input exists
    expect(find.text('DashTab POS'), findsOneWidget);
    expect(find.text('Restaurant ID'), findsOneWidget);
  });
}
