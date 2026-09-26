import 'package:dashtab_pos/core/shell/views/pos_view.dart';
import 'package:dashtab_pos/core/theme/app_icons.dart';
import 'package:dashtab_pos/core/theme/demo_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Customer window opened from the POS cart: search + select + create live
/// in one dialog so the cart panel stays clean.
void main() {
  Future<ProviderContainer> pumpPos(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1700, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    demo.products
      ..clear()
      ..add(DemoProduct(
        id: 1,
        name: 'Coffee',
        cat: 'Drinks',
        price: 2.5,
        iva: 10,
        stock: 50,
      ));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 1700, height: 1000, child: PosView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  void addCustomers() {
    demo.customers
      ..clear()
      ..addAll([
        Customer(
          id: 1,
          name: 'John Smith',
          phone: '+34600111222',
          visits: 4,
          total: 120,
          points: 30,
          tier: 'Silver',
        ),
        Customer(
          id: 2,
          name: 'John Smith',
          phone: '+34600333444',
          visits: 1,
          total: 20,
          points: 5,
          tier: 'Bronze',
        ),
      ]);
  }

  /// The cart's customer row opens the window.
  Future<void> openWindow(WidgetTester tester) async {
    await tester.tap(find.text('Add customer…'));
    await tester.pumpAndSettle();
  }

  /// Flush the confirmation toast timers so none leak out of the test.
  Future<void> flushToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  tearDown(() {
    demo.cancelPendingUndos();
    demo.cart.clear();
    demo.cartMeta = {'type': 'Dine In'};
    demo.customers.clear();
  });

  testWidgets('cart row opens the window; picking a customer links it',
      (tester) async {
    addCustomers();
    await pumpPos(tester);

    // Compact summary row, no chips cluttering the cart.
    expect(find.text('Add customer…'), findsOneWidget);
    expect(find.text('New customer'), findsNothing);

    await openWindow(tester);
    expect(find.text('Search by name or phone…'), findsOneWidget);

    // Pick the second John Smith by its phone.
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or phone…').first,
        '+34600333444');
    await tester.pump();
    await tester.tap(find.text('John Smith').last);
    await tester.pumpAndSettle();
    await flushToast(tester);

    expect(demo.cartMeta['customer'], 'John Smith');
    expect(demo.cartMeta['customerId'], '2');
    // The row shows the linked name; the window (its search field) is gone.
    expect(find.text('John Smith'), findsOneWidget);
    expect(find.text('Search by name or phone…'), findsNothing);
  });

  testWidgets('unknown name offers create; dialog requires a phone when duplicates exist',
      (tester) async {
    addCustomers();
    await pumpPos(tester);

    await openWindow(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or phone…').first,
        'Maria Lopez');
    await tester.pumpAndSettle();

    // Empty result offers one-tap creation with the typed name.
    expect(find.text('No customer matches "Maria Lopez"'), findsOneWidget);
    await tester.tap(find.text('Create "Maria Lopez"'));
    await tester.pumpAndSettle();

    // Form pre-filled; optional phone; create + link.
    expect(find.text('New customer'), findsOneWidget);
    expect(find.text('FULL NAME'), findsOneWidget);
    await tester.tap(find.text('Create customer'));
    await tester.pumpAndSettle();
    await flushToast(tester);

    expect(demo.customersNamed('Maria Lopez'), hasLength(1));
    expect(demo.cartMeta['customer'], 'Maria Lopez');
    expect(demo.cartMeta['customerId'], isNotNull);
  });

  testWidgets('duplicate names: attach wins and creating needs a phone',
      (tester) async {
    addCustomers();
    await pumpPos(tester);

    await openWindow(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or phone…').first,
        'John Smith');
    await tester.pumpAndSettle();

    // Both duplicates listed with disambiguating details.
    // (Pill renders uppercase; search within the list only.)
    final list = find.byType(ListView);
    expect(
        find.descendant(of: list, matching: find.textContaining('+34600111222')),
        findsOneWidget);
    expect(
        find.descendant(of: list, matching: find.textContaining('+34600333444')),
        findsOneWidget);
    expect(find.text('2 WITH THIS NAME'), findsNWidgets(2));

    // New → form with the duplicate banner + Attach buttons.
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already named "John Smith"'), findsOneWidget);
    expect(find.text('Attach'), findsNWidgets(2));

    // Creating without a phone is blocked.
    final createBtn = tester.widget<ElevatedButton>(find.ancestor(
      of: find.text('Create customer'),
      matching: find.byType(ElevatedButton),
    ));
    expect(createBtn.onPressed, isNull);

    // Attach the first duplicate instead — closes both dialogs.
    await tester.tap(find.text('Attach').first);
    await tester.pumpAndSettle();
    await flushToast(tester);

    expect(demo.customersNamed('John Smith'), hasLength(2));
    expect(demo.cartMeta['customer'], 'John Smith');
    expect(demo.cartMeta['customerId'], '1');
    expect(find.text('Search by name or phone…'), findsNothing);
  });

  testWidgets('creating a same-name record with a phone stores and links it',
      (tester) async {
    addCustomers();
    await pumpPos(tester);

    await openWindow(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or phone…').first,
        'John Smith');
    await tester.pumpAndSettle();
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'PHONE (required)').first,
        '+34600999888');
    await tester.pump();
    await tester.tap(find.text('Create customer'));
    await tester.pumpAndSettle();
    await flushToast(tester);

    final matches = demo.customersNamed('John Smith');
    expect(matches, hasLength(3));
    expect(matches.last.phone, '+34600999888');
    expect(demo.cartMeta['customerId'], matches.last.id.toString());
  });

  testWidgets('phone search disambiguates same-name customers',
      (tester) async {
    addCustomers();
    await pumpPos(tester);

    await openWindow(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Search by name or phone…').first,
        '+34600333444');
    await tester.pumpAndSettle();

    // Only the matching John Smith remains visible (search within the
    // list — the search field itself holds the typed phone).
    final list = find.byType(ListView);
    expect(
        find.descendant(of: list, matching: find.textContaining('+34600111222')),
        findsNothing);
    expect(
        find.descendant(of: list, matching: find.textContaining('+34600333444')),
        findsOneWidget);
  });

  testWidgets('a linked customer can be removed from the order',
      (tester) async {
    addCustomers();
    await pumpPos(tester);

    await openWindow(tester);
    await tester.tap(find.text('John Smith').last);
    await tester.pumpAndSettle();
    await flushToast(tester);
    expect(demo.cartMeta['customerId'], '2');

    // The ✕ on the linked row (sibling of the name text) unlinks the
    // customer (record untouched).
    final removeBtn = find.byIcon(AppIcons.x);
    expect(removeBtn, findsOneWidget);
    await tester.tap(removeBtn);
    await tester.pumpAndSettle();

    expect(find.text('Add customer…'), findsOneWidget);
    expect(demo.cartMeta['customer'], isNull);
    expect(demo.cartMeta['customerId'], isNull);
    // The customer record still exists.
    expect(demo.customersNamed('John Smith'), hasLength(2));

    // Reopening the window works after removal.
    await openWindow(tester);
    expect(find.text('Search by name or phone…'), findsOneWidget);
  });
}
