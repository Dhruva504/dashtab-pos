import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../security/app_lock.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/demo_data.dart';
import '../../theme/app_widgets.dart';
import '../widgets/payment_modal.dart';
import '../widgets/pin_pad.dart';

/// POS view — mirrors the HTML POS section (catalog + cart panel).
class PosView extends ConsumerStatefulWidget {
  const PosView({super.key});

  @override
  ConsumerState<PosView> createState() => _PosViewState();
}

class _PosViewState extends ConsumerState<PosView> {
  final _searchController = TextEditingController();
  final _customerController = TextEditingController();
  String? _customerId; // linked customer (from search selection)

  /// The discount applied to this cart. It lives in [AppStore.cartMeta] so it
  /// survives a hold → resume round-trip instead of silently disappearing.
  AppDiscount? get _appliedDiscount =>
      demo.findDiscount(demo.cartMeta['discount'] as String? ?? '');

  @override
  void dispose() {
    _searchController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  /// Clears the cart + metadata through the store and resets the POS-local
  /// UI state (customer text field, linked customer). One reset path so no
  /// stale text survives into the next order. Also closes the cart drawer —
  /// a commit means the cart is done; the next order starts from the
  /// catalog, not with a stale open drawer.
  void _resetCartUi() {
    demo.clearActiveCart();
    demo.cartDrawerOpen = false;
    _customerController.clear();
    _customerId = null;
  }

  /// Resolves the selected (or exactly typed) customer to its db id.
  /// With duplicate names, an explicitly selected id wins; an ambiguous
  /// typed name (multiple exact matches) resolves to null rather than
  /// silently crediting the wrong customer.
  String? get _resolvedCustomerId {
    if (_customerId != null) return _customerId;
    final name = (demo.cartMeta['customer'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    final matches = demo.customersNamed(name);
    return matches.length == 1
        ? (matches.first.dbId ?? matches.first.id.toString())
        : null;
  }

  /// Called on every keystroke in the customer field; drops the linked
  /// customer once the typed name no longer matches it exactly.
  void _onCustomerChanged(String v) {
    demo.cartMeta['customer'] = v;
    if (_customerId != null) {
      final c = demo.customers
          .where((c) =>
              c.dbId == _customerId || c.id.toString() == _customerId)
          .firstOrNull;
      final typed = v.trim().toLowerCase();
      if (c == null || c.name.toLowerCase() != typed) _customerId = null;
    }
    setState(() {});
  }

  /// Stable reference for a linked customer: the DB id when connected,
  /// otherwise the local id — so demo mode links work identically.
  String? _customerRef(Customer c) => c.dbId ?? c.id.toString();

  /// Removes the linked customer from the current order (the customer
  /// record itself is untouched; any applied discount stays as-is).
  void _removeCustomerFromCart() {
    setState(() {
      demo.cartMeta['customer'] = null;
      demo.cartMeta['customerId'] = null;
      _customerController.clear();
      _customerId = null;
    });
  }

  /// Selects a customer from the search suggestions.
  void _selectCustomer(Customer c) {
    _customerController.value = TextEditingValue(
      text: c.name,
      selection: TextSelection.collapsed(offset: c.name.length),
    );
    demo.cartMeta['customer'] = c.name;
    demo.cartMeta['customerId'] = _customerRef(c);
    _customerId = _customerRef(c);
    setState(() {});
  }

  /// Opens the customer window — search + select + create in one dialog so
  /// the cart stays clean. Returns `(customer, created)` or null when closed
  /// without a choice.
  Future<(Customer, bool)?> _openCustomerWindow() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchCtrl = TextEditingController(
      text: (demo.cartMeta['customer'] as String?) ?? '',
    );
    (Customer, bool)? result;

    // The create form, layered on top of the picker. Resolves through
    // `result`; the picker closes itself when a customer came out of it.
    Future<void> showCreateForm(
      TextEditingController nameCtrl,
    ) async {
      final phoneCtrl = TextEditingController();
      final emailCtrl = TextEditingController();
      Customer? created;
      await showDialog<void>(
        context: context,
        builder: (dctx) => StatefulBuilder(
          builder: (dctx2, setDlg2) {
            final dupes = demo.customersNamed(nameCtrl.text);
            final canSave = nameCtrl.text.trim().isNotEmpty &&
                // Same-name records must stay distinguishable by phone.
                (dupes.isEmpty || phoneCtrl.text.trim().isNotEmpty);
            return AlertDialog(
              title: const Text('New customer'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      onChanged: (_) => setDlg2(() {}),
                      decoration: const InputDecoration(
                        labelText: 'FULL NAME',
                        hintText: 'e.g. Jessica Alba',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setDlg2(() {}),
                      decoration: InputDecoration(
                        labelText: dupes.isEmpty
                            ? 'PHONE (optional)'
                            : 'PHONE (required)',
                        hintText: '+34 …',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'EMAIL (optional)',
                      ),
                    ),
                    if (dupes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.amberT,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  AppIcons.info,
                                  size: 14,
                                  color: AppColors.amber,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${dupes.length} customer${dupes.length > 1 ? 's' : ''} already named "${nameCtrl.text.trim()}"',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.amber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            for (final dup in dupes)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${dup.name} · ${dup.phone == '—' ? 'no phone' : dup.phone} · ${dup.tier} · ${dup.visits} visits',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark
                                              ? AppColors.darkText2
                                              : AppColors.text2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () {
                                        result = (dup, false);
                                        Navigator.pop(dctx2); // close form
                                        Navigator.pop(dctx); // close picker
                                      },
                                      icon: const Icon(AppIcons.check, size: 14),
                                      label: const Text('Attach'),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dctx2),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: canSave
                      ? () {
                          created = demo.addCustomer(
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim().isEmpty
                                ? '—'
                                : phoneCtrl.text.trim(),
                            email: emailCtrl.text.trim().isEmpty
                                ? null
                                : emailCtrl.text.trim(),
                          );
                          demo.addAudit(
                            'Customer added',
                            'create',
                            '${created!.name} · ${created!.phone} — from POS cart',
                          );
                          Navigator.pop(dctx2); // close form
                        }
                    : null,
                  icon: const Icon(AppIcons.plus, size: 16),
                  label: const Text('Create customer'),
                ),
              ],
            );
          },
        ),
      );
      if (created != null) result = (created!, true);
    }

    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDlg) {
          final q = searchCtrl.text.trim().toLowerCase();
          final exact = demo.customersNamed(q);
          final matches = q.isEmpty
              ? demo.customers
              : ({
                  ...exact,
                  ...demo.customers.where((c) =>
                      c.name.toLowerCase().contains(q) || c.phone.contains(q)),
                }.toList()
                ..sort((a, b) {
                  final byName =
                      a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  return byName != 0 ? byName : a.phone.compareTo(b.phone);
                }));
          return Dialog(
            backgroundColor: isDark ? AppColors.darkCard : AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? AppColors.darkLine2 : AppColors.line2,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Customer',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => Navigator.pop(dctx),
                          borderRadius: BorderRadius.circular(9),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              AppIcons.x,
                              size: 20,
                              color:
                                  isDark ? AppColors.darkText3 : AppColors.text3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            autofocus: true,
                            onChanged: (_) => setDlg(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Search by name or phone…',
                              prefixIcon: Icon(AppIcons.search, size: 18),
                            ),
                          ),
                          ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await showCreateForm(
                              TextEditingController(text: searchCtrl.text.trim()),
                            );
                            if (result != null) {
                              if (Navigator.of(dctx).canPop()) {
                                Navigator.pop(dctx);
                              }
                            } else {
                              setDlg(() {}); // back to the picker, unchanged
                            }
                          },
                          icon: const Icon(AppIcons.plus, size: 16),
                          label: const Text('New'),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: matches.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'No customer matches "${searchCtrl.text.trim()}"',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.darkText2
                                        : AppColors.text2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await showCreateForm(
                                      TextEditingController(
                                          text: searchCtrl.text.trim()),
                                    );
                                    if (result != null) {
                                      if (Navigator.of(dctx).canPop()) {
                                        Navigator.pop(dctx);
                                      }
                                    } else {
                                      setDlg(() {});
                                    }
                                  },
                                  icon: const Icon(AppIcons.plus, size: 16),
                                  label: Text(
                                      'Create "${searchCtrl.text.trim()}"'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                            itemCount: matches.length,
                            itemBuilder: (ctx, i) {
                              final c = matches[i];
                              final dupCount = demo.customersNamed(c.name).length;
                              return InkWell(
                                onTap: () {
                                  result = (c, false);
                                  Navigator.pop(dctx);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  child: Row(
                                    children: [
                                      Avatar(name: c.name),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              '${c.phone == '—' ? 'no phone' : c.phone} · ${c.tier} · ${c.visits} visits',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: isDark
                                                    ? AppColors.darkText2
                                                    : AppColors.text2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (dupCount > 1)
                                        Pill.pending(
                                            '$dupCount with this name'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return result;
  }

  /// Entry point from the cart: opens the window and links the result.
  Future<void> _openCustomerFromCart() async {
    final result = await _openCustomerWindow();
    if (result == null || !mounted) return;
    final (c, created) = result;
    _selectCustomer(c);
    showToast(
      context,
      created ? '${c.name} created' : '${c.name} attached to this order',
      subtitle: 'Loyalty credits go to this record',
      icon: AppIcons.check,
    );
  }

  double _lineTotal(CartLine line) {
    final p = demo.product(line.productId);
    if (p == null) return 0;
    final base = p.price * line.qty;
    final disc = line.discPct != null ? base * line.discPct! / 100 : 0;
    return base - disc;
  }

  double get _subtotal =>
      demo.cart.fold<double>(0, (s, l) => s + _lineTotal(l));

  double get _tax => demo.cart.fold<double>(0, (s, l) {
    final p = demo.product(l.productId);
    return s + (p != null ? _lineTotal(l) * p.iva / 100 : 0);
  });

  double get _promoDisc => _appliedDiscount?.applyTo(_subtotal) ?? 0;
  double get _total => _subtotal + _tax - _promoDisc;

  /// What a discount would take off the current cart.
  double _savingFor(AppDiscount d) => d.applyTo(_subtotal);

  /// Every active discount, best deal for this cart first — the cart shows
  /// them as tap-to-apply chips so no promo code has to be typed.
  List<AppDiscount> get _activeDiscounts {
    final list = List<AppDiscount>.of(demo.discounts);
    list.sort((a, b) {
      final bySaving = _savingFor(b).compareTo(_savingFor(a));
      return bySaving != 0
          ? bySaving
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }
  int get _cartCount => demo.cart.fold<int>(0, (s, l) => s + l.qty);

  void _addToCart(DemoProduct p) {
    setState(() {
      final existing = demo.cart.where((l) => l.productId == p.id).firstOrNull;
      if (existing != null) {
        if (existing.qty < p.stock) existing.qty++;
      } else {
        demo.cart.add(CartLine(p.id, 1));
      }
    });
  }

  void _openPayment() {
    final type = (demo.cartMeta['type'] as String?) ?? 'Dine In';
    final customer = (demo.cartMeta['customer'] as String?)?.trim() ?? '';
    // A resumed (held) order settles ITS OWN row — the order number the
    // customer saw when ordering is the one on the receipt.
    final resumedId = demo.cartMeta['resumedOrderId'] as int?;
    final resumed = resumedId == null
        ? null
        : demo.orders.where((o) => o.id == resumedId).firstOrNull;
    if (resumedId != null && resumed == null) {
      // The resumed order no longer exists (cancelled/refunded elsewhere or
      // removed by an undo) — drop the stale marker so the cart behaves as a
      // fresh order again instead of silently creating a duplicate.
      demo.cartMeta.remove('resumedOrderId');
    }
    PaymentModal.show(
      context,
      PaySession(
        items: List.of(demo.cart),
        type: type,
        customer: customer.isEmpty ? 'Walk-in' : customer,
        customerId: _resolvedCustomerId,
        table: type == 'Dine In' ? demo.cartMeta['table'] as String? : null,
        sub: _subtotal,
        disc: _promoDisc,
        tax: _tax,
        total: _total,
        srcOrder: resumed,
      ),
    ).then((paid) {
      if (paid != null && mounted) {
        setState(_resetCartUi);
        showToast(
          context,
          resumed == null
              ? 'Order #${paid.id} paid'
              : 'Order #${paid.id} settled',
          subtitle:
              '${fmt(paid.total)} · ${paid.method} · Ready for next order',
        );
      }
    });
  }

  void _sendToKitchen() {
    if (demo.cart.isEmpty) return;
    final type = (demo.cartMeta['type'] as String?) ?? 'Dine In';
    final customer = (demo.cartMeta['customer'] as String?)?.trim() ?? '';
    final table = type == 'Dine In' ? demo.cartMeta['table'] as String? : null;
    final customerId = _resolvedCustomerId;
    // Resumed order: update IT in place (same id / DB row) instead of
    // creating a new one — order numbers never change mid-flow.
    final resumedId = demo.cartMeta['resumedOrderId'] as int?;
    final resumed = resumedId == null
        ? null
        : demo.orders.where((o) => o.id == resumedId).firstOrNull;
    if (resumedId != null && resumed == null) {
      // Stale resume marker (order gone) — continue as a fresh order.
      demo.cartMeta.remove('resumedOrderId');
    }
    if (resumed != null) {
      demo.updateCommittedOrder(
        resumed,
        items: List.of(demo.cart),
        sub: _subtotal,
        disc: _promoDisc,
        tax: _tax,
        total: _total,
        type: type,
        table: table,
        customer: customer,
        customerId: customerId ?? '',
        status: 'Preparing',
        sendKitchen: true,
      );
      _afterCommit(order: resumed, toast: 'sent to kitchen');
      return;
    }
    final order = DemoOrder(
      id: demo.orderSeq++,
      type: type,
      table: table,
      customerId: customerId,
      customer: customer.isEmpty ? 'Walk-in' : customer,
      status: 'Preparing',
      items: List.of(demo.cart),
      time: demo.timeNow,
      date: demo.dateNow,
      sub: _subtotal,
      disc: _promoDisc,
      tax: _tax,
      total: _total,
    );
    demo.pushOrder(order);
    demo.addKitchen(order.id);
    demo.addAudit(
      'Order #${order.id} sent to kitchen',
      'create',
      '${order.items.length} items · Table ${table ?? '—'}',
    );
    setState(_resetCartUi);
    showToast(
      context,
      'Order #${order.id} sent to kitchen',
      subtitle: '${order.items.length} items · ${fmt(order.total)}',
      icon: AppIcons.chef,
    );
  }

  void _holdOrder() {
    if (demo.cart.isEmpty) return;
    final type = (demo.cartMeta['type'] as String?) ?? 'Dine In';
    final customer = (demo.cartMeta['customer'] as String?)?.trim() ?? '';
    final table = type == 'Dine In' ? demo.cartMeta['table'] as String? : null;
    final customerId = _resolvedCustomerId;
    // Resumed order: re-hold updates IT in place — id stays the same.
    final resumedId = demo.cartMeta['resumedOrderId'] as int?;
    final resumed = resumedId == null
        ? null
        : demo.orders.where((o) => o.id == resumedId).firstOrNull;
    if (resumedId != null && resumed == null) {
      // Stale resume marker (order gone) — continue as a fresh order.
      demo.cartMeta.remove('resumedOrderId');
    }
    if (resumed != null) {
      demo.updateCommittedOrder(
        resumed,
        items: List.of(demo.cart),
        sub: _subtotal,
        disc: _promoDisc,
        tax: _tax,
        total: _total,
        type: type,
        table: table,
        customer: customer,
        customerId: customerId ?? '',
        status: 'Pending',
      );
      _afterCommit(order: resumed, toast: 'held');
      return;
    }
    final held = DemoOrder(
      id: demo.orderSeq++,
      type: type,
      table: table,
      customerId: customerId,
      customer: customer.isEmpty ? 'Walk-in' : customer,
      status: 'Pending',
      items: List.of(demo.cart),
      time: demo.timeNow,
      date: demo.dateNow,
      sub: _subtotal,
      disc: _promoDisc,
      tax: _tax,
      total: _total,
    );
    demo.pushOrder(held);
    setState(_resetCartUi);
    showToast(
      context,
      'Order #${held.id} held — you can resume it from Orders',
      icon: AppIcons.clock,
    );
  }

  /// Shared post-commit cleanup for resumed-order paths: clears the cart
  /// (including the resume marker) and shows a toast naming the SAME order.
  void _afterCommit({required DemoOrder order, required String toast}) {
    setState(_resetCartUi);
    showToast(
      context,
      'Order #${order.id} $toast',
      subtitle: '${order.items.length} items · ${fmt(order.total)}',
      icon: toast == 'held' ? AppIcons.clock : AppIcons.chef,
    );
  }

  void _chooseTable() {
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Choose Table'),
        content: SizedBox(
          width: 380,
          height: 380,
          child: GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: demo.tables
                .map(
                  (t) => InkWell(
                    onTap: () {
                      Navigator.pop(dctx);
                      setState(() => demo.cartMeta['table'] = t.name);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.status == 'occ'
                            ? AppColors.brandT
                            : t.status == 'res'
                            ? AppColors.violetT
                            : (Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkCard2
                                  : AppColors.card2),
                        border: Border.all(
                          color: t.status == 'occ'
                              ? AppColors.brand
                              : t.status == 'res'
                              ? AppColors.violet
                              : AppColors.line,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            AppIcons.table,
                            size: 18,
                            color: AppColors.brand,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            t.status == 'free'
                                ? 'Free'
                                : t.status.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.text3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _editLine(CartLine line) {
    final note = TextEditingController(text: line.note ?? '');
    var disc = line.discPct ?? 0;
    showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDlg) => AlertDialog(
          title: const Text('Edit line'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'e.g. No onions please',
                  prefixIcon: Icon(AppIcons.pencil, size: 18),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'LINE DISCOUNT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.06,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in [0, 5, 10, 15, 20])
                    InkWell(
                      onTap: () => setDlg(() => disc = d),
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: disc == d ? AppColors.brand : AppColors.card2,
                          border: Border.all(
                            color: disc == d ? AppColors.brand : AppColors.line,
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          d == 0 ? 'No' : '$d%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: disc == d ? Colors.white : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dctx);
                setState(() {
                  line.note = note.text.trim().isEmpty
                      ? null
                      : note.text.trim();
                  line.discPct = disc == 0 ? null : disc;
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = demo;

    // POS quick-login gate: when the workspace has a POS PIN, the terminal
    // asks for it before opening (and can be locked again from the header).
    final posUnlocked = ref.watch(posUnlockedProvider);
    if (demo.hasPin && !posUnlocked) {
      return PinPadScreen(
        title: 'POS quick login',
        subtitle: 'Enter your PIN to open the terminal',
        icon: AppIcons.pos,
        onSubmit: (pin) {
          if (!demo.verifyPin(pin)) return false;
          ref.read(posUnlockedProvider.notifier).unlock();
          return true;
        },
      );
    }

    final q = _searchController.text.toLowerCase();
    final filtered = d.products.where((p) {
      final matchesCat = d.cat == 'All' || p.cat == d.cat;
      final matchesQ =
          q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.cat.toLowerCase().contains(q);
      return matchesCat && matchesQ;
    }).toList();
    final cats = [
      'All',
      ...{for (final p in d.products) p.cat},
    ];
    // A previously selected category may no longer exist after a menu
    // reload — fall back to 'All' instead of showing an empty catalog.
    if (d.cat != 'All' && !cats.contains(d.cat)) {
      d.cat = 'All';
    }
    final quickTop = (List.of(
      d.products,
    )..sort((a, b) => b.sold.compareTo(a.sold))).take(6).toList();

    final catalog = Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search products by name or type…',
                    prefixIcon: Icon(AppIcons.search, size: 18),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (demo.hasPin) ...[
                const SizedBox(width: 10),
                Tooltip(
                  message: 'Lock the terminal (PIN required to reopen)',
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(posUnlockedProvider.notifier).lock();
                      showToast(
                        context,
                        'Terminal locked',
                        subtitle: 'Enter your PIN to open it again',
                        icon: AppIcons.lock,
                      );
                    },
                    icon: const Icon(AppIcons.lock, size: 15),
                    label: const Text('Lock'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Category chips in a wrapping layout so every category is
          // reachable without scrolling (they don't fit in one row).
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final c in cats)
                FilterChipBtn(
                  label: c,
                  selected: d.cat == c,
                  height: 28,
                  horizontalPadding: 12,
                  onTap: () => setState(() => d.cat = c),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: quickTop.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final p = quickTop[i];
                return InkWell(
                  onTap: () => _addToCart(p),
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.network(
                            p.img,
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 46,
                              height: 46,
                              color: AppColors.brandT,
                              child: const Icon(
                                AppIcons.book,
                                color: AppColors.brand,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkText2
                                : AppColors.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: AppIcons.search,
                    title: 'No products match your search.',
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 185,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.98,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      final out = p.stock <= 0 || !p.avail;
                      final low = !out && p.stock <= 5;
                      final inCart = demo.cart
                          .where((l) => l.productId == p.id)
                          .fold<int>(0, (s, l) => s + l.qty);
                      return Opacity(
                        opacity: out ? 0.5 : 1,
                        child: InkWell(
                          onTap: out ? null : () => _addToCart(p),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : AppColors.card,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkLine
                                    : AppColors.line,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: AppTheme.shadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: SizedBox(
                                    height: 76,
                                    width: double.infinity,
                                    child: Image.network(
                                      p.img,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: AppColors.brandT,
                                        child: const Icon(
                                          AppIcons.book,
                                          color: AppColors.brand,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Expanded so the block below gets a bounded
                                // height — its Spacers pin the price row to
                                // the card's bottom edge.
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                p.cat.toUpperCase(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.brand,
                                                  letterSpacing: 0.08,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (inCart > 0)
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.brand,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          99),
                                                ),
                                                child: Text(
                                                  '$inCart in cart',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9.5,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          p.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                            height: 1.2,
                                          ),
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                '€${p.price.toStringAsFixed(2)}',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (out)
                                              const Flexible(
                                                child: Text(
                                                  'Sold out',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: AppColors.red,
                                                    fontSize: 10.5,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                  ),
                                                ),
                                              )
                                            else if (low)
                                              Flexible(
                                                child: Text(
                                                  '${p.stock} left',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: AppColors.amber,
                                                    fontSize: 10.5,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                  ),
                                                ),
                                              )
                                            else
                                              const Icon(
                                                AppIcons.plus,
                                                size: 18,
                                                color: AppColors.brand,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    final cartPanel = _CartPanel(
      isDark: isDark,
      lineTotal: _lineTotal,
      subtotal: _subtotal,
      tax: _tax,
      promoDisc: _promoDisc,
      promoLabel: _appliedDiscount?.name,
      total: _total,
      onQuantityChanged: () => setState(() {}),
      customerController: _customerController,
      onCustomerChanged: _onCustomerChanged,
      onSelectCustomer: _selectCustomer,
      discounts: _activeDiscounts,
      discountSaving: _savingFor,
      onSelectDiscount: (d) =>
          setState(() => demo.cartMeta['discount'] = d?.name),
      onClearCart: () async {
        if (demo.cart.isEmpty) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Clear cart?'),
            content: const Text(
              'This removes all items and any applied discount from the current order. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Clear cart'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        setState(() {
          demo.cart.clear();
          demo.cartMeta['discount'] = null;
          demo.cartMeta['customer'] = null;
          demo.cartMeta['customerId'] = null;
          _customerController.clear();
        });
      },
      onCharge: _openPayment,
      onSendKitchen: _sendToKitchen,
      onHold: _holdOrder,
      onChooseTable: _chooseTable,
      onEditLine: _editLine,
      onCreateCustomer: _openCustomerFromCart,
      onRemoveCustomer: _removeCustomerFromCart,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: catalog),
              const SizedBox(width: 18),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 20, 16),
                child: SizedBox(width: 385, child: cartPanel),
              ),
            ],
          );
        }
        return Stack(
          children: [
            Positioned.fill(child: catalog),
            // The cart slides over the catalog only when the user opens it
            // (FAB / cart button); the flag resets on every commit so the
            // drawer never re-opens itself for the next order.
            if (_cartCount > 0 && demo.cartDrawerOpen)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: CartDrawerWidget(
                  onClose: () => setState(() => demo.cartDrawerOpen = false),
                  child: cartPanel,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Right-hand cart panel (styled like the HTML `.cart-panel`).
class _CartPanel extends StatelessWidget {
  final bool isDark;
  final double Function(CartLine) lineTotal;
  final double subtotal;
  final double tax;
  final double promoDisc;
  final String? promoLabel;
  final double total;
  final VoidCallback onQuantityChanged;
  final TextEditingController customerController;
  final ValueChanged<String> onCustomerChanged;
  final void Function(Customer c) onSelectCustomer;

  /// All active discounts plus the saving each would give this cart.
  final List<AppDiscount> discounts;
  final double Function(AppDiscount) discountSaving;

  /// Applies a discount, or clears it when passed null.
  final ValueChanged<AppDiscount?> onSelectDiscount;
  final VoidCallback onClearCart;
  final VoidCallback onCharge;
  final VoidCallback onSendKitchen;
  final VoidCallback onHold;
  final VoidCallback onChooseTable;
  final ValueChanged<CartLine> onEditLine;
  final VoidCallback onCreateCustomer;
  final VoidCallback onRemoveCustomer;

  const _CartPanel({
    required this.isDark,
    required this.lineTotal,
    required this.subtotal,
    required this.tax,
    required this.promoDisc,
    required this.promoLabel,
    required this.total,
    required this.onQuantityChanged,
    required this.customerController,
    required this.onCustomerChanged,
    required this.onSelectCustomer,
    required this.discounts,
    required this.discountSaving,
    required this.onSelectDiscount,
    required this.onClearCart,
    required this.onCharge,
    required this.onSendKitchen,
    required this.onHold,
    required this.onChooseTable,
    required this.onEditLine,
    required this.onCreateCustomer,
    required this.onRemoveCustomer,
  });

  /// One compact line for discounts. Applying a discount is optional on most
  /// orders, so it stays out of the way and opens the picker on tap.
  Widget _discountRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkText3 : AppColors.text3;
    final applied = promoDisc > 0 && promoLabel != null;
    final none = discounts.isEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 8),
      child: InkWell(
        onTap: none ? null : () => _showDiscountPicker(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: applied
                ? AppColors.greenT
                : (isDark ? AppColors.darkCard2 : AppColors.card2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.tag,
                size: 14,
                color: applied ? AppColors.green : muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  applied
                      ? 'Discount · $promoLabel'
                      : (none ? 'No discounts set up' : 'Add discount'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: applied
                        ? AppColors.green
                        : (isDark ? AppColors.darkText2 : AppColors.text2),
                  ),
                ),
              ),
              if (applied)
                Text(
                  '−€${promoDisc.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
              const SizedBox(width: 8),
              if (applied)
                InkWell(
                  onTap: () => onSelectDiscount(null),
                  child: const Icon(
                    AppIcons.x,
                    size: 15,
                    color: AppColors.green,
                  ),
                )
              else
                Icon(AppIcons.chevD, size: 16, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  /// Full list of active discounts, opened from the compact discount row.
  /// Returns `(discount, remove)` — exactly one of the two is meaningful.
  Future<void> _showDiscountPicker(BuildContext context) async {
    final picked = await showDialog<(AppDiscount?, bool)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply a discount'),
        content: SizedBox(
          width: 400,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final disc in discounts)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      promoLabel == disc.name
                          ? AppIcons.checkCircle
                          : AppIcons.tag,
                      size: 18,
                      color: promoLabel == disc.name
                          ? AppColors.green
                          : AppColors.text3,
                    ),
                    title: Text(
                      disc.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      disc.type == 0
                          ? '${disc.value.toStringAsFixed(0)}% off the subtotal'
                          : '€${disc.value.toStringAsFixed(2)} off the subtotal',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: Text(
                      '−€${discountSaving(disc).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.green,
                        fontSize: 12.5,
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, (disc, false)),
                  ),
                if (promoLabel != null)
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      AppIcons.x,
                      size: 18,
                      color: AppColors.red,
                    ),
                    title: const Text(
                      'Remove the applied discount',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.red,
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, (null, true)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (picked == null) return;
    if (picked.$2) {
      onSelectDiscount(null);
    } else if (picked.$1 != null) {
      onSelectDiscount(picked.$1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = demo;
    final typed = (d.cartMeta['customer'] as String? ?? '')
        .trim()
        .toLowerCase();
    // Original casing for the customer summary row.
    final typedRaw = (d.cartMeta['customer'] as String? ?? '').trim();
    final customerRef = d.cartMeta['customerId'] as String?;
    final linkedCustomer =
        typed.isEmpty || customerRef == null
            ? null
            : d.customers
                .where((c) =>
                    c.dbId == customerRef ||
                    c.id.toString() == customerRef)
                .firstOrNull;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        border: Border.all(color: isDark ? AppColors.darkLine : AppColors.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Flexible so the header fits the narrow cart drawer too.
              Flexible(
                child: Text(
                  'Current Order',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: d.cartMeta['resumedOrderId'] != null
                    ? 'Resumed order — paying or holding keeps this number'
                    : 'Next order number',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: d.cartMeta['resumedOrderId'] != null
                        ? AppColors.amberT
                        : AppColors.brandT,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    d.cartMeta['resumedOrderId'] != null
                        ? '#${d.cartNo} · resumed'
                        : '#${d.cartNo}',
                    style: TextStyle(
                      color: d.cartMeta['resumedOrderId'] != null
                          ? AppColors.amber
                          : AppColors.brand,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (d.cart.isNotEmpty)
                InkWell(
                  onTap: onClearCart,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          AppIcons.trash,
                          size: 14,
                          color: AppColors.red,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Segmented(
            brand: true,
            selectedIndex: switch (d.cartMeta['type']) {
              'Take Away' => 1,
              'Delivery' => 2,
              _ => 0,
            },
            onChanged: (i) {
              d.cartMeta['type'] = i == 0
                  ? 'Dine In'
                  : i == 1
                  ? 'Take Away'
                  : 'Delivery';
              onQuantityChanged();
            },
            options: const [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.fork, size: 15),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Dine In',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.bag, size: 15),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Take Away',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.truck, size: 15),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Delivery',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // The customer lives in its own window (search / select /
          // create). The field is a read-only summary that opens it, so the
          // cart panel stays free of suggestion chips and pills.
          InkWell(
            onTap: onCreateCustomer,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard2 : AppColors.card2,
                border: Border.all(
                  color: linkedCustomer != null
                      ? AppColors.green
                      : (isDark ? AppColors.darkLine : AppColors.line),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    linkedCustomer != null ? AppIcons.check : AppIcons.user,
                    size: 17,
                    color: linkedCustomer != null
                        ? AppColors.green
                        : AppColors.brand,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      linkedCustomer != null
                          ? linkedCustomer.name
                          : typedRaw.isEmpty
                              ? 'Add customer…'
                              : 'Customer: $typedRaw',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: linkedCustomer != null
                            ? AppColors.green
                            : (isDark ? AppColors.darkText2 : AppColors.text2),
                      ),
                    ),
                  ),
                  if (linkedCustomer != null) ...[
                    Text(
                      linkedCustomer.phone == '—' ? '' : linkedCustomer.phone,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkText3 : AppColors.text3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Unlink the customer from this order (the record stays).
                    InkWell(
                      onTap: onRemoveCustomer,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          AppIcons.x,
                          size: 15,
                          color: isDark ? AppColors.darkText3 : AppColors.text3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ] else ...[
                    const SizedBox(width: 4),
                  ],
                  const Icon(AppIcons.chevD, size: 15, color: AppColors.text3),
                ],
              ),
            ),
          ),
          if ((d.cartMeta['type'] as String?) == 'Dine In') ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: onChooseTable,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard2 : AppColors.card2,
                  border: Border.all(
                    color: isDark ? AppColors.darkLine : AppColors.line,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      AppIcons.table,
                      size: 17,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        d.cartMeta['table'] == null
                            ? 'Choose table…'
                            : 'Table ${d.cartMeta['table']}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: d.cartMeta['table'] == null
                              ? FontWeight.w500
                              : FontWeight.w800,
                          color: d.cartMeta['table'] == null
                              ? (isDark ? AppColors.darkText2 : AppColors.text2)
                              : (isDark ? AppColors.darkText : AppColors.text),
                        ),
                      ),
                    ),
                    const Icon(
                      AppIcons.chevD,
                      size: 16,
                      color: AppColors.text3,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const SizedBox(height: 10),
          if (d.cart.isEmpty)
            const Expanded(
              child: EmptyState(
                icon: AppIcons.bag,
                title: 'Cart is empty',
                message: 'Tap products on the left to start a new order.',
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: d.cart.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final line = d.cart[i];
                  final p = d.product(line.productId)!;
                  final pct = line.discPct ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard2 : AppColors.card2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            p.img,
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 42,
                              height: 42,
                              color: AppColors.brandT,
                              child: const Icon(
                                AppIcons.book,
                                color: AppColors.brand,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${p.name}${pct > 0 ? '  −$pct%' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              if (line.note != null)
                                Text(
                                  line.note!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.amber,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _QtyBtn(
                                    icon: AppIcons.minus,
                                    onTap: () {
                                      line.qty--;
                                      if (line.qty <= 0) d.cart.remove(line);
                                      onQuantityChanged();
                                    },
                                  ),
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '${line.qty}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  _QtyBtn(
                                    icon: AppIcons.plus,
                                    onTap: () {
                                      if (line.qty < p.stock) line.qty++;
                                      onQuantityChanged();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '€${lineTotal(line).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => onEditLine(line),
                                  borderRadius: BorderRadius.circular(6),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      AppIcons.pencil,
                                      size: 14,
                                      color: AppColors.text3,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    d.cart.remove(line);
                                    onQuantityChanged();
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      AppIcons.trash,
                                      size: 14,
                                      color: AppColors.text3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          _discountRow(context),
          TotalRow('Subtotal', '€${subtotal.toStringAsFixed(2)}'),
          if (promoDisc > 0)
            TotalRow(
              'Discount ${promoLabel ?? ''}',
              '−€${promoDisc.toStringAsFixed(2)}',
              free: true,
            ),
          TotalRow('IVA', '€${tax.toStringAsFixed(2)}'),
          TotalRow(
            'Total',
            '€${total.toStringAsFixed(2)}',
            total: true,
            fontSize: 16,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: d.cart.isEmpty ? null : onHold,
                  icon: const Icon(AppIcons.clock, size: 16),
                  label: const Text('Hold'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: d.cart.isEmpty ? null : onCharge,
                  icon: const Icon(AppIcons.arrowR, size: 16),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Charge  €${total.toStringAsFixed(2)}'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: d.cart.isEmpty ? null : onSendKitchen,
              icon: const Icon(AppIcons.chef, size: 16),
              label: const Text('Send to Kitchen'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          border: Border.all(
            color: isDark ? AppColors.darkLine : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 13,
          color: isDark ? AppColors.darkText2 : AppColors.text2,
        ),
      ),
    );
  }
}

/// Mobile cart drawer overlay.
class CartDrawerWidget extends StatelessWidget {
  final VoidCallback onClose;
  final Widget child;

  const CartDrawerWidget({
    super.key,
    required this.onClose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: MediaQuery.of(context).size.width * 0.94,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCard
            : AppColors.card,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
        boxShadow: AppTheme.shadowLg,
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(AppIcons.x),
              tooltip: 'Close cart',
            ),
          ),
          Positioned.fill(top: 40, child: child),
        ],
      ),
    );
  }
}
