import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dashtab_pos/core/shell/views/customers_view.dart';
import 'package:dashtab_pos/core/shell/views/pos_view.dart';
import 'package:dashtab_pos/core/shell/views/tables_view.dart';
import 'package:dashtab_pos/core/theme/demo_data.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('floor plan: tables can be dragged and the move is snapped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1700, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    demo.floors
      ..clear()
      ..add(DemoFloor(name: 'Indoor', dbId: 'floor-1'));
    demo.tables
      ..clear()
      ..addAll([
        DemoTable(
          name: 'T1',
          seats: 4,
          status: 'free',
          zone: 'Indoor',
          floorId: 'floor-1',
          dbId: 't1',
        ),
        DemoTable(
          name: 'T2',
          seats: 2,
          status: 'free',
          zone: 'Indoor',
          floorId: 'floor-1',
          dbId: 't2',
        ),
      ]);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _host(const TablesView()),
      ),
    );
    await tester.pump();

    // Grid → floor plan → layout editing.
    await tester.tap(find.text('Floor plan'));
    await tester.pump();
    await tester.tap(find.text('Edit layout'));
    await tester.pump();

    final t1 = demo.tables.firstWhere((t) => t.name == 'T1');
    final t2 = demo.tables.firstWhere((t) => t.name == 'T2');
    expect(t1.placed, isFalse, reason: 'nothing laid out yet');

    await tester.drag(find.text('T1'), const Offset(80, 60));
    await tester.pump();

    expect(t1.placed, isTrue);
    expect(t1.x, greaterThan(0));
    expect(t1.y, greaterThan(0));
    // Snapped to the 10-unit grid.
    expect(t1.x % 10, 0);
    expect(t1.y % 10, 0);
    // Only the dragged table moved.
    expect(t2.placed, isFalse);
    expect(t2.x, 0);
    expect(t2.y, 0);
  });

  testWidgets('floor plan: the corner handle resizes a table', (tester) async {
    tester.view.physicalSize = const Size(1700, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    demo.floors
      ..clear()
      ..add(DemoFloor(name: 'Indoor', dbId: 'floor-1'));
    demo.tables
      ..clear()
      ..add(
        DemoTable(
          name: 'T1',
          seats: 4,
          status: 'free',
          zone: 'Indoor',
          floorId: 'floor-1',
          dbId: 't1',
          x: 100,
          y: 100,
          width: 150,
          height: 130,
          placed: true,
        ),
      );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _host(const TablesView()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Floor plan'));
    await tester.pump();
    await tester.tap(find.text('Edit layout'));
    await tester.pump();

    final t1 = demo.tables.first;
    final before = t1.width;

    // Drag the resize handle (bottom-right corner of the table box).
    final box = tester.getRect(find.byKey(const ValueKey('plan-box-T1')));
    await tester.dragFrom(
      box.bottomRight - const Offset(8, 8),
      const Offset(60, 0),
    );
    await tester.pump();

    expect(t1.width, greaterThan(before));
    // Resizing snaps to the same 10-unit grid as moving.
    expect(t1.width % 10, 0);
    // A resize must never move the table.
    expect(t1.x, 100);
    expect(t1.y, 100);
  });

  testWidgets('POS cart: discounts stay behind a compact row', (tester) async {
    tester.view.physicalSize = const Size(1700, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    demo.settings.remove('pin_hash');
    demo.products
      ..clear()
      ..add(
        DemoProduct(
          id: 1,
          name: 'Pizza',
          cat: 'Pizza',
          price: 10,
          iva: 10,
          stock: 5,
        ),
      );
    demo.discounts
      ..clear()
      ..add(const AppDiscount(name: 'SAVE10', type: 0, value: 10));
    demo.cart
      ..clear()
      ..add(CartLine(1, 1));
    demo.cartMeta = {'type': 'Dine In'};

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Rendered inside the shell so the POS gets the same constraints as the
    // running app (the bare view has no shell sizing).
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 1700, height: 1000, child: PosView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Compact by default: one line, no discount applied.
    expect(find.text('Add discount'), findsOneWidget);
    expect(find.text('SAVE10'), findsNothing);

    // Tapping it opens the picker with every active discount.
    await tester.tap(find.text('Add discount'));
    await tester.pumpAndSettle();
    expect(find.text('Apply a discount'), findsOneWidget);
    await tester.tap(find.text('SAVE10').last);
    await tester.pumpAndSettle();

    // Applied: still one compact line, now showing the saving.
    expect(find.textContaining('Discount · SAVE10'), findsOneWidget);
    expect(find.text('−€1.00'), findsWidgets);

    // The X clears it again.
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Add discount'), findsOneWidget);
  });

  testWidgets('customers: header sorts the list and filters by tier', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1700, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    demo.customers
      ..clear()
      ..addAll([
        Customer(
          id: 1,
          name: 'Ann Alpha',
          phone: '111',
          visits: 2,
          total: 50,
          points: 10,
          tier: 'Gold',
        ),
        Customer(
          id: 2,
          name: 'Bob Beta',
          phone: '222',
          visits: 9,
          total: 10,
          points: 90,
          tier: 'Bronze',
        ),
      ]);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _host(const CustomersView()),
      ),
    );
    await tester.pump();

    double topOf(String name) => tester.getTopLeft(find.text(name)).dy;

    // Default: highest spend first.
    expect(topOf('Ann Alpha'), lessThan(topOf('Bob Beta')));

    // Sort by visits (descending) — Bob has more visits.
    await tester.tap(find.text('VISITS'));
    await tester.pump();
    expect(topOf('Bob Beta'), lessThan(topOf('Ann Alpha')));

    // Tapping the active column flips the direction.
    await tester.tap(find.text('VISITS'));
    await tester.pump();
    expect(topOf('Ann Alpha'), lessThan(topOf('Bob Beta')));

    // Tier filter: keep only Gold.
    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gold').last);
    await tester.pumpAndSettle();

    expect(find.text('Ann Alpha'), findsOneWidget);
    expect(find.text('Bob Beta'), findsNothing);
  });

  testWidgets('customers: the details dialog lists past orders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1700, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    demo.customers
      ..clear()
      ..add(
        Customer(
          id: 1,
          name: 'Ann Alpha',
          phone: '111',
          visits: 1,
          total: 24,
          points: 5,
          tier: 'Gold',
        ),
      );
    demo.orders
      ..clear()
      ..add(
        DemoOrder(
          id: 4242,
          type: 'Dine In',
          table: 'T2',
          customer: 'Ann Alpha',
          status: 'Paid',
          items: [CartLine(1, 2)],
          method: 'Cash',
          time: '12:30',
          date: '2026-09-20',
          sub: 20,
          tax: 4,
          total: 24,
        ),
      );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _host(const CustomersView()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Ann Alpha'));
    await tester.pumpAndSettle();

    expect(find.text('PURCHASE HISTORY'), findsOneWidget);
    expect(find.text('#4242'), findsOneWidget);
    expect(find.textContaining('2 items · Dine In'), findsOneWidget);
  });
}
