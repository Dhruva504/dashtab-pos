import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/demo_data.dart';
import '../../theme/app_widgets.dart';
import '../widgets/csv_export.dart';

/// Audit view — filterable, paginated audit trail with CSV exports.
class AuditView extends ConsumerStatefulWidget {
  const AuditView({super.key});

  @override
  ConsumerState<AuditView> createState() => _AuditViewState();
}

class _AuditViewState extends ConsumerState<AuditView> {
  String _filter = 'All';
  String _userFilter = 'All users';
  String _range = 'All time'; // All time | Today | 7 days | 30 days
  static const _pageSize = 25;
  int _visible = _pageSize;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AuditEntry> get _filtered {
    final d = demo;
    final q = _search.text.toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? from;
    if (_range == 'Today') from = today;
    if (_range == '7 days') from = today.subtract(const Duration(days: 6));
    if (_range == '30 days') from = today.subtract(const Duration(days: 29));

    return d.auditLogs.where((a) {
      final matchesFilter = _filter == 'All' || a.type == _filter;
      final matchesUser = _userFilter == 'All users' || a.user == _userFilter;
      final matchesRange = from == null ||
          (a.createdAt != null && !a.createdAt!.isBefore(from));
      final matchesQ =
          q.isEmpty ||
          a.action.toLowerCase().contains(q) ||
          a.user.toLowerCase().contains(q) ||
          a.detail.toLowerCase().contains(q);
      return matchesFilter && matchesUser && matchesRange && matchesQ;
    }).toList();
  }

  String _csvDate(DateTime? t) => t?.toIso8601String() ?? '';

  Future<void> _saveCsv(String defaultName, String csv, int rows) async {
    await saveFileToChosenLocation(
      context: context,
      data: csv,
      defaultName: defaultName,
      label: 'CSV',
      subtitle: '$rows rows · exported by DashTab POS',
    );
  }

  Future<void> _exportAuditCsv() async {
    final rows = _filtered;
    final csv = buildCsv([
      ['timestamp', 'action', 'type', 'user', 'role', 'detail'],
      for (final a in rows)
        [a.createdAt?.toIso8601String() ?? '', a.action, a.type, a.user, a.role, a.detail],
    ]);
    await _saveCsv(
      'audit-logs-${DateTime.now().toIso8601String().split('T').first}.csv',
      csv,
      rows.length,
    );
  }

  /// Orders report — revenue rows for compliance review, scoped to the same
  /// date range selected on the audit screen.
  Future<void> _exportOrdersCsv() async {
    final d = demo;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? from;
    if (_range == 'Today') from = today;
    if (_range == '7 days') from = today.subtract(const Duration(days: 6));
    if (_range == '30 days') from = today.subtract(const Duration(days: 29));

    final rows = d.orders.where((o) {
      final c = o.createdAt;
      return c != null && (from == null || !c.isBefore(from));
    }).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

    final csv = buildCsv([
      [
        'order_id', 'date', 'type', 'table', 'customer', 'status', 'items',
        'subtotal', 'discount', 'tax', 'tip', 'total', 'method', 'invoice',
      ],
      for (final o in rows)
        [
          o.id,
          _csvDate(o.createdAt),
          o.type,
          o.table,
          o.customer,
          o.status,
          o.items.fold<int>(0, (s, l) => s + l.qty),
          o.sub.toStringAsFixed(2),
          o.disc.toStringAsFixed(2),
          o.tax.toStringAsFixed(2),
          o.tip.toStringAsFixed(2),
          o.total.toStringAsFixed(2),
          o.method,
          o.invoice,
        ],
    ]);
    await _saveCsv(
      'orders-report-${DateTime.now().toIso8601String().split('T').first}.csv',
      csv,
      rows.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = demo;
    final filters = [
      'All',
      'pay',
      'create',
      'update',
      'delete',
      'refund',
      'auth',
    ];
    final users = d.auditLogs.map((a) => a.user).toSet().toList()..sort();
    final list = _filtered;
    final shown = list.take(_visible).toList();
    final remaining = list.length - shown.length;

    IconData iconFor(String type) {
      switch (type) {
        case 'pay':
          return AppIcons.card;
        case 'create':
          return AppIcons.plus;
        case 'update':
          return AppIcons.pencil;
        case 'delete':
          return AppIcons.trash;
        case 'refund':
          return AppIcons.refund;
        case 'auth':
          return AppIcons.key;
        default:
          return AppIcons.info;
      }
    }

    Color colorFor(String type) {
      switch (type) {
        case 'pay':
          return AppColors.brand;
        case 'create':
          return AppColors.green;
        case 'update':
          return AppColors.blue;
        case 'delete':
          return AppColors.red;
        case 'refund':
          return AppColors.amber;
        case 'auth':
          return AppColors.violet;
        default:
          return AppColors.text3;
      }
    }

    Widget dropdown({
      required String value,
      required List<String> items,
      required ValueChanged<String?> onChanged,
      double width = 150,
    }) {
      return Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? AppColors.darkLine2 : AppColors.line2,
          ),
          borderRadius: BorderRadius.circular(10),
          color: isDark ? AppColors.darkCard2 : Colors.white,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isDense: true,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
            dropdownColor: isDark ? AppColors.darkCard : Colors.white,
            icon: Icon(
              AppIcons.chevD,
              size: 14,
              color: isDark ? AppColors.darkText3 : AppColors.text3,
            ),
            borderRadius: BorderRadius.circular(10),
            items: [
              for (final it in items)
                DropdownMenuItem(value: it, child: Text(it)),
            ],
            onChanged: onChanged,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SectionCard(
          title: 'Audit Logs',
          trailing: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Pill.paid('IMMUTABLE'),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Search by user / action…',
                    prefixIcon: Icon(AppIcons.search, size: 18),
                  ),
                  onChanged: (_) => setState(() => _visible = _pageSize),
                ),
              ),
              dropdown(
                value: _range,
                width: 120,
                items: const ['All time', 'Today', '7 days', '30 days'],
                onChanged: (v) =>
                    setState(() { _range = v ?? _range; _visible = _pageSize; }),
              ),
              dropdown(
                value: _userFilter,
                items: ['All users', ...users],
                onChanged: (v) => setState(
                    () { _userFilter = v ?? _userFilter; _visible = _pageSize; }),
              ),
              dropdown(
                value: _filter,
                width: 110,
                items: filters,
                onChanged: (v) =>
                    setState(() { _filter = v ?? _filter; _visible = _pageSize; }),
              ),
              SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: list.isEmpty ? null : _exportAuditCsv,
                  icon: const Icon(AppIcons.download, size: 15),
                  label: const Text('Export CSV'),
                ),
              ),
              SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: _exportOrdersCsv,
                  icon: const Icon(AppIcons.receipt, size: 15),
                  label: const Text('Orders report'),
                ),
              ),
            ],
          ),
          bodyPadding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '${list.length} entr${list.length == 1 ? 'y' : 'ies'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText2 : AppColors.text2,
                      ),
                    ),
                    if (list.length > shown.length) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· showing ${shown.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkText3 : AppColors.text3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      _search.text.isEmpty &&
                              _filter == 'All' &&
                              _userFilter == 'All users' &&
                              _range == 'All time'
                          ? 'No activity recorded yet — actions appear here as '
                              'the team works.'
                          : 'No entries match these filters.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.text3),
                    ),
                  ),
                ),
              for (final a in shown)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.darkLine2 : AppColors.line2,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorFor(a.type).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          iconFor(a.type),
                          size: 16,
                          color: colorFor(a.type),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.action,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              a.detail,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkText2
                                    : AppColors.text2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Pill.free(a.role),
                                const SizedBox(width: 8),
                                Text(
                                  a.user,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.darkText3
                                        : AppColors.text3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            a.time,
                            style: TextStyle(
                              fontSize: 11.5,
                              color:
                                  isDark ? AppColors.darkText3 : AppColors.text3,
                            ),
                          ),
                          if (a.createdAt != null)
                            Text(
                              '${a.createdAt!.day.toString().padLeft(2, '0')}/'
                              '${a.createdAt!.month.toString().padLeft(2, '0')}/'
                              '${a.createdAt!.year} '
                              '${a.createdAt!.hour.toString().padLeft(2, '0')}:'
                              '${a.createdAt!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color:
                                    isDark ? AppColors.darkText3 : AppColors.text3,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (remaining > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _visible += _pageSize),
                    icon: const Icon(AppIcons.chevD, size: 16),
                    label: Text('Load more · $remaining older'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
