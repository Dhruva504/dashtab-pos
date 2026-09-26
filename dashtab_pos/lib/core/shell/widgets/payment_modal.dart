
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/demo_data.dart';
import '../../theme/app_widgets.dart';

/// Everything the payment modal needs to charge a cart or settle an order.
class PaySession {
  final List<CartLine> items;
  final String type;
  final String customer;
  final String? customerId;
  final String? table;
  final double sub;
  final double disc;
  final double tax;
  final double total;
  final DemoOrder? srcOrder; // non-null when settling an existing order

  const PaySession({
    required this.items,
    required this.type,
    required this.customer,
    this.customerId,
    this.table,
    required this.sub,
    this.disc = 0,
    required this.tax,
    required this.total,
    this.srcOrder,
  });
}

/// Payment modal mirroring the HTML `modalPay` flow.
class PaymentModal extends StatefulWidget {
  final PaySession session;

  const PaymentModal({super.key, required this.session});

  /// Opens the modal and resolves with the paid [DemoOrder] (or null if closed).
  static Future<DemoOrder?> show(BuildContext context, PaySession session) {
    return showDialog<DemoOrder>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => PaymentModal(session: session),
    );
  }

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  late final PaySession s = widget.session;
  late final List<CartLine> items = List.of(s.items);
  late final Map<int, DemoProduct> _products = {
    for (final l in items)
      if (demo.product(l.productId) != null)
        l.productId: demo.product(l.productId)!,
  };

  String method = 'Cash';
  String tender = '';
  int tipPct = 0;
  String facturaType = 'simplificada';
  String nif = '';
  String gcCode = '';
  String gcCodeApplied = '';
  double gcBalance = 0;
  int? gcId;
  final _gcCodeController = TextEditingController();
  // Loyalty redemption state.
  Customer? _loyaltyCustomer;
  bool _redeemPoints = false;

  @override
  void dispose() {
    _gcCodeController.dispose();
    super.dispose();
  }

  /// Gift cards that can still pay something.
  List<GiftCard> get _activeGiftCards {
    final list = demo.giftCards
        .where((g) => g.status == 'Active' && g.balance > 0)
        .toList();
    list.sort((a, b) => b.balance.compareTo(a.balance));
    return list;
  }

  /// Read-only lookup of an existing customer for this session.
  /// Never creates anything — display only.
  Customer? get _sessionCustomer {
    if (_loyaltyCustomer != null) return _loyaltyCustomer;
    final raw = s.customer.trim();
    if (raw.isEmpty) return null;
    _loyaltyCustomer = demo.customers
        .where((x) => x.name.toLowerCase() == raw.toLowerCase())
        .firstOrNull;
    return _loyaltyCustomer;
  }

  int get _pointsToRedeem {
    if (!_redeemPoints) return 0;
    final c = _sessionCustomer;
    if (c == null || !demo.loyaltyEnabled) return 0;
    // Cap the redemption at the amount due so points never overpay.
    final maxEuro = s.total;
    final maxPoints = (maxEuro / demo.pointValue).floor();
    return c.points.clamp(0, maxPoints);
  }

  double get _pointsDiscount => _pointsToRedeem * demo.pointValue;

  /// Amount actually charged after points discount.
  double get _netTotal => (s.total - _pointsDiscount).clamp(0, double.maxFinite);

  bool _cardApproved = false;
  bool _bizumReceived = false;
  bool _printing = false;

  double get _tipAmt => _netTotal * (tipPct / 100);
  double get _grand => _netTotal + _tipAmt;

  /// Amount covered by the applied gift card (capped at the bill).
  double get _gcApplied =>
      gcId == null ? 0 : (gcBalance < _grand ? gcBalance : _grand);

  /// What still has to be paid with the selected cash/card method.
  double get _dueAfterGc => (_grand - _gcApplied).clamp(0, double.maxFinite);

  /// The gift card alone settles the bill — no second method needed.
  bool get _gcCoversAll => gcId != null && _dueAfterGc <= 0.005;

  /// How the payment is recorded on the order/audit trail.
  String get _methodLabel {
    if (_gcCoversAll) return 'Gift Card';
    if (_gcApplied > 0) return 'Gift Card + $method';
    return method;
  }

  bool get _canPay {
    // Guard against the order being closed while the modal is open —
    // e.g. the customer paid at another terminal, or the bill was
    // cancelled. Blocking here prevents a second payment/row.
    final src = s.srcOrder;
    if (src != null &&
        (src.status == 'Paid' ||
            src.status == 'Cancelled' ||
            src.status == 'Refunded')) {
      return false;
    }
    if (_gcCoversAll) return true; // gift card pays the whole bill
    switch (method) {
      case 'Cash':
        return (double.tryParse(tender) ?? 0) >= _dueAfterGc;
      case 'Debit Card':
        return _cardApproved;
      case 'Bizum':
        return _bizumReceived;
      default:
        return false;
    }
  }

  /// Applies an active gift card directly from the list (no typing needed).
  void _applyGiftCard(GiftCard gc) {
    setState(() {
      gcCode = gc.code;
      gcBalance = gc.balance;
      gcId = gc.id;
      gcCodeApplied = gc.code;
    });
    final applied = gc.balance < _grand ? gc.balance : _grand;
    final remaining = _grand - applied;
    showToast(
      context,
      remaining <= 0.005
          ? 'Gift card covers the whole bill'
          : 'Gift card covers ${fmt(applied)}',
      subtitle: remaining <= 0.005
          ? null
          : 'Remaining ${fmt(remaining)} to pay by $method',
      icon: AppIcons.gift,
    );
  }

  void _clearGiftCard() {
    setState(() {
      gcCode = '';
      gcBalance = 0;
      gcId = null;
      gcCodeApplied = '';
    });
  }

  /// Split-payment row: apply a gift card against this bill, or show how the
  /// bill is currently split between the card and the chosen method.
  Widget _buildGiftCardRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (gcId == null) {
      final n = _activeGiftCards.length;
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _showGiftCardPicker,
          icon: const Icon(AppIcons.gift, size: 16),
          label: Text(
            n == 0
                ? 'Pay with a gift card'
                : 'Pay with a gift card ($n active)',
          ),
        ),
      );
    }
    final left = (gcBalance - _gcApplied).clamp(0, double.maxFinite);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.greenT,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.gift, size: 15, color: AppColors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gift card $gcCodeApplied',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
              ),
              Text(
                '−${fmt(_gcApplied)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _clearGiftCard,
                child: const Icon(
                  AppIcons.x,
                  size: 15,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _gcCoversAll
                ? 'Covers the whole bill · ${fmt(left)} left on the card'
                : 'Card balance ${fmt(gcBalance)} · ${fmt(_dueAfterGc)} still '
                    'due by $method',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText2 : AppColors.text2,
            ),
          ),
        ],
      ),
    );
  }

  /// Picks a gift card — from the active cards or by typing its code.
  Future<void> _showGiftCardPicker() async {
    final cards = _activeGiftCards;
    _gcCodeController.text = gcCode;
    String? error;
    final chosen = await showDialog<GiftCard>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Apply a gift card'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _gcCodeController,
                        decoration: InputDecoration(
                          hintText: 'Card code',
                          prefixIcon: const Icon(AppIcons.gift, size: 18),
                          errorText: error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        final code = _gcCodeController.text.trim().toUpperCase();
                        final match = demo.giftCards
                            .where((g) => g.code.toUpperCase() == code)
                            .firstOrNull;
                        if (match == null) {
                          setDlg(() => error = 'No gift card with that code');
                          return;
                        }
                        if (match.status != 'Active') {
                          setDlg(() => error =
                              'Card ${match.code} is ${match.status.toLowerCase()}');
                          return;
                        }
                        if (match.balance <= 0) {
                          setDlg(() => error =
                              'Card ${match.code} has no balance left');
                          return;
                        }
                        Navigator.pop(ctx, match);
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'ACTIVE CARDS (${cards.length})',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.06,
                    color: AppColors.text3,
                  ),
                ),
                const SizedBox(height: 6),
                if (cards.isEmpty)
                  const Text(
                    'No gift cards with a balance — issue one from '
                    'Customers → Gift Cards.',
                    style: TextStyle(fontSize: 12, color: AppColors.text3),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final gc in cards)
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              AppIcons.gift,
                              size: 18,
                              color: AppColors.green,
                            ),
                            title: Text(
                              gc.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              '${gc.recipient.isEmpty ? 'Unassigned' : gc.recipient}'
                              ' · expires ${gc.expiry}',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            trailing: Text(
                              fmt(gc.balance),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            onTap: () => Navigator.pop(ctx, gc),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) _applyGiftCard(chosen);
  }

  /// Builds the new Paid order for a fresh (non-resumed) session. Resumed
  /// sessions settle their existing order through [AppStore.settleOrder] —
  /// metadata is applied to it in _confirmPay before the transition.
  DemoOrder _buildPaidOrder() {
    return DemoOrder(
      id: demo.orderSeq++,
      type: s.type,
      table: s.table,
      customer: s.customer,
      status: 'Paid',
      items: List.of(items),
      method: _methodLabel,
      time: demo.timeNow,
      date: demo.dateNow,
      sub: s.sub,
      disc: s.disc,
      tax: s.tax,
      total: s.total,
      invoice: demo.nextInvoice(),
      tip: _tipAmt,
      tipPct: tipPct,
      facturaType: facturaType,
      customerNIF: facturaType == 'completa' ? nif : null,
    );
  }

  void _confirmPay() {
    // Re-check the closed-state guard at the moment of charge — the modal
    // can sit open while another view settles/cancels the same order.
    final src = s.srcOrder;
    if (src != null &&
        (src.status == 'Paid' ||
            src.status == 'Cancelled' ||
            src.status == 'Refunded')) {
      showToast(
        context,
        'Order #${src.id} is already ${src.status.toLowerCase()} — charge blocked',
        icon: AppIcons.info,
        kind: 'err',
      );
      return;
    }
    final redeemed = _pointsToRedeem;
    // Redeem points first (persists the new balance + tier).
    final c = _sessionCustomer;
    if (c != null && redeemed > 0) {
      demo.redeemPoints(c, redeemed);
    }
    // Customers are NEVER auto-created on payment: a typed, unlinked name
    // simply doesn't earn loyalty. Staff create/link customers explicitly
    // from the cart (inline create handles duplicate-name disambiguation).
    // Credit target: explicit link first, then the session-resolved record
    // by id — never a raw name (duplicate-name safety).
    final String? creditRef = s.customerId ??
        (c != null ? (c.dbId ?? c.id.toString()) : null);
    final DemoOrder order;
    if (s.srcOrder != null) {
      // Settling an existing bill — update the SAME DB row. Sequence is
      // deliberate: metadata + edited items/totals first (no status touch),
      // THEN settleOrder performs the single Paid transition so the guard
      // sees an unsettled order and emits payment side effects exactly once.
      final existing = s.srcOrder!;
      existing.method = _methodLabel;
      existing.invoice = existing.invoice ?? demo.nextInvoice();
      // Tip is stored separately (o.tip) — same convention as new orders,
      // so receipts/list views don't double-count it in the grand total.
      existing.tip = _tipAmt;
      existing.tipPct = tipPct;
      existing.facturaType = facturaType;
      existing.customerNIF = facturaType == 'completa' ? nif : null;
      demo.updateCommittedOrder(
        existing,
        items: items,
        sub: s.sub,
        disc: s.disc,
        tax: s.tax,
        total: s.total,
        // If the cart's customer changed after resume, sync the attribution.
        customerId: creditRef ?? '',
      );
      demo.settleOrder(existing);
      order = existing;
      demo.creditCustomer(creditRef, _netTotal);
    } else {
      order = _buildPaidOrder();
      demo.pushOrder(order, customerId: creditRef);
      demo.creditCustomer(creditRef, _netTotal);
    }
    // Gift card covers its part of the bill (partial redemption is fine —
    // the rest was taken by cash/card).
    if (gcId != null && _gcApplied > 0) {
      demo.redeemGiftCard(gcId, _gcApplied);
    }
    demo.freeTableByName(order.table);
    demo.addNotif(
      'Order #${order.id} paid successfully',
      '${fmt(_grand)} · $_methodLabel · ${order.invoice}',
      'ok',
    );
    demo.addAudit(
      'Order #${order.id} paid',
      'pay',
      '${fmt(_grand)} via $_methodLabel · ${order.invoice}'
          '${_gcApplied > 0 && !_gcCoversAll ? ' (gift card ${fmt(_gcApplied)} + '
              '${fmt(_dueAfterGc)} $method)' : ''}'
          '${_tipAmt > 0 ? ' (incl. ${fmt(_tipAmt)} tip)' : ''}',
    );

    setState(() => _paid = order);
  }

  DemoOrder? _paid;

  @override
  Widget build(BuildContext context) {
    final paid = _paid;
    if (paid != null) return _buildSuccess(context, paid);
    return _buildPay(context);
  }

  // ---------------------------------------------------------------------------

  Widget _buildPay(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 980,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkLine2 : AppColors.line2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text('Payment', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  Pill.preparing(
                    '${s.type.toUpperCase()}${s.table != null ? ' · ${s.table}' : ''}',
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(AppIcons.x, size: 20, color: AppColors.text3),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 800;
                    final left = _buildDetails(context);
                    final right = _buildMethodPanel(context);
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: left),
                          const SizedBox(width: 24),
                          SizedBox(width: 380, child: right),
                        ],
                      );
                    }
                    return Column(
                      children: [left, const SizedBox(height: 20), right],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction details',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        for (final l in items)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkLine2 : AppColors.line2,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${l.qty}× ${_products[l.productId]?.name ?? 'Item'}'
                    '${l.note != null ? '  (${l.note})' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: l.note != null ? FontWeight.w600 : FontWeight.w400,
                      color: l.note != null ? AppColors.amber : null,
                    ),
                  ),
                ),
                Text(
                  fmt(_lineTotal(l)),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        TotalRow('Subtotal', fmt(s.sub)),
        TotalRow('IVA', fmt(s.tax)),
        TotalRow('Total', fmt(s.total), total: true, fontSize: 15),
        if (_tipAmt > 0) ...[
          TotalRow('Tip ($tipPct%)', fmt(_tipAmt)),
          TotalRow('Grand Total', fmt(_grand), total: true, fontSize: 16),
        ],
        // Split payment: what the gift card takes and what is still due.
        if (_gcApplied > 0) ...[
          TotalRow('Gift card $gcCodeApplied', '−${fmt(_gcApplied)}', free: true),
          TotalRow(
            _gcCoversAll ? 'Balance due' : 'Due by $method',
            fmt(_dueAfterGc),
            total: true,
            fontSize: 15,
          ),
        ],
      ],
    );
  }

  double _lineTotal(CartLine l) {
    final p = _products[l.productId];
    if (p == null) return 0;
    final base = p.price * l.qty;
    final disc = l.discPct != null ? base * l.discPct! / 100 : 0;
    return base - disc;
  }

  Widget _buildMethodPanel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select a payment method', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final m in [
              ('Cash', AppIcons.cash),
              ('Debit Card', AppIcons.card),
              ('Bizum', AppIcons.wallet),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() {
                      // Reset the terminal confirmations when switching method,
                      // but keep any applied gift card — the split stays valid
                      // whichever way the remaining balance is collected.
                      _cardApproved = false;
                      _bizumReceived = false;
                      tender = '';
                      method = m.$1;
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: method == m.$1
                            ? AppColors.brand
                            : (isDark ? AppColors.darkCard2 : AppColors.card2),
                        border: Border.all(
                          color: method == m.$1
                              ? AppColors.brand
                              : (isDark ? AppColors.darkLine : AppColors.line),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            m.$2,
                            size: 20,
                            color: method == m.$1 ? Colors.white : AppColors.text2,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m.$1,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: method == m.$1 ? Colors.white : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        ..._methodBody(context),
        const SizedBox(height: 12),
        _buildGiftCardRow(context),
        const SizedBox(height: 14),
        if (_buildLoyaltyRow(context) != null) ...[
          _buildLoyaltyRow(context)!,
          const SizedBox(height: 14),
        ],
        _buildTipRow(context),
        const SizedBox(height: 12),
        _buildFacturaRow(context),
        if (facturaType == 'completa') ...[
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => nif = v,
            decoration: const InputDecoration(
              labelText: 'CUSTOMER NIF / CIF',
              hintText: 'e.g. B-87654321',
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _canPay ? _confirmPay : null,
            icon: const Icon(AppIcons.check, size: 18),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _gcApplied <= 0
                    ? 'Pay ${fmt(_dueAfterGc)}'
                    : (_gcCoversAll
                        ? 'Settle with gift card'
                        : 'Charge ${fmt(_dueAfterGc)} by $method'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Loyalty strip: shows the customer's points and lets staff redeem them
  /// against this bill. Returns null when loyalty is off / no customer.
  Widget? _buildLoyaltyRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = _sessionCustomer;
    if (c == null || !demo.loyaltyEnabled) return null;
    final earnPreview = (s.total * demo.earnRate).floor();
    final redeemable = _pointsToRedeem;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.violetT,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.star, size: 15, color: AppColors.violet),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${c.name} · ${c.points} pts (${c.tier})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: AppColors.violet,
                  ),
                ),
              ),
              Text(
                '+$earnPreview pts on this order',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText2 : AppColors.text2,
                ),
              ),
            ],
          ),
          if (c.points > 0 && s.total > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _redeemPoints = !_redeemPoints),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Icon(
                        _redeemPoints
                            ? AppIcons.checkCircle
                            : AppIcons.circleOutline,
                        size: 17,
                        color: _redeemPoints ? AppColors.violet : AppColors.text3,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Redeem $redeemable pts (−${fmt(_pointsDiscount)})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _redeemPoints ? AppColors.violet : AppColors.text2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _methodBody(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (method) {
      case 'Cash':
        // Only the part not covered by a gift card is collected in cash.
        final due = _dueAfterGc;
        final cands = <int>[];
        for (final c in [
          due.ceil(),
          (due / 5).ceil() * 5,
          (due / 10).ceil() * 10,
          (due / 50).ceil() * 50,
        ]) {
          if (!cands.contains(c) && cands.length < 4) cands.add(c);
        }
        final tenderVal = double.tryParse(tender) ?? 0;
        final change = tenderVal - due;
        return [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cands)
                InkWell(
                  onTap: () => setState(() => tender = '$c'),
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard2 : AppColors.card2,
                      border: Border.all(
                        color: tender == '$c' ? AppColors.brand : AppColors.line,
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '€$c',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2.4,
            children: [
              for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', '⌫'])
                InkWell(
                  onTap: () => setState(() {
                    if (k == 'C') {
                      tender = '';
                    } else if (k == '⌫') {
                      if (tender.isNotEmpty) tender = tender.substring(0, tender.length - 1);
                    } else if (tender.length < 6) {
                      tender += k;
                    }
                  }),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard2 : AppColors.card2,
                      border: Border.all(
                        color: isDark ? AppColors.darkLine : AppColors.line,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      k,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard2 : AppColors.card2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CASH RECEIVED',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.06,
                          color: AppColors.text3,
                        ),
                      ),
                      Text(
                        tender.isEmpty ? '€0' : '€$tender',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'CHANGE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.06,
                        color: AppColors.text3,
                      ),
                    ),
                    Text(
                      change >= 0 ? fmt(change) : '—',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: change >= 0 ? AppColors.green : AppColors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ];
      case 'Debit Card':
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard2 : AppColors.card2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.blueT,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(AppIcons.card, color: AppColors.blue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Charge on the card terminal',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          Text(
                            'Run the card for ${fmt(_dueAfterGc)} on your '
                            'terminal, then confirm once it is approved.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _cardApproved = !_cardApproved),
                    icon: Icon(
                      _cardApproved ? AppIcons.checkCircle : AppIcons.card,
                      size: 16,
                      color: _cardApproved ? AppColors.green : null,
                    ),
                    label: Text(
                      _cardApproved
                          ? 'Terminal approved — ready to charge'
                          : 'Terminal approved the charge',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      case 'Bizum':
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard2 : AppColors.card2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandT,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(AppIcons.wallet, color: AppColors.brand, size: 22),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bizum to your business phone',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  RestaurantInfo.phone.isEmpty
                      ? 'Ask the customer to send ${fmt(_dueAfterGc)} via '
                        'Bizum. Check your bank app, then confirm receipt.'
                      : 'Ask the customer to send ${fmt(_dueAfterGc)} via Bizum to '
                        '${RestaurantInfo.phone}. Check your bank app, then '
                        'confirm receipt.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.text2),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _bizumReceived = !_bizumReceived),
                    icon: Icon(
                      _bizumReceived ? AppIcons.checkCircle : AppIcons.wallet,
                      size: 16,
                      color: _bizumReceived ? AppColors.green : null,
                    ),
                    label: Text(
                      _bizumReceived ? 'Payment received — ready to charge' : 'I received the Bizum',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      default:
        return const [];
    }
  }

  Widget _buildTipRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tips = [
      ('0', 'No tip'),
      ('5', '5%'),
      ('10', '10%'),
      ('15', '15%'),
      ('custom', 'Custom'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tip', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in tips)
              InkWell(
                onTap: () {
                  if (t.$1 == 'custom') {
                    final controller = TextEditingController(text: '10');
                    showDialog<void>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        title: const Text('Custom tip %'),
                        content: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Tip percent'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dctx),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              final v = int.tryParse(controller.text) ?? 0;
                              if (mounted) setState(() => tipPct = v.clamp(0, 100));
                              Navigator.pop(dctx);
                            },
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }
                  setState(() => tipPct = int.parse(t.$1));
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: '$tipPct' == t.$1
                        ? AppColors.brand
                        : (isDark ? AppColors.darkCard2 : AppColors.card2),
                    border: Border.all(
                      color: '$tipPct' == t.$1
                          ? AppColors.brand
                          : (isDark ? AppColors.darkLine : AppColors.line),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.$2,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: '$tipPct' == t.$1 ? Colors.white : null,
                        ),
                      ),
                      if (t.$1 != '0' && t.$1 != 'custom')
                        Text(
                          fmt(s.total * int.parse(t.$1) / 100),
                          style: TextStyle(
                            fontSize: 10,
                            color: '$tipPct' == t.$1
                                ? Colors.white70
                                : AppColors.text3,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFacturaRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: _facturaBtn(
            'Simplificada',
            AppIcons.receipt,
            facturaType == 'simplificada',
            isDark,
            onTap: () => setState(() => facturaType = 'simplificada'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _facturaBtn(
            'Completa (B2B)',
            AppIcons.buildings,
            facturaType == 'completa',
            isDark,
            onTap: () => setState(() => facturaType = 'completa'),
          ),
        ),
      ],
    );
  }

  Widget _facturaBtn(
    String label,
    IconData icon,
    bool selected,
    bool isDark, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandT
              : (isDark ? AppColors.darkCard2 : AppColors.card2),
          border: Border.all(
            color: selected ? AppColors.brand : (isDark ? AppColors.darkLine : AppColors.line),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: selected ? AppColors.brand : AppColors.text3),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.brand : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _buildSuccess(BuildContext context, DemoOrder order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(26),
                child: Column(
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: AppColors.greenT,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        AppIcons.checkCircle,
                        size: 40,
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Payment successful!',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Order #${order.id} · '
                      '${fmt(order.total + order.tip)} via ${order.method}'
                      '${order.tip > 0 ? ' · Tip ${fmt(order.tip)}' : ''}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkText2 : AppColors.text2,
                      ),
                    ),
                    Text(
                      '${order.facturaType == 'completa' ? 'Factura Completa' : 'Factura Simplificada'}'
                      ' · ${order.invoice}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.text3,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ReceiptView(order: order),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkLine2 : AppColors.line2,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _printing ? null : () => _printReceipt(order),
                    icon: _printing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIcons.printer, size: 16),
                    label: const Text('Print Receipt'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, order),
                    icon: const Icon(AppIcons.plus, size: 16),
                    label: const Text('New Order'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printReceipt(DemoOrder order) async {
    setState(() => _printing = true);
    try {
      await Printing.layoutPdf(
        name: 'Receipt ${order.invoice ?? order.id}',
        onLayout: (format) => buildReceiptPdf(order),
      );
    } catch (e) {
      if (mounted) {
        showToast(context, 'Could not print: $e', icon: AppIcons.x, kind: 'err');
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }
}

/// Styled receipt (monospace) mirroring `receiptHTML` in the design.
class ReceiptView extends StatelessWidget {
  final DemoOrder order;
  const ReceiptView({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: 11,
      height: 1.5,
      color: isDark ? AppColors.darkText : AppColors.text,
    );
    final muted = TextStyle(
      fontFamily: 'monospace',
      fontSize: 10,
      height: 1.4,
      color: isDark ? AppColors.darkText3 : AppColors.text3,
    );
    final bold = mono.copyWith(fontWeight: FontWeight.w800);

    String lineTotal(CartLine l) {
      final p = demo.product(l.productId);
      final base = (p?.price ?? 0) * l.qty;
      final disc = l.discPct != null ? base * l.discPct! / 100 : 0;
      return fmt(base - disc);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkLine : AppColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(RestaurantInfo.name, style: bold),
          if (RestaurantInfo.legal.isNotEmpty) Text(RestaurantInfo.legal, style: muted),
          if (RestaurantInfo.address.isNotEmpty)
            Text(RestaurantInfo.address, style: muted),
          if (RestaurantInfo.cif.isNotEmpty)
            Text('CIF: ${RestaurantInfo.cif}', style: muted),
          if (RestaurantInfo.phone.isNotEmpty)
            Text('Tel: ${RestaurantInfo.phone}', style: muted),
          Text('Branch: ${RestaurantInfo.branchLabel}', style: muted),
          const SizedBox(height: 6),
          Text(
            '${order.facturaType == 'completa' ? 'FACTURA COMPLETA' : 'FACTURA SIMPLIFICADA'}'
            '   Nº ${order.invoice}',
            style: bold.copyWith(color: AppColors.brand),
          ),
          Divider(color: isDark ? AppColors.darkLine : AppColors.line, height: 14),
          Text('Order #${order.id} · ${order.date} ${order.time}', style: muted),
          Text(
            '${order.customer}${order.table != null ? ' · Table ${order.table}' : ''}'
            ' · ${order.type}'
            '${order.customerNIF != null ? '\nNIF: ${order.customerNIF}' : ''}',
            style: muted,
          ),
          Divider(color: isDark ? AppColors.darkLine : AppColors.line, height: 14),
          for (final l in order.items)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l.qty}× ${demo.product(l.productId)?.name ?? 'Item'}'
                    '${l.note != null ? ' (${l.note})' : ''}',
                    style: mono,
                  ),
                ),
                Text(lineTotal(l), style: mono),
              ],
            ),
          Divider(color: isDark ? AppColors.darkLine : AppColors.line, height: 14),
          _rLine('Subtotal', fmt(order.sub)),
          if (order.disc > 0) _rLine('Discount', '−${fmt(order.disc)}'),
          _rLine('IVA', fmt(order.tax)),
          _rLine('TOTAL', fmt(order.total), total: true),
          if (order.tip > 0) _rLine('Propina (${order.tipPct}%)', fmt(order.tip)),
          if (order.tip > 0)
            _rLine('TOTAL COBRADO', fmt(order.total + order.tip), total: true),
          _rLine('Paid via', order.method ?? '—'),
          Divider(color: isDark ? AppColors.darkLine : AppColors.line, height: 14),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Thank you for dining with us! ★',
              style: muted.copyWith(color: AppColors.brand),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rLine(String label, String value, {bool total = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: total ? const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'monospace', fontSize: 11) : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: total ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds a print-ready 80mm thermal receipt PDF for [order] using the
/// workspace details configured in Settings.
Future<Uint8List> buildReceiptPdf(DemoOrder order) => buildReceiptsPdf([order]);

/// Builds one 80mm receipt page per order — used by the payment modal and
/// the bulk print action in Orders.
Future<Uint8List> buildReceiptsPdf(List<DemoOrder> orders) {
  final doc = pw.Document();

  pw.Widget line(String label, String value, {bool total = false}) {
    final style = pw.TextStyle(fontSize: total ? 10 : 8.5, fontWeight: total ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.8),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  for (final order in orders) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) {
          final muted = pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700);
          return pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    RestaurantInfo.name,
                    style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                if (RestaurantInfo.legal.isNotEmpty)
                  pw.Center(child: pw.Text(RestaurantInfo.legal, style: muted)),
                if (RestaurantInfo.address.isNotEmpty)
                  pw.Center(child: pw.Text(RestaurantInfo.address, style: muted)),
                if (RestaurantInfo.cif.isNotEmpty)
                  pw.Center(child: pw.Text('CIF: ${RestaurantInfo.cif}', style: muted)),
                if (RestaurantInfo.phone.isNotEmpty)
                  pw.Center(child: pw.Text('Tel: ${RestaurantInfo.phone}', style: muted)),
                // The location that made the sale — printed on every receipt
                // and invoice so multi-branch sales stay traceable.
                pw.Center(
                  child: pw.Text(
                    'Branch: ${RestaurantInfo.branchLabel}',
                    style: muted,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text(
                    order.facturaType == 'completa'
                        ? 'FACTURA COMPLETA'
                        : 'FACTURA SIMPLIFICADA',
                    style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Center(child: pw.Text('Nº ${order.invoice ?? order.id}', style: muted)),
                pw.Divider(height: 10),
                pw.Text('Order #${order.id} · ${order.date} ${order.time}', style: muted),
                pw.Text(
                  '${order.customer}'
                  '${order.table != null ? ' · Table ${order.table}' : ''}'
                  ' · ${order.type}',
                  style: muted,
                ),
                if (order.customerNIF != null && order.customerNIF!.isNotEmpty)
                  pw.Text('NIF: ${order.customerNIF}', style: muted),
                pw.Divider(height: 10),
                for (final l in order.items)
                  line(
                    '${l.qty}× ${demo.product(l.productId)?.name ?? 'Item'}'
                    '${l.note != null ? ' (${l.note})' : ''}',
                    fmt((demo.product(l.productId)?.price ?? 0) * l.qty),
                  ),
                pw.Divider(height: 10),
                line('Subtotal', fmt(order.sub)),
                if (order.disc > 0) line('Discount', '-${fmt(order.disc)}'),
                line('IVA', fmt(order.tax)),
                line('TOTAL', fmt(order.total), total: true),
                if (order.tip > 0) line('Propina (${order.tipPct}%)', fmt(order.tip)),
                if (order.tip > 0)
                  line('TOTAL COBRADO', fmt(order.total + order.tip), total: true),
                line('Paid via', order.method ?? '—'),
                pw.Divider(height: 10),
                pw.Center(
                  child: pw.Text(
                    'Thank you for dining with us! *',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  return doc.save();
}
