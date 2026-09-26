
import 'package:dashtab_pos/core/shell/home_shell.dart';
import 'package:dashtab_pos/core/shell/shell_views.dart';
import 'package:dashtab_pos/core/theme/app_icons.dart';
import 'package:dashtab_pos/core/theme/demo_data.dart';
import 'package:dashtab_pos/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phone/tablet viewport smoke tests: every primary view must render
/// without layout-overflow exceptions on small screens, and the shell
/// navigation must be reachable (drawer) with the compact topbar.
class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isAuthenticated: true,
        userId: 'test-user',
        fullName: 'Test User',
      );
}

void main() {
  // Seed enough data that views render real content, not empty states.
  setUp(() {
    // HomeShell normally gets its content builder from the GoRouter; the
    // test harness mounts the shell directly, so wire it here.
    shellChildBuilder = (context, key) => ShellViews.build(context, key);
    demo.cancelPendingUndos();
    demo.cart.clear();
    demo.cartMeta = {'type': 'Dine In'};
    demo.products
      ..clear()
      ..addAll([
        DemoProduct(
            id: 1,
            name: 'Margherita Pizza',
            cat: 'Pizza',
            price: 11.48,
            iva: 10,
            stock: 20),
        DemoProduct(
            id: 2,
            name: 'Espresso',
            cat: 'Drinks',
            price: 2.2,
            iva: 10,
            stock: 100),
      ]);
    demo.tables
      ..clear()
      ..add(DemoTable(
          name: 'T1', seats: 4, status: 'free', zone: 'Indoor'));
    demo.customers.clear();
    demo.orders.clear();
  });

  Future<ProviderContainer> pumpShell(
    WidgetTester tester,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(_FakeAuthNotifier.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> goTo(WidgetTester tester, String label) async {
    // Phone: navigation lives in the drawer.
    await tester.tap(find.byIcon(AppIcons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  group('phone viewport (390×844)', () {
    const size = Size(390, 844);

    testWidgets('dashboard renders without overflow', (tester) async {
      await pumpShell(tester, size);
      expect(find.text('Dashboard'), findsWidgets);
    });

    testWidgets('drawer opens and navigates to orders/kitchen/inventory',
        (tester) async {
      await pumpShell(tester, size);
      await goTo(tester, 'Orders');
      expect(find.byIcon(AppIcons.menu), findsOneWidget);
      await goTo(tester, 'Kitchen Display');
      await goTo(tester, 'Inventory');
    });

    testWidgets('topbar stays intact: title bounded, branch icon-only',
        (tester) async {
      await pumpShell(tester, size);
      // Compact branch selector (icon button, no BRANCH caption).
      expect(find.text('BRANCH'), findsNothing);
      expect(find.byIcon(AppIcons.buildings), findsOneWidget);
    });

    testWidgets('POS renders catalog; cart drawer opens only when asked',
        (tester) async {
      await pumpShell(tester, size);
      await goTo(tester, 'New Order');
      await tester.pumpAndSettle();
      // Product cards render the name twice (card + quick stats row).
      expect(find.text('Margherita Pizza'), findsNWidgets(2));
      // Drawer must NOT cover the catalog before the user opens it.
      expect(demo.cartDrawerOpen, isFalse);
      // With items in the cart the FAB appears; its callback opens the
      // drawer over the catalog and the close button dismisses it.
      demo.cart.add(CartLine(1, 1));
      demo.notifyListeners(); // the FAB is a Consumer on the shell rebuild
      await tester.pumpAndSettle();
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      expect(find.byTooltip('Close cart'), findsNothing);

      // Run the FAB's own onPressed (hit-testing is unreliable in tests).
      tester.widget<FloatingActionButton>(fab).onPressed!();
      await tester.pumpAndSettle();
      expect(demo.cartDrawerOpen, isTrue);
      expect(find.byTooltip('Close cart'), findsOneWidget);
      await tester.tap(find.byTooltip('Close cart'));
      await tester.pumpAndSettle();
      expect(demo.cartDrawerOpen, isFalse);
      expect(find.byTooltip('Close cart'), findsNothing);
    });

    testWidgets('tables view renders without overflow', (tester) async {
      await pumpShell(tester, size);
      await goTo(tester, 'Tables');
      expect(find.text('T1'), findsWidgets);
    });
  });

  group('tablet viewport (800×1100)', () {
    const size = Size(800, 1100);

    testWidgets('dashboard and orders render without overflow',
        (tester) async {
      await pumpShell(tester, size);
      expect(find.text('Dashboard'), findsWidgets);
      await goTo(tester, 'Orders');
    });

    testWidgets('POS renders without overflow', (tester) async {
      await pumpShell(tester, size);
      await goTo(tester, 'New Order');
      expect(find.text('Margherita Pizza'), findsWidgets);
    });
  });
}
