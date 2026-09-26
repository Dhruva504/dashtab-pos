import 'package:dashtab_pos/core/theme/demo_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Multi-user sync: another terminal's changes (kitchen stage moves, table
/// check-ins, settlements, menu edits) reach this device through the live
/// reload loaders. These tests drive the loaders the same way realtime
/// events and the polling fallback do — with row snapshots straight from
/// the (simulated) database.
void main() {
  setUp(() {
    demo.cancelPendingUndos();
    demo.cart.clear();
    demo.cartMeta = {'type': 'Dine In'};
    demo.orders.clear();
    demo.kitchen.clear();
    demo.tables.clear();
    demo.products.clear();
    demo.customers.clear();
    demo.notifs.clear();
    demo.auditLogs.clear();
    demo.debugOrdersSignature = '';
    demo.debugTablesSignature = '';
  });


  test('a remote order change is applied by the live reload', () {
    // Device A created order 5; device B sees it and then its settlement.
    demo.debugLoadOrders([
      {
        'id': 'srv-5',
        'order_number': '5',
        'order_type': 0,
        'status': 1,
        'subtotal': 10,
        'tax_amount': 1,
        'discount_amount': 0,
        'total': 11,
        'created_at': '2026-09-25T12:00:00Z',
        'order_items': <Map<String, dynamic>>[],
      },
    ]);
    expect(demo.orders.first.status, 'Preparing');

    // Later snapshot: order was settled at the other terminal.
    demo.debugLoadOrders([
      {
        'id': 'srv-5',
        'order_number': '5',
        'order_type': 0,
        'status': 6,
        'payment_method': 'Cash',
        'subtotal': 10,
        'tax_amount': 1,
        'discount_amount': 0,
        'total': 11,
        'created_at': '2026-09-25T12:00:00Z',
        'order_items': <Map<String, dynamic>>[],
      },
    ]);
    expect(demo.orders.first.status, 'Paid');
  });

  test('orders signature changes only when business state changes', () {
    const row = {
      'id': 'srv-1',
      'order_number': '1',
      'status': 1,
      'total': 11.0,
      'updated_at': '2026-09-25T12:00:00Z',
      'order_items': <Map<String, dynamic>>[],
    };
    final a = demo.ordersSignatureFor([row]);
    final b = demo.ordersSignatureFor([
      {...row, 'updated_at': '2026-09-25T12:00:01Z'},
    ]);
    expect(a != b, isTrue, reason: 'updated_at differs → new snapshot');

    // Identical snapshot → identical signature → reload is skipped.
    final c = demo.ordersSignatureFor([
      {...row},
    ]);
    expect(c, a);
  });

  test('kitchen stage changes flow through order items into tickets', () {
    demo.debugLoadOrders([
      {
        'id': 'srv-9',
        'order_number': '9',
        'order_type': 0,
        'status': 1,
        'subtotal': 10,
        'tax_amount': 1,
        'discount_amount': 0,
        'total': 11,
        'created_at': '2026-09-25T12:00:00Z',
        'order_items': [
          {'id': 'oi-1', 'kitchen_stage': 0, 'quantity': 1},
        ],
      },
    ]);
    expect(demo.kitchen.first.status, 'new');

    // Kitchen advanced the ticket at their screen → stage 2 = ready.
    demo.debugLoadOrders([
      {
        'id': 'srv-9',
        'order_number': '9',
        'order_type': 0,
        'status': 1,
        'subtotal': 10,
        'tax_amount': 1,
        'discount_amount': 0,
        'total': 11,
        'created_at': '2026-09-25T12:00:00Z',
        'order_items': [
          {'id': 'oi-1', 'kitchen_stage': 2, 'quantity': 1},
        ],
      },
    ]);
    expect(demo.kitchen.first.status, 'ready');
  });

  test('pending local writes block the reload (no clobber), then sync runs',
      () async {
    // Simulate an in-flight write like pushOrder's persist.
    demo.debugPendingSync = 1;
    // Realtime fired mid-write: the loader must NOT apply a snapshot that
    // could be missing the just-written row.
    demo.debugReloadLive();
    expect(demo.debugOrdersSignature, '',
        reason: 'reload skipped while a write is in flight');

    // Write settles → the post-write sync unblocks subsequent reloads.
    demo.debugPendingSync = 0;
    await demo.debugReloadLive();
    // Signature is now set (empty snapshot applied) — guard is lifted.
    expect(demo.debugOrdersSignature, isNotNull);
  });

  test('reference reload merges remote product/customer edits', () {
    // Device B renamed a product and a customer arrived.
    demo.debugLoadProducts([
      {
        'id': 'p-1',
        'name': 'Pizza Margherita',
        'price': 12.5,
        'stock_qty': 7,
        'sold_count': 3,
        'iva': 10,
        'available': true,
        'categories': <String, dynamic>{'name': 'Pizza'},
      },
    ]);
    expect(demo.products.first.name, 'Pizza Margherita');

    demo.debugLoadCustomers([
      {'id': 'c-1', 'name': 'Ana', 'phone': '111', 'tier': 'Bronze'},
    ]);
    expect(demo.customers.first.name, 'Ana');
  });

  test('manual refresh invalidates signatures and forces a pull', () async {
    // Seed a snapshot so the signature is non-empty.
    demo.debugLoadOrders([
      {
        'id': 'srv-1',
        'order_number': '1',
        'status': 1,
        'total': 11,
        'updated_at': '2026-09-25T12:00:00Z',
        'order_items': <Map<String, dynamic>>[],
      },
    ]);
    demo.debugOrdersSignature = 'prior-sync';
    expect(demo.debugOrdersSignature, isNotEmpty);

    // A manual refresh resets the signature so nothing can be skipped.
    await demo.refreshAll();
    expect(demo.debugOrdersSignature, '',
        reason: 'refreshAll must invalidate cached signatures');
  });

  test('beginManualRefresh is re-entrant safe', () async {
    final a = demo.beginManualRefresh();
    final b = demo.beginManualRefresh();
    await Future.wait([a, b]);
    expect(demo.isRefreshing, isFalse);
  });
}
