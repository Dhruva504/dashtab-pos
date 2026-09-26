import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/supabase_store.dart';

/// IVA (Spanish VAT) rate definitions.
class IvaRate {
  final int rate;
  final String label;
  final double pct;

  const IvaRate(this.rate, this.label) : pct = rate / 100;

  static const general = IvaRate(21, 'General');
  static const reduced = IvaRate(10, 'Reducido');
  static const superReduced = IvaRate(4, 'Super-reducido');
  static const all = [general, reduced, superReduced];

  static IvaRate of(int rate) =>
      all.firstWhere((r) => r.rate == rate, orElse: () => reduced);
}

/// Restaurant metadata. Everything is read from the workspace settings
/// (tenant table + settings key/values) so receipts and invoices print the
/// owner's real details. Fields the owner has not filled in yet are empty
/// and callers hide them.
class RestaurantInfo {
  static String get name => demo.settings['name'] ?? 'My Restaurant';
  static String get legal => demo.settings['legal_name'] ?? '';
  static String get cif => demo.settings['cif'] ?? '';
  static String get address => demo.settings['address'] ?? '';
  static String get phone => demo.settings['phone'] ?? '';
  static String get email => demo.settings['email'] ?? '';

  /// Products at or below this quantity count as "low stock". Configurable
  /// in Settings → Store; default 5.
  static int get lowStockThreshold {
    final v = int.tryParse(demo.settings['low_stock_threshold'] ?? '');
    return (v == null || v < 0) ? 5 : v;
  }

  /// Inventory items expiring within this many days are flagged "near
  /// expiry". Configurable in Settings → Store; default 7.
  static int get expiryWarnDays {
    final v = int.tryParse(demo.settings['expiry_warn_days'] ?? '');
    return (v == null || v < 0) ? 7 : v;
  }

  /// The branch currently selected in the top bar.
  static Branch? get branch =>
      demo.branches.where((b) => b.name == demo.currentBranch).firstOrNull;

  /// Branch printed on receipts and invoices, so a sale can be traced to the
  /// location that made it. Uses the same name shown in the top-bar selector.
  static String get branchLabel {
    final b = branch;
    if (b == null) return demo.currentBranch;
    return b.city.isEmpty ? b.name : '${b.name} · ${b.city}';
  }
}

/// Product (mirrors the design `S.products`).
class DemoProduct {
  final int id;
  String name;
  String cat;
  double price;
  double cost;
  int iva;
  int stock;
  String img;
  int sold;
  bool avail;
  String? dbId;

  DemoProduct({
    required this.id,
    required this.name,
    required this.cat,
    required this.price,
    this.cost = 0,
    required this.iva,
    required this.stock,
    this.img = '',
    this.sold = 0,
    this.avail = true,
    this.dbId,
  });

  /// Margin per unit based on the recorded supplier cost.
  double get margin => price - cost;
}

/// Zone (floor plan area, DB `floors` table) that groups tables.
/// The legacy `tables.zone` string column is kept in sync with the zone
/// name so the DB stays consistent, but the app groups tables by floor.
class DemoFloor {
  String name;
  String? dbId;

  DemoFloor({required this.name, this.dbId});
}

/// Table (mirrors the design `S.tables`).
class DemoTable {
  String name;
  int seats;
  String status; // free | occ | res
  String? guest;
  int? persons;
  double? startedAtMs;
  int? orderId;
  String zone; // legacy mirror of the zone (floor) name
  String? floorId; // DB floors.id this table belongs to
  String? dbId;

  /// Floor-plan geometry, in canvas design units (the plan is 1000 × 640 and
  /// is scaled to fit). Mirrors the DB `x / y / width / height` columns.
  double x;
  double y;
  double width;
  double height;
  int shape; // 0 = rectangle, 1 = round table

  /// True once the table has a real spot on the plan (saved layout or the
  /// editor) — unplaced tables are auto-arranged on a tidy grid instead.
  bool placed;

  DemoTable({
    required this.name,
    required this.seats,
    required this.status,
    this.guest,
    this.persons,
    this.startedAtMs,
    this.orderId,
    required this.zone,
    this.floorId,
    this.dbId,
    this.x = 0,
    this.y = 0,
    this.width = 150,
    this.height = 130,
    this.shape = 0,
    this.placed = false,
  });
}

/// Cart line.
class CartLine {
  final int productId;
  int qty;
  String? note;
  int? discPct;

  CartLine(this.productId, this.qty, {this.note, this.discPct});
}

/// Order (mirrors the design `S.orders`).
class DemoOrder {
  int id;
  String type;
  String? table;

  /// Customer dbId the order is attributed to (null for walk-in or a typed
  /// name with no unique record). The [customer] field is the name snapshot
  /// shown on receipts; the id is the source of truth for loyalty/history.
  String? customerId;
  String customer;
  String status; // Pending | Preparing | Ready | Paid | Cancelled | Refunded
  List<CartLine> items;
  String? method;
  String time;
  String date;
  double sub;
  double disc;
  double tax;
  double total;
  String? invoice;
  double tip;
  int tipPct;
  String? facturaType;
  String? customerNIF;
  String? waiter;
  String? dbId;
  DateTime? createdAt;

  DemoOrder({
    required this.id,
    required this.type,
    this.table,
    this.customerId,
    required this.customer,
    required this.status,
    required this.items,
    this.method,
    required this.time,
    required this.date,
    required this.sub,
    this.disc = 0,
    required this.tax,
    required this.total,
    this.invoice,
    this.tip = 0,
    this.tipPct = 0,
    this.facturaType,
    this.customerNIF,
    this.waiter,
    this.dbId,
    this.createdAt,
  });
}

/// Kitchen ticket (derived from order_items with status = sent-to-kitchen).
class KitchenTicket {
  final int orderId;
  String status; // new | preparing | ready
  double sinceMs;
  String notes;
  String? itemId;
  String? orderDbId;

  KitchenTicket({
    required this.orderId,
    required this.status,
    required this.sinceMs,
    this.notes = '',
    this.itemId,
    this.orderDbId,
  });
}

/// Notification.
class AppNotification {
  final String title;
  final String subtitle;
  final String time;
  final String kind; // ok | warn | err
  bool unread;
  String? dbId;

  AppNotification({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.kind,
    this.unread = true,
    this.dbId,
  });
}

/// Branch.
class Branch {
  final int id;
  String name;
  String full;
  String city;
  String cif;
  String manager;
  int terminals;
  String status;
  final String? dbId;

  Branch({
    required this.id,
    required this.name,
    required this.full,
    required this.city,
    required this.cif,
    required this.manager,
    required this.terminals,
    this.status = 'active',
    this.dbId,
  });
}

/// Tax rate (mirrors the DB `tax_rates` table).
class TaxRate {
  final int id;
  String name;
  double rate;
  bool isInclusive;
  bool isDefault;
  final String? dbId;

  TaxRate({
    required this.id,
    required this.name,
    required this.rate,
    this.isInclusive = true,
    this.isDefault = false,
    this.dbId,
  });
}

/// Supplier.
class Supplier {
  final int id;
  final String name;
  final String contact;
  final String phone;
  final String email;
  final String cat;
  final String terms;
  final String addr;
  final String? dbId;

  Supplier({
    required this.id,
    required this.name,
    required this.contact,
    required this.phone,
    required this.email,
    required this.cat,
    required this.terms,
    required this.addr,
    this.dbId,
  });
}

/// Inventory item.
class InvItem {
  final int id;
  final String name;
  final String cat;
  final String sku;
  double qty;
  final String unit;
  double cost;
  final double reorder;
  final String supplier;
  final String expiry;
  String? dbId;

  InvItem({
    required this.id,
    required this.name,
    required this.cat,
    required this.sku,
    required this.qty,
    required this.unit,
    required this.cost,
    required this.reorder,
    required this.supplier,
    required this.expiry,
    this.dbId,
  });

  /// Days until expiry (negative when already expired), or null when no
  /// expiry is recorded.
  int? get daysToExpiry {
    if (expiry.isEmpty) return null;
    final d = DateTime.tryParse(expiry);
    if (d == null) return null;
    return d.difference(DateTime.now()).inDays;
  }

  /// True when an expiry is recorded and it falls inside the warning window
  /// configured in Settings (or has already passed).
  bool get isNearExpiry {
    final d = daysToExpiry;
    return d != null && d <= RestaurantInfo.expiryWarnDays;
  }

  bool get isExpired {
    final d = daysToExpiry;
    return d != null && d < 0;
  }
}

/// Customer.
class Customer {
  final int id;
  String name;
  String phone;
  final String? email;
  int visits;
  double total;
  int points;
  String tier;
  String lastVisit;
  final String diet;
  String? dbId;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.visits,
    required this.total,
    required this.points,
    required this.tier,
    this.lastVisit = '—',
    this.diet = 'None',
    this.dbId,
  });
}

/// Gift card.
class GiftCard {
  final int id;
  final String code;
  double amount;
  double balance;
  String recipient;
  final String issued;
  final String expiry;
  String status;
  String? dbId;

  GiftCard({
    required this.id,
    required this.code,
    required this.amount,
    required this.balance,
    this.recipient = '',
    required this.issued,
    required this.expiry,
    required this.status,
    this.dbId,
  });
}

/// Staff member (users table).
class StaffMember {
  final int id;
  String name;
  String role;
  String phone;
  String hired;
  bool active;
  String? dbId;

  /// The linked auth.users id — set when the account was provisioned with
  /// login credentials (create_staff_user). Staff without one cannot log in.
  final String? authId;
  final String? email;

  StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    required this.hired,
    this.active = true,
    this.dbId,
    this.authId,
    this.email,
  });

  bool get canLogIn => authId != null;
}

/// A named staff role with a set of granted permissions. Roles are fully
/// user-defined (created/edited by the owner) and persisted as JSON in the
/// tenant settings table.
class StaffRole {
  final String name;
  final Set<String> permissions;

  const StaffRole({required this.name, this.permissions = const {}});

  bool can(String permission) =>
      permissions.contains(Permissions.all) || permissions.contains(permission);

  Map<String, dynamic> toJson() => {
        'name': name,
        'permissions': permissions.toList(),
      };

  static StaffRole fromJson(Map<String, dynamic> j) => StaffRole(
        name: j['name'] as String,
        permissions:
            ((j['permissions'] as List?) ?? const []).cast<String>().toSet(),
      );
}

/// Permission keys used across the shell/views.
class Permissions {
  static const all = 'all';
  static const pos = 'pos';
  static const orders = 'orders';
  static const tables = 'tables';
  static const kitchen = 'kitchen';
  static const menu = 'menu';
  static const inventory = 'inventory';
  static const suppliers = 'suppliers';
  static const customers = 'customers';
  static const staff = 'staff';
  static const shift = 'shift';
  static const audit = 'audit';
  static const reports = 'reports';
  static const settings = 'settings';
  static const refunds = 'refunds';
  static const discounts = 'discounts';

  /// Human-readable labels for the permission editor.
  static const labels = {
    all: 'Full access (everything)',
    pos: 'New Order (POS terminal)',
    orders: 'Orders',
    tables: 'Tables & floor plan',
    kitchen: 'Kitchen Display',
    menu: 'Menu items & pricing',
    inventory: 'Inventory & purchase orders',
    suppliers: 'Suppliers',
    customers: 'Customers, loyalty & gift cards',
    staff: 'Staff management',
    shift: 'Shift & cash drawer',
    audit: 'Audit logs',
    reports: 'Reports & analytics',
    settings: 'Workspace settings',
    refunds: 'Issue refunds',
    discounts: 'Apply discounts / promo codes',
  };
}

/// Audit log entry.
class AuditEntry {
  final int id;
  final String action;
  final String type; // create | update | delete | pay | refund | auth
  final String user;
  final String role;
  final String detail;
  final String time;
  final DateTime? createdAt;

  AuditEntry({
    required this.id,
    required this.action,
    required this.type,
    required this.user,
    required this.role,
    required this.detail,
    required this.time,
    this.createdAt,
  });
}

/// A line item on a purchase order.
class PoLine {
  final String item;
  final double qty;
  final double cost;

  const PoLine({required this.item, required this.qty, required this.cost});

  double get total => qty * cost;

  Map<String, dynamic> toJson() => {'item': item, 'qty': qty, 'cost': cost};

  factory PoLine.fromJson(Map<String, dynamic> j) => PoLine(
        item: j['item'] as String? ?? '',
        qty: (j['qty'] as num?)?.toDouble() ?? 0,
        cost: (j['cost'] as num?)?.toDouble() ?? 0,
      );
}

/// Purchase order. Line items are serialized as JSON into the `notes`
/// column (no schema migration needed); `itemsCount`/`totalAmount` keep the
/// DB column values as fallback for rows created before line items existed.
class PurchaseOrder {
  final String id;
  final String supplier;
  final List<PoLine> lines;
  final String expected;
  final int itemsCount;
  final double totalAmount;
  String status;
  String? dbId;

  PurchaseOrder({
    required this.id,
    required this.supplier,
    this.lines = const [],
    this.itemsCount = 0,
    this.totalAmount = 0,
    required this.expected,
    required this.status,
    this.dbId,
  });

  int get items => lines.isEmpty ? itemsCount : lines.length;

  double get total =>
      lines.isEmpty ? totalAmount : lines.fold(0, (t, l) => t + l.total);

  /// Serializes the lines for storage in the notes column.
  String get linesJson => jsonEncode(lines.map((l) => l.toJson()).toList());

  static List<PoLine> parseLines(String? notes) {
    if (notes == null || notes.isEmpty) return const [];
    try {
      final v = jsonDecode(notes);
      if (v is List) {
        return v
            .whereType<Map<String, dynamic>>()
            .map(PoLine.fromJson)
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}

/// Cash movement for shift.
class CashMovement {
  final String time;
  final String type;
  final String note;
  final double amount;
  final String by;

  CashMovement({
    required this.time,
    required this.type,
    required this.note,
    required this.amount,
    required this.by,
  });
}

/// Discount / promo code (discounts table).
class AppDiscount {
  final String name;
  final int type; // 0 = percentage, 1 = fixed amount
  final double value;
  final String? dbId;

  const AppDiscount({
    required this.name,
    required this.type,
    required this.value,
    this.dbId,
  });

  double applyTo(double subtotal) =>
      type == 0 ? subtotal * value / 100 : value.clamp(0, subtotal);
}

/// Central app store. Backed by Supabase — every collection loads from the
/// database on [init] and every mutation persists asynchronously.
///
/// The store is a [ChangeNotifier] so live views (kitchen, tables, orders,
/// dashboard) can rebuild when background sync/realtime updates arrive.
/// Which slice of shared state a sync event touches. Realtime events are
/// grouped so one burst (e.g. an order + its items) triggers one reload per
/// area instead of one per table event.
enum _SyncArea { orders, tables, feeds, reference }

class AppStore extends ChangeNotifier {
  String view = 'dashboard';
  String query = '';
  String cat = 'All';
  String ordFilter = 'All';

  List<CartLine> cart = [];
  Map<String, Object?> cartMeta = {'type': 'Dine In'};

  /// Order number shown for the cart in the POS panel. It mirrors
  /// [orderSeq] when the cart is fresh and sticks to the resumed order's
  /// number while a held order is loaded in the cart (set by the resume
  /// flows via [cartMeta]'s 'resumedOrderId').
  int get cartNo {
    final resumed = cartMeta['resumedOrderId'] as int?;
    if (resumed != null) return resumed;
    return orderSeq;
  }
  int customerIdSeq = 1;
  int orderSeq = 0;
  int invoiceSeq = 0;
  String currentBranch = 'Main';
  bool isDark = false;
  bool cartDrawerOpen = false;

  final List<DemoProduct> products = [];
  final List<DemoFloor> floors = [];
  final List<DemoTable> tables = [];
  final List<KitchenTicket> kitchen = [];
  final List<DemoOrder> orders = [];
  final List<AppNotification> notifs = [];
  final List<Branch> branches = [];
  final List<TaxRate> taxRates = [];
  final List<Supplier> suppliers = [];
  final List<PurchaseOrder> purchaseOrders = [];
  final List<InvItem> inventory = [];
  final List<Customer> customers = [];
  final List<GiftCard> giftCards = [];
  final List<StaffMember> staff = [];
  final List<StaffRole> customRoles = [];
  final List<AuditEntry> auditLogs = [];
  final List<AppDiscount> discounts = [];
  final List<Map<String, dynamic>> paymentMethods = [];

  /// Tenant profile + key/value settings loaded from the database.
  Map<String, dynamic> tenant = {};
  final Map<String, String> settings = {};

  /// Open shift state (mirrors the design `S.shift`).
  Map<String, dynamic> shift = {
    'open': false,
    'cashier': '—',
    'openedAt': null,
    'float': 0.0,
    'cashSales': 0.0,
    'cashRefunds': 0.0,
    'cashInOut': 0.0,
    'movements': <CashMovement>[],
  };

  /// Set when a background write fails; surfaces in the topbar.
  String? syncError;
  int _pendingSync = 0;

  SupabaseStore? _db;
  String? _openShiftId;
  final Set<int> _kitchenQueue = {};
  final Map<int, int> _orderKitchenStage = {};
  final Map<String, String> _tableIdByName = {};
  final Map<int, String> _taxRateIdByRate = {};
  final Map<String, String> _categoryIdByName = {};

  /// Orders whose stock/sold deduction has already been applied in memory
  /// (set when the order row is persisted). Guards against double-deduction
  /// when a resumed order is edited while its initial persist is still in
  /// flight.
  final Set<int> _stockAppliedFor = {};

  /// Test/teardown hook: the in-memory receipt for the last audit write.
  Uint8List? lastAuditBytes;

  /// Test hook: marks an order's base stock deduction as already applied
  /// (normally done inside _persistOrder when the DB is connected).
  void debugMarkStockApplied(int orderId) => _stockAppliedFor.add(orderId);

  /// Test/white-box surface for the live-sync machinery: lets sync tests
  /// drive the same loaders the realtime streams and polling fallback use,
  /// and inspect/adjust the change signatures and the pending-write gate.
  void debugLoadOrders(List<Map<String, dynamic>> rows) =>
      _loadOrdersInto(rows);
  String get debugOrdersSignature => _lastOrdersSig;
  set debugOrdersSignature(String v) => _lastOrdersSig = v;
  String get debugTablesSignature => _lastTablesSig;
  set debugTablesSignature(String v) => _lastTablesSig = v;
  int get debugPendingSync => _pendingSync;
  set debugPendingSync(int v) => _pendingSync = v;
  Future<void> debugReloadLive() => _reloadLive();
  Future<void> debugReloadTables() => _reloadTables();
  void debugLoadProducts(List<Map<String, dynamic>> rows) =>
      _loadProductsInto(rows);
  void debugLoadCustomers(List<Map<String, dynamic>> rows) =>
      _loadCustomersInto(rows);
  final List<StreamSubscription> _subs = [];
  Timer? _liveTimer;

  /// Signatures of the last live snapshot — used to skip notifyListeners()
  /// Debounce timers per sync area — realtime bursts collapse into one
  /// reload each, and the polling fallback reuses the same path so it can
  /// skip work when a reload for that area already ran recently.
  final Map<_SyncArea, Timer> _syncKicks = {};

  /// In-flight flags per area: prevents overlapping reloads of the same
  /// slice (a slow reload plus rapid events would otherwise run duplicates
  /// and apply out of order).
  final Set<_SyncArea> _syncInFlight = {};

  /// Consecutive failed reloads per area — drives the error backoff so a
  /// down backend is retried at most every ~30s instead of hammering it.
  final Map<_SyncArea, int> _syncFailures = {};

  /// Last time each area completed a reload (any outcome).
  final Map<_SyncArea, DateTime> _syncLastRun = {};

  /// Minimum spacing between two reloads of the same area (ms). Realtime
  /// bursts and the 8s poll both funnel through here.
  static const int _syncMinGapMs = 1500;

  /// Entry point for every realtime event and poll tick. Debounces per
  /// area, enforces a minimum gap, and refuses to run while local writes
  /// are in flight (the post-write sync covers those). Returns nothing;
  /// failures are counted for backoff.
  void _kickSync(_SyncArea area) {
    if (_db == null) return;
    if (_pendingSync > 0) return; // writes in flight — post-write sync covers
    if (_syncInFlight.contains(area)) return; // already reloading this area

    // Error backoff: after 3+ consecutive failures, wait it out.
    final failures = _syncFailures[area] ?? 0;
    if (failures >= 3) {
      final last = _syncLastRun[area];
      if (last != null &&
          DateTime.now().difference(last).inMilliseconds < 30000) {
        return;
      }
    }

    // Minimum gap between reloads of the same area (debounce).
    final lastRun = _syncLastRun[area];
    if (lastRun != null) {
      final since = DateTime.now().difference(lastRun).inMilliseconds;
      if (since < _syncMinGapMs) {
        _syncKicks[area]?.cancel();
        _syncKicks[area] = Timer(
          Duration(milliseconds: _syncMinGapMs - since),
          () => _runAreaSync(area),
        );
        return;
      }
    }
    _runAreaSync(area);
  }

  Future<void> _runAreaSync(_SyncArea area) async {
    if (_db == null || _pendingSync > 0 || _syncInFlight.contains(area)) {
      return;
    }
    _syncInFlight.add(area);
    _syncLastRun[area] = DateTime.now();
    try {
      switch (area) {
        case _SyncArea.orders:
          await _reloadLive();
        case _SyncArea.tables:
          await _reloadTables();
        case _SyncArea.feeds:
          await Future.wait([
            _reloadNotifications(),
            _reloadAudit(),
            _reloadPurchaseOrders(),
          ]);
        case _SyncArea.reference:
          await _reloadReferenceData();
      }
      _syncFailures[area] = 0;
    } catch (_) {
      _syncFailures[area] = (_syncFailures[area] ?? 0) + 1;
    } finally {
      _syncInFlight.remove(area);
    }
  }

  /// when a poll/realtime event did not actually change anything (prevents
  /// constant full-app rebuilds that make the UI feel frozen).
  String _lastOrdersSig = '';
  String _lastTablesSig = '';

  /// Whether the store has been initialized with data.
  bool get ready => _db != null;

  /// Number of background writes still in flight.
  bool get syncing => _pendingSync > 0;

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  /// Loads every collection from Supabase and wires live updates.
  /// Throws [StateError] when the session has no tenant claim (not bootstrapped).
  Future<void> init({SupabaseStore? store}) async {
    _db = store ?? SupabaseStore(Supabase.instance.client);
    final db = _db!;
    if (db.tenantId == null) {
      throw StateError('No tenant claim in session — run bootstrap first');
    }

    _pendingSync = 0;
    syncError = null;
    _kitchenQueue.clear();
    _orderKitchenStage.clear();
    _tableIdByName.clear();
    _taxRateIdByRate.clear();
    _categoryIdByName.clear();
    _lastOrdersSig = '';
    _lastTablesSig = '';

    // Load the reference data in parallel; each failure is recorded but
    // does not brick the whole app (defensive against partial schemas).
    await Future.wait([
      _loadReference(db),
      _loadTransactional(db),
    ]);

    // Scope branch-specific loads to the persisted active branch.
    db.activeBranchId =
        branches.where((b) => b.name == currentBranch).firstOrNull?.dbId;
    if (db.activeBranchId != null) {
      await Future.wait([
        _loadReference(db),
        _loadTransactional(db),
      ]);
    }

    _wireLiveUpdates(db);
    notifyListeners();
  }

  Future<void> _loadReference(SupabaseStore db) async {
    final results = await Future.wait<Object?>([
      _safe(() => db.loadProducts()),
      _safe(() => db.loadTaxRates()),
      _safe(() => db.loadCategories()),
      _safe(() => db.loadFloors()),
      _safe(() => db.loadTables()),
      _safe(() => db.loadCustomers()),
      _safe(() => db.loadStaff()),
      _safe(() => db.loadSuppliers()),
      _safe(() => db.loadInventory()),
      _safe(() => db.loadGiftCards()),
      _safe(() => db.loadBranches()),
      _safe(() => db.loadTenant()),
      _safe(() => db.loadSettings()),
      _safe(() => db.loadPaymentMethods()),
      _safe(() => db.loadDiscounts()),
    ]);

    final products = results[0] as List? ?? [];
    final taxRates = results[1] as List? ?? [];
    final cats = results[2] as List? ?? [];
    final floorRows = results[3] as List? ?? [];
    final tableRows = results[4] as List? ?? [];
    final customerRows = results[5] as List? ?? [];
    final staffRows = results[6] as List? ?? [];
    final supplierRows = results[7] as List? ?? [];
    final inventoryRows = results[8] as List? ?? [];
    final giftRows = results[9] as List? ?? [];
    final branchRows = results[10] as List? ?? [];
    final tenantRow = results[11] as Map<String, dynamic>?;
    final settingsRows = results[12] as List? ?? [];
    final paymentRows = results[13] as List? ?? [];
    final discountRows = results[14] as List? ?? [];

    paymentMethods
      ..clear()
      ..addAll(paymentRows.cast<Map<String, dynamic>>());

    discounts
      ..clear()
      ..addAll(discountRows
          .cast<Map<String, dynamic>>()
          .map((d) => AppDiscount(
                name: d['name'] as String,
                type: d['type'] as int? ?? 0,
                value: (d['value'] as num?)?.toDouble() ?? 0,
                dbId: d['id'] as String?,
              )));

    _taxRateIdByRate.clear();
    this.taxRates
      ..clear()
      ..addAll(taxRates.cast<Map<String, dynamic>>().map((tr) => TaxRate(
            id: this.taxRates.length + 1,
            name: tr['name'] as String? ?? 'Tax',
            rate: (tr['rate'] as num?)?.toDouble() ?? 0,
            isInclusive: tr['is_inclusive'] as bool? ?? true,
            isDefault: tr['is_default'] as bool? ?? false,
            dbId: tr['id'] as String,
          )));
    for (final tr in taxRates.cast<Map<String, dynamic>>()) {
      final rate = (tr['rate'] as num).round();
      _taxRateIdByRate[rate] = tr['id'] as String;
    }
    _categoryIdByName.clear();
    for (final c in cats.cast<Map<String, dynamic>>()) {
      _categoryIdByName[c['name'] as String] = c['id'] as String;
    }

    _loadFloorsInto(floorRows.cast<Map<String, dynamic>>());
    _loadProductsInto(products.cast<Map<String, dynamic>>());
    _loadTablesInto(tableRows.cast<Map<String, dynamic>>());
    _loadCustomersInto(customerRows.cast<Map<String, dynamic>>());
    _loadStaffInto(staffRows.cast<Map<String, dynamic>>());
    _loadSuppliersInto(supplierRows.cast<Map<String, dynamic>>());
    _loadInventoryInto(inventoryRows.cast<Map<String, dynamic>>());
    _loadGiftCardsInto(giftRows.cast<Map<String, dynamic>>());
    _loadBranchesInto(branchRows.cast<Map<String, dynamic>>());
    _loadCustomRoles();

    if (tenantRow != null) {
      tenant = tenantRow;
      final t = tenantRow;
      settings['name'] = t['name'] as String? ?? RestaurantInfo.name;
      settings['address'] = t['address'] as String? ?? '';
      settings['phone'] = t['phone'] as String? ?? '';
      settings['email'] = t['email'] as String? ?? '';
    }
    for (final s in settingsRows.cast<Map<String, dynamic>>()) {
      settings[s['key'] as String] = s['value'] as String? ?? '';
    }
    // Restore the persisted branch choice now that settings are loaded.
    final savedBranch = settings['active_branch'];
    final branchMatch = branches
        .where((b) => b.name == savedBranch && b.status != 'inactive')
        .firstOrNull;
    if (branchMatch != null) currentBranch = branchMatch.name;
  }

  Future<void> _loadTransactional(SupabaseStore db) async {
    final results = await Future.wait<Object?>([
      _safe(() => db.loadOrders()),
      _safe(() => db.loadNotifications()),
      _safe(() => db.loadAuditLogs()),
      _safe(() => db.loadPurchaseOrders()),
      _safe(() => db.loadOpenShifts()),
    ]);

    final orderRows = results[0] as List? ?? [];
    final notifRows = results[1] as List? ?? [];
    final auditRows = results[2] as List? ?? [];
    final poRows = results[3] as List? ?? [];

    _loadOrdersInto(orderRows.cast<Map<String, dynamic>>());
    _loadNotifsInto(notifRows.cast<Map<String, dynamic>>());
    _loadAuditInto(auditRows.cast<Map<String, dynamic>>());
    _loadPurchaseOrdersInto(poRows.cast<Map<String, dynamic>>());
    _loadShiftFrom(db, results[4] as List? ?? []);

    // Resume invoice numbering from the atomic counter.
    final counter = await _safe(() => db.loadCounter('invoice'));
    if (counter is int && counter > 0) invoiceSeq = counter;
  }

  Future<void> _loadShiftFrom(SupabaseStore db, List<dynamic> openShifts) async {
    shift = {
      'open': false,
      'cashier': '—',
      'openedAt': null,
      'float': 0.0,
      'cashSales': 0.0,
      'cashRefunds': 0.0,
      'cashInOut': 0.0,
      'movements': <CashMovement>[],
    };
    _openShiftId = null;
    if (openShifts.isEmpty) return;
    final s = openShifts.first as Map<String, dynamic>;
    _openShiftId = s['id'] as String;
    final movements = (await _safe(
          () => db.loadCashMovements(_openShiftId!),
        ) as List?)?.cast<Map<String, dynamic>>() ??
        <Map<String, dynamic>>[];
    shift = {
      'open': true,
      'cashier': s['user_id'] == null ? '—' : _staffNameFor(s['user_id']),
      'openedAt': s['opened_at'],
      'float': (s['opening_cash'] as num?)?.toDouble() ?? 0,
      'cashSales': (s['cash_sales'] as num?)?.toDouble() ?? 0,
      'cashRefunds': (s['cash_refunds'] as num?)?.toDouble() ?? 0,
      'cashInOut': (s['cash_in_out'] as num?)?.toDouble() ?? 0,
      'movements': movements
          .map((m) => CashMovement(
                time: _clock(m['created_at'] as String?),
                type: _movementTypeName(m['type'] as int? ?? 0),
                note: m['reason'] as String? ?? '',
                amount: (m['amount'] as num).toDouble(),
                by: _staffNameFor(m['user_id']),
              ))
          .toList(),
    };
  }

  String _staffNameFor(Object? userId) {
    for (final s in staff) {
      if (s.dbId == userId) return s.name;
    }
    return 'Staff';
  }

  String _movementTypeName(int t) => switch (t) {
        0 => 'Cash in',
        1 => 'Cash out',
        2 => 'Sale',
        3 => 'Refund',
        _ => 'Movement',
      };

  // ------------------------------------------------------------------
  // Loaders (row → entity)
  // ------------------------------------------------------------------

  void _loadProductsInto(List<Map<String, dynamic>> rows) {
    // Preserve stable local ids across reloads so cart lines / order lines
    // keep pointing at the same product when the catalog refreshes in the
    // background (realtime or polling).
    final previousIds = <String, int>{
      for (final p in products)
        if (p.dbId != null) p.dbId!: p.id,
    };
    products.clear();
    var nextId = 1;
    int freshId() {
      while (previousIds.containsValue(nextId)) {
        nextId++;
      }
      return nextId++;
    }

    for (final r in rows) {
      final cat =
          (r['categories'] as Map<String, dynamic>?)?['name'] as String? ??
              'General';
      final rate = (r['tax_rates'] as Map<String, dynamic>?)?['rate'];
      final dbId = r['id'] as String;
      products.add(DemoProduct(
        id: previousIds[dbId] ?? freshId(),
        name: r['name'] as String,
        cat: cat,
        price: (r['price'] as num).toDouble(),
        cost: (r['cost'] as num?)?.toDouble() ?? 0,
        iva: (rate as num?)?.round() ?? 21,
        stock: (r['stock_qty'] as num?)?.toInt() ?? 0,
        img: r['image_url'] as String? ?? '',
        sold: (r['sold_count'] as num?)?.toInt() ?? 0,
        avail: r['is_available'] as bool? ?? true,
        dbId: dbId,
      ));
    }
  }

  void _loadFloorsInto(List<Map<String, dynamic>> rows) {
    floors.clear();
    for (final r in rows) {
      floors.add(DemoFloor(
        name: r['name'] as String? ?? 'Floor',
        dbId: r['id'] as String?,
      ));
    }
  }

  void _loadTablesInto(List<Map<String, dynamic>> rows) {
    tables.clear();
    _tableIdByName.clear();
    for (final r in rows) {
      final t = DemoTable(
        name: r['name'] as String,
        seats: (r['capacity'] as num?)?.toInt() ?? 4,
        status: switch (r['status'] as int? ?? 0) {
          1 => 'occ',
          2 => 'res',
          _ => 'free',
        },
        guest: (r['guest'] as String?)?.trim().isNotEmpty == true
            ? (r['guest'] as String).trim()
            : null,
        persons: (r['persons'] as num?)?.toInt(),
        startedAtMs: (r['guest'] as String?)?.trim().isNotEmpty != true
            ? null
            : (r['updated_at'] != null
                ? DateTime.parse(r['updated_at'] as String)
                    .millisecondsSinceEpoch
                    .toDouble()
                : DateTime.now().millisecondsSinceEpoch.toDouble()),
        zone: r['zone'] as String? ?? 'Indoor',
        floorId: r['floor_id'] as String?,
        dbId: r['id'] as String,
        x: (r['x'] as num?)?.toDouble() ?? 0,
        y: (r['y'] as num?)?.toDouble() ?? 0,
        width: (r['width'] as num?)?.toDouble() ?? 150,
        height: (r['height'] as num?)?.toDouble() ?? 130,
        shape: (r['shape'] as num?)?.toInt() ?? 0,
        // 0,0 is the DB default: treat it as "never placed on a plan".
        placed: ((r['x'] as num?)?.toDouble() ?? 0) != 0 ||
            ((r['y'] as num?)?.toDouble() ?? 0) != 0,
      );
      tables.add(t);
      _tableIdByName[t.name] = t.dbId!;
    }
  }

  void _loadCustomersInto(List<Map<String, dynamic>> rows) {
    customers.clear();
    var id = 1;
    for (final r in rows) {
      final c = Customer(
        id: id++,
        name: r['name'] as String,
        phone: r['phone'] as String? ?? '',
        email: r['email'] as String?,
        visits: (r['visits'] as num?)?.toInt() ?? 0,
        total: (r['total_spent'] as num?)?.toDouble() ?? 0,
        points: (r['points'] as num?)?.toInt() ?? 0,
        tier: r['tier'] as String? ?? 'Bronze',
        lastVisit: _relTime(r['last_visit_at'] as String?),
        diet: r['notes'] as String? ?? 'None',
        dbId: r['id'] as String,
      );
      customers.add(c);
    }
    // Keep the local sequence ahead of the loaded ids.
    customerIdSeq = (id > customerIdSeq) ? id : customerIdSeq;
  }

  void _loadStaffInto(List<Map<String, dynamic>> rows) {
    staff.clear();
    var id = 1;
    for (final r in rows) {
      staff.add(StaffMember(
        id: id++,
        name: r['full_name'] as String? ?? r['email'] as String? ?? 'Staff',
        role: r['role'] as String? ?? 'Staff',
        phone: r['phone'] as String? ?? '',
        hired: _dateStr(r['hired_at'] as String?),
        active: r['is_active'] as bool? ?? true,
        dbId: r['id'] as String,
        authId: r['user_id'] as String?,
        email: r['email'] as String?,
      ));
    }
  }

  void _loadSuppliersInto(List<Map<String, dynamic>> rows) {
    suppliers.clear();
    var id = 1;
    for (final r in rows) {
      suppliers.add(Supplier(
        id: id++,
        name: r['name'] as String,
        contact: r['contact'] as String? ?? '',
        phone: r['phone'] as String? ?? '',
        email: r['email'] as String? ?? '',
        cat: r['category'] as String? ?? 'General',
        terms: r['terms'] as String? ?? '',
        addr: r['address'] as String? ?? '',
        dbId: r['id'] as String,
      ));
    }
  }

  void _loadInventoryInto(List<Map<String, dynamic>> rows) {
    inventory.clear();
    var id = 1;
    for (final r in rows) {
      inventory.add(InvItem(
        id: id++,
        name: r['name'] as String,
        cat: r['category'] as String? ?? 'General',
        sku: r['sku'] as String? ?? '',
        qty: (r['quantity'] as num?)?.toDouble() ?? 0,
        unit: r['unit'] as String? ?? 'units',
        cost: (r['cost'] as num?)?.toDouble() ?? 0,
        reorder: (r['reorder_level'] as num?)?.toDouble() ?? 0,
        supplier: r['supplier_name'] as String? ?? '',
        expiry: _dateStr(r['expiry'] as String?),
        dbId: r['id'] as String,
      ));
    }
  }

  void _loadGiftCardsInto(List<Map<String, dynamic>> rows) {
    giftCards.clear();
    var id = 1;
    for (final r in rows) {
      giftCards.add(GiftCard(
        id: id++,
        code: r['code'] as String,
        amount: (r['amount'] as num).toDouble(),
        balance: (r['balance'] as num).toDouble(),
        recipient: r['recipient'] as String? ?? '',
        issued: _dateStr(r['issued_at'] as String?),
        expiry: _dateStr(r['expires_at'] as String?),
        status: r['status'] as String? ?? 'Active',
        dbId: r['id'] as String,
      ));
    }
  }

  void _loadBranchesInto(List<Map<String, dynamic>> rows) {
    branches.clear();
    var id = 1;
    for (final r in rows) {
      final b = Branch(
        id: id++,
        name: r['name'] as String,
        full: r['full_name'] as String? ?? r['name'] as String,
        city: r['city'] as String? ?? '',
        cif: r['cif'] as String? ?? '',
        manager: r['manager'] as String? ?? '',
        terminals: (r['terminals'] as num?)?.toInt() ?? 1,
        status: r['status'] as String? ?? 'active',
        dbId: r['id'] as String,
      );
      branches.add(b);
    }
    if (branches.isNotEmpty) {
      // Restore the persisted branch choice when it still exists & is active.
      final saved = settings['active_branch'];
      final match = branches
          .where((b) => b.name == saved && b.status != 'inactive')
          .firstOrNull;
      currentBranch = (match ?? branches.first).name;
      settings['name'] ??= branches.first.full;
    }
  }

  void _loadOrdersInto(List<Map<String, dynamic>> rows) {
    orders.clear();
    var maxId = 0;
    for (final r in rows) {
      final orderId = int.tryParse(r['order_number'] as String? ?? '') ?? 0;
      if (orderId > maxId) maxId = orderId;
      final tableRow = r['tables'] as Map<String, dynamic>?;
      final customerRow = r['customers'] as Map<String, dynamic>?;
      final items = <CartLine>[];
      for (final i in (r['order_items'] as List? ?? []).cast<Map<String, dynamic>>()) {
        items.add(CartLine(
          (i['product_id'] as String?) == null ? 0 : _productIdForDb(i['product_id'] as String),
          (i['quantity'] as num?)?.toInt() ?? 1,
          note: i['notes'] as String?,
        ));
      }
      final createdAt = DateTime.tryParse(r['created_at'] as String? ?? '');
      // Kitchen stage = highest stage among this order's items.
      var stage = 0;
      for (final i in (r['order_items'] as List? ?? [])
          .cast<Map<String, dynamic>>()) {
        final s = (i['kitchen_stage'] as num?)?.toInt() ?? 0;
        if (s > stage) stage = s;
      }
      orders.add(DemoOrder(
        id: orderId == 0 ? ++maxId : orderId,
        type: switch (r['order_type'] as int? ?? 0) {
          1 => 'Take Away',
          2 => 'Delivery',
          _ => 'Dine In',
        },
        table: tableRow?['name'] as String?,
        customerId: customerRow?['id'] as String?,
        customer: customerRow?['name'] as String? ?? 'Walk-in',
        status: _orderStatusName(r['status'] as int? ?? 0),
        items: items,
        method: r['payment_method'] as String?,
        time: _clock(r['created_at'] as String?),
        date: _dateStr(r['created_at'] as String?),
        sub: (r['subtotal'] as num?)?.toDouble() ?? 0,
        disc: (r['discount_amount'] as num?)?.toDouble() ?? 0,
        tax: (r['tax_amount'] as num?)?.toDouble() ?? 0,
        total: (r['total'] as num?)?.toDouble() ?? 0,
        invoice: r['invoice_number'] as String?,
        tip: (r['tip_amount'] as num?)?.toDouble() ?? 0,
        facturaType: r['factura_type'] as String?,
        customerNIF: r['customer_nif'] as String?,
        waiter: (r['users'] as Map<String, dynamic>?)?['full_name'] as String?,
        dbId: r['id'] as String,
        createdAt: createdAt,
      ));
      _orderKitchenStage[orderId == 0 ? maxId : orderId] = stage;
    }
    if (maxId >= orderSeq) orderSeq = maxId + 1;
    _rebuildKitchenFromOrders();
  }

  int _productIdForDb(String dbId) {
    for (final p in products) {
      if (p.dbId == dbId) return p.id;
    }
    return 0;
  }

  void _loadNotifsInto(List<Map<String, dynamic>> rows) {
    notifs.clear();
    for (final r in rows) {
      notifs.add(AppNotification(
        title: r['title'] as String,
        subtitle: r['subtitle'] as String? ?? '',
        time: _relTime(r['created_at'] as String?),
        kind: r['kind'] as String? ?? 'ok',
        unread: r['unread'] as bool? ?? true,
        dbId: r['id'] as String,
      ));
    }
  }

  void _loadAuditInto(List<Map<String, dynamic>> rows) {
    auditLogs.clear();
    var id = 1;
    for (final r in rows) {
      final user = (r['users'] as Map<String, dynamic>?)?['full_name'] as String?;
      final role = (r['users'] as Map<String, dynamic>?)?['role'] as String?;
      auditLogs.add(AuditEntry(
        id: id++,
        action: r['action'] as String,
        type: r['entity_type'] as String? ?? 'update',
        user: user ?? '—',
        role: role ?? '—',
        detail: r['new_values'] as String? ?? r['action'] as String,
        time: _relTime(r['created_at'] as String?),
        createdAt: DateTime.tryParse(r['created_at'] as String? ?? ''),
      ));
    }
  }

  void _loadPurchaseOrdersInto(List<Map<String, dynamic>> rows) {
    purchaseOrders.clear();
    for (final r in rows) {
      purchaseOrders.add(PurchaseOrder(
        id: r['po_number'] as String? ?? r['id'] as String,
        supplier: r['supplier_name'] as String,
        lines: PurchaseOrder.parseLines(r['notes'] as String?),
        itemsCount: (r['items_count'] as num?)?.toInt() ?? 0,
        totalAmount: (r['total'] as num?)?.toDouble() ?? 0,
        expected: _dateStr(r['expected_at'] as String?),
        status: r['status'] as String? ?? 'Pending',
        dbId: r['id'] as String,
      ));
    }
  }

  /// Kitchen tickets are derived from order items marked sent-to-kitchen.
  /// The ticket stage mirrors the highest `kitchen_stage` of the order's items.
  void _rebuildKitchenFromOrders() {
    kitchen.clear();
    for (final o in orders) {
      // Only orders actually in the kitchen pipeline get tickets: held
      // (Pending) orders wait in the orders list, paid/cancelled are done.
      if (o.status != 'Preparing' && o.status != 'Ready') continue;
      final stage = _orderKitchenStage[o.id] ?? (o.status == 'Ready' ? 2 : 1);
      if (stage >= 3) continue; // fully served — no ticket
      kitchen.add(KitchenTicket(
        orderId: o.id,
        status: stage >= 2 ? 'ready' : stage == 1 ? 'preparing' : 'new',
        sinceMs: (o.createdAt ?? DateTime.now()).millisecondsSinceEpoch.toDouble(),
        orderDbId: o.dbId,
      ));
    }
  }

  /// Advances a kitchen ticket: Incoming → Preparing → Ready → Done.
  /// Persists `kitchen_stage` on the order's items (and order status when
  /// the ticket is fully served).
  void advanceKitchen(KitchenTicket k) {
    final db = _db;
    if (k.status == 'new') {
      k.status = 'preparing';
      _orderKitchenStage[k.orderId] = 1;
      if (db != null && k.orderDbId != null) {
        _persist(() => db.client.from('order_items').update({
              'kitchen_stage': 1,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('order_id', k.orderDbId!));
      }
    } else if (k.status == 'preparing') {
      k.status = 'ready';
      _orderKitchenStage[k.orderId] = 2;
      if (db != null && k.orderDbId != null) {
        _persist(() => db.client.from('order_items').update({
              'kitchen_stage': 2,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('order_id', k.orderDbId!));
      }
    } else {
      // Done — mark items completed and the order served.
      kitchen.remove(k);
      _orderKitchenStage.remove(k.orderId);
      final o = orders.where((x) => x.id == k.orderId).firstOrNull;
      if (o != null && o.status == 'Preparing') o.status = 'Ready';
      if (db != null && k.orderDbId != null) {
        _persist(() async {
          await db.client.from('order_items').update({
            'kitchen_stage': 3,
            'status': 2,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('order_id', k.orderDbId!);
          await db.updateOrder(k.orderDbId!, {
            'status': 3,
            'updated_at': DateTime.now().toIso8601String(),
          });
        });
      }
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Live updates (realtime + polling fallback)
  // ------------------------------------------------------------------

  void _wireLiveUpdates(SupabaseStore db) {
    // Realtime streams (RLS-filtered by Supabase). Each subscription is
    // error-tolerant: a dropped socket or a table missing from the
    // supabase_realtime publication never crashes the app.
    void watch(String table, void Function() onChange) {
      try {
        _subs.add(
          db.watch(table).listen(
                (_) => onChange(),
                onError: (Object _) => onChange(),
                cancelOnError: false,
              ),
        );
      } catch (_) {
        // Realtime not available for this table — polling covers it.
      }
    }

    // Multi-user surface: every entity two devices can touch at the same
    // time is watched. Orders/items/tables carry the live business state
    // (kitchen moves, table status, settlements); products/customers cover
    // menu edits, stock counters and loyalty; notifications/audit are the
    // shared activity feeds; floors/discounts/gift-cards/purchase-orders
    // change rarely but mislead badly when stale (floor plan, promo totals,
    // card balances).
    watch('orders', () => _kickSync(_SyncArea.orders));
    watch('order_items', () => _kickSync(_SyncArea.orders));
    watch('tables', () => _kickSync(_SyncArea.tables));
    watch('products', () => _kickSync(_SyncArea.reference));
    watch('customers', () => _kickSync(_SyncArea.reference));
    watch('notifications', () => _kickSync(_SyncArea.feeds));
    watch('audit_logs', () => _kickSync(_SyncArea.feeds));
    watch('floors', () => _kickSync(_SyncArea.reference));
    watch('discounts', () => _kickSync(_SyncArea.reference));
    watch('gift_cards', () => _kickSync(_SyncArea.reference));
    watch('purchase_orders', () => _kickSync(_SyncArea.feeds));
    watch('inventory', () => _kickSync(_SyncArea.reference));
    watch('suppliers', () => _kickSync(_SyncArea.reference));

    // Polling fallback (realtime down / publication missing). Every
    // watched area is covered here so a socket drop degrades to
    // seconds-fresh data instead of a frozen screen. The kick helper
    // debounces and signature-skips, so the poll is cheap for the DB.
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_db == null || _pendingSync > 0) return;
      _kickSync(_SyncArea.orders);
      _kickSync(_SyncArea.tables);
      _kickSync(_SyncArea.feeds);
      _kickSync(_SyncArea.reference);
    });
  }

  /// Re-syncs everything once pending writes have settled (called after
  /// each write completes) so the UI reflects the DB exactly.
  void _schedulePostWriteSync() {
    if (_pendingSync > 0 || _db == null) return;
    _kickSync(_SyncArea.orders);
    _kickSync(_SyncArea.tables);
    _kickSync(_SyncArea.feeds);
    _kickSync(_SyncArea.reference);
  }

  /// Test-visible wrapper around [_ordersSignature].
  String ordersSignatureFor(List<Map<String, dynamic>> rows) =>
      _ordersSignature(rows);

  String _ordersSignature(List<Map<String, dynamic>> rows) {
    final buf = StringBuffer();
    for (final r in rows) {
      buf
        ..write(r['id'])
        ..write(':')
        ..write(r['status'])
        ..write(':')
        ..write(r['total'])
        ..write(':')
        ..write(r['updated_at'])
        ..write('|');
      for (final i
          in (r['order_items'] as List? ?? []).cast<Map<String, dynamic>>()) {
        buf
          ..write(i['id'])
          ..write(':')
          ..write(i['kitchen_stage'])
          ..write(';');
      }
    }
    return buf.toString();
  }

  String _tablesSignature(List<Map<String, dynamic>> rows) {
    final buf = StringBuffer();
    for (final r in rows) {
      buf
        ..write(r['id'])
        ..write(':')
        ..write(r['status'])
        ..write(':')
        ..write(r['guest'])
        ..write(':')
        ..write(r['persons'])
        ..write(':')
        ..write(r['updated_at'])
        ..write(';');
    }
    return buf.toString();
  }

  Future<void> _reloadLive() async {
    final db = _db;
    if (db == null) return;
    // A write from THIS device may not be visible in the DB snapshot yet
    // (in-flight); applying the older remote list would flash-delete rows.
    if (_pendingSync > 0) return;
    final rows = await _safe(() => db.loadOrders(limit: 100));
    if (rows is List) {
      if (_pendingSync > 0) return; // a write started while we awaited
      final casted = rows.cast<Map<String, dynamic>>();
      final sig = _ordersSignature(casted);
      if (sig == _lastOrdersSig) return; // nothing changed — skip rebuild
      _lastOrdersSig = sig;
      _loadOrdersInto(casted);
      notifyListeners();
    }
  }

  Future<void> _reloadTables() async {
    final db = _db;
    if (db == null) return;
    if (_pendingSync > 0) return;
    final rows = await _safe(() => db.loadTables());
    if (rows is List) {
      if (_pendingSync > 0) return;
      final casted = rows.cast<Map<String, dynamic>>();
      final sig = _tablesSignature(casted);
      if (sig == _lastTablesSig) return; // nothing changed — skip rebuild
      _lastTablesSig = sig;
      _loadTablesInto(casted);
      notifyListeners();
    }
  }

  /// Live notification updates (realtime).
  Future<void> _reloadNotifications() async {
    final db = _db;
    if (db == null) return;
    if (_pendingSync > 0) return;
    final rows = await _safe(() => db.loadNotifications());
    if (rows is List) {
      if (_pendingSync > 0) return;
      _loadNotifsInto(rows.cast<Map<String, dynamic>>());
      notifyListeners();
    }
  }

  /// Live audit trail (realtime) — shared activity feed across terminals.
  Future<void> _reloadAudit() async {
    final db = _db;
    if (db == null) return;
    if (_pendingSync > 0) return;
    final rows = await _safe(() => db.loadAuditLogs());
    if (rows is List) {
      if (_pendingSync > 0) return;
      _loadAuditInto(rows.cast<Map<String, dynamic>>());
      notifyListeners();
    }
  }

  /// Live purchase orders (realtime).
  Future<void> _reloadPurchaseOrders() async {
    final db = _db;
    if (db == null) return;
    if (_pendingSync > 0) return;
    final rows = await _safe(() => db.loadPurchaseOrders());
    if (rows is List) {
      if (_pendingSync > 0) return;
      _loadPurchaseOrdersInto(rows.cast<Map<String, dynamic>>());
      notifyListeners();
    }
  }

  /// Reference data shared across devices (menu, stock, loyalty, floors,
  /// promos, gift cards, suppliers). Reloads wholesale — these tables are
  /// small, and per-table signatures would add complexity without benefit.
  /// Overlap is prevented by the per-area in-flight set in [_runAreaSync].
  Future<void> _reloadReferenceData() async {
    final db = _db;
    if (db == null) return;
    if (_pendingSync > 0) return; // don't clobber in-flight writes
    await _loadReference(db);
    notifyListeners();
  }

  /// Reloads everything (after login).
  Future<void> refresh() async {
    final db = _db;
    if (db == null) return;
    await Future.wait([_loadReference(db), _loadTransactional(db)]);
    notifyListeners();
  }

  /// Manual full re-sync (topbar refresh button). Bypasses the debounce,
  /// the minimum gap and the error backoff — the user explicitly asked for
  /// fresh data, typically right before a critical action. Pending local
  /// writes are awaited first so the pull can't race them.
  Future<void> refreshAll() async {
    // Invalidate cached signatures up front: the pull must never be
    // skipped as a no-op, and stale signatures are meaningless after a
    // forced refresh (also makes this work predictably when offline).
    _lastOrdersSig = '';
    _lastTablesSig = '';
    final db = _db;
    if (db == null) return;
    if (_pendingSync > 0) {
      // Wait (bounded) for in-flight writes to settle.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (_pendingSync > 0 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    _syncKicks.values.forEach((t) => t.cancel());
    _syncKicks.clear();
    _syncFailures.clear();
    _syncInFlight.clear();
    await Future.wait([
      _loadReference(db),
      _loadTransactional(db),
    ]);
    _syncLastRun.clear();
    notifyListeners();
  }

  /// Whether a manual refresh is currently running (drives the button's
  /// spinner state).
  bool _refreshing = false;
  bool get isRefreshing => _refreshing;

  /// Wraps [refreshAll] with the refreshing flag for the UI.
  Future<void> beginManualRefresh() async {
    if (_refreshing) return;
    _refreshing = true;
    notifyListeners();
    try {
      await refreshAll();
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  /// Drops all state and disconnects from the backend (on logout).
  void reset() {
    _liveTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _db = null;
    _openShiftId = null;
    _kitchenQueue.clear();
    _tableIdByName.clear();
    _taxRateIdByRate.clear();
    _categoryIdByName.clear();
    _pendingSync = 0;
    syncError = null;
    _orderKitchenStage.clear();
    _lastOrdersSig = '';
    _lastTablesSig = '';
    products.clear();
    tables.clear();
    kitchen.clear();
    orders.clear();
    notifs.clear();
    branches.clear();
    suppliers.clear();
    purchaseOrders.clear();
    inventory.clear();
    customers.clear();
    giftCards.clear();
    staff.clear();
    auditLogs.clear();
    discounts.clear();
    paymentMethods.clear();
    tenant = {};
    settings.clear();
    cart.clear();
    cartMeta = {'type': 'Dine In'};
    shift = {
      'open': false,
      'cashier': '—',
      'openedAt': null,
      'float': 0.0,
      'cashSales': 0.0,
      'cashRefunds': 0.0,
      'cashInOut': 0.0,
      'movements': <CashMovement>[],
    };
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Reads
  // ------------------------------------------------------------------

  DemoProduct? product(int id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  String get timeNow {
    final t = DateTime.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String get dateNow {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final d = DateTime.now();
    return '${days[d.weekday % 7]} ${months[d.month - 1]} '
        '${d.day.toString().padLeft(2, '0')}, ${d.year}';
  }

  /// Next invoice number in the configured series (e.g. 2026/00427, or
  /// FAC/A/2026/00427 when a prefix is set in Settings).
  /// Falls back to a local sequence when the backend is unreachable.
  String nextInvoice() {
    final prefix = settings['invoice_prefix'] ?? '';
    final year = DateTime.now().year.toString();
    invoiceSeq++;
    final n = invoiceSeq.toString().padLeft(5, '0');
    final invoice = prefix.isEmpty ? '$year/$n' : '$prefix$year/$n';
    final db = _db;
    if (db != null) {
      db.nextCounter('invoice').then((v) {
        invoiceSeq = v;
        notifyListeners();
      }).catchError((_) {});
    }
    return invoice;
  }

  int get activeOrderCount => orders
      .where(
        (o) =>
            o.status != 'Paid' &&
            o.status != 'Cancelled' &&
            o.status != 'Refunded',
      )
      .length;

  int get kitchenCount => kitchen.length;

  /// Resolves a promo code against the active discounts in the database.
  /// Returns null when the code does not match any active discount.
  AppDiscount? findDiscount(String code) {
    final c = code.trim().toLowerCase();
    if (c.isEmpty) return null;
    for (final d in discounts) {
      if (d.name.trim().toLowerCase() == c) return d;
    }
    return null;
  }

  /// Creates a promo code / discount. Returns null on success or an error.
  Future<String?> addDiscount({
    required String name,
    required int type,
    required double value,
  }) async {
    final db = _db;
    if (db == null) return 'Not connected to the workspace';
    final code = name.trim().toUpperCase();
    if (code.isEmpty) return 'Enter a promo code.';
    if (findDiscount(code) != null) return 'That promo code already exists.';
    if (value <= 0) return 'Enter a value greater than zero.';
    try {
      final row = await db.createDiscount({
        'name': code,
        'type': type,
        'value': value,
        'is_active': true,
      });
      discounts.add(AppDiscount(
        name: code,
        type: type,
        value: value,
        dbId: row['id'] as String?,
      ));
      addAudit(
        'Promo code created',
        'create',
        '$code · ${type == 0 ? '${value.toStringAsFixed(0)}%' : fmt(value)} off',
      );
      notifyListeners();
      return null;
    } catch (e) {
      return _readableRpcError(e);
    }
  }

  /// Deactivates a promo code so it can no longer be applied at the POS.
  void deactivateDiscount(AppDiscount d) {
    discounts.remove(d);
    if (d.dbId != null) {
      _persist(() => _db!.updateDiscount(d.dbId!, {'is_active': false}));
    }
    addAudit('Promo code deactivated', 'delete', d.name);
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Persistence plumbing
  // ------------------------------------------------------------------

  void _persist(Future<void> Function() op) {
    _pendingSync++;
    op().then((_) {
      _pendingSync--;
      if (_pendingSync == 0) {
        syncError = null;
        // Local writes settled — pull once so this device sees the exact
        // persisted state (and any rows other devices wrote meanwhile).
        _schedulePostWriteSync();
      }
    }).catchError((Object e) {
      _pendingSync--;
      syncError = 'Sync failed: $e';
      debugPrint('Persist failed: $e');
      notifyListeners();
    });
  }

  // ------------------------------------------------------------------
  // Undo for deletes
  // ------------------------------------------------------------------
  // Deleting is deferred: the row leaves the UI immediately, but the DB
  // delete only fires after the 5-second undo window. Undo cancels the
  // timer and re-inserts the row in memory — the DB never changed.

  final Map<String, Timer> _undoTimers = {};
  int _undoSeq = 0;

  /// Registers a deferred DB delete. Returns an undo token: call it to
  /// cancel the delete and re-insert the removed item(s) into the store.
  String Function() scheduleDbDelete(
    void Function() delete, {
    required VoidCallback undoUi,
    Duration delay = const Duration(seconds: 5),
  }) {
    final token = 'undo-${_undoSeq++}';
    final timer = Timer(delay, () {
      _undoTimers.remove(token);
      _persist(() async => delete());
    });
    _undoTimers[token] = timer;
    return () {
      _undoTimers.remove(token)?.cancel();
      undoUi();
      notifyListeners();
      return token;
    };
  }

  /// Test/teardown helper: cancels every pending undo delete.
  void cancelPendingUndos() {
    for (final t in _undoTimers.values) {
      t.cancel();
    }
    _undoTimers.clear();
  }

  Future<Object?> _safe(Future<Object?> Function() op) async {
    try {
      return await op();
    } catch (e) {
      syncError = 'Load failed: $e';
      return null;
    }
  }

  // ------------------------------------------------------------------
  // Orders
  // ------------------------------------------------------------------

  /// Resets the active cart to a clean, fresh order: clears items, the
  /// resume marker, any applied discount and the table/customer link. Called
  /// after a cart is committed (paid / sent to kitchen / held) so the POS
  /// always starts the next order with the NEXT order number.
  void clearActiveCart() {
    cart.clear();
    cartMeta = {'type': 'Dine In', 'customerId': null};
  }

  void pushOrder(
    DemoOrder o, {
    String? customerId,
  }) {
    // '' explicitly clears; null keeps what the caller already set on `o`.
    if (customerId != null) {
      o.customerId = customerId.isEmpty ? null : customerId;
    }
    o.createdAt ??= DateTime.now();
    orders.insert(0, o);
    // Keep the sequence ahead of every known order so two terminals (or a
    // resume that arrived from another device) can never mint a duplicate id.
    if (o.id >= orderSeq) orderSeq = o.id + 1;
    _persist(() => _persistOrder(o));
  }

  Future<void> _persistOrder(DemoOrder o) async {
    final db = _db;
    if (db == null) return;
    final tableId = o.table == null ? null : _tableIdByName[o.table];
    // Attribution is explicit only: the id linked in the cart. A typed name
    // that was never linked stays unattributed — never guessed by name.
    final customerId = o.customerId;
    final sendKitchen = _kitchenQueue.contains(o.id);
    final row = <String, dynamic>{
      'order_number': '${o.id}',
      'order_type': _orderType(o.type),
      'status': _orderStatus(o.status),
      'table_id': ?tableId,
      'customer_id': ?customerId,
      if (_currentStaffDbId != null) 'waiter_id': _currentStaffDbId,
      'subtotal': o.sub,
      'tax_amount': o.tax,
      'discount_amount': o.disc,
      'total': o.total,
      if (o.method != null) 'payment_method': o.method,
      if (o.invoice != null) 'invoice_number': o.invoice,
      'tip_amount': o.tip,
      if (o.facturaType != null) 'factura_type': o.facturaType,
      if (o.customerNIF != null) 'customer_nif': o.customerNIF,
      if (o.status == 'Paid' || o.status == 'Cancelled' || o.status == 'Refunded')
        'closed_at': DateTime.now().toIso8601String(),
    };
    // Stock leaves inventory and sold counters tick exactly once, when the
    // order row is created (this method runs once per order — resumed
    // orders settle through [settleOrder]/[updateCommittedOrder], whose
    // stock sync lives there).
    final created = await db.createOrder(row);
    o.dbId = created['id'] as String;
    _kitchenQueue.remove(o.id);

    final items = <Map<String, dynamic>>[];
    for (final l in o.items) {
      final p = product(l.productId);
      final base = (p?.price ?? 0) * l.qty;
      final disc = l.discPct != null ? base * l.discPct! / 100 : 0;
      items.add({
        'order_id': created['id'],
        'product_id': p?.dbId,
        'product_name': p?.name ?? 'Item',
        'quantity': l.qty,
        'unit_price': p?.price ?? 0,
        'discount_amount': disc,
        'tax_rate': p?.iva ?? 0,
        'tax_amount': _taxFor(base - disc, p?.iva ?? 0),
        'subtotal': base - disc,
        'total': base - disc,
        'notes': l.note,
        if (sendKitchen) 'status': 1 else 'status': 0,
        'kitchen_stage': 0,
      });
    }
    if (items.isNotEmpty) {
      await db.createOrderItems(items);
    }
    if (sendKitchen && o.dbId != null) {
      _persist(() => _sendKitchenForOrder(o.dbId!));
    }
    if (o.status == 'Paid') {
      await _persistPaymentSideEffects(o, created['id'] as String);
    }
    // Availability is deliberately untouched: sell-outs don't auto-disable
    // dishes, the Availability switch is the single source of truth.
    if (!_stockAppliedFor.contains(o.id)) {
      for (final l in o.items) {
        final p = product(l.productId);
        if (p == null || p.dbId == null) continue;
        p.stock = (p.stock - l.qty).clamp(0, 999999).toInt();
        p.sold += l.qty;
        db.updateProduct(p.dbId!, {
          'sold_count': p.sold,
          'stock_qty': p.stock,
        }).catchError((_) {});
      }
      _stockAppliedFor.add(o.id);
    }
    notifyListeners();
  }

  /// Reconciles stock/sold counters when a committed order's items are
  /// edited (resume flow): added quantities deduct, removed quantities are
  /// restored. Keeps the cart — the source of truth after a resume — and
  /// the inventory in agreement without double-counting.
  void _syncStockForEdit(
    List<CartLine> before,
    List<CartLine> after, {
    int? editingOrderId,
  }) {
    final db = _db;
    // The base deduction for this order runs inside _persistOrder; until it
    // has actually applied (async), it will deduct the FINAL item list — so
    // editing before then must not apply a delta on top.
    final basePending = editingOrderId != null &&
        !_stockAppliedFor.contains(editingOrderId);
    if (basePending) return;
    final oldQty = <int, int>{for (final l in before) l.productId: l.qty};
    final newQty = <int, int>{for (final l in after) l.productId: l.qty};
    final ids = {...oldQty.keys, ...newQty.keys};
    for (final id in ids) {
      final delta = (newQty[id] ?? 0) - (oldQty[id] ?? 0);
      if (delta == 0) continue;
      final p = product(id);
      if (p == null || p.dbId == null) continue;
      if (delta > 0) {
        p.stock = (p.stock - delta).clamp(0, 999999).toInt();
      } else {
        p.stock = (p.stock - delta).clamp(0, 999999).toInt();
      }
      p.sold = (p.sold + delta).clamp(0, 999999).toInt();
      db?.updateProduct(p.dbId!, {
        'sold_count': p.sold,
        'stock_qty': p.stock,
      }).catchError((_) {});
    }
  }

  Future<void> _persistPaymentSideEffects(DemoOrder o, String orderDbId) async {
    final db = _db;
    if (db == null) return;
    // Payment row
    final methodRow = paymentMethods
        .where((m) => (m['name'] as String).toLowerCase() ==
            (o.method?.toLowerCase() ?? ''))
        .firstOrNull;
    await db.createPayment({
      'order_id': orderDbId,
      if (methodRow != null) 'payment_method_id': methodRow['id'],
      'amount': o.total,
      'tip_amount': o.tip,
      'status': 0,
      'reference': o.invoice,
    });
    // Cash drawer entry when the shift is open
    if (_isCash(o.method) && _openShiftId != null) {
      await db.createCashMovement({
        'shift_id': _openShiftId,
        'type': 2, // Sale
        'amount': o.total + o.tip,
        'reason': 'Order #${o.id} — ${o.method}',
        'order_id': orderDbId,
        'user_id': _currentStaffDbId,
      });
      final sales =
          ((shift['cashSales'] as num?)?.toDouble() ?? 0) + o.total + o.tip;
      shift['cashSales'] = sales;
      db.closeShift(_openShiftId!, {'cash_sales': sales}).catchError((_) {});
      notifyListeners();
    }
  }

  bool _isCash(String? method) =>
      method != null && method.toLowerCase().contains('cash');

  /// Adds a kitchen ticket; marks the order's items sent-to-kitchen.
  void addKitchen(int orderId, {String note = ''}) {
    _kitchenQueue.add(orderId);
    _orderKitchenStage[orderId] = 0;
    kitchen.insert(
      0,
      KitchenTicket(
        orderId: orderId,
        status: 'new',
        sinceMs: DateTime.now().millisecondsSinceEpoch.toDouble(),
        notes: note,
      ),
    );
    final o = orders.where((x) => x.id == orderId).firstOrNull;
    if (o?.status == 'Pending' || o?.status == 'Preparing') {
      o?.status = 'Preparing';
    }
    if (o?.dbId != null) {
      _persist(() => _sendKitchenForOrder(o!.dbId!));
    }
    notifyListeners();
  }

  Future<void> _sendKitchenForOrder(String orderDbId) async {
    final db = _db;
    if (db == null) return;
    // Items were already persisted with status=1 when the queue flag was
    // consumed by _persistOrder; this covers orders persisted earlier.
    await db.updateOrder(orderDbId, {
      'status': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Cancels one or more orders (persists the status change).
  void cancelOrders(Iterable<DemoOrder> targets, {String reason = ''}) {
    final list = targets.toList();
    for (final o in list) {
      if (o.status == 'Paid' ||
          o.status == 'Cancelled' ||
          o.status == 'Refunded') {
        continue; // settled money cannot be cancelled from the orders list
      }
      o.status = 'Cancelled';
      // A cancelled order leaves the kitchen pipeline immediately.
      _orderKitchenStage.remove(o.id);
      kitchen.removeWhere((k) => k.orderId == o.id);
      _kitchenQueue.remove(o.id);
      // If the cancelled order is loaded in the cart, drop the resume
      // marker so the cart behaves as a fresh order again.
      if (cartMeta['resumedOrderId'] == o.id) {
        cartMeta.remove('resumedOrderId');
      }
      if (o.dbId != null) {
        _persist(() async {
          final db = _db!;
          await db.updateOrder(o.dbId!, {
            'status': 5,
            'notes': reason,
            'closed_at': DateTime.now().toIso8601String(),
          });
        });
      }
    }
    notifyListeners();
  }

  /// Settles an existing order (from the tables view / resume flow):
  /// updates the row to Paid with payment details — never inserts a new one.
  ///
  /// When the settled order is the one currently loaded in the cart, the
  /// cart is cleared too so the POS is immediately ready for the next
  /// order (it shows the NEXT order number, not the paid one).
  void settleOrder(DemoOrder o) {
    if (o.status == 'Paid' ||
        o.status == 'Cancelled' ||
        o.status == 'Refunded') {
      // Already settled — never re-charge, re-credit loyalty or emit a
      // second payment row (double-payment guard).
      return;
    }
    o.status = 'Paid';
    o.method = o.method;
    if (cartMeta['resumedOrderId'] == o.id) {
      clearActiveCart();
    } else if (cartMeta['resumedOrderId'] != null) {
      // Safety net: the marker should never reference an order other than
      // the one being settled, but if it does, drop it so the cart number
      // can't get stuck on a dead id.
      cartMeta.remove('resumedOrderId');
    }
    if (o.dbId != null) {
      _persist(() async {
        final db = _db!;
        await db.updateOrder(o.dbId!, {
          'status': 6,
          'payment_method': o.method,
          // Totals may have been edited after a resume — persist current.
          'subtotal': o.sub,
          'tax_amount': o.tax,
          'discount_amount': o.disc,
          'total': o.total,
          if (o.invoice != null) 'invoice_number': o.invoice,
          'tip_amount': o.tip,
          'factura_type': o.facturaType,
          'customer_nif': o.customerNIF,
          'closed_at': DateTime.now().toIso8601String(),
        });
        await _persistPaymentSideEffects(o, o.dbId!);
      });
    }
    notifyListeners();
  }

  /// Resume flow: the held order goes back into the cart **keeping its
  /// order number and its database row**. The row is NOT cancelled —
  /// settling it later updates the same row via [settleOrder], so the
  /// order id is stable for the whole lifecycle (hold → resume → pay).
  /// Returns the order (still registered in [orders]).
  ///
  /// Orders that can no longer be edited (paid/cancelled/refunded) are
  /// refused and returned as null so callers never resume them.
  DemoOrder? resumeOrder(DemoOrder o) {
    if (o.status == 'Paid' ||
        o.status == 'Cancelled' ||
        o.status == 'Refunded') {
      return null;
    }
    // Refuse a DIFFERENT order while another one is actively resumed —
    // resuming it would abandon the first resume marker and its next
    // commit would split one bill across two rows. Re-resuming the SAME
    // order is fine (the cart load replaces, not appends).
    final activeId = cartMeta['resumedOrderId'] as int?;
    if (activeId != null && activeId != o.id) {
      final active = orders.where((x) => x.id == activeId).firstOrNull;
      final activeOpen = active != null &&
          active.status != 'Paid' &&
          active.status != 'Cancelled' &&
          active.status != 'Refunded';
      if (activeOpen || cart.isNotEmpty) return null;
    }
    notifyListeners();
    return o;
  }

  /// Replaces an existing (already-persisted) order's items and totals —
  /// used by the resume flow when Hold / Send-to-Kitchen / Pay is pressed
  /// on a resumed order. The order keeps its id and DB row.
  void updateCommittedOrder(
    DemoOrder o, {
    required List<CartLine> items,
    required double sub,
    required double disc,
    required double tax,
    required double total,
    String? type,
    String? table,
    String? customer,
    String? customerId,
    String? status,
    bool sendKitchen = false,
  }) {
    // Status written to the DB only when THIS update changes it — see the
    // persist block below.
    final prevStatus = o.status;
    // Keep inventory in agreement when a resumed order's items were edited.
    final before = List<CartLine>.of(o.items);
    o.items
      ..clear()
      ..addAll(items);
    _syncStockForEdit(before, o.items, editingOrderId: o.id);
    o.sub = sub;
    o.disc = disc;
    o.tax = tax;
    o.total = total;
    if (type != null) o.type = type;
    if (table != null) o.table = table;
    if (customer != null && customer.isNotEmpty) o.customer = customer;
    // '' explicitly clears the attribution (customer removed from cart);
    // null leaves whatever the order already carries.
    if (customerId != null) {
      o.customerId = customerId.isEmpty ? null : customerId;
    }
    if (status != null) o.status = status;
    if (sendKitchen) {
      // One ticket per order — a resumed order sent to the kitchen again
      // updates its existing ticket instead of adding a duplicate.
      kitchen.removeWhere((k) => k.orderId == o.id);
      _kitchenQueue.add(o.id);
      _orderKitchenStage[o.id] = 0;
      kitchen.insert(
        0,
        KitchenTicket(
          orderId: o.id,
          status: 'new',
          sinceMs: DateTime.now().millisecondsSinceEpoch.toDouble(),
          notes: '',
          orderDbId: o.dbId,
        ),
      );
    }
    addAudit('Order #${o.id} updated', 'update',
        '${items.length} items · ${total.toStringAsFixed(2)}${sendKitchen ? ' · sent to kitchen' : ''}');
    notifyListeners();
    if (o.dbId != null) {
      _persist(() async {
        final db = _db!;
        // Only write status when this update actually changed it — the
        // async write must never clobber a status change that happened
        // meanwhile (e.g. settleOrder setting Paid while items synced).
        final statusPatch = <String, dynamic>{
          'order_type': _orderType(o.type),
          'subtotal': sub,
          'tax_amount': tax,
          'discount_amount': disc,
          'total': total,
          'table_id': ?(o.table == null ? null : _tableIdByName[o.table]),
          // Customer attribution can change while resumed (re-link, remove).
          'customer_id': ?o.customerId,
          'updated_at': DateTime.now().toIso8601String(),
          if (o.status != prevStatus) 'status': _orderStatus(o.status),
        };
        await db.updateOrder(o.dbId!, statusPatch);
        // Replace line items wholesale so quantities stay in sync.
        await db.deleteOrderItems(o.dbId!);
        final rows = <Map<String, dynamic>>[];
        for (final l in items) {
          final p = product(l.productId);
          final base = (p?.price ?? 0) * l.qty;
          final d = l.discPct != null ? base * l.discPct! / 100 : 0;
          rows.add({
            'order_id': o.dbId,
            'product_id': p?.dbId,
            'product_name': p?.name ?? 'Item',
            'quantity': l.qty,
            'unit_price': p?.price ?? 0,
            'discount_amount': d,
            'tax_rate': p?.iva ?? 0,
            'tax_amount': _taxFor(base - d, p?.iva ?? 0),
            'subtotal': base - d,
            'total': base - d,
            'notes': l.note,
            if (sendKitchen) 'status': 1 else 'status': 0,
            'kitchen_stage': 0,
          });
        }
        if (rows.isNotEmpty) await db.createOrderItems(rows);
        if (sendKitchen) {
          await db.updateOrder(o.dbId!, {
            'status': 1,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      });
    }
  }

  /// Refunds a paid order.
  void refundOrder(DemoOrder o, {required double amount, String reason = ''}) {
    o.status = 'Refunded';
    o.method = 'Refunded';
    if (o.dbId != null) {
      _persist(() async {
        final db = _db!;
        await db.updateOrder(o.dbId!, {
          'status': 7,
          'payment_method': 'Refunded',
          'notes': reason.isEmpty ? null : reason,
        });
        if (_isCash(o.method) && _openShiftId != null) {
          await db.createCashMovement({
            'shift_id': _openShiftId,
            'type': 3, // Refund
            'amount': -amount,
            'reason': 'Refund order #${o.id}${reason.isEmpty ? '' : ' — $reason'}',
            'order_id': o.dbId,
            'user_id': _currentStaffDbId,
          });
          final refunds =
              ((shift['cashRefunds'] as num?)?.toDouble() ?? 0) + amount;
          shift['cashRefunds'] = refunds;
          db.closeShift(_openShiftId!, {'cash_refunds': refunds})
              .catchError((_) {});
        }
      });
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Tables
  // ------------------------------------------------------------------

  void reserveTable(DemoTable t, String guest, int persons) {
    t.status = 'res';
    t.guest = guest.isEmpty ? 'Reserved' : guest;
    t.persons = persons;
    t.startedAtMs = null;
    t.orderId = null;
    _persist(() async {
      await _db!.updateTable(t.dbId!, {
        'status': 2,
        'guest': t.guest,
        'persons': persons,
      });
    });
    notifyListeners();
  }

  void checkIn(DemoTable t, String guest, int persons) {
    t.status = 'occ';
    t.guest = guest.isEmpty ? 'Walk-in' : guest;
    t.persons = persons;
    t.startedAtMs = DateTime.now().millisecondsSinceEpoch.toDouble();
    t.orderId = orderSeq;
    _persist(() async {
      await _db!.updateTable(t.dbId!, {
        'status': 1,
        'guest': t.guest,
        'persons': persons,
      });
    });
    notifyListeners();
  }

  void freeTable(DemoTable t) {
    t.status = 'free';
    t.guest = null;
    t.persons = null;
    t.startedAtMs = null;
    t.orderId = null;
    _persist(() async {
      await _db!.updateTable(t.dbId!, {
        'status': 0,
        'guest': null,
        'persons': null,
      });
    });
    notifyListeners();
  }

  /// Creates a new table in the given zone (falls back to the first zone).
  Future<DemoTable?> addTable({
    required String name,
    required int seats,
    String? floorId,
    int shape = 0,
  }) async {
    final db = _db;
    if (db == null) return null;
    final fid = floorId ?? await db.loadFirstFloorId();
    if (fid == null) {
      syncError = 'No zone found — cannot create table';
      notifyListeners();
      return null;
    }
    // Keep the legacy `zone` column in sync with the zone name.
    final zoneName = floors
        .where((f) => f.dbId == fid)
        .map((f) => f.name)
        .firstOrNull ?? 'Indoor';
    // Drop the new table into the next free spot on the floor plan so it is
    // immediately visible and draggable instead of stacked at 0,0.
    final slot = autoLayoutSlot(
      tables.where((x) => x.floorId == fid).length,
    );
    final row = await db.createTable({
      'floor_id': fid,
      'name': name,
      'capacity': seats,
      'zone': zoneName,
      'x': slot.x,
      'y': slot.y,
      'width': 150,
      'height': 130,
      'shape': shape,
    });
    final t = DemoTable(
      name: name,
      seats: seats,
      status: 'free',
      zone: zoneName,
      floorId: fid,
      dbId: row['id'] as String,
      x: (row['x'] as num?)?.toDouble() ?? slot.x,
      y: (row['y'] as num?)?.toDouble() ?? slot.y,
      shape: (row['shape'] as num?)?.toInt() ?? shape,
      placed: true,
    );
    tables.add(t);
    _tableIdByName[t.name] = t.dbId!;
    notifyListeners();
    return t;
  }

  // ------------------------------------------------------------------
  // Floor plan (table layout)
  // ------------------------------------------------------------------

  /// Persists a table's position/size after a drag or resize on the plan.
  void setTableLayout(DemoTable t) {
    t.placed = true;
    final db = _db;
    if (db != null && t.dbId != null) {
      _persist(() => db.updateTable(t.dbId!, {
            'x': t.x,
            'y': t.y,
            'width': t.width,
            'height': t.height,
            'shape': t.shape,
          }));
    }
    notifyListeners();
  }

  /// Lays every table of [floorId] out on a tidy grid and saves it — the
  /// "Arrange" action for a plan that was never laid out by hand.
  void arrangeFloorLayout(String? floorId) {
    const startX = 40.0, startY = 40.0, colW = 190.0, rowH = 170.0;
    const w = 150.0, h = 130.0, perRow = 5;
    var i = 0;
    for (final t in tables.where((t) => t.floorId == floorId)) {
      t
        ..x = startX + (i % perRow) * colW
        ..y = startY + (i ~/ perRow) * rowH
        ..width = w
        ..height = h
        ..placed = true;
      final db = _db;
      if (db != null && t.dbId != null) {
        _persist(() => db.updateTable(t.dbId!, {
              'x': t.x,
              'y': t.y,
              'width': t.width,
              'height': t.height,
            }));
      }
      i++;
    }
    addAudit('Floor plan arranged', 'update', '${tables.where((t) => t.floorId == floorId).length} tables');
    notifyListeners();
  }

  /// Grid slot used for tables that have no saved position yet.
  static ({double x, double y}) autoLayoutSlot(int index) => (
        x: 40 + (index % 5) * 190,
        y: 40 + (index ~/ 5) * 170,
      );

  /// Orders placed by a customer, newest first. Attributed by the order's
  /// stored customer id when present; the name snapshot is only a fallback
  /// for legacy orders (a renamed record keeps its history either way,
  /// and two same-name records never share history).
  List<DemoOrder> ordersForCustomer(Customer c) {
    final key = c.name.trim().toLowerCase();
    final list = orders.where((o) {
      if (o.customerId != null) {
        // Id attribution: dbId when connected, local id in demo mode.
        return o.customerId == c.dbId || o.customerId == c.id.toString();
      }
      return o.customer.trim().toLowerCase() == key;
    }).toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    return list;
  }

  /// Persists field edits (name / seats / shape) on an existing table.
  void editTable(DemoTable t, {String? name, int? seats, int? shape}) {
    final oldName = t.name;
    if (name != null && name.isNotEmpty) t.name = name;
    if (seats != null) t.seats = seats;
    if (shape != null) t.shape = shape;
    final newName = (name != null && name.isNotEmpty) ? name : null;
    _persist(() async {
      await _db!.updateTable(t.dbId!, {
        'name': ?newName,
        'capacity': ?seats,
        'shape': ?shape,
      });
    });
    // Keep the name -> id lookup and open orders in sync after a rename.
    _tableIdByName.remove(oldName);
    _tableIdByName[t.name] = t.dbId!;
    for (final o in orders) {
      if (o.table == oldName) o.table = t.name;
    }
    notifyListeners();
  }

  /// Moves a table to another zone (or out of any zone when null).
  Future<void> moveTableToFloor(DemoTable t, String? floorId) async {
    t.floorId = floorId;
    // Mirror the zone name onto the legacy column.
    final zoneName = floors
        .where((f) => f.dbId == floorId)
        .map((f) => f.name)
        .firstOrNull;
    if (zoneName != null) t.zone = zoneName;
    notifyListeners();
    if (floorId == null) return; // DB requires a floor; keep UI value only
    try {
      await _db?.updateTable(t.dbId!, {
        'floor_id': floorId,
        'zone': ?zoneName,
      });
    } catch (e) {
      syncError = 'Could not move table: $e';
      notifyListeners();
    }
  }

  /// Removes a table. Blocked while an open order sits on it.
  /// DB delete is deferred — call [deleteTableDb] after the undo window.
  bool deleteTable(DemoTable t) {
    final hasOpenOrder = orders.any(
      (o) => o.table == t.name && o.status != 'Paid' && o.status != 'Cancelled' && o.status != 'Refunded',
    );
    if (hasOpenOrder) return false;
    tables.remove(t);
    _tableIdByName.remove(t.name);
    notifyListeners();
    return true;
  }

  /// DB part of the table delete (deferred for undo).
  void deleteTableDb(DemoTable t) {
    if (t.dbId != null) {
      _persist(() => _db!.deleteTable(t.dbId!));
    }
  }

  // ------------------------------------------------------------------
  // Zones (floors)
  // ------------------------------------------------------------------

  /// Creates a new zone (floor plan area).
  Future<DemoFloor?> addFloor(String name) async {
    final db = _db;
    if (db == null) return null;
    try {
      final row = await db.createFloor({'name': name});
      final f = DemoFloor(name: name, dbId: row['id'] as String);
      floors.add(f);
      notifyListeners();
      return f;
    } catch (e) {
      syncError = 'Could not create zone: $e';
      notifyListeners();
      return null;
    }
  }

  /// Renames a zone. Open orders and tables referencing the old zone name
  /// are updated so check-ins keep working after a rename.
  Future<void> editFloor(DemoFloor f, String name) async {
    final old = f.name;
    f.name = name;
    for (final t in tables) {
      if (t.floorId == f.dbId) t.zone = name;
    }
    notifyListeners();
    try {
      await _db?.updateFloor(f.dbId!, {'name': name});
      // Keep the legacy `tables.zone` mirror in sync for tables in this zone.
      for (final t in tables.where((t) => t.floorId == f.dbId)) {
        if (t.dbId != null) {
          _db?.updateTable(t.dbId!, {'zone': name}).catchError((_) {});
        }
      }
    } catch (e) {
      syncError = 'Could not rename zone: $e';
      f.name = old;
      notifyListeners();
    }
  }

  /// Deletes a zone and all tables on it (cascade in the DB).
  /// Returns false when the zone still has tables with open orders.
  /// Removes a zone and its tables. Blocked while any table under it has
  /// an open order. DB delete deferred — call [deleteFloorDb] after undo.
  Future<bool> deleteFloor(DemoFloor f) async {
    final floorTables = tables.where((t) => t.floorId == f.dbId).toList();
    final blocked = floorTables.any(
      (t) => orders.any(
        (o) =>
            o.table == t.name &&
            o.status != 'Paid' &&
            o.status != 'Cancelled' &&
            o.status != 'Refunded',
      ),
    );
    if (blocked) return false;
    floors.remove(f);
    tables.removeWhere((t) => t.floorId == f.dbId);
    for (final t in floorTables) {
      _tableIdByName.remove(t.name);
    }
    notifyListeners();
    return true;
  }

  /// DB part of the zone delete (deferred for undo). The RPC removes the
  /// floor; its tables cascade.
  void deleteFloorDb(DemoFloor f) {
    if (f.dbId != null) {
      _persist(() => _db!.deleteFloor(f.dbId!));
    }
  }

  /// Free a table by name (design: auto-free on pay).
  void freeTableByName(String? name) {
    if (name == null) return;
    for (final t in tables) {
      if (t.name == name) {
        freeTable(t);
        return;
      }
    }
  }

  // ------------------------------------------------------------------
  // Branches & tax rates
  // ------------------------------------------------------------------

  /// Creates a branch and returns it (null when offline).
  Future<Branch?> addBranch({
    required String name,
    String full = '',
    String city = '',
    String cif = '',
    String manager = '',
    int terminals = 1,
  }) async {
    final db = _db;
    if (db == null) return null;
    final row = await db.createBranch({
      'name': name,
      'full_name': full.isEmpty ? name : full,
      'city': city,
      'cif': cif,
      'manager': manager,
      'terminals': terminals,
      'status': 'active',
    });
    final b = Branch(
      id: branches.length + 1,
      name: name,
      full: full.isEmpty ? name : full,
      city: city,
      cif: cif,
      manager: manager,
      terminals: terminals,
      status: 'active',
      dbId: row['id'] as String,
    );
    branches.add(b);
    addAudit('Branch added', 'create', name);
    notifyListeners();
    return b;
  }

  /// Persists branch edits (all fields).
  void editBranch(Branch b,
      {String? name, String? full, String? city, String? cif, String? manager, int? terminals, String? status}) {
    if (name != null && name.isNotEmpty) b.name = name;
    if (full != null) b.full = full;
    if (city != null) b.city = city;
    if (cif != null) b.cif = cif;
    if (manager != null) b.manager = manager;
    if (terminals != null) b.terminals = terminals;
    if (status != null) b.status = status;
    addAudit('Branch updated', 'update', b.name);
    notifyListeners();
    _persist(() async {
      await _db!.updateBranch(b.dbId!, {
        if (name != null && name.isNotEmpty) 'name': name,
        if (full != null) 'full_name': full,
        if (city != null) 'city': city,
        if (cif != null) 'cif': cif,
        if (manager != null) 'manager': manager,
        if (terminals != null) 'terminals': terminals,
        if (status != null) 'status': status,
      });
    });
  }

  /// Switches the active branch and persists the choice across restarts.
  void selectBranch(String name) {
    if (!branches.any((b) => b.name == name)) return;
    if (currentBranch == name) return;
    currentBranch = name;
    settings['active_branch'] = name;
    notifyListeners();
    final db = _db;
    if (db != null) {
      db.upsertSetting('active_branch', name)
          .catchError((_) => <String, dynamic>{});
      // Re-scope branch-specific data (orders, tables, floors, inventory)
      // to the newly selected location.
      db.activeBranchId = branches.where((b) => b.name == name).firstOrNull?.dbId;
      _kitchenQueue.clear();
      _orderKitchenStage.clear();
      _tableIdByName.clear();
      _lastOrdersSig = '';
      _lastTablesSig = '';
      _persist(() async {
        await _loadReference(db);
        await _loadTransactional(db);
      });
    }
  }

  /// Removes the branch from the UI; DB delete deferred (undo window).
  void deleteBranch(Branch b) {
    branches.remove(b);
    if (currentBranch == b.name && branches.isNotEmpty) {
      currentBranch = branches.first.name;
    }
    addAudit('Branch deleted', 'delete', b.name);
    notifyListeners();
  }

  /// DB part of the branch delete (deferred for undo).
  void deleteBranchDb(Branch b) {
    if (b.dbId != null) {
      _persist(() => _db!.deleteBranch(b.dbId!));
    }
  }

  /// Adds a tax rate. `makeDefault` clears the previous default.
  Future<TaxRate?> addTaxRate({
    required String name,
    required double rate,
    bool isInclusive = true,
    bool makeDefault = false,
  }) async {
    final db = _db;
    if (db == null) return null;
    final row = await db.createTaxRate({
      'name': name,
      'rate': rate,
      'is_inclusive': isInclusive,
      'is_default': makeDefault,
      'is_active': true,
    });
    final t = TaxRate(
      id: taxRates.length + 1,
      name: name,
      rate: rate,
      isInclusive: isInclusive,
      isDefault: makeDefault,
      dbId: row['id'] as String,
    );
    taxRates.add(t);
    if (makeDefault) {
      for (final other in taxRates) {
        if (other != t && other.isDefault) other.isDefault = false;
      }
    }
    _taxRateIdByRate[rate.round()] = t.dbId!;
    addAudit('Tax rate added', 'create', '$name ($rate%)');
    notifyListeners();
    return t;
  }

  /// Persists tax rate edits. Optionally reassigns the default flag.
  void editTaxRate(TaxRate t,
      {String? name, double? rate, bool? isInclusive, bool? makeDefault}) {
    if (name != null && name.isNotEmpty) t.name = name;
    if (rate != null) {
      t.rate = rate;
      _taxRateIdByRate[rate.round()] = t.dbId!;
    }
    if (isInclusive != null) t.isInclusive = isInclusive;
    if (makeDefault == true) {
      for (final other in taxRates) {
        other.isDefault = other == t;
      }
    }
    addAudit('Tax rate updated', 'update', '${t.name} (${t.rate}%)');
    notifyListeners();
    _persist(() async {
      await _db!.updateTaxRate(t.dbId!, {
        if (name != null && name.isNotEmpty) 'name': name,
        if (rate != null) 'rate': rate,
        if (isInclusive != null) 'is_inclusive': isInclusive,
        if (makeDefault == true) 'is_default': true,
      });
    });
  }

  /// Removes the tax rate from the UI; DB delete deferred (undo window).
  void deleteTaxRate(TaxRate t) {
    taxRates.remove(t);
    addAudit('Tax rate deleted', 'delete', '${t.name} (${t.rate}%)');
    notifyListeners();
  }

  /// DB part of the tax-rate delete (deferred for undo).
  void deleteTaxRateDb(TaxRate t) {
    if (t.dbId != null) {
      _persist(() => _db!.deleteTaxRate(t.dbId!));
    }
  }

  /// Saves the signed-in user's profile fields onto their staff record
  /// (phone, PIN hash in settings) and syncs the display name via auth.
  /// Returns an error message, or null on success.
  Future<String?> saveProfile({String? fullName, String? phone, String? pin}) async {
    final me = _currentStaff();
    final authName = fullName?.trim() ?? '';

    // 1. Update the staff `users` row (name + phone) — the source of truth
    //    for the sidebar, orders and audit attribution.
    if (me != null && me.dbId != null) {
      if (authName.isNotEmpty) me.name = authName;
      if (phone != null) me.phone = phone.trim();
      notifyListeners();
      _persist(() async {
        await _db!.updateStaff(me.dbId!, {
          if (authName.isNotEmpty) 'full_name': authName,
          if (phone != null) 'phone': phone.trim(),
        });
      });
    }

    // 2. PIN: stored as a salted hash — never in clear text. Saving a new
    //    PIN also unlocks the current session (you just proved you know it).
    if (pin != null && pin.trim().isNotEmpty) {
      await setPin(pin.trim());
    }

    addAudit('Profile updated', 'update',
        authName.isNotEmpty ? authName : (me?.name ?? 'settings'));
    notifyListeners();

    // 3. Auth metadata (display name) is handled by the caller via
    //    AuthNotifier.updateDisplayName — return name for that purpose.
    return null;
  }

  // ------------------------------------------------------------------
  // POS quick-login PIN
  // ------------------------------------------------------------------
  // Stored as a salted SHA-256 hash in the workspace settings; the plain
  // PIN never leaves memory and is never written to the database.

  bool get hasPin => (settings['pin_hash'] ?? '').isNotEmpty;

  String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt::$pin')).toString();

  String _newSalt() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Sets (or replaces) the POS quick-login PIN.
  Future<void> setPin(String pin) async {
    var salt = settings['pin_salt'] ?? '';
    if (salt.isEmpty) {
      salt = _newSalt();
      settings['pin_salt'] = salt;
    }
    settings['pin_hash'] = _hashPin(pin, salt);
    settings['profile_pin'] = '';
    final db = _db;
    if (db != null) {
      _persist(() async {
        await db.upsertSetting('pin_salt', salt);
        await db.upsertSetting('pin_hash', settings['pin_hash']!);
        await db.upsertSetting('profile_pin', '');
      });
    }
    addAudit('POS PIN updated', 'update', '');
    notifyListeners();
  }

  /// Removes the PIN — the POS then opens without a gate.
  Future<void> clearPin() async {
    settings['pin_hash'] = '';
    settings['profile_pin'] = '';
    final db = _db;
    if (db != null) {
      _persist(() async {
        await db.upsertSetting('pin_hash', '');
        await db.upsertSetting('profile_pin', '');
      });
    }
    addAudit('POS PIN removed', 'delete', '');
    notifyListeners();
  }

  /// True when [pin] matches the stored hash.
  bool verifyPin(String pin) {
    if (!hasPin) return false;
    return _hashPin(pin, settings['pin_salt'] ?? '') == settings['pin_hash'];
  }

  // ------------------------------------------------------------------
  // Products / menu
  // ------------------------------------------------------------------

  /// Adds a product; creates its category / tax rate when missing.
  Future<DemoProduct?> addProduct({
    required String name,
    required String cat,
    required double price,
    double cost = 0,
    required int iva,
    int stock = 0,
    String? img,
    bool avail = true,
  }) async {
    final db = _db;
    if (db == null) return null;
    String? categoryId = _categoryIdByName[cat];
    if (categoryId == null) {
      final created = await db.createCategory({
        'name': cat,
        'sort_order': _categoryIdByName.length + 1,
      });
      categoryId = created['id'] as String;
      _categoryIdByName[cat] = categoryId;
    }
    String? taxRateId = _taxRateIdByRate[iva];
    if (taxRateId == null) {
      final created = await db.client.from('tax_rates').insert({
        'name': 'IVA $iva%',
        'rate': iva,
        'is_inclusive': true,
        'is_active': true,
      }).select().single();
      taxRateId = created['id'] as String;
      _taxRateIdByRate[iva] = taxRateId;
    }
    final row = await db.createProduct({
      'category_id': categoryId,
      'name': name,
      'price': price,
      'cost': cost,
      'stock_qty': stock,
      'image_url': (img == null || img.isEmpty) ? null : img,
      'is_available': avail,
      'tax_rate_id': taxRateId,
      'sort_order': products.length + 1,
    });
    final p = DemoProduct(
      id: products.length + 1,
      name: name,
      cat: cat,
      price: price,
      cost: cost,
      iva: iva,
      stock: stock,
      img: img ?? '',
      sold: 0,
      avail: avail,
      dbId: row['id'] as String,
    );
    products.add(p);
    notifyListeners();
    return p;
  }

  /// Persists field edits on an existing product.
  void updateProduct(DemoProduct p) {
    _persist(() async {
      final db = _db!;
      String? taxRateId = _taxRateIdByRate[p.iva];
      if (taxRateId == null) {
        final created = await db.client.from('tax_rates').insert({
          'name': 'IVA ${p.iva}%',
          'rate': p.iva,
          'is_inclusive': true,
          'is_active': true,
        }).select().single();
        taxRateId = created['id'] as String;
        _taxRateIdByRate[p.iva] = taxRateId;
      }
      await db.updateProduct(p.dbId!, {
        'name': p.name,
        'price': p.price,
        'cost': p.cost,
        'stock_qty': p.stock,
        'is_available': p.avail,
        'image_url': p.img.isEmpty ? null : p.img,
        'tax_rate_id': taxRateId,
      });
    });
  }

  /// Removes the product from the UI. The DB delete is deferred — call
  /// [deleteProductDb] once the undo window has passed.
  void deleteProduct(DemoProduct p) {
    products.remove(p);
    notifyListeners();
  }

  /// DB part of the product delete (deferred for undo).
  void deleteProductDb(DemoProduct p) {
    if (p.dbId != null) {
      _persist(() => _db!.deleteProduct(p.dbId!));
    }
  }

  /// Deducts stock for sold items. Availability is NOT touched here —
  /// an item selling out stays available (staff can still oversell-tolerate
  /// it or disable it manually); the Availability switch is the only thing
  /// that controls whether a dish can be ordered.
  void deductStock(Iterable<CartLine> items) {
    for (final i in items) {
      final p = product(i.productId);
      if (p == null || p.dbId == null) continue;
      p.stock = (p.stock - i.qty).clamp(0, 999999).toInt();
      _persist(() => _db!.updateProduct(p.dbId!, {
            'stock_qty': p.stock,
          }));
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Customers / loyalty / gift cards
  // ------------------------------------------------------------------

  /// Creates a customer record and returns it. Callers link the returned
  /// customer to the active order explicitly — nothing auto-attaches.
  Customer addCustomer({
    required String name,
    required String phone,
    String? email,
  }) {
    final c = Customer(
      id: customerIdSeq++,
      name: name,
      phone: phone,
      email: email,
      visits: 0,
      total: 0,
      points: 0,
      tier: 'Bronze',
      lastVisit: '—',
      diet: 'None',
    );
    customers.add(c);
    _persist(() async {
      final db = _db;
      if (db == null) return;
      final row = await db.createCustomer({
        'name': name,
        'phone': phone,
        'email': ?email,
      });
      c.dbId = row['id'] as String;
    });
    notifyListeners();
    return c;
  }

  /// Customers whose exact name (case-insensitive) matches — used to detect
  /// ambiguity when several records share one name.
  List<Customer> customersNamed(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return const [];
    return customers.where((x) => x.name.toLowerCase() == n).toList();
  }

  /// DEPRECATED hook kept for API compatibility — auto-enrolment was
  /// removed in favour of explicit inline creation in the POS cart.
  /// Returns null always: customers are only created deliberately now.
  Customer? autoEnrolCustomer(String? nameOrPhone, {bool forceNew = false}) {
    return null;
  }

  /// Loyalty settings (persisted in the tenant settings key/values).
  double get earnRate =>
      double.tryParse(settings['loyalty_earn_rate'] ?? '') ?? 1.0;
  double get pointValue =>
      double.tryParse(settings['loyalty_point_value'] ?? '') ?? 0.01;
  bool get loyaltyEnabled =>
      (settings['loyalty_enabled'] ?? 'true') != 'false';

  /// Loyalty tiers — fully user-defined (name + minimum points), stored
  /// as JSON in the settings table. Sorted ascending by threshold.
  List<({String name, int minPoints})> get loyaltyTiers {
    final raw = settings['loyalty_tiers'];
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .map(
              (e) => (
                name: (e as Map<String, dynamic>)['name'] as String,
                minPoints: (e['min_points'] as num).toInt(),
              ),
            )
            .toList()
          ..sort((a, b) => a.minPoints.compareTo(b.minPoints));
        if (list.isNotEmpty) return list;
      } catch (_) {
        // fall through to defaults
      }
    }
    return const [
      (name: 'Bronze', minPoints: 0),
      (name: 'Silver', minPoints: 500),
      (name: 'Gold', minPoints: 2000),
    ];
  }

  /// Replaces the whole tier list and re-tiers every customer.
  void saveLoyaltyTiers(List<({String name, int minPoints})> tiers) {
    final sorted = List.of(tiers)
      ..sort((a, b) => a.minPoints.compareTo(b.minPoints));
    settings['loyalty_tiers'] = jsonEncode(
      sorted
          .map(
            (t) => {'name': t.name, 'min_points': t.minPoints},
          )
          .toList(),
    );
    // Re-tier all customers under the new thresholds.
    for (final c in customers) {
      final newTier = tierFor(c.points);
      if (newTier != c.tier) {
        c.tier = newTier;
        if (c.dbId != null) {
          _persist(() => _db!.updateCustomer(c.dbId!, {'tier': newTier}));
        }
      }
    }
    notifyListeners();
    final db = _db;
    if (db != null) {
      db
          .upsertSetting('loyalty_tiers', settings['loyalty_tiers']!)
          .catchError((_) => <String, dynamic>{});
    }
  }

  // Backwards-compatible accessors used across the UI.
  int get silverThreshold {
    final tiers = loyaltyTiers;
    return tiers.length > 1 ? tiers[1].minPoints : 500;
  }

  int get goldThreshold {
    final tiers = loyaltyTiers;
    return tiers.length > 2 ? tiers[2].minPoints : 2000;
  }

  String tierFor(int points) {
    final tiers = loyaltyTiers;
    var tier = tiers.first.name;
    for (final t in tiers) {
      if (points >= t.minPoints) tier = t.name;
    }
    return tier;
  }

  /// Credits loyalty points/visits for a paid order. Only an explicitly
  /// linked customer is credited — matched by id (dbId when connected,
  /// local id in demo mode), never by name, so duplicate-name records can
  /// never receive each other's credit. Nothing is created implicitly.
  void creditCustomer(String? customerIdOrName, double amount) {
    if (customerIdOrName == null) return;
    Customer? c;
    for (final x in customers) {
      if (x.id.toString() == customerIdOrName ||
          (x.dbId != null && x.dbId == customerIdOrName)) {
        c = x;
        break;
      }
    }
    if (c == null) return;
    final cc = c;
    if (loyaltyEnabled) cc.points += (amount * earnRate).floor();
    cc.total += amount;
    cc.visits++;
    cc.lastVisit = 'Today';
    cc.tier = tierFor(cc.points);
    final db = _db;
    if (cc.dbId != null && db != null) {
      _persist(() => db.updateCustomer(cc.dbId!, {
            'points': cc.points,
            'total_spent': cc.total,
            'visits': cc.visits,
            'tier': cc.tier,
            'last_visit_at': DateTime.now().toIso8601String(),
          }));
    }
    notifyListeners();
  }

  /// Redeems loyalty points for a euro discount and persists the change.
  /// Returns the euro value redeemed (0 when the customer lacks points).
  double redeemPoints(Customer c, int points) {
    final usable = points.clamp(0, c.points);
    if (usable == 0) return 0;
    c.points -= usable;
    c.tier = tierFor(c.points);
    if (c.dbId != null) {
      _persist(() => _db!.updateCustomer(c.dbId!, {
            'points': c.points,
            'tier': c.tier,
          }));
    }
    notifyListeners();
    return usable * pointValue;
  }

  void updateCustomer(Customer c) {
    final db = _db;
    if (c.dbId != null && db != null) {
      _persist(() => db.updateCustomer(c.dbId!, {
            'name': c.name,
            'phone': c.phone,
            'email': c.email,
            'notes': c.diet == 'None' ? null : c.diet,
          }));
    }
    notifyListeners();
  }

  /// Removes the customer from the UI; DB delete deferred (undo window).
  void deleteCustomer(Customer c) {
    customers.remove(c);
    // Unlink the cart if the deleted customer is attached to it.
    if (c.dbId != null && cartMeta['customerId'] == c.dbId) {
      cartMeta['customer'] = null;
      cartMeta['customerId'] = null;
    }
    notifyListeners();
  }

  /// DB part of the customer delete (deferred for undo). After the undo
  /// window the record is really gone, so orders that pointed at it lose
  /// their id link (applied in memory regardless of connectivity) — their
  /// name snapshot keeps the history readable.
  void deleteCustomerDb(Customer c) {
    final dbId = c.dbId;
    if (dbId == null) return;
    for (final o in orders) {
      if (o.customerId == dbId) o.customerId = null;
    }
    final db = _db;
    if (db != null) {
      _persist(() => db.deleteCustomer(dbId));
    }
  }

  void issueGiftCard({
    required double amount,
    String recipient = '',
    String? code,
  }) {
    final finalCode = (code == null || code.isEmpty) ? _gcCode() : code;
    // Both the UI copy and the database row use the same 12-month validity,
    // so the card listing can never disagree with the stored record.
    final expiresAt = DateTime.now().add(const Duration(days: 365));
    final expiresDate =
        '${expiresAt.year}-${expiresAt.month.toString().padLeft(2, '0')}-${expiresAt.day.toString().padLeft(2, '0')}';
    final g = GiftCard(
      id: giftCards.length + 1,
      code: finalCode,
      amount: amount,
      balance: amount,
      recipient: recipient,
      issued: dateNow,
      expiry: _dateStr(expiresAt.toIso8601String()),
      status: 'Active',
    );
    giftCards.insert(0, g);
    _persist(() async {
      final row = await _db!.createGiftCard({
        'code': finalCode,
        'amount': amount,
        'balance': amount,
        if (recipient.isNotEmpty) 'recipient': recipient,
        'expires_at': expiresDate,
      });
      g.dbId = row['id'] as String;
    });
    addAudit(
      'Gift card issued',
      'create',
      '$finalCode · ${fmt(amount)}${recipient.isEmpty ? '' : ' to $recipient'}',
    );
    notifyListeners();
  }

  void redeemGiftCard(int? id, double amount) {
    if (id == null) return;
    for (final g in giftCards) {
      if (g.id == id) {
        g.balance = (g.balance - amount).clamp(0, 1e9);
        if (g.balance == 0) g.status = 'Redeemed';
        if (g.dbId != null) {
          _persist(() => _db!.updateGiftCard(g.dbId!, {
                'balance': g.balance,
                'status': g.status,
              }));
        }
        break;
      }
    }
    notifyListeners();
  }

  /// Adds credit to an existing gift card (top-up). Returns true on success.
  bool topUpGiftCard(GiftCard g, double amount) {
    if (amount <= 0 || g.status == 'Expired') return false;
    g.amount += amount;
    g.balance += amount;
    if (g.status == 'Redeemed' && g.balance > 0) g.status = 'Active';
    if (g.dbId != null) {
      _persist(() => _db!.updateGiftCard(g.dbId!, {
            'amount': g.amount,
            'balance': g.balance,
            'status': g.status,
          }));
    }
    addAudit('Gift card topped up', 'update',
        '${g.code} · +${fmt(amount)} → ${fmt(g.balance)}');
    notifyListeners();
    return true;
  }

  /// Sets a gift card's active/expired state (freeze or re-enable it).
  void setGiftCardStatus(GiftCard g, String status) {
    g.status = status;
    if (g.dbId != null) {
      _persist(() => _db!.updateGiftCard(g.dbId!, {'status': status}));
    }
    addAudit('Gift card $status', 'update', g.code);
    notifyListeners();
  }

  /// Updates a gift card's recipient (assign / reassign / clear).
  void updateGiftCardRecipient(GiftCard g, String recipient) {
    g.recipient = recipient;
    if (g.dbId != null) {
      _persist(() => _db!.updateGiftCard(g.dbId!, {
            'recipient': recipient.isEmpty ? null : recipient,
          }));
    }
    addAudit(
      'Gift card recipient updated',
      'update',
      '${g.code} → ${recipient.isEmpty ? '—' : recipient}',
    );
    notifyListeners();
  }

  /// Adjusts a card's balance directly (e.g. corrections). Refuses to go
  /// below 0. Returns true when the change was applied.
  bool adjustGiftCardBalance(GiftCard g, double newBalance) {
    if (newBalance < 0) return false;
    g.balance = newBalance;
    if (g.balance > g.amount) g.amount = g.balance;
    if (g.balance == 0 && g.status == 'Active') g.status = 'Redeemed';
    if (g.balance > 0 && g.status == 'Redeemed') g.status = 'Active';
    if (g.dbId != null) {
      _persist(() => _db!.updateGiftCard(g.dbId!, {
            'balance': g.balance,
            'amount': g.amount,
            'status': g.status,
          }));
    }
    addAudit(
      'Gift card balance adjusted',
      'update',
      '${g.code} → ${fmt(newBalance)}',
    );
    notifyListeners();
    return true;
  }

  /// Removes the gift card from the UI; DB delete deferred (undo window).
  void deleteGiftCard(GiftCard g) {
    giftCards.remove(g);
    addAudit('Gift card deleted', 'delete', g.code);
    notifyListeners();
  }

  /// DB part of the gift-card delete (deferred for undo).
  void deleteGiftCardDb(GiftCard g) {
    if (g.dbId != null) {
      _persist(() => _db!.deleteGiftCard(g.dbId!));
    }
  }

  /// Saves a loyalty setting and mirrors it to the DB settings table.
  void saveLoyaltySetting(String key, String value) {
    settings[key] = value;
    notifyListeners();
    final db = _db;
    if (db != null) {
      db.upsertSetting(key, value).catchError((_) => <String, dynamic>{});
    }
  }

  // ------------------------------------------------------------------
  // Staff
  // ------------------------------------------------------------------

  /// Creates a staff member together with a real login account.
  /// The `create_staff_user` RPC (security definer) provisions the auth
  /// user, links it to this workspace and stamps the tenant claim.
  /// Returns null on success or a user-readable error message.
  Future<String?> addStaff({
    required String name,
    required String email,
    required String password,
    required String role,
    required String phone,
    String hired = '',
  }) async {
    final db = _db;
    if (db == null) return 'Not connected to the workspace';
    try {
      final row = await db.client.rpc(
        'create_staff_user',
        params: {
          'p_email': email.trim(),
          'p_password': password,
          'p_full_name': name.trim(),
          'p_role': role,
          'p_phone': phone.trim().isEmpty ? null : phone.trim(),
        },
      ) as Map<String, dynamic>;
      staff.add(StaffMember(
        id: staff.length + 1,
        name: name.trim(),
        role: role,
        phone: phone,
        hired: hired.isEmpty ? dateNow : hired,
        dbId: row['id'] as String?,
        authId: row['user_id'] as String?,
        email: row['email'] as String?,
      ));
      addAudit('Staff account created', 'create',
          '$name · $role · ${email.trim()}');
      notifyListeners();
      return null;
    } catch (e) {
      return _readableRpcError(e);
    }
  }

  /// Extracts the human message from a PostgREST/Supabase error.
  String _readableRpcError(Object e) {
    final raw = e.toString();
    final marker = 'failure:';
    final idx = raw.indexOf(marker);
    var msg = idx >= 0 ? raw.substring(idx + marker.length).trim() : raw;
    if (msg.length > 160) msg = '${msg.substring(0, 157)}...';
    return msg.isEmpty ? 'The operation was rejected by the server.' : msg;
  }

  /// Replaces a staff member's login password via the `set_staff_password`
  /// RPC (security definer — the client cannot write to auth.users).
  /// Returns null on success or a user-readable error message.
  Future<String?> changeStaffPassword(
    StaffMember s,
    String password,
  ) async {
    final db = _db;
    if (db == null) return 'Not connected to the workspace';
    if (s.dbId == null) return 'This member has no staff record';
    if (!s.canLogIn) {
      return 'This member has no login account yet';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    try {
      await db.client.rpc(
        'set_staff_password',
        params: {'p_staff_id': s.dbId, 'p_password': password},
      );
      addAudit('Staff password changed', 'update', s.name);
      notifyListeners();
      return null;
    } catch (e) {
      return _readableRpcError(e);
    }
  }

  void updateStaff(StaffMember s) {
    if (s.dbId != null) {
      _persist(() => _db!.updateStaff(s.dbId!, {
            'full_name': s.name,
            'role': s.role,
            'phone': s.phone,
            'is_active': s.active,
          }));
    }
    notifyListeners();
  }

  /// Removes the staff member from the UI; DB delete deferred (undo window).
  void deleteStaff(StaffMember s) {
    staff.remove(s);
    addAudit('Staff member removed', 'delete', s.name);
    notifyListeners();
  }

  /// DB part of the staff delete (deferred for undo).
  void deleteStaffDb(StaffMember s) {
    if (s.dbId != null) {
      _persist(() => _db!.deleteStaff(s.dbId!));
    }
  }

  // ------------------------------------------------------------------
  // Custom staff roles & permissions
  // ------------------------------------------------------------------

  /// The active role list: custom roles created by the owner, plus the
  /// built-in defaults so a fresh workspace works out of the box.
  List<StaffRole> get roles {
    if (customRoles.isNotEmpty) return customRoles;
    return const [
      StaffRole(name: 'Owner', permissions: {Permissions.all}),
      StaffRole(name: 'Manager', permissions: {
        Permissions.all,
      }),
      StaffRole(name: 'Cashier', permissions: {
        Permissions.pos,
        Permissions.orders,
        Permissions.tables,
        Permissions.customers,
        Permissions.shift,
        Permissions.discounts,
      }),
      StaffRole(name: 'Chef', permissions: {Permissions.kitchen}),
      StaffRole(name: 'Waiter', permissions: {
        Permissions.pos,
        Permissions.orders,
        Permissions.tables,
      }),
    ];
  }

  StaffRole? roleFor(String name) {
    for (final r in roles) {
      if (r.name.toLowerCase() == name.toLowerCase()) return r;
    }
    return null;
  }

  /// Permissions of the given staff member's role (falls back to POS-only).
  Set<String> permissionsFor(StaffMember s) {
    // The workspace owner always has everything.
    if (s.role.toLowerCase() == 'owner') return {Permissions.all};
    return roleFor(s.role)?.permissions ?? {Permissions.pos};
  }

  bool staffCan(StaffMember s, String permission) {
    final p = permissionsFor(s);
    return p.contains(Permissions.all) || p.contains(permission);
  }

  /// The signed-in staff member's row (null when the auth account has no
  /// linked staff record).
  StaffMember? get me => _currentStaff();

  /// Permissions granted to the signed-in member. Defaults to full access
  /// when no staff row is linked (e.g. the very first owner login).
  Set<String> get myPermissions {
    final s = _currentStaff();
    if (s == null) return {Permissions.all};
    return permissionsFor(s);
  }

  /// Whether the signed-in member may access [permission].
  bool can(String permission) {
    final p = myPermissions;
    return p.contains(Permissions.all) || p.contains(permission);
  }

  void _loadCustomRoles() {
    customRoles.clear();
    final raw = settings['staff_roles'];
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => StaffRole.fromJson(e as Map<String, dynamic>))
          .toList();
      customRoles.addAll(list);
    } catch (_) {
      // Corrupt payload — fall back to the defaults.
    }
  }

  void _persistRoles() {
    settings['staff_roles'] = jsonEncode(
      customRoles.map((r) => r.toJson()).toList(),
    );
    final db = _db;
    if (db != null) {
      db
          .upsertSetting('staff_roles', settings['staff_roles']!)
          .catchError((_) => <String, dynamic>{});
    }
  }

  /// Replaces the whole custom-role list (used by the role editor).
  void saveRoles(List<StaffRole> newRoles) {
    customRoles
      ..clear()
      ..addAll(newRoles);
    _persistRoles();
    addAudit(
      'Staff roles updated',
      'update',
      newRoles.map((r) => r.name).join(', '),
    );
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Suppliers
  // ------------------------------------------------------------------

  void addSupplier({
    required String name,
    required String contact,
    required String phone,
    required String email,
    required String cat,
    required String terms,
    required String addr,
  }) {
    final s = Supplier(
      id: suppliers.length + 1,
      name: name,
      contact: contact,
      phone: phone,
      email: email,
      cat: cat,
      terms: terms,
      addr: addr,
    );
    suppliers.add(s);
    _persist(() async {
      final row = await _db!.createSupplier({
        'name': name,
        'contact': contact,
        'phone': phone,
        'email': email,
        'category': cat,
        'terms': terms,
        'address': addr,
      });
      // Suppliers are immutable in the UI — replaced wholesale on edit.
      final index = suppliers.indexOf(s);
      if (index >= 0) {
        suppliers[index] = Supplier(
          id: s.id,
          name: name,
          contact: contact,
          phone: phone,
          email: email,
          cat: cat,
          terms: terms,
          addr: addr,
          dbId: row['id'] as String,
        );
      }
    });
    notifyListeners();
  }

  void updateSupplier(Supplier s, {required String name, required String contact, required String phone, required String email, required String cat, required String terms, required String addr}) {
    if (s.dbId == null) return;
    final index = suppliers.indexOf(s);
    if (index >= 0) {
      suppliers[index] = Supplier(
        id: s.id,
        name: name,
        contact: contact,
        phone: phone,
        email: email,
        cat: cat,
        terms: terms,
        addr: addr,
        dbId: s.dbId,
      );
    }
    _persist(() => _db!.updateSupplier(s.dbId!, {
          'name': name,
          'contact': contact,
          'phone': phone,
          'email': email,
          'category': cat,
          'terms': terms,
          'address': addr,
        }));
    notifyListeners();
  }

  /// Removes the supplier from the UI; DB delete deferred (undo window).
  void deleteSupplier(Supplier s) {
    suppliers.remove(s);
    notifyListeners();
  }

  /// DB part of the supplier delete (deferred for undo).
  void deleteSupplierDb(Supplier s) {
    if (s.dbId != null) {
      _persist(() => _db!.deleteSupplier(s.dbId!));
    }
  }

  /// Supplier categories — fully user-defined, stored as a JSON string list
  /// in the settings table.
  List<String> get supplierCategories {
    final raw = settings['supplier_categories'];
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).map((e) => e as String).toList();
        if (list.isNotEmpty) return list;
      } catch (_) {
        // fall through to defaults
      }
    }
    return const [
      'Food & Beverages',
      'Meat & Seafood',
      'Dairy',
      'Bakery',
      'Vegetables',
      'Cleaning',
      'Dry goods',
    ];
  }

  /// Replaces the category list. Suppliers pointing at a removed category
  /// are moved to the first remaining one (or 'General' if none left).
  void saveSupplierCategories(List<String> cats) {
    final cleaned = cats.map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    if (cleaned.isEmpty) cleaned.add('General');
    settings['supplier_categories'] = jsonEncode(cleaned);
    final fallback = cleaned.first;
    for (var i = 0; i < suppliers.length; i++) {
      final s = suppliers[i];
      if (!cleaned.contains(s.cat)) {
        suppliers[i] = Supplier(
          id: s.id,
          name: s.name,
          contact: s.contact,
          phone: s.phone,
          email: s.email,
          cat: fallback,
          terms: s.terms,
          addr: s.addr,
          dbId: s.dbId,
        );
        if (s.dbId != null) {
          _persist(
            () => _db!.updateSupplier(s.dbId!, {'category': fallback}),
          );
        }
      }
    }
    notifyListeners();
    final db = _db;
    if (db != null) {
      db
          .upsertSetting('supplier_categories', settings['supplier_categories']!)
          .catchError((_) => <String, dynamic>{});
    }
  }

  // ------------------------------------------------------------------
  // Inventory / purchase orders
  // ------------------------------------------------------------------

  void addInventoryItem({
    required String name,
    required String cat,
    required String sku,
    required double qty,
    required String unit,
    required double cost,
    required double reorder,
    required String supplier,
    required String expiry,
  }) {
    final i = InvItem(
      id: inventory.length + 1,
      name: name,
      cat: cat,
      sku: sku,
      qty: qty,
      unit: unit,
      cost: cost,
      reorder: reorder,
      supplier: supplier,
      expiry: expiry,
    );
    inventory.add(i);
    _persist(() async {
      final row = await _db!.createInventoryItem({
        'name': name,
        'category': cat,
        'sku': sku,
        'quantity': qty,
        'unit': unit,
        'cost': cost,
        'reorder_level': reorder,
        'supplier_name': supplier,
        if (expiry.isNotEmpty) 'expiry': expiry,
      });
      i.dbId = row['id'] as String;
    });
    notifyListeners();
  }

  void updateInventoryItem(InvItem i) {
    if (i.dbId != null) {
      _persist(() => _db!.updateInventoryItem(i.dbId!, {
            'name': i.name,
            'category': i.cat,
            'quantity': i.qty,
            'unit': i.unit,
            'cost': i.cost,
            'reorder_level': i.reorder,
            if (i.expiry.isNotEmpty) 'expiry': i.expiry else 'expiry': null,
          }));
    }
    notifyListeners();
  }

  /// Removes the stock item from the UI; DB delete deferred (undo window).
  void deleteInventoryItem(InvItem i) {
    inventory.remove(i);
    notifyListeners();
  }

  /// DB part of the stock-item delete (deferred for undo).
  void deleteInventoryItemDb(InvItem i) {
    if (i.dbId != null) {
      _persist(() => _db!.deleteInventoryItem(i.dbId!));
    }
  }

  void createPurchaseOrder({
    required String supplier,
    required List<PoLine> lines,
    required String expected,
  }) {
    final db = _db;
    final seq = purchaseOrders
        .where((p) => p.id.contains(DateTime.now().year.toString()))
        .length +
        1;
    final id = 'PO-${DateTime.now().year}-'
        '${seq.toString().padLeft(4, '0')}';
    final po = PurchaseOrder(
      id: id,
      supplier: supplier,
      lines: lines,
      expected: expected,
      status: 'Pending',
    );
    purchaseOrders.insert(0, po);
    _persist(() async {
      if (db == null) return;
      final row = await db.createPurchaseOrder({
        'po_number': id,
        'supplier_name': supplier,
        'items_count': lines.length,
        'total': po.total,
        if (expected.isNotEmpty) 'expected_at': expected,
        'notes': po.linesJson,
        'status': 'Pending',
      });
      po.dbId = row['id'] as String;
    });
    notifyListeners();
  }

  /// Adds a PO's lines into inventory stock and marks it Received.
  void receivePurchaseOrder(PurchaseOrder po) {
    final db = _db;
    po.status = 'Received';
    for (final line in po.lines) {
      InvItem? item;
      for (final i in inventory) {
        if (i.name.toLowerCase() == line.item.toLowerCase()) {
          item = i;
          break;
        }
      }
      if (item != null) {
        // Existing stock item — top up and refresh cost.
        final target = item;
        target.qty += line.qty;
        if (line.cost > 0) target.cost = line.cost;
        if (db != null && target.dbId != null) {
          _persist(() => db.updateInventoryItem(target.dbId!, {
                'quantity': target.qty,
                'cost': target.cost,
              }));
        }
      } else {
        // Unknown item — create a new stock record from the line.
        addInventoryItem(
          name: line.item,
          cat: 'Dry goods',
          sku: 'SKU-${inventory.length + 100}',
          qty: line.qty,
          unit: 'units',
          cost: line.cost,
          reorder: (line.qty * 0.2).ceilToDouble().clamp(1, 50),
          supplier: po.supplier,
          expiry: '',
        );
      }
    }
    if (db != null && po.dbId != null) {
      _persist(() => db.updatePurchaseOrder(po.dbId!, {'status': 'Received'}));
    }
    addAudit(
      'Purchase order received',
      'update',
      '${po.id} · ${po.lines.length} lines into stock',
    );
    notifyListeners();
  }

  /// Cancels a pending PO.
  void cancelPurchaseOrder(PurchaseOrder po) {
    po.status = 'Cancelled';
    if (_db != null && po.dbId != null) {
      _persist(
        () => _db!.updatePurchaseOrder(po.dbId!, {'status': 'Cancelled'}),
      );
    }
    addAudit('Purchase order cancelled', 'update', po.id);
    notifyListeners();
  }

  /// Removes the purchase order from the UI; DB delete deferred (undo).
  void deletePurchaseOrder(PurchaseOrder po) {
    purchaseOrders.remove(po);
    notifyListeners();
  }

  /// DB part of the PO delete (deferred for undo).
  void deletePurchaseOrderDb(PurchaseOrder po) {
    if (_db != null && po.dbId != null) {
      _persist(() => _db!.deletePurchaseOrder(po.dbId!));
    }
  }

  // ------------------------------------------------------------------
  // Shifts / cash drawer
  // ------------------------------------------------------------------

  /// Opens a shift with an opening float.
  Future<void> openShift({required double float}) async {
    final db = _db;
    if (db == null) return;
    final staffId = _currentStaffDbId;
    if (staffId == null) {
      syncError = 'Your account is not linked to a staff profile yet. '
          'Ask an owner to add you from Staff.';
      notifyListeners();
      return;
    }
    try {
      final row = await db.openShift({
        'user_id': staffId,
        'opening_cash': float,
        'status': 0,
      });
      _openShiftId = row['id'] as String;
      shift = {
        'open': true,
        'cashier': _currentUserName(),
        'openedAt': DateTime.now(),
        'float': float,
        'cashSales': 0.0,
        'cashRefunds': 0.0,
        'cashInOut': 0.0,
        'movements': <CashMovement>[
          CashMovement(
            time: timeNow,
            type: 'Opening float',
            note: 'Shift open',
            amount: float,
            by: _currentUserName(),
          ),
        ],
      };
      addAudit('Cash drawer opened', 'auth', 'Shift opened · Float ${fmt(float)}');
      notifyListeners();
    } catch (e) {
      syncError = 'Could not open shift: $e';
      notifyListeners();
    }
  }

  /// Closes the open shift with counted drawer → Z-Report.
  Future<void> closeShift({required double counted}) async {
    final db = _db;
    if (db == null || _openShiftId == null) return;
    final float = (shift['float'] as num?)?.toDouble() ?? 0;
    final sales = (shift['cashSales'] as num?)?.toDouble() ?? 0;
    final refunds = (shift['cashRefunds'] as num?)?.toDouble() ?? 0;
    final inOut = (shift['cashInOut'] as num?)?.toDouble() ?? 0;
    final expected = float + sales - refunds + inOut;
    final variance = counted - expected;
    try {
      await db.closeShift(_openShiftId!, {
        'closing_cash': counted,
        'expected_cash': expected,
        'variance': variance,
        'status': 1,
        'closed_at': DateTime.now().toIso8601String(),
      });
      shift = {
        'open': false,
        'cashier': '—',
        'openedAt': null,
        'float': 0.0,
        'cashSales': 0.0,
        'cashRefunds': 0.0,
        'cashInOut': 0.0,
        'movements': <CashMovement>[],
      };
      _openShiftId = null;
      addAudit(
        'Daily Z-Report generated',
        'pay',
        'Cash ${fmt(sales)} · Variance ${fmt(variance)}',
      );
      notifyListeners();
    } catch (e) {
      syncError = 'Could not close shift: $e';
      notifyListeners();
    }
  }

  /// Registers a cash in/out movement.
  void addCashMovement({required String type, required double amount, required String note}) {
    final db = _db;
    final open = shift['open'] as bool? ?? false;
    if (db == null || _openShiftId == null || !open) return;
    final by = _currentUserName();
    final movements = (shift['movements'] as List).cast<CashMovement>();
    movements.add(CashMovement(
      time: timeNow,
      type: type,
      note: note,
      amount: amount,
      by: by,
    ));
    final inOut = (shift['cashInOut'] as num?)?.toDouble() ?? 0;
    shift['cashInOut'] = inOut + amount;
    _persist(() async {
      await db.createCashMovement({
        'shift_id': _openShiftId,
        'type': amount < 0 ? 1 : 0, // CashOut | CashIn
        'amount': amount,
        'reason': '$type — $note',
        'user_id': _currentStaffDbId,
      });
      await db.closeShift(_openShiftId!, {'cash_in_out': shift['cashInOut']});
    });
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Audit / notifications
  // ------------------------------------------------------------------

  void addAudit(
    String action,
    String type,
    String detail, {
    String user = '',
    String role = '',
  }) {
    auditLogs.insert(
      0,
      AuditEntry(
        id: auditLogs.length + 1,
        action: action,
        type: type,
        user: user.isEmpty ? _currentUserName() : user,
        role: role.isEmpty ? _currentUserRole() : role,
        detail: detail,
        time: 'Just now',
        createdAt: DateTime.now(),
      ),
    );
    final db = _db;
    if (db != null) {
      lastAuditBytes = Uint8List.fromList(utf8.encode('$action|$type|$detail'));
      _persist(() => db.createAuditLog({
            'action': action,
            'entity_type': type,
            'entity_id': 'manual',
            'new_values': detail,
            'user_id': _currentStaffDbId,
          }));
    } else {
      lastAuditBytes = null;
    }
    notifyListeners();
  }

  void addNotif(String title, String subtitle, String kind) {
    notifs.insert(
      0,
      AppNotification(
        title: title,
        subtitle: subtitle,
        time: 'Just now',
        kind: kind,
      ),
    );
    _persist(() async {
      final row = await _db!.createNotification({
        'title': title,
        'subtitle': subtitle,
        'kind': kind,
        'unread': true,
      });
      notifs[0].dbId = row['id'] as String;
    });
    notifyListeners();
  }

  void markAllRead() {
    for (final n in notifs) {
      n.unread = false;
    }
    _persist(() => _db!.markNotificationsRead());
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Settings / tenant
  // ------------------------------------------------------------------

  void saveSetting(String key, String value) {
    settings[key] = value;
    _persist(() => _db!.upsertSetting(key, value));
    notifyListeners();
  }

  void saveRestaurant(Map<String, String> info) {
    for (final e in info.entries) {
      settings[e.key] = e.value;
    }
    _persist(() async {
      final db = _db!;
      await db.updateTenant({
        'name': info['name'],
        'address': info['address'],
        'phone': info['phone'],
        'email': info['email'],
      });
      for (final e in info.entries) {
        if (e.key == 'name' || e.key == 'address' || e.key == 'phone' || e.key == 'email') continue;
        await db.upsertSetting(e.key, e.value);
      }
    });
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  String _currentUserName() {
    final me = _currentStaff();
    if (me != null) return me.name;
    return _db?.client.auth.currentUser?.email ?? 'Owner';
  }

  String _currentUserRole() => _currentStaff()?.role ?? 'Owner';

  /// The signed-in user's row in `users` (matched via the auth user_id link).
  StaffMember? _currentStaff() {
    final authId = _db?.client.auth.currentUser?.id;
    if (authId == null) return null;
    for (final s in staff) {
      if (s.authId == authId) return s;
    }
    return null;
  }

  /// The signed-in user's `users.id`, used as waiter_id on new orders.
  String? get _currentStaffDbId => _currentStaff()?.dbId;

  int _orderType(String type) => switch (type) {
        'Take Away' => 1,
        'Delivery' => 2,
        _ => 0,
      };

  int _orderStatus(String s) => switch (s) {
        'Paid' => 6,
        'Cancelled' => 5,
        'Refunded' => 7,
        'Preparing' => 1,
        'Ready' => 3,
        _ => 0,
      };

  String _orderStatusName(int s) => switch (s) {
        0 => 'Pending',
        1 => 'Preparing',
        2 => 'Preparing',
        3 => 'Ready',
        4 => 'Paid',
        5 => 'Cancelled',
        6 => 'Paid',
        7 => 'Refunded',
        _ => 'Pending',
      };

  double _taxFor(double base, int iva) => base * iva / 100;

  String _gcCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    final code = List.generate(5, (_) => chars[r.nextInt(chars.length)]).join();
    return 'BP-GC-$code';
  }

  /// Public code generator for the issue-gift-card dialog.
  String generateGiftCardCode() => _gcCode();

  String _clock(String? iso) {
    if (iso == null) return '--:--';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '--:--';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _relTime(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    final diff = DateTime.now().difference(d.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _dateStr(iso);
  }

  String _dateStr(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Spanish-style money format: €1.847,20 (dot thousands, comma decimals).
String fmt(num value) {
  final neg = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final buf = StringBuffer();
  for (var i = 0; i < parts[0].length; i++) {
    if (i > 0 && (parts[0].length - i) % 3 == 0) buf.write('.');
    buf.write(parts[0][i]);
  }
  final s = '€$buf,${parts[1]}';
  return neg ? '−$s' : s;
}

/// Global app store singleton.
final demo = AppStore();

/// Random helpers reused across views.
final _rng = Random();

List<T> shuffled<T>(List<T> items) => List<T>.of(items)..shuffle(_rng);
