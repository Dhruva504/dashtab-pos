import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/demo_data.dart';
import '../../theme/app_widgets.dart';
import '../../../features/auth/providers/auth_provider.dart';

/// Settings view — 7 tabs, all backed by the live workspace.
class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  String _tab = 'profile';

  final _restName = TextEditingController();
  final _restLegal = TextEditingController();
  final _restCif = TextEditingController();
  final _restAddress = TextEditingController();
  final _restPhone = TextEditingController();
  final _restEmail = TextEditingController();
  final _invoicePrefix = TextEditingController();
  final _profName = TextEditingController();
  final _profPhone = TextEditingController();
  final _profPin = TextEditingController();
  final _lowStock = TextEditingController();
  final _expiryWarn = TextEditingController();
  bool _profSeeded = false;

  @override
  void dispose() {
    _restName.dispose();
    _restLegal.dispose();
    _restCif.dispose();
    _restAddress.dispose();
    _restPhone.dispose();
    _restEmail.dispose();
    _invoicePrefix.dispose();
    _profName.dispose();
    _profPhone.dispose();
    _profPin.dispose();
    _lowStock.dispose();
    _expiryWarn.dispose();
    super.dispose();
  }

  /// Seeds the restaurant config fields from the store once data is loaded.
  void _seedFromStore() {
    if (demo.settings.isEmpty || _restName.text.isNotEmpty) return;
    _restName.text = demo.settings['name'] ?? '';
    _restLegal.text = demo.settings['legal_name'] ?? '';
    _restCif.text = demo.settings['cif'] ?? '';
    _restAddress.text = demo.settings['address'] ?? '';
    _restPhone.text = demo.settings['phone'] ?? '';
    _restEmail.text = demo.settings['email'] ?? '';
    _invoicePrefix.text = demo.settings['invoice_prefix'] ?? '';
    _lowStock.text = demo.settings['low_stock_threshold'] ??
        RestaurantInfo.lowStockThreshold.toString();
    _expiryWarn.text = demo.settings['expiry_warn_days'] ??
        RestaurantInfo.expiryWarnDays.toString();
    if (!_profSeeded && demo.settings.isNotEmpty) {
      _profSeeded = true;
      _profName.text = demo.settings['profile_name'] ??
          (ref.read(authProvider).fullName ?? '');
      _profPhone.text = demo.settings['profile_phone'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _seedFromStore();
    final auth = ref.watch(authProvider);
    final userName = auth.fullName ?? 'User';
    final initials = userName
        .split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '?' : w[0])
        .join()
        .toUpperCase();
    final userRole =
        demo.staff.where((s) => s.authId == auth.userId).firstOrNull?.role ??
            'Owner';
    final tabs = [
      ('profile', 'Profile', AppIcons.user),
      ('restaurant', 'Restaurant', AppIcons.store),
      ('stock', 'Stock & Inventory', AppIcons.box),
      ('tax', 'IVA & Taxes', AppIcons.tax),
      ('discounts', 'Promo Codes', AppIcons.tag),
      ('fiscal', 'Fiscal', AppIcons.shield),
      ('roles', 'Roles', AppIcons.key),
      ('branches', 'Branches', AppIcons.branch),
      ('cloud', 'Cloud', AppIcons.cloud),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              return FilterChipBtn(
                label: tabs[i].$2,
                selected: _tab == tabs[i].$1,
                onTap: () => setState(() => _tab = tabs[i].$1),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (_tab == 'profile')
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personal Information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Update your own details. Email and role are managed from Staff.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkText3 : AppColors.text3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8A4C), AppColors.brand],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            userRole,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? AppColors.darkText2
                                  : AppColors.text2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsInput(label: 'FULL NAME', controller: _profName),
                  _SettingsInput(label: 'PHONE', controller: _profPhone),
                  _SettingsInput(
                    label: demo.hasPin
                        ? 'POS PIN — SET (ENTER A NEW ONE TO CHANGE)'
                        : 'POS PIN (4–8 DIGITS, QUICK LOGIN)',
                    controller: _profPin,
                    keyboardType: TextInputType.number,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          demo.hasPin ? AppIcons.lock : AppIcons.info,
                          size: 15,
                          color: isDark
                              ? AppColors.darkText3
                              : AppColors.text3,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            demo.hasPin
                                ? 'The workspace locks on start and the POS '
                                    'asks for this PIN before it opens. '
                                    'Stored only as a hash.'
                                : 'Set a PIN to lock the workspace on start and '
                                    'gate the POS with a quick login.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkText3
                                  : AppColors.text3,
                            ),
                          ),
                        ),
                        if (demo.hasPin)
                          TextButton.icon(
                            onPressed: () async {
                              await demo.clearPin();
                              if (!context.mounted) return;
                              setState(() {});
                              showToast(
                                context,
                                'POS PIN removed',
                                subtitle: 'The workspace no longer locks.',
                                icon: AppIcons.lock,
                                kind: 'warn',
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.red,
                            ),
                            icon: const Icon(AppIcons.trash, size: 14),
                            label: const Text('Remove PIN'),
                          ),
                      ],
                    ),
                  ),
                  _SettingsField(
                    label: 'EMAIL (login — read only)',
                    value: auth.email ?? '—',
                  ),
                  _SettingsField(label: 'ROLE', value: userRole),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final newName = _profName.text.trim();
                        final pinText = _profPin.text.trim();
                        // A PIN is 4–8 digits; ignore an empty field so saving
                        // the rest of the profile doesn't wipe an existing PIN.
                        if (pinText.isNotEmpty &&
                            (pinText.length < 4 ||
                                pinText.length > 8 ||
                                int.tryParse(pinText) == null)) {
                          showToast(
                            context,
                            'PIN must be 4–8 digits',
                            icon: AppIcons.x,
                            kind: 'warn',
                          );
                          return;
                        }
                        await demo.saveProfile(
                          fullName: newName,
                          phone: _profPhone.text.trim(),
                          pin: pinText,
                        );
                        _profPin.clear();
                        // Sync the auth metadata so the topbar/sidebar
                        // display name updates everywhere immediately.
                        String? err;
                        if (newName.isNotEmpty && newName != userName) {
                          err = await ref
                              .read(authProvider.notifier)
                              .updateDisplayName(newName);
                        }
                        if (!context.mounted) return;
                        if (err != null) {
                          showToast(
                            context,
                            'Saved locally',
                            subtitle: err,
                            icon: AppIcons.x,
                            kind: 'err',
                          );
                        } else {
                          showToast(
                            context,
                            'Profile saved',
                            subtitle: 'Your details have been updated.',
                            icon: AppIcons.check,
                          );
                        }
                        setState(() {});
                      },
                      icon: const Icon(AppIcons.check, size: 16),
                      label: const Text('Save profile'),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_tab == 'tax')
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Tax Rates',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _showTaxRateDialog(context, null),
                        icon: const Icon(AppIcons.plus, size: 16),
                        label: const Text('Add rate'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rates are applied to products in Menu Items. The default rate is preselected for new dishes.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkText3 : AppColors.text3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (demo.taxRates.isEmpty)
                    _emptyHint(
                        'No tax rates yet — add one, e.g. IVA 21%.', isDark)
                  else
                    for (final t in demo.taxRates)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard2 : AppColors.card2,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${t.rate == t.rate.roundToDouble() ? t.rate.toStringAsFixed(0) : t.rate.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brand,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        t.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (t.isDefault) ...[
                                        const SizedBox(width: 8),
                                        const Pill.paid('DEFAULT'),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    t.isInclusive
                                        ? 'Prices include this tax'
                                        : 'Tax added on top of prices',
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
                            TextButton(
                              onPressed: () =>
                                  _showTaxRateDialog(context, t),
                              child: const Text('Edit'),
                            ),
                            IconButton(
                              tooltip: 'Delete rate',
                              icon: const Icon(AppIcons.trash,
                                  size: 16, color: AppColors.red),
                              onPressed: () async {
                                final n = demo.products
                                    .where((p) => p.iva == t.rate.round())
                                    .length;
                                var msg = 'Delete "${t.name}" (${t.rate}%)?';
                                if (n > 0) {
                                  msg =
                                      '$n product(s) use ${t.rate}%. Deleting this rate won\'t change them, but it will no longer be selectable for new products.';
                                }
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete tax rate?'),
                                    content: Text(msg),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  setState(() {
                                    final idx = demo.taxRates.indexOf(t);
                                    demo.deleteTaxRate(t);
                                    final undo = demo.scheduleDbDelete(
                                      () => demo.deleteTaxRateDb(t),
                                      undoUi: () {
                                        if (idx >= 0) {
                                          demo.taxRates.insert(
                                              idx.clamp(0, demo.taxRates.length),
                                              t);
                                        } else {
                                          demo.taxRates.add(t);
                                        }
                                      },
                                    );
                                    showToast(
                                      context,
                                      '${t.name} deleted',
                                      subtitle: 'Deleting in 5s',
                                      icon: AppIcons.trash,
                                      kind: 'danger',
                                      actionLabel: 'Undo',
                                      onAction: () {
                                        undo();
                                        demo.addAudit(
                                            'Delete undone', 'update', t.name);
                                      },
                                      duration: const Duration(seconds: 5),
                                    );
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          )
        else if (_tab == 'branches')
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Branches',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _showBranchDialog(context, null),
                        icon: const Icon(AppIcons.plus, size: 16),
                        label: const Text('Add branch'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Each branch is a separate location with its own terminals.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkText3 : AppColors.text3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (demo.branches.isEmpty)
                    _emptyHint('No branches configured for this workspace.', isDark)
                  else
                    for (final b in demo.branches)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark
                                  ? AppColors.darkLine2
                                  : AppColors.line2,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              AppIcons.buildings,
                              size: 18,
                              color: AppColors.brand,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.full,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    [
                                      if (b.city.isNotEmpty) b.city,
                                      if (b.manager.isNotEmpty)
                                        'Manager: ${b.manager}',
                                      if (b.cif.isNotEmpty) 'CIF ${b.cif}',
                                      '${b.terminals} terminal${b.terminals == 1 ? '' : 's'}',
                                    ].join(' · '),
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
                            Pill.paid(b.status == 'active' ? 'ACTIVE' : 'INACTIVE'),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: () => _showBranchDialog(context, b),
                              child: const Text('Edit'),
                            ),
                            IconButton(
                              tooltip: 'Delete branch',
                              icon: const Icon(AppIcons.trash,
                                  size: 16, color: AppColors.red),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('Delete ${b.name}?'),
                                    content: const Text(
                                      'The branch is removed from this workspace. Its sales history stays in reports.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  setState(() {
                                    final idx = demo.branches.indexOf(b);
                                    demo.deleteBranch(b);
                                    final undo = demo.scheduleDbDelete(
                                      () => demo.deleteBranchDb(b),
                                      undoUi: () {
                                        if (idx >= 0) {
                                          demo.branches.insert(
                                              idx.clamp(0, demo.branches.length),
                                              b);
                                        } else {
                                          demo.branches.add(b);
                                        }
                                      },
                                    );
                                    showToast(
                                      context,
                                      '${b.name} deleted',
                                      subtitle: 'Deleting in 5s',
                                      icon: AppIcons.trash,
                                      kind: 'danger',
                                      actionLabel: 'Undo',
                                      onAction: () {
                                        undo();
                                        demo.addAudit(
                                            'Delete undone', 'update', b.name);
                                      },
                                      duration: const Duration(seconds: 5),
                                    );
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          )
        else if (_tab == 'restaurant')
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restaurant Configuration',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'These details are printed on receipts and invoices.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkText3 : AppColors.text3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsInput(label: 'RESTAURANT NAME', controller: _restName),
                  _SettingsInput(label: 'LEGAL NAME', controller: _restLegal),
                  _SettingsInput(label: 'CIF / NIF (TAX ID)', controller: _restCif),
                  _SettingsInput(
                    label: 'INVOICE PREFIX (OPTIONAL, E.G. FAC/A/)',
                    controller: _invoicePrefix,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard2 : AppColors.card2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Currency Euro (€) · Language Español · Timezone Europe/Madrid',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? AppColors.darkText2
                            : AppColors.text2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SettingsInput(label: 'ADDRESS', controller: _restAddress),
                  _SettingsInput(label: 'PHONE', controller: _restPhone),
                  _SettingsInput(label: 'EMAIL', controller: _restEmail),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          _restName.clear();
                          _restLegal.clear();
                          _restCif.clear();
                          _restAddress.clear();
                          _restPhone.clear();
                          _restEmail.clear();
                          _invoicePrefix.clear();
                          _seedFromStore();
                          setState(() {});
                        },
                        child: const Text('Discard'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          demo.saveRestaurant({
                            'name': _restName.text,
                            'legal_name': _restLegal.text,
                            'cif': _restCif.text,
                            'invoice_prefix': _invoicePrefix.text,
                            'address': _restAddress.text,
                            'phone': _restPhone.text,
                            'email': _restEmail.text,
                          });
                          showToast(
                            context,
                            'Configuration saved',
                            icon: AppIcons.check,
                          );
                        },
                        child: const Text('Save Configuration'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else if (_tab == 'stock')
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stock & Inventory',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Thresholds used by Product Management, Inventory and the '
                    'dashboard warnings.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkText3 : AppColors.text3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lowStock,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'LOW STOCK AT (UNITS)',
                            helperText:
                                'Dishes at/below this count as low stock',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _expiryWarn,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'EXPIRY WARNING (DAYS BEFORE)',
                            helperText:
                                'Inventory items expiring within this window are flagged',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard2 : AppColors.card2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Used by: the “Low stock” filter and badges in Product '
                      'Management, the default restock quantity (threshold × 4), '
                      'the “Expiring” filter in Inventory, and the Expiry alerts '
                      'card on the Dashboard.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? AppColors.darkText2
                            : AppColors.text2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          _seedFromStore();
                          setState(() {});
                        },
                        child: const Text('Discard'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          demo.saveRestaurant({
                            'low_stock_threshold': _lowStock.text.trim(),
                            'expiry_warn_days': _expiryWarn.text.trim(),
                          });
                          demo.addAudit(
                            'Stock settings updated',
                            'update',
                            'Low stock ${_lowStock.text.trim()} · '
                                'expiry warn ${_expiryWarn.text.trim()} days',
                          );
                          showToast(
                            context,
                            'Stock settings saved',
                            icon: AppIcons.check,
                          );
                        },
                        child: const Text('Save Stock Settings'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else if (_tab == 'discounts')
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Promo Codes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _showDiscountDialog,
                        icon: const Icon(AppIcons.plus, size: 16),
                        label: const Text('New promo code'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Codes you create here can be applied at the POS in the '
                    'cart panel. Deactivated codes stop working immediately.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkText3 : AppColors.text3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (demo.discounts.isEmpty)
                    _emptyHint(
                      'No active promo codes. Create one to offer a '
                      'percentage or fixed-amount discount at the POS.',
                      isDark,
                    )
                  else
                    for (final d in demo.discounts)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard2 : AppColors.card2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandT,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                d.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: AppColors.brand,
                                  letterSpacing: 0.04,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                d.type == 0
                                    ? '${d.value.toStringAsFixed(0)}% off the subtotal'
                                    : '${fmt(d.value)} off the subtotal',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark
                                      ? AppColors.darkText2
                                      : AppColors.text2,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                demo.deactivateDiscount(d);
                                setState(() {});
                                showToast(
                                  context,
                                  'Promo code ${d.name} deactivated',
                                  icon: AppIcons.check,
                                );
                              },
                              child: const Text('Deactivate'),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          )
        else if (_tab == 'fiscal')
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fiscal Features',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'What this system does today',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkText3 : AppColors.text3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final f in [
                    (AppIcons.receipt, 'Sequential invoice numbering',
                        'Atomic, gap-free per-year series with an optional prefix'),
                    (AppIcons.book, 'Simplified & full invoices',
                        'Factura simplificada by default; factura completa records the customer NIF'),
                    (AppIcons.shield, 'Action audit log',
                        'Payments, refunds, discounts and staff changes are logged with user and time'),
                    (AppIcons.refund, 'Refund tracking',
                        'Refunds are recorded against the original order and cash drawer'),
                  ])
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard2 : AppColors.card2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.brandT,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(f.$1, size: 18, color: AppColors.brand),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.$2,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Text(
                                  f.$3,
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
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.amberT,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(AppIcons.info, size: 17, color: AppColors.amber),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This software does not provide AEAT/Verifactu '
                            'certification, fiscal QR codes, or signed invoice '
                            'transmission. Spanish restaurants required to '
                            'comply with Verifactu must connect a certified '
                            'billing provider — consult your asesor fiscal.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.amber,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_tab == 'roles')
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Roles',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Pill.paid('${demo.staff.where((s) => s.active).length} ACTIVE'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Roles are assigned when you add or edit a staff member '
                    'in Staff.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkText3 : AppColors.text3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (demo.staff.isEmpty)
                    _emptyHint('No staff accounts yet. Add them from Staff.', isDark)
                  else
                    for (final s in demo.staff)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
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
                                  Text(
                                    s.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  Text(
                                    [
                                      s.role,
                                      if (s.email != null && s.email!.isNotEmpty) s.email!,
                                      if (!s.canLogIn) 'no login yet',
                                    ].join(' · '),
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
                            s.active
                                ? const Pill.paid('ACTIVE')
                                : const Pill.pending('INACTIVE'),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          )
        else
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Cloud Sync',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      demo.syncError != null
                          ? const Pill.pending('ATTENTION')
                          : const Pill.paid('ONLINE'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard2 : AppColors.card2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _syncRow(
                          'Data lives in your Supabase cloud project',
                          'Orders, menu, customers and cash drawer are saved '
                          'to PostgreSQL as they happen.',
                        ),
                        _syncRow(
                          'Live updates across terminals',
                          'Realtime subscriptions plus a periodic refresh keep '
                          'kitchen, tables and orders in sync.',
                        ),
                        _syncRow(
                          'Row Level Security',
                          'Every table is tenant-scoped; staff only ever see '
                          'this workspace\'s data.',
                        ),
                      ],
                    ),
                  ),
                  if (demo.syncError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.redT,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(AppIcons.x, size: 16, color: AppColors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              demo.syncError!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(AppIcons.cloud, size: 16, color: AppColors.text3),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          demo.syncing
                              ? 'Syncing changes…'
                              : 'All changes saved',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppColors.darkText2 : AppColors.text2,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await demo.refresh();
                          if (context.mounted) {
                            showToast(
                              context,
                              'Workspace synced',
                              subtitle: 'Data refreshed from the cloud',
                              icon: AppIcons.cloud,
                            );
                          }
                        },
                        icon: const Icon(AppIcons.download, size: 16),
                        label: const Text('Sync now'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showDiscountDialog() {
    final code = TextEditingController();
    final value = TextEditingController();
    var type = 0; // 0 = percentage, 1 = fixed amount
    bool creating = false;

    showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDialog) => AlertDialog(
          title: const Text('New promo code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'CODE',
                  hintText: 'e.g. HOTO10',
                  prefixIcon: Icon(AppIcons.tag, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'DISCOUNT TYPE'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Percentage off')),
                  DropdownMenuItem(value: 1, child: Text('Fixed amount off (€)')),
                ],
                onChanged: (v) => setDialog(() => type = v ?? 0),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: value,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: type == 0 ? 'PERCENT (%)' : 'AMOUNT (€)',
                  hintText: type == 0 ? 'e.g. 10' : 'e.g. 2.50',
                  prefixIcon: const Icon(AppIcons.cash, size: 18),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: creating ? null : () => Navigator.pop(dctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: creating
                  ? null
                  : () async {
                      setDialog(() => creating = true);
                      final error = await demo.addDiscount(
                        name: code.text,
                        type: type,
                        value:
                            double.tryParse(value.text.replaceAll(',', '.')) ??
                                0,
                      );
                      if (!mounted) return;
                      if (dctx.mounted) Navigator.pop(dctx);
                      if (error != null) {
                        showToast(
                          context,
                          'Could not create the promo code',
                          subtitle: error,
                          icon: AppIcons.x,
                          kind: 'err',
                        );
                      } else {
                        setState(() {});
                        showToast(
                          context,
                          'Promo code ${code.text.trim().toUpperCase()} created',
                          icon: AppIcons.check,
                        );
                      }
                    },
              child: creating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _syncRow(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.checkCircle, size: 16, color: AppColors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Branch & tax-rate dialogs
  // ------------------------------------------------------------------

  Future<void> _showBranchDialog(BuildContext context, Branch? existing) =>
      showDialog<void>(
        context: context,
        builder: (ctx) {
          final name = TextEditingController(text: existing?.name ?? '');
          final full = TextEditingController(text: existing?.full ?? '');
          final city = TextEditingController(text: existing?.city ?? '');
          final cif = TextEditingController(text: existing?.cif ?? '');
          final manager = TextEditingController(text: existing?.manager ?? '');
          final terminals =
              TextEditingController(text: '${existing?.terminals ?? 1}');
          var active = existing?.status != 'inactive';
          return StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              title: Text(existing == null ? 'Add branch' : 'Edit branch'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      autofocus: existing == null,
                      decoration: const InputDecoration(
                          labelText: 'Short name * (e.g. Gran Vía)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: full,
                      decoration: const InputDecoration(
                          labelText: 'Full legal name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: city,
                      decoration: const InputDecoration(labelText: 'City'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: manager,
                      decoration: const InputDecoration(
                          labelText: 'Manager'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: cif,
                      decoration: const InputDecoration(labelText: 'CIF / NIF'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: terminals,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Terminals'),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: active,
                      onChanged: (v) => setDialogState(() => active = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final n = name.text.trim();
                    if (n.isEmpty) return;
                    final term = int.tryParse(terminals.text.trim()) ?? 1;
                    if (existing == null) {
                      await demo.addBranch(
                        name: n,
                        full: full.text.trim(),
                        city: city.text.trim(),
                        cif: cif.text.trim(),
                        manager: manager.text.trim(),
                        terminals: term,
                      );
                    } else {
                      demo.editBranch(
                        existing,
                        name: n,
                        full: full.text.trim(),
                        city: city.text.trim(),
                        cif: cif.text.trim(),
                        manager: manager.text.trim(),
                        terminals: term,
                        status: active ? 'active' : 'inactive',
                      );
                    }
                    if (context.mounted) Navigator.pop(ctx);
                    setState(() {});
                  },
                  child: Text(existing == null ? 'Add' : 'Save'),
                ),
              ],
            ),
          );
        },
      );

  Future<void> _showTaxRateDialog(BuildContext context, TaxRate? existing) =>
      showDialog<void>(
        context: context,
        builder: (ctx) {
          final name = TextEditingController(text: existing?.name ?? '');
          final rate = TextEditingController(
              text: existing == null
                  ? ''
                  : existing.rate == existing.rate.roundToDouble()
                      ? existing.rate.toStringAsFixed(0)
                      : existing.rate.toStringAsFixed(1));
          var inclusive = existing?.isInclusive ?? true;
          var isDefault = existing?.isDefault ?? false;
          return StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              title: Text(existing == null ? 'Add tax rate' : 'Edit tax rate'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      autofocus: existing == null,
                      decoration: const InputDecoration(
                          labelText: 'Name * (e.g. IVA 21%)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: rate,
                      autofocus: existing != null,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Rate % * (e.g. 21 or 10.5)'),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Prices include this tax'),
                      subtitle: const Text(
                          'Off = tax is added on top at checkout'),
                      value: inclusive,
                      onChanged: (v) => setDialogState(() => inclusive = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Default rate'),
                      subtitle: const Text(
                          'Preselected for new products'),
                      value: isDefault,
                      onChanged: (v) => setDialogState(() => isDefault = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final n = name.text.trim();
                    final r = double.tryParse(rate.text.trim().replaceAll(',', '.'));
                    if (n.isEmpty || r == null || r < 0 || r > 100) return;
                    if (existing == null) {
                      demo.addTaxRate(
                        name: n,
                        rate: r,
                        isInclusive: inclusive,
                        makeDefault: isDefault,
                      );
                    } else {
                      demo.editTaxRate(
                        existing,
                        name: n,
                        rate: r,
                        isInclusive: inclusive,
                        makeDefault: isDefault,
                      );
                    }
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                  child: Text(existing == null ? 'Add' : 'Save'),
                ),
              ],
            ),
          );
        },
      );

  Widget _emptyHint(String message, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkText3 : AppColors.text3,
          ),
        ),
      ),
    );
  }
}

class _SettingsInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const _SettingsInput({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.02,
              color: isDark ? AppColors.darkText2 : AppColors.text2,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: const InputDecoration(),
          ),
        ],
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  final String label;
  final String value;

  const _SettingsField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.02,
              color: isDark ? AppColors.darkText2 : AppColors.text2,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: value),
            decoration: const InputDecoration(),
          ),
        ],
      ),
    );
  }
}
