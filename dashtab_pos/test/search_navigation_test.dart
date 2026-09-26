import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dashtab_pos/core/shell/home_shell.dart';
import 'package:dashtab_pos/core/theme/demo_data.dart';
import 'package:dashtab_pos/features/auth/providers/auth_provider.dart';

/// Auth provider stub so HomeShell renders without a Supabase backend.
class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isAuthenticated: true,
        userId: 'test-user',
        fullName: 'Test User',
      );
}

void main() {
  // HomeShell starts a periodic clock Timer; it is cancelled on dispose,
  // so we unmount the shell before the test ends.
  tearDown(() {});

  testWidgets('Tapping a search result navigates to its view', (
    WidgetTester tester,
  ) async {
    // Wide desktop viewport — the search field only shows at width >= 1024,
    // and the default test font (Ahem) renders much wider than production
    // fonts, so the topbar needs the extra room.
    tester.view.physicalSize = const Size(2400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_FakeAuthNotifier.new)],
    );
    addTearDown(container.dispose);

    // Seed the store with a product so the search produces a hit.
    demo.products.add(
      DemoProduct(
        id: 1,
        name: 'Margherita Pizza',
        cat: 'Pizza',
        price: 11.48,
        iva: 10,
        stock: 20,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pump();

    expect(container.read(currentViewProvider).key, 'dashboard');

    // Type a query — results render into the root overlay.
    await tester.enterText(find.byType(TextField), 'margherita');
    await tester.pump();

    expect(find.text('Margherita Pizza'), findsOneWidget);

    // The panel must wrap its content (~340px wide), not fill the overlay:
    // this Flutter version lays out overlay entries with tight constraints,
    // so the Align wrapper (in HomeShell) is load-bearing.
    final panelRender = tester.renderObject<RenderBox>(
      find.ancestor(
        of: find.text('RESULTS  (1)'),
        matching: find.byType(Container),
      ).first,
    );
    expect(panelRender.size.width, 340);
    expect(panelRender.size.height, lessThan(300));

    // THE REGRESSION: the result panel used to paint via a Stack overflow,
    // which renders but is never hit-tested outside its parent's bounds.
    // Tapping the result must now navigate to the Menu view.
    await tester.tap(find.text('Margherita Pizza'));
    await tester.pump();

    expect(container.read(currentViewProvider).key, 'menu');
    // The search field is cleared after navigating.
    expect(find.widgetWithText(TextField, 'margherita'), findsNothing);

    // Unmount so the shell's clock Timer is cancelled (pending timers
    // otherwise fail the test).
    await tester.pumpWidget(const SizedBox());
  });
}
