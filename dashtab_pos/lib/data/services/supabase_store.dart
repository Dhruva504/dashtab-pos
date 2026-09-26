import 'package:supabase_flutter/supabase_flutter.dart';

/// Typed persistence layer for the DashTab POS app.
///
/// Every method maps directly to a table in the Supabase schema
/// (see supabase/migrations). All queries are scoped by RLS to the
/// authenticated tenant via the JWT `tenant_id` claim.
class SupabaseStore {
  final SupabaseClient _client;

  SupabaseStore(this._client);

  SupabaseClient get client => _client;

  /// The tenant id from the JWT app_metadata (set by `bootstrap_tenant`).
  String? get tenantId =>
      _client.auth.currentUser?.appMetadata['tenant_id'] as String?;

  bool get isOnline => _client.auth.currentSession != null;

  /// The active branch id (uuid). Loads for branch-scoped entities filter by
  /// it; NULL (legacy/shared) rows are always included. Set by the app store
  /// when the user switches branches; null = no filtering (single branch).
  String? activeBranchId;

  // ------------------------------------------------------------------
  // Loaders
  // ------------------------------------------------------------------

  /// PostgREST or-filter for branch scoping: rows of the active branch OR
  /// rows with no branch (shared/legacy). Returns null when no branch is
  /// active (single-branch workspace) — no filter is applied at all.
  String? get _branchOr => activeBranchId == null
      ? null
      : 'or(branch_id.eq.$activeBranchId,branch_id.is.null)';

  /// Loads products together with their category name and tax rate.
  /// Falls back to a plain select when the embedded join fails (e.g. a
  /// missing lookup table) so the menu still renders instead of vanishing.
  Future<List<Map<String, dynamic>>> loadProducts() async {
    try {
      final data = await _client
          .from('products')
          .select('*, categories(name), tax_rates(rate)')
          .order('sort_order', ascending: true);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      final data = await _client
          .from('products')
          .select('*')
          .order('sort_order', ascending: true);
      return (data as List).cast<Map<String, dynamic>>();
    }
  }

  Future<List<Map<String, dynamic>>> loadTaxRates() async {
    final data = await _client
        .from('tax_rates')
        .select('*')
        .eq('is_active', true)
        .order('is_default', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadCategories() async {
    final data = await _client
        .from('categories')
        .select('*')
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadTables() async {
    var q = _client.from('tables').select('*, floors(name)');
    final scope = _branchOr;
    if (scope != null) q = q.or(scope);
    final data = await q.order('name', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadCustomers() async {
    final data = await _client
        .from('customers')
        .select('*')
        .order('name', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Loads orders with nested items plus table / customer / waiter names.
  /// Falls back to a simpler embed when a join is unavailable so the orders
  /// list never comes back empty because of one missing relationship.
  Future<List<Map<String, dynamic>>> loadOrders({int limit = 200}) async {
    try {
      var q = _client
          .from('orders')
          .select(
              '*, order_items(*), users(full_name), tables(name), customers(name)');
      final scope = _branchOr;
      if (scope != null) q = q.or(scope);
      final data = await q.order('created_at', ascending: false).limit(limit);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      var q = _client.from('orders').select('*, order_items(*)');
      final scope = _branchOr;
      if (scope != null) q = q.or(scope);
      final data = await q.order('created_at', ascending: false).limit(limit);
      return (data as List).cast<Map<String, dynamic>>();
    }
  }

  Future<List<Map<String, dynamic>>> loadStaff() async {
    final data = await _client
        .from('users')
        .select('*')
        .order('full_name', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadSuppliers() async {
    final data = await _client
        .from('suppliers')
        .select('*')
        .order('name', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadInventory() async {
    var q = _client.from('inventory').select('*');
    final scope = _branchOr;
    if (scope != null) q = q.or(scope);
    final data = await q.order('name', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadGiftCards() async {
    final data = await _client
        .from('gift_cards')
        .select('*')
        .order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadAuditLogs({int limit = 500}) async {
    // Prefer the embedded join (gives user name/role); fall back to a plain
    // select so the audit screen still renders if the join fails (e.g. RLS
    // on `users` blocking the embedded resource).
    try {
      final data = await _client
          .from('audit_logs')
          .select('*, users(full_name, role)')
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      final data = await _client
          .from('audit_logs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).cast<Map<String, dynamic>>();
    }
  }

  Future<List<Map<String, dynamic>>> loadNotifications({int limit = 50}) async {
    final data = await _client
        .from('notifications')
        .select('*')
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadBranches() async {
    final data = await _client
        .from('branches')
        .select('*')
        .order('name', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> loadTenant() async {
    final data = await _client.from('tenants').select('*').maybeSingle();
    return data;
  }

  Future<List<Map<String, dynamic>>> loadSettings() async {
    final data = await _client.from('settings').select('*');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadPurchaseOrders() async {
    final data = await _client
        .from('purchase_orders')
        .select('*')
        .order('created_at', ascending: false)
        .limit(100);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadOpenShifts() async {
    final data = await _client
        .from('shifts')
        .select('*')
        .eq('status', 0)
        .order('opened_at', ascending: false)
        .limit(5);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadShiftHistory({int limit = 50}) async {
    final data = await _client
        .from('shifts')
        .select('*')
        .eq('status', 1)
        .order('closed_at', ascending: false)
        .limit(limit);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadCashMovements(String shiftId) async {
    final data = await _client
        .from('cash_drawer_transactions')
        .select('*')
        .eq('shift_id', shiftId)
        .order('created_at', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadPaymentMethods() async {
    final data = await _client
        .from('payment_methods')
        .select('*')
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadDiscounts() async {
    final data = await _client
        .from('discounts')
        .select('*')
        .eq('is_active', true)
        .order('name', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createDiscount(Map<String, dynamic> d) async {
    final data = await _client
        .from('discounts')
        .insert(d)
        .select()
        .single();
    return data;
  }

  Future<void> updateDiscount(String id, Map<String, dynamic> updates) async {
    await _client.from('discounts').update(updates).eq('id', id);
  }

  Future<void> deleteDiscount(String id) async {
    await _client.from('discounts').delete().eq('id', id);
  }

  /// Reads a per-tenant counter without incrementing it (used to resume
  /// invoice/order numbering after a restart).
  Future<int> loadCounter(String name) async {
    final data = await _client
        .from('counters')
        .select('value')
        .eq('name', name)
        .maybeSingle();
    return (data?['value'] as num?)?.toInt() ?? 0;
  }

  /// Atomically increments and returns a per-tenant counter.
  Future<int> nextCounter(String name) async {
    final data = await _client.rpc('next_counter', params: {'p_name': name});
    return (data as num).toInt();
  }

  // ------------------------------------------------------------------
  // Orders / items / kitchen
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> order) async {
    final data = await _client
        .from('orders')
        .insert({
          ...order,
          if (order['branch_id'] == null && activeBranchId != null)
            'branch_id': activeBranchId,
        })
        .select()
        .single();
    return data;
  }

  Future<void> updateOrder(String id, Map<String, dynamic> updates) async {
    await _client.from('orders').update(updates).eq('id', id);
  }

  /// Deletes all line items of an order (used when replacing them on resume).
  Future<void> deleteOrderItems(String orderId) async {
    await _client.from('order_items').delete().eq('order_id', orderId);
  }

  Future<void> createOrderItems(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    await _client.from('order_items').insert(items);
  }

  Future<void> updateOrderItem(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('order_items').update(updates).eq('id', id);
  }

  // ------------------------------------------------------------------
  // Payments
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>> createPayment(Map<String, dynamic> payment) async {
    final data = await _client
        .from('payments')
        .insert(payment)
        .select()
        .single();
    return data;
  }

  // ------------------------------------------------------------------
  // Products / categories
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> p) async {
    final data = await _client
        .from('products')
        .insert(p)
        .select()
        .single();
    return data;
  }

  Future<void> updateProduct(String id, Map<String, dynamic> updates) async {
    await _client.from('products').update(updates).eq('id', id);
  }

  Future<void> deleteProduct(String id) async {
    await _client.from('products').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> c) async {
    final data = await _client
        .from('categories')
        .insert(c)
        .select()
        .single();
    return data;
  }

  // ------------------------------------------------------------------
  // Customers
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> c) async {
    final data = await _client
        .from('customers')
        .insert(c)
        .select()
        .single();
    return data;
  }

  Future<void> updateCustomer(String id, Map<String, dynamic> updates) async {
    await _client.from('customers').update(updates).eq('id', id);
  }

  Future<void> deleteCustomer(String id) async {
    await _client.from('customers').delete().eq('id', id);
  }

  // ------------------------------------------------------------------
  // Staff (users table)
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>> createStaff(Map<String, dynamic> u) async {
    final data = await _client.from('users').insert(u).select().single();
    return data;
  }

  Future<void> updateStaff(String id, Map<String, dynamic> updates) async {
    await _client.from('users').update(updates).eq('id', id);
  }

  Future<void> deleteStaff(String id) async {
    await _client.from('users').delete().eq('id', id);
  }

  // ------------------------------------------------------------------
  // Suppliers / inventory / gift cards / purchase orders
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>> createSupplier(Map<String, dynamic> s) async {
    final data = await _client.from('suppliers').insert(s).select().single();
    return data;
  }

  Future<void> updateSupplier(String id, Map<String, dynamic> updates) async {
    await _client.from('suppliers').update(updates).eq('id', id);
  }

  Future<void> deleteSupplier(String id) async {
    await _client.from('suppliers').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> createInventoryItem(Map<String, dynamic> i) async {
    final data = await _client.from('inventory').insert({
      ...i,
      if (i['branch_id'] == null && activeBranchId != null)
        'branch_id': activeBranchId,
    }).select().single();
    return data;
  }

  Future<void> updateInventoryItem(String id, Map<String, dynamic> updates) async {
    await _client.from('inventory').update(updates).eq('id', id);
  }

  Future<void> deleteInventoryItem(String id) async {
    await _client.from('inventory').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> createGiftCard(Map<String, dynamic> g) async {
    final data = await _client.from('gift_cards').insert(g).select().single();
    return data;
  }

  Future<void> updateGiftCard(String id, Map<String, dynamic> updates) async {
    await _client.from('gift_cards').update(updates).eq('id', id);
  }

  Future<void> deleteGiftCard(String id) async {
    await _client.from('gift_cards').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> createPurchaseOrder(Map<String, dynamic> po) async {
    final data = await _client.from('purchase_orders').insert(po).select().single();
    return data;
  }

  Future<void> updatePurchaseOrder(String id, Map<String, dynamic> updates) async {
    await _client.from('purchase_orders').update(updates).eq('id', id);
  }

  Future<void> deletePurchaseOrder(String id) async {
    await _client.from('purchase_orders').delete().eq('id', id);
  }

  // ------------------------------------------------------------------
  // Audit / notifications / settings / tenant
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>> createAuditLog(Map<String, dynamic> a) async {
    // audit_logs has no auto tenant_id trigger (unlike most tables), so the
    // column must be provided explicitly to satisfy the RLS insert check.
    final payload = {
      ...a,
      if (a['tenant_id'] == null && tenantId != null) 'tenant_id': tenantId,
    };
    final data = await _client.from('audit_logs').insert(payload).select().single();
    return data;
  }

  Future<Map<String, dynamic>> createNotification(Map<String, dynamic> n) async {
    final data = await _client.from('notifications').insert(n).select().single();
    return data;
  }

  Future<void> markNotificationsRead() async {
    await _client
        .from('notifications')
        .update({'unread': false})
        .eq('unread', true);
  }

  Future<void> deleteNotification(String id) async {
    await _client.from('notifications').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> updateTenant(Map<String, dynamic> updates) async {
    final data = await _client
        .from('tenants')
        .update(updates)
        .select()
        .single();
    return data;
  }

  Future<Map<String, dynamic>> upsertSetting(String key, String value) async {
    final data = await _client
        .from('settings')
        .upsert({'key': key, 'value': value}, onConflict: 'tenant_id,key')
        .select()
        .single();
    return data;
  }

  // ------------------------------------------------------------------
  // Shifts / cash drawer
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>> openShift(Map<String, dynamic> s) async {
    final data = await _client.from('shifts').insert(s).select().single();
    return data;
  }

  Future<void> closeShift(String id, Map<String, dynamic> updates) async {
    await _client.from('shifts').update(updates).eq('id', id);
  }

  Future<Map<String, dynamic>> createCashMovement(Map<String, dynamic> m) async {
    final data = await _client
        .from('cash_drawer_transactions')
        .insert(m)
        .select()
        .single();
    return data;
  }

  // ------------------------------------------------------------------
  // Tables
  // ------------------------------------------------------------------

  Future<void> updateTable(String id, Map<String, dynamic> updates) async {
    await _client.from('tables').update(updates).eq('id', id);
  }

  Future<Map<String, dynamic>> createTable(Map<String, dynamic> t) async {
    final data = await _client.from('tables').insert({
      ...t,
      if (t['branch_id'] == null && activeBranchId != null)
        'branch_id': activeBranchId,
    }).select().single();
    return data;
  }

  Future<void> deleteTable(String id) async {
    await _client.from('tables').delete().eq('id', id);
  }

  // ------------------------------------------------------------------
  // Floors
  // ------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> loadFloors() async {
    var q = _client.from('floors').select('*').eq('is_active', true);
    final scope = _branchOr;
    if (scope != null) q = q.or(scope);
    final data = await q.order('created_at', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Returns the first floor id for the tenant (used when creating tables).
  Future<String?> loadFirstFloorId() async {
    final data = await _client
        .from('floors')
        .select('id')
        .order('created_at', ascending: true)
        .limit(1);
    final rows = (data as List).cast<Map<String, dynamic>>();
    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  Future<Map<String, dynamic>> createFloor(Map<String, dynamic> f) async {
    final data = await _client.from('floors').insert({
      ...f,
      if (f['branch_id'] == null && activeBranchId != null)
        'branch_id': activeBranchId,
    }).select().single();
    return data;
  }

  Future<void> updateFloor(String id, Map<String, dynamic> updates) async {
    await _client.from('floors').update(updates).eq('id', id);
  }

  Future<void> deleteFloor(String id) async {
    await _client.from('floors').delete().eq('id', id);
  }

  // ------------------------------------------------------------------
  // Branches
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>> createBranch(Map<String, dynamic> b) async {
    final data = await _client.from('branches').insert(b).select().single();
    return data;
  }

  Future<void> updateBranch(String id, Map<String, dynamic> updates) async {
    await _client.from('branches').update(updates).eq('id', id);
  }

  Future<void> deleteBranch(String id) async {
    await _client.from('branches').delete().eq('id', id);
  }

  // ------------------------------------------------------------------
  // Tax rates
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>> createTaxRate(Map<String, dynamic> t) async {
    final data = await _client.from('tax_rates').insert(t).select().single();
    return data;
  }

  Future<void> updateTaxRate(String id, Map<String, dynamic> updates) async {
    await _client.from('tax_rates').update(updates).eq('id', id);
  }

  Future<void> deleteTaxRate(String id) async {
    await _client.from('tax_rates').delete().eq('id', id);
  }

  // ------------------------------------------------------------------
  // Realtime
  // ------------------------------------------------------------------

  /// Subscribes to row changes for a table (RLS-filtered by Supabase).
  ///
  /// The returned stream emits the FULL row list of the table on every
  /// change — reload-with-signature on the store side decides whether the
  /// snapshot actually differs before rebuilding the UI.
  Stream<List<Map<String, dynamic>>> watch(
    String table, {
    List<String> primaryKeys = const ['id'],
  }) {
    return _client
        .from(table)
        .stream(primaryKey: primaryKeys)
        .map((data) => (data as List).cast<Map<String, dynamic>>());
  }
}
