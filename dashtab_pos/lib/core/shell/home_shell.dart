import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../security/app_lock.dart';
import '../theme/app_theme.dart';
import '../theme/app_icons.dart';
import '../theme/app_widgets.dart';
import '../theme/demo_data.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'widgets/pin_pad.dart';

/// Current shell view — mirrors the HTML nav-item data-view.
class ShellView {
  final String key;
  final String title;
  final String subtitle;
  const ShellView(this.key, this.title, this.subtitle);
}

final viewsProvider = Provider<List<ShellView>>((ref) {
  const main = [
    ShellView('dashboard', 'Dashboard', 'Overview & live activity'),
    ShellView('pos', 'New Order', 'Point of Sale terminal · Register A'),
    ShellView('orders', 'Orders', 'Manage, resume, refund & split orders'),
    ShellView('tables', 'Tables', 'Floor & seating management'),
    ShellView('kitchen', 'Kitchen Display', 'Live preparation queue'),
  ];
  const manage = [
    ShellView('menu', 'Menu Items', 'Products, stock & availability'),
    ShellView(
      'inventory',
      'Inventory',
      'Stock, purchase orders & product margins',
    ),
    ShellView('suppliers', 'Suppliers', 'Vendor management'),
    ShellView('customers', 'Customers', 'Database, loyalty & gift cards'),
    ShellView('staff', 'Staff', 'Team & login accounts'),
  ];
  const ops = [
    ShellView(
      'shift',
      'Shift & Cash',
      'Daily closing, reconciliation & Z-report',
    ),
    ShellView('audit', 'Audit Logs', 'Insert-only activity trail'),
    ShellView(
      'reports',
      'Reports',
      'Sales, VAT, performance & profit analytics',
    ),
    ShellView(
      'settings',
      'Settings',
      'Profile, restaurant, fiscal & workspace',
    ),
  ];
  return [...main, ...manage, ...ops];
});

class CurrentViewNotifier extends Notifier<ShellView> {
  @override
  ShellView build() =>
      const ShellView('dashboard', 'Dashboard', 'Overview & live activity');

  void go(ShellView view) {
    state = view;
    demo.view = view.key;
  }
}

final currentViewProvider = NotifierProvider<CurrentViewNotifier, ShellView>(
  CurrentViewNotifier.new,
);

/// UI overlay state (notifications/branch dropdowns).
class UiStateNotifier extends Notifier<UiState> {
  @override
  UiState build() => const UiState();

  void toggleNotifs() => state = state.copyWith(notifsOpen: !state.notifsOpen);
  void closeNotifs() => state = state.copyWith(notifsOpen: false);
  void toggleBranch() => state = state.copyWith(branchOpen: !state.branchOpen);
  void closeBranch() => state = state.copyWith(branchOpen: false);
}

class UiState {
  final bool notifsOpen;
  final bool branchOpen;
  const UiState({this.notifsOpen = false, this.branchOpen = false});
  UiState copyWith({bool? notifsOpen, bool? branchOpen}) => UiState(
    notifsOpen: notifsOpen ?? this.notifsOpen,
    branchOpen: branchOpen ?? this.branchOpen,
  );
}

final uiStateProvider = NotifierProvider<UiStateNotifier, UiState>(
  UiStateNotifier.new,
);

/// Theme mode provider for persistence + toggle.
class ThemeModeNotifier extends Notifier<bool> {
  @override
  bool build() => demo.isDark;

  void toggle() {
    state = !state;
    demo.isDark = state;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, bool>(
  ThemeModeNotifier.new,
);

/// The persistent app shell: sidebar + topbar + content.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

/// Permission required to open each shell view. Dashboard is the landing
/// screen and is always available so nobody can lock themselves out.
const _viewPermission = <String, String>{
  'pos': Permissions.pos,
  'orders': Permissions.orders,
  'tables': Permissions.tables,
  'kitchen': Permissions.kitchen,
  'menu': Permissions.menu,
  'inventory': Permissions.inventory,
  'suppliers': Permissions.suppliers,
  'customers': Permissions.customers,
  'staff': Permissions.staff,
  'shift': Permissions.shift,
  'audit': Permissions.audit,
  'reports': Permissions.reports,
  'settings': Permissions.settings,
};

/// Whether the signed-in member may open the view with this [key].
bool canOpenView(String key) {
  final permission = _viewPermission[key];
  if (permission == null) return true; // dashboard and any future view
  return demo.can(permission);
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late Timer _clockTimer;
  String _clockText = '--:--';
  final _searchController = TextEditingController();
  final _searchLink = LayerLink();
  final _searchPortal = OverlayPortalController();
  final _notifLink = LayerLink();
  final _notifPortal = OverlayPortalController();
  final _branchLink = LayerLink();
  final _branchPortal = OverlayPortalController();
  List<({String title, String sub, IconData icon, String view})> _searchHits = [];

  @override
  void initState() {
    super.initState();
    // Dropdown panels are hosted in the root overlay: a Stack painted with
    // clipBehavior: Clip.none renders outside its parent's bounds but is
    // never hit-tested there, so taps on search results landed on the
    // content underneath instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchPortal.show();
        _notifPortal.show();
        _branchPortal.show();
      }
    });
    _updateClock();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateClock(),
    );
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onGlobalSearch(String q) {
    final query = q.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _searchHits = []);
      return;
    }
    final hits = <({String title, String sub, IconData icon, String view})>[];
    for (final o in demo.orders) {
      if ('#${o.id}'.contains(query) || o.customer.toLowerCase().contains(query)) {
        hits.add((
          title: 'Order #${o.id}',
          sub: '${o.customer} · ${o.status}',
          icon: AppIcons.receipt,
          view: 'orders',
        ));
      }
    }
    for (final p in demo.products) {
      if (p.name.toLowerCase().contains(query) || p.cat.toLowerCase().contains(query)) {
        hits.add((
          title: p.name,
          sub: '${p.cat} · ${fmt(p.price)}',
          icon: AppIcons.book,
          view: 'menu',
        ));
      }
    }
    for (final s in demo.staff) {
      if (s.name.toLowerCase().contains(query)) {
        hits.add((
          title: s.name,
          sub: '${s.role} · Staff',
          icon: AppIcons.users,
          view: 'staff',
        ));
      }
    }
    for (final c in demo.customers) {
      if (c.name.toLowerCase().contains(query) || c.phone.contains(query)) {
        hits.add((
          title: c.name,
          sub: '${c.tier} · Customer',
          icon: AppIcons.heart,
          view: 'customers',
        ));
      }
    }
    for (final t in demo.tables) {
      if (t.name.toLowerCase().contains(query) ||
          (t.guest ?? '').toLowerCase().contains(query)) {
        hits.add((
          title: 'Table ${t.name}',
          sub:
              '${t.status == 'free' ? 'Free' : t.status == 'occ' ? 'Occupied · ${t.guest}' : 'Reserved · ${t.guest}'} · ${t.seats} seats',
          icon: AppIcons.table,
          view: 'tables',
        ));
      }
    }
    for (final i in demo.inventory) {
      if (i.name.toLowerCase().contains(query) || i.sku.toLowerCase().contains(query)) {
        hits.add((
          title: i.name,
          sub: '${i.sku.isEmpty ? i.cat : i.sku} · Stock ${i.qty} ${i.unit}',
          icon: AppIcons.box,
          view: 'inventory',
        ));
      }
    }
    for (final s in demo.suppliers) {
      if (s.name.toLowerCase().contains(query)) {
        hits.add((
          title: s.name,
          sub: '${s.cat} · Supplier',
          icon: AppIcons.truck,
          view: 'suppliers',
        ));
      }
    }
    // Never surface results the member cannot open.
    setState(() => _searchHits = hits
        .where((h) => canOpenView(h.view))
        .take(8)
        .toList());
  }

  void _goToView(String key) {
    final views = ref.read(viewsProvider);
    final v = views.where((x) => x.key == key).firstOrNull;
    if (v != null) {
      ref.read(currentViewProvider.notifier).go(v);
    }
    _searchController.clear();
    setState(() => _searchHits = []);
  }

  void _updateClock() {
    final d = DateTime.now();
    final t =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final date = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][d.weekday - 1];
    final month = [
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
    ][d.month - 1];
    // Only rebuild when the displayed text actually changes (once a minute).
    // Rebuilding every second re-created the whole shell and all views,
    // which made the UI feel frozen on lower-end terminals.
    final text = '$t · $date $month ${d.day}';
    if (text == _clockText) return;
    setState(() => _clockText = text);
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(currentViewProvider);
    final isDark = ref.watch(themeModeProvider);
    final authState = ref.watch(authProvider);
    final locked = ref.watch(appLockProvider);

    // The workspace is locked behind the POS PIN (set in Settings → Profile).
    if (locked && demo.hasPin) {
      return Scaffold(
        body: PinPadScreen(
          title: 'Workspace locked',
          subtitle: 'Enter your POS PIN to continue',
          onSubmit: (pin) {
            if (!demo.verifyPin(pin)) return false;
            ref.read(appLockProvider.notifier).unlock();
            // The PIN was just proven — don't immediately ask for it again
            // when the operator opens the POS terminal.
            ref.read(posUnlockedProvider.notifier).unlock();
            return true;
          },
          footer: TextButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            child: const Text('Sign out instead'),
          ),
        ),
      );
    }

    // A role change (or a deep link from search) can leave an unpermitted
    // view selected — bounce back to the dashboard.
    if (!canOpenView(view.key)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(currentViewProvider.notifier).go(ref.read(viewsProvider).first);
        }
      });
    }

    // Rebuild the whole shell when the store changes (realtime / poll /
    // background sync) so badges, the sync chip and the live views update.
    return ListenableBuilder(
      listenable: demo,
      builder: (context, _) {
        final sidebar = _buildSidebar(context, view, isDark, authState);
        final isDesktop = MediaQuery.of(context).size.width >= 1024;
        return Scaffold(
          // The mobile drawer lives on the Scaffold so it overlays (not
          // squeezes) the body — a Drawer child inside the body Stack would
          // shrink ALL content to its 250px width on phones.
          drawer: isDesktop
              ? null
              : Drawer(
                  backgroundColor: AppColors.side,
                  width: 250,
                  // Clear the status bar / camera notch on phones.
                  child: SafeArea(
                    top: true,
                    bottom: false,
                    child: sidebar,
                  ),
                ),
          body: Stack(
            children: [
              // Content (shifted right on desktop)
              Positioned.fill(
                left: isDesktop ? 250 : 0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Content fills below the topbar
                    Positioned.fill(
                      top: 66,
                      child: _buildContent(context, view.key),
                    ),
                    // Topbar painted LAST so its dropdown overlays paint above content
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 66,
                      child: _buildTopbar(context, view, isDark, authState),
                    ),
                  ],
                ),
              ),
              // Desktop sidebar only — mobile uses the Scaffold drawer.
              if (isDesktop)
                Align(alignment: Alignment.centerLeft, child: sidebar),
            ],
          ),
          floatingActionButton: view.key == 'pos' ? _buildCartFab() : null,
        );
      },
    );
  }

  Widget _buildCartFab() {
    return Consumer(
      builder: (context, ref, _) {
        // The cart panel is permanently visible on wide layouts, so the
        // floating pill would only cover its Charge button — skip it there.
        final wide = MediaQuery.of(context).size.width >= 1024;
        if (wide) return const SizedBox.shrink();
        final cartCount = demo.cart.fold<int>(0, (sum, l) => sum + l.qty);
        if (cartCount == 0) return const SizedBox.shrink();
        final total = demo.cart.fold<double>(
          0,
          (sum, l) => sum + (demo.product(l.productId)?.price ?? 0) * l.qty,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 16, right: 4),
          child: FloatingActionButton.extended(
            heroTag: 'cartFab',
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            onPressed: () {
              demo.cartDrawerOpen = true;
              ref.read(uiStateProvider.notifier).closeNotifs();
              setState(() {});
            },
            icon: const Icon(AppIcons.bag, size: 18),
            label: Text('$cartCount items · €${total.toStringAsFixed(2)}'),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------

  Widget _buildSidebar(
    BuildContext context,
    ShellView current,
    bool isDark,
    AuthState auth,
  ) {
    final views = ref.watch(viewsProvider);
    final isDarkMode = ref.watch(themeModeProvider);
    final userName = auth.fullName ?? 'User';
    final initials = userName
        .split(' ')
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();
    final userRole =
        demo.staff.where((s) => s.authId == auth.userId).firstOrNull?.role ??
            'Owner';

    // Sidebar is filtered by the signed-in member's role permissions: a
    // waiter simply does not see Staff, Settings or Reports.
    const allSections = [
      ('MAIN', ['dashboard', 'pos', 'orders', 'tables', 'kitchen']),
      ('MANAGE', ['menu', 'inventory', 'suppliers', 'customers', 'staff']),
      ('OPERATIONS', ['shift', 'audit', 'reports', 'settings']),
    ];
    final sections = [
      for (final s in allSections)
        (s.$1, [for (final k in s.$2) if (canOpenView(k)) k]),
    ].where((s) => s.$2.isNotEmpty).toList();

    IconData iconFor(String key) {
      switch (key) {
        case 'dashboard':
          return AppIcons.grid;
        case 'pos':
          return AppIcons.pos;
        case 'orders':
          return AppIcons.receipt;
        case 'tables':
          return AppIcons.table;
        case 'kitchen':
          return AppIcons.chef;
        case 'menu':
          return AppIcons.book;
        case 'inventory':
          return AppIcons.box;
        case 'suppliers':
          return AppIcons.truck;
        case 'customers':
          return AppIcons.heart;
        case 'staff':
          return AppIcons.users;
        case 'shift':
          return AppIcons.drawer;
        case 'audit':
          return AppIcons.shield;
        case 'reports':
          return AppIcons.chart;
        case 'settings':
          return AppIcons.sliders;
        default:
          return Icons.circle_outlined;
      }
    }

    final sidebar = Material(
      color: isDarkMode ? AppColors.darkSide : AppColors.side,
      child: SizedBox(
        width: 250,
        child: Column(
          children: [
            // Brand
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.brand, Color(0xFFFF8A4C)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brand.withValues(alpha: 0.55),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      AppIcons.flame,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DashTab',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Plus Jakarta Sans',
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'POS SUITE',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Nav
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final section in sections) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
                        child: Text(
                          section.$1,
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.14,
                            color: Colors.white.withValues(alpha: 0.38),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final key in section.$2.toList())
                        _NavItem(
                          label: views.firstWhere((v) => v.key == key).title,
                          icon: iconFor(key),
                          selected: current.key == key,
                          badge: key == 'orders'
                              ? demo.activeOrderCount
                              : key == 'kitchen'
                              ? demo.kitchenCount
                              : null,
                          onTap: () {
                            ref
                                .read(currentViewProvider.notifier)
                                .go(views.firstWhere((v) => v.key == key));
                          },
                        ),
                    ],
                  ],
                ),
              ),
            ),
            // Footer user chip
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8A4C), AppColors.brand],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          userRole,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        AppIcons.logout,
                        color: Colors.white.withValues(alpha: 0.45),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // The wrapping differs by device: desktop pins the sidebar via Align in
    // the body Stack; mobile wraps it in a Scaffold Drawer (see build).
    return sidebar;
  }

  // ---------------------------------------------------------------------------

  Widget _buildTopbar(
    BuildContext context,
    ShellView view,
    bool isDark,
    AuthState auth,
  ) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final compact = MediaQuery.of(context).size.width < 520;
    final userName = auth.fullName ?? 'User';
    final initials = userName
        .split(' ')
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();

    return Container(
      height: 66,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 26 : 14),
      decoration: BoxDecoration(
        color: color.surface.withValues(alpha: 0.86),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkLine
                : AppColors.line,
          ),
        ),
      ),
      child: LayoutBuilder(builder: (context, c) {
        return Row(
          children: [
            if (!isDesktop)
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(AppIcons.menu, size: 20),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
          const SizedBox(width: 4),
          // Bounded so long titles never push the topbar buttons off-screen.
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  view.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (isDesktop)
                  Text(
                    view.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 20),
            _buildGlobalSearch(context),
          ],
          const Spacer(),
          if (isDesktop) ...[
            Builder(builder: (context) {
              final syncErr = demo.syncError;
              final syncing = demo.syncing;
              final ok = syncErr == null;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: ok
                      ? (syncing ? AppColors.blueT : AppColors.greenT)
                      : AppColors.amberT,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.cloud,
                      size: 14,
                      color: ok
                          ? (syncing ? AppColors.blue : AppColors.green)
                          : AppColors.amber,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      syncErr != null
                          ? 'Sync issue'
                          : syncing
                          ? 'Syncing…'
                          : 'Cloud synced',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: ok
                            ? (syncing ? AppColors.blue : AppColors.green)
                            : AppColors.amber,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(width: 12),
          ],
          Consumer(
            builder: (context, ref, _) {
              final branchOpen = ref.watch(uiStateProvider).branchOpen;
              return _BranchSelector(
                branchOpen: branchOpen,
                compact: compact,
                onToggle: () =>
                    ref.read(uiStateProvider.notifier).toggleBranch(),
                onSelect: (branch) {
                  demo.selectBranch(branch.name);
                  ref.read(uiStateProvider.notifier).closeBranch();
                },
                link: _branchLink,
                portal: _branchPortal,
              );
            },
          ),
          SizedBox(width: compact ? 4 : 12),
          // The clock needs room; drop it first on narrow windows.
          if (MediaQuery.of(context).size.width >= 720)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkCard2
                    : AppColors.card2,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkLine
                      : AppColors.line,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                _clockText,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkText2
                      : AppColors.text2,
                ),
              ),
            ),
          SizedBox(width: compact ? 2 : 8),
          // Manual full re-sync — staff press this before a critical
          // action (settling a bill, issuing a refund, closing the shift)
          // so the data on screen is exactly what is in the database.
          _IconBtn(
            icon: AppIcons.refresh,
            tooltip: demo.isRefreshing
                ? 'Refreshing…'
                : 'Refresh data\nPulls the latest orders, tables, menu and balances from the cloud',
            onTap: demo.isRefreshing
                ? () {}
                : () async {
                    await demo.beginManualRefresh();
                    if (context.mounted) {
                      showToast(
                        context,
                        'Data refreshed',
                        subtitle: 'Everything is up to date',
                        icon: AppIcons.check,
                      );
                    }
                  },
          ),
          SizedBox(width: compact ? 2 : 8),
          _IconBtn(
            icon: isDark ? AppIcons.sun : AppIcons.moon,
            tooltip: 'Toggle theme',
            onTap: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          SizedBox(width: compact ? 2 : 8),
          Consumer(
            builder: (context, ref, _) {
              final notifOpen = ref.watch(uiStateProvider).notifsOpen;
              final unread = demo.notifs.where((n) => n.unread).length;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  CompositedTransformTarget(
                    link: _notifLink,
                    child: _IconBtn(
                      icon: AppIcons.bell,
                      tooltip: 'Notifications',
                      onTap: () =>
                          ref.read(uiStateProvider.notifier).toggleNotifs(),
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.darkCard : AppColors.card,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  OverlayPortal(
                    controller: _notifPortal,
                    overlayChildBuilder: (context) {
                      if (!notifOpen) return const SizedBox.shrink();
                      // The overlay lays out entries with tight constraints;
                      // Align relaxes them so the panel wraps its content.
                      return Align(
                        alignment: Alignment.topLeft,
                        child: CompositedTransformFollower(
                        link: _notifLink,
                        targetAnchor: Alignment.bottomRight,
                        followerAnchor: Alignment.topRight,
                        offset: const Offset(60, 8),
                        showWhenUnlinked: false,
                          child: Material(
                            elevation: 8,
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: _NotificationDrop(
                              onClose: () => ref
                                  .read(uiStateProvider.notifier)
                                  .closeNotifs(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          SizedBox(width: compact ? 2 : 8),
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8A4C), AppColors.brand],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          ],
        );
      }),
    );
  }

  Widget _buildGlobalSearch(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CompositedTransformTarget(
          link: _searchLink,
          child: SizedBox(
            width: 250,
            child: TextField(
              controller: _searchController,
              onChanged: _onGlobalSearch,
              decoration: InputDecoration(
                hintText: 'Search orders, items, staff…',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                prefixIcon: const Icon(AppIcons.search, size: 18),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchHits = []);
                        },
                        icon: const Icon(AppIcons.x, size: 15),
                      ),
              ),
            ),
          ),
        ),
        OverlayPortal(
          controller: _searchPortal,
          overlayChildBuilder: (context) {
            if (_searchHits.isEmpty) return const SizedBox.shrink();
            // The overlay lays out entries with tight constraints; Align
            // relaxes them so the panel wraps its content.
            return Align(
              alignment: Alignment.topLeft,
              child: CompositedTransformFollower(
              link: _searchLink,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 8),
              showWhenUnlinked: false,
                child: Material(
                  elevation: 8,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: _SearchResultsPanel(
                    isDark: isDark,
                    hits: _searchHits,
                    onSelect: _goToView,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, String key) {
    // Defence in depth: even if a view is selected programmatically (search
    // hit, restored state), the content is only built when the role grants it.
    if (!canOpenView(key)) {
      return const EmptyState(
        icon: AppIcons.lock,
        title: 'No access to this section',
        message: 'Your role does not include this area. Ask the owner to '
            'update your permissions in Staff → Roles & permissions.',
      );
    }
    return shellChildBuilder?.call(context, key) ?? const SizedBox.shrink();
  }
}

/// Set by the router so the shell can host the active view.
Widget Function(BuildContext, String)? shellChildBuilder;

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final int? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onTap();
        // In the mobile drawer, selecting a view must close it — otherwise
        // the drawer stays over the content and every further tap lands on
        // the drawer instead of the new view.
        final scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.isDrawerOpen) {
          Navigator.of(context).pop();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.6),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : const Color(0xFFA6ACBB),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFFA6ACBB),
                ),
              ),
            ),
            if (badge != null && badge! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: 39,
        height: 39,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          border: Border.all(
            color: isDark ? AppColors.darkLine : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDark ? AppColors.darkText2 : AppColors.text2,
        ),
      ),
    );
  }
}

/// Search results panel hosted in the root overlay (see [_HomeShellState]).
class _SearchResultsPanel extends StatelessWidget {
  final bool isDark;
  final List<({String title, String sub, IconData icon, String view})> hits;
  final ValueChanged<String> onSelect;

  const _SearchResultsPanel({
    required this.isDark,
    required this.hits,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        border: Border.all(
          color: isDark ? AppColors.darkLine : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.shadowLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Text(
              'RESULTS  (${hits.length})',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.08,
                color: AppColors.text3,
              ),
            ),
          ),
          for (final h in hits)
            InkWell(
              onTap: () => onSelect(h.view),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.brandT,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(h.icon, size: 15, color: AppColors.brand),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            h.sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppColors.darkText3
                                  : AppColors.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      AppIcons.arrowR,
                      size: 14,
                      color: AppColors.text3,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BranchSelector extends StatelessWidget {
  final bool branchOpen;

  /// Icon-only on phone-width topbars so nothing overflows.
  final bool compact;
  final VoidCallback onToggle;
  final ValueChanged<Branch> onSelect;
  final LayerLink link;
  final OverlayPortalController portal;

  const _BranchSelector({
    required this.branchOpen,
    this.compact = false,
    required this.onToggle,
    required this.onSelect,
    required this.link,
    required this.portal,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CompositedTransformTarget(
          link: link,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard2 : AppColors.card2,
                border: Border.all(
                  color: isDark ? AppColors.darkLine : AppColors.line,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.brandT,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      AppIcons.buildings,
                      size: 15,
                      color: AppColors.brand,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BRANCH',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.06,
                            color:
                                isDark ? AppColors.darkText3 : AppColors.text3,
                          ),
                        ),
                        Text(
                          demo.currentBranch,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    const Icon(AppIcons.chevD, size: 14, color: AppColors.text3),
                  ],
                ],
              ),
            ),
          ),
        ),
        OverlayPortal(
          controller: portal,
          overlayChildBuilder: (context) {
            if (!branchOpen) return const SizedBox.shrink();
            // The overlay lays out entries with tight constraints; Align
            // relaxes them so the panel wraps its content.
            return Align(
              alignment: Alignment.topLeft,
              child: CompositedTransformFollower(
                link: link,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 8),
                showWhenUnlinked: false,
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    width: 300,
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.card,
                  border: Border.all(
                    color: isDark ? AppColors.darkLine : AppColors.line,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.shadowLg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Switch branch',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    for (final b in demo.branches.where((b) => b.status != 'inactive'))
                      InkWell(
                        onTap: () => onSelect(b),
                        borderRadius: BorderRadius.circular(9),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.buildings,
                                size: 16,
                                color: b.name == demo.currentBranch
                                    ? AppColors.brand
                                    : AppColors.text3,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  b.full,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: b.name == demo.currentBranch
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: b.name == demo.currentBranch
                                        ? AppColors.brand
                                        : (isDark
                                              ? AppColors.darkText
                                              : AppColors.text),
                                  ),
                                ),
                              ),
                              if (b.name == demo.currentBranch)
                                const Icon(
                                  AppIcons.check,
                                  size: 16,
                                  color: AppColors.brand,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ),
            );
          },
        ),
      ],
    );
  }
}

class _NotificationDrop extends StatelessWidget {
  final VoidCallback onClose;

  const _NotificationDrop({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        border: Border.all(
          color: isDark ? AppColors.darkLine : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowLg,
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      demo.markAllRead();
                      onClose();
                    },
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        color: AppColors.brand,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              color: isDark ? AppColors.darkLine2 : AppColors.line2,
              height: 1,
            ),
            for (final n in demo.notifs.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: n.kind == 'ok'
                            ? AppColors.greenT
                            : n.kind == 'warn'
                            ? AppColors.amberT
                            : AppColors.redT,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        n.kind == 'ok'
                            ? AppIcons.check
                            : n.kind == 'warn'
                            ? AppIcons.alert
                            : AppIcons.x,
                        size: 16,
                        color: n.kind == 'ok'
                            ? AppColors.green
                            : n.kind == 'warn'
                            ? AppColors.amber
                            : AppColors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            n.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkText2
                                  : AppColors.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      n.time,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkText3 : AppColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
            if (demo.notifs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('All caught up ✨')),
              ),
          ],
        ),
      );
  }
}
