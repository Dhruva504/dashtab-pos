import 'package:dashtab_pos/core/theme/demo_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Store-level regression tests for the order processing flow: order-number
/// stability across hold → resume → pay, cart clearing after payment, and
/// kitchen-ticket dedupe.
void main() {
  setUp(() {
    demo.cancelPendingUndos();
    demo.cart.clear();
    demo.cartMeta = {'type': 'Dine In'};
    demo.orders.clear();
    demo.kitchen.clear();
    demo.orderSeq = 101;
    demo.invoiceSeq = 0;
    demo.customers.clear();
  });

  DemoOrder makeOrder(
    int id, {
    String status = 'Pending',
    String? table,
    String customer = 'Walk-in',
    List<CartLine>? items,
  }) =>
      DemoOrder(
        id: id,
        type: 'Dine In',
        table: table,
        customer: customer,
        status: status,
        items: items ?? [CartLine(1, 1)],
        time: '12:00',
        date: '2026-09-25',
        sub: 10,
        tax: 1,
        total: 11,
      );

  test('cart badge mirrors the next order number and sticks on resume', () {
    // Fresh cart: the badge shows the number the NEXT order will get.
    expect(demo.orderSeq, 101);
    expect(demo.cartNo, 101);

    // Hold order 101 — the sequence advances so the badge shows 102.
    final held = makeOrder(101);
    demo.pushOrder(held);
    expect(demo.orderSeq, 102);
    expect(demo.cartNo, 102);

    // Resuming the held order pins the badge to ITS number.
    demo.cartMeta['resumedOrderId'] = 101;
    expect(demo.cartNo, 101);

    // Dropping the marker (cart cleared) returns to the next number.
    demo.clearActiveCart();
    expect(demo.cartNo, 102);
  });

  test('pushOrder never lets a foreign order mint a duplicate id', () {
    demo.pushOrder(makeOrder(500));
    expect(demo.orderSeq, 501);
    expect(demo.cartNo, 501);
  });

  test('resumeOrder refuses paid/cancelled orders, allows held ones', () {
    final paid = makeOrder(1, status: 'Paid');
    expect(demo.resumeOrder(paid), isNull);

    final cancelled = makeOrder(2, status: 'Cancelled');
    expect(demo.resumeOrder(cancelled), isNull);

    final held = makeOrder(3, status: 'Pending');
    expect(demo.resumeOrder(held), same(held));
  });

  test('paying the resumed order clears the cart for the next order', () {
    demo.cart
      ..add(CartLine(1, 1))
      ..add(CartLine(2, 2));
    demo.cartMeta = {
      'type': 'Dine In',
      'table': 'T1',
      'resumedOrderId': 7,
      'discount': 'SAVE10',
    };
    final o = makeOrder(7, status: 'Pending');
    demo.orders.add(o);

    demo.settleOrder(o);

    expect(o.status, 'Paid');
    expect(demo.cart, isEmpty);
    expect(demo.cartMeta['resumedOrderId'], isNull);
    expect(demo.cartMeta['discount'], isNull);
    expect(demo.cartMeta['type'], 'Dine In');
    // The badge shows the NEXT number right away — no confusion with the
    // order that was just paid.
    expect(demo.cartNo, demo.orderSeq);
  });

  test('settling a foreign order leaves the active cart alone', () {
    demo.cart.add(CartLine(1, 2));
    demo.cartMeta = {'type': 'Dine In'};
    final o = makeOrder(9, status: 'Pending');
    demo.orders.add(o);

    demo.settleOrder(o);

    expect(o.status, 'Paid');
    expect(demo.cart, isNotEmpty);
  });

  test('sending a resumed order to the kitchen keeps a single ticket', () {
    final o = makeOrder(11, status: 'Preparing');
    demo.orders.add(o);
    demo.kitchen
        .add(KitchenTicket(orderId: 11, status: 'new', sinceMs: 0));

    demo.updateCommittedOrder(
      o,
      items: [CartLine(1, 2)],
      sub: 10,
      disc: 0,
      tax: 1,
      total: 11,
      status: 'Preparing',
      sendKitchen: true,
    );

    expect(demo.kitchen.where((k) => k.orderId == 11).length, 1);
  });

  test('settleOrder is idempotent — no double payment on repeated calls', () {
    final o = makeOrder(21, status: 'Pending');
    demo.orders.add(o);
    demo.settleOrder(o);
    expect(o.status, 'Paid');
    // A second settle (double-tap, retry, race) must not go through.
    demo.settleOrder(o);
    expect(o.status, 'Paid');
    expect(demo.lastAuditBytes, isNull,
        reason: 'no side effects can run on a re-settle');
  });

  test('paid orders can no longer be cancelled', () {
    final o = makeOrder(22, status: 'Paid');
    demo.orders.add(o);
    demo.cancelOrders([o]);
    expect(o.status, 'Paid', reason: 'settled money cannot be cancelled');
  });

  test('cancelling removes the kitchen ticket and drops the cart marker', () {
    final o = makeOrder(23, status: 'Preparing');
    demo.orders.add(o);
    demo.kitchen.add(KitchenTicket(orderId: 23, status: 'new', sinceMs: 0));
    demo.cartMeta['resumedOrderId'] = 23;

    demo.cancelOrders([o]);

    expect(o.status, 'Cancelled');
    expect(demo.kitchen.where((k) => k.orderId == 23), isEmpty);
    expect(demo.cartMeta['resumedOrderId'], isNull);
  });

  test('editing a resumed order reconciles stock exactly once', () {
    final p = DemoProduct(
      id: 5,
      name: 'Pizza',
      cat: 'Food',
      price: 10,
      iva: 10,
      stock: 20,
      dbId: 'p5',
    );
    demo.products.add(p);
    final o = makeOrder(24, items: [CartLine(5, 2)]);
    demo.orders.add(o);
    // Simulate the base deduction + sold increment from the initial persist.
    p.stock -= 2;
    p.sold += 2;
    demo.debugMarkStockApplied(24);

    // Kitchen had it, resume edits it down to 1 and back up to 3.
    demo.updateCommittedOrder(
      o,
      items: [CartLine(5, 1)],
      sub: 10,
      disc: 0,
      tax: 1,
      total: 11,
    );
    expect(p.stock, 19, reason: '+1 restored after base deduction (20-2+1)');
    demo.updateCommittedOrder(
      o,
      items: [CartLine(5, 3)],
      sub: 30,
      disc: 0,
      tax: 1,
      total: 33,
    );
    expect(p.stock, 17, reason: '-2 deducted (20-2+1-2)');
    expect(p.sold, 3);
  });

  test('resuming a different order while one is active is refused', () {
    demo.cart.add(CartLine(1, 1));
    demo.cartMeta['resumedOrderId'] = 30;
    final held = makeOrder(31, status: 'Pending');
    demo.orders.add(held);

    expect(demo.resumeOrder(held), isNull);

    // Re-resuming the SAME order stays allowed (cart load replaces).
    final active = makeOrder(30, status: 'Pending');
    demo.orders.add(active);
    expect(demo.resumeOrder(active), same(active));
  });

  test('clearActiveCart resets items and metadata together', () {
    demo.cart.add(CartLine(3, 1));
    demo.cartMeta = {
      'type': 'Delivery',
      'table': 'T9',
      'resumedOrderId': 5,
      'discount': 'D',
      'customer': 'Reda',
    };

    demo.clearActiveCart();

    expect(demo.cart, isEmpty);
    expect(demo.cartMeta['resumedOrderId'], isNull);
    expect(demo.cartMeta['table'], isNull);
    expect(demo.cartMeta['discount'], isNull);
    expect(demo.cartMeta['type'], 'Dine In');
  });

  test('no customer is auto-created when orders commit', () {
    // Simulates kitchen-send/hold/pay of an order with a typed, unlinked
    // name — the old flow silently created a customer record.
    final before = demo.customers.length;
    demo.updateCommittedOrder(
      makeOrder(41, status: 'Pending'),
      items: [CartLine(1, 1)],
      sub: 10,
      disc: 0,
      tax: 1,
      total: 11,
    );
    demo.settleOrder(makeOrder(42, status: 'Pending'));
    expect(demo.customers.length, before);
    expect(demo.customersNamed('John Doe'), isEmpty);
  });

  test('addCustomer returns the record and registers duplicates fine', () {
    final a = demo.addCustomer(name: 'Youssef', phone: '+34600111222');
    final b = demo.addCustomer(name: 'Youssef', phone: '+34600333444');
    expect(identical(a, b), isFalse);
    expect(demo.customersNamed('youssef').length, 2);
    expect(a.phone, '+34600111222');
    expect(b.phone, '+34600333444');
  });

  test('creditCustomer credits the exact linked record (dbId match)', () {
    final c = demo.addCustomer(name: 'Ana', phone: '+34600555666');
    c.dbId = 'db-ana-1'; // as assigned by the DB in connected mode
    demo.creditCustomer('db-ana-1', 50);
    expect(c.total, 50);
    expect(c.visits, 1);
    // Local-id references work too (demo mode).
    demo.creditCustomer(c.id.toString(), 10);
    expect(c.total, 60);
  });

  test('creditCustomer never invents customers from a typed name', () {
    final before = demo.customers.length;
    demo.creditCustomer('Some Random Stranger', 50);
    expect(demo.customers.length, before,
        reason: 'no implicit creation on pay');
  });

  test('creditCustomer never matches by name (duplicate-name safety)', () {
    final a = demo.addCustomer(name: 'Sam', phone: '111');
    final b = demo.addCustomer(name: 'Sam', phone: '222');
    // A raw name must not credit whichever record comes first.
    demo.creditCustomer('Sam', 50);
    expect(a.total, 0);
    expect(b.total, 0);
    // Ids still work.
    demo.creditCustomer(a.id.toString(), 30);
    expect(a.total, 30);
    expect(b.total, 0);
  });

  test('orders carry the customer id and history follows the id, not the name', () {
    final a = demo.addCustomer(name: 'Chris', phone: '111');
    final b = demo.addCustomer(name: 'Chris', phone: '222');
    a.dbId = 'db-chris-a';
    b.dbId = 'db-chris-b';

    final o1 = makeOrder(61, customer: 'Chris');
    o1.customerId = a.dbId;
    final o2 = makeOrder(62, customer: 'Chris');
    o2.customerId = b.dbId;
    demo.orders.addAll([o1, o2]);

    expect(demo.ordersForCustomer(a), [o1]);
    expect(demo.ordersForCustomer(b), [o2]);
  });

  test('renaming a customer keeps id-attributed history, drops name matches', () {
    final a = demo.addCustomer(name: 'Old Name', phone: '111');
    a.dbId = 'db-old';
    final o = makeOrder(63, customer: 'Old Name');
    o.customerId = a.dbId;
    demo.orders.add(o);

    a.name = 'New Name';
    demo.updateCustomer(a);

    expect(demo.ordersForCustomer(a), [o],
        reason: 'id attribution survives renames');
  });

  test('deleting a customer unlinks the cart and detaches order ids', () {
    final a = demo.addCustomer(name: 'Gone', phone: '111');
    a.dbId = 'db-gone';
    demo.cartMeta['customer'] = 'Gone';
    demo.cartMeta['customerId'] = a.dbId;
    final o = makeOrder(64, customer: 'Gone');
    o.customerId = a.dbId;
    demo.orders.add(o);

    demo.deleteCustomer(a);
    demo.deleteCustomerDb(a);

    expect(demo.cartMeta['customerId'], isNull);
    expect(o.customerId, isNull,
        reason: 'orders keep only the name snapshot after delete');
  });

  test('updateCommittedOrder can clear attribution with an empty id', () {
    final o = makeOrder(65, customer: 'Chris');
    o.customerId = 'db-chris';
    demo.orders.add(o);

    demo.updateCommittedOrder(
      o,
      items: [CartLine(1, 1)],
      sub: 10,
      disc: 0,
      tax: 1,
      total: 11,
      customer: 'Walk-in',
      customerId: '',
    );
    expect(o.customerId, isNull);
    expect(o.customer, 'Walk-in');
  });
}
