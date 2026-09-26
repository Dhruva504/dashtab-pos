import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/demo_data.dart';
import '../../theme/app_widgets.dart';

/// Shift view — mirrors the HTML shift & cash section.
class ShiftView extends ConsumerStatefulWidget {
  const ShiftView({super.key});

  @override
  ConsumerState<ShiftView> createState() => _ShiftViewState();
}

class _ShiftViewState extends ConsumerState<ShiftView> {
  late Timer _ticker;
  String _elapsed = '00:00:00';
  final _counted = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final opened = demo.shift['openedAt'] as DateTime?;
      if (opened != null) {
        final diff = DateTime.now().difference(opened);
        final h = diff.inHours.toString().padLeft(2, '0');
        final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
        if (mounted) setState(() => _elapsed = '$h:$m:$s');
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _counted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = demo;
    final sh = d.shift;
    final open = sh['open'] as bool? ?? true;
    final float = sh['float'] as double? ?? 0;
    final cashSales = sh['cashSales'] as double? ?? 0;
    final cashRefunds = sh['cashRefunds'] as double? ?? 0;
    final cashInOut = sh['cashInOut'] as double? ?? 0;
    final expected = float + cashSales - cashRefunds + cashInOut;
    final movements = sh['movements'] as List<CashMovement>? ?? [];
    final counted = double.tryParse(_counted.text) ?? 0;
    final variance = counted == 0 ? null : counted - expected;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brand, Color(0xFFFF8A4C)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.45),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CASH IN DRAWER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fmt(expected),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      open
                          ? 'Shift opened · Cashier: ${sh['cashier']}'
                          : 'Shift closed',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _elapsed,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          if (open) {
                            await demo.closeShift(counted: expected);
                          } else {
                            _showOpenShiftDialog();
                          }
                          if (mounted) setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.brand,
                        ),
                        child: Text(open ? 'Close Shift' : 'Open Shift'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: open ? () => _showZReport(expected) : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        icon: const Icon(AppIcons.receipt, size: 16),
                        label: const Text('Close Day (Z-Report)'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final movementsCard = AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          'Cash Movements',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () => _addMovement(),
                          icon: const Icon(AppIcons.plus, size: 15),
                          label: const Text('Add movement'),
                        ),
                      ],
                    ),
                  ),
                  if (movements.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'No movements recorded.',
                          style: TextStyle(color: AppColors.text3),
                        ),
                      ),
                    ),
                  for (final m in movements)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.type,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${m.note} · ${m.time} · ${m.by}',
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
                          Text(
                            '${m.amount >= 0 ? '+' : ''}${fmt(m.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: m.amount >= 0
                                  ? AppColors.green
                                  : AppColors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
            final reconCard = AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text(
                      'Today\'s Cash Reconciliation',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _CashRow(label: 'Opening float', value: fmt(float)),
                  _CashRow(label: 'Cash sales', value: fmt(cashSales)),
                  _CashRow(label: 'Cash refunds', value: '−${fmt(cashRefunds)}'),
                  _CashRow(label: 'Cash in / out', value: fmt(cashInOut)),
                  _CashRow(
                    label: 'Expected in drawer',
                    value: fmt(expected),
                    bold: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Counted in drawer',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _counted,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: '€0.00',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              suffix: variance == null
                                  ? null
                                  : Text(
                                      variance >= 0
                                          ? '+${fmt(variance)}'
                                          : fmt(variance),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: variance == 0
                                            ? AppColors.green
                                            : variance > 0
                                            ? AppColors.amber
                                            : AppColors.red,
                                      ),
                                    ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (variance != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: variance == 0
                              ? AppColors.greenT
                              : variance > 0
                              ? AppColors.amberT
                              : AppColors.redT,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          variance == 0
                              ? 'Drawer matches — variance €0.00 ✓'
                              : 'Variance ${variance > 0 ? 'over' : 'short'} by ${fmt(variance.abs())}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: variance == 0
                                ? AppColors.green
                                : variance > 0
                                ? AppColors.amber
                                : AppColors.red,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: movementsCard),
                  const SizedBox(width: 16),
                  Expanded(child: reconCard),
                ],
              );
            }
            return Column(
              children: [movementsCard, const SizedBox(height: 16), reconCard],
            );
          },
        ),
      ],
    );
  }

  void _addMovement() {
    final note = TextEditingController();
    final amount = TextEditingController();
    String? type = 'Cash in';
    const types = ['Cash in', 'Cash out', 'Petty cash', 'Opening float'];
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Add cash movement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'TYPE'),
              items: [
                for (final t in types) DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => type = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'AMOUNT (€)',
                hintText: 'e.g. 25.00',
                prefixIcon: Icon(AppIcons.cash, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: const InputDecoration(
                labelText: 'NOTE',
                hintText: 'e.g. Bread delivery payment',
                prefixIcon: Icon(AppIcons.pencil, size: 18),
              ),
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
              final v = double.tryParse(amount.text) ?? 0;
              if (v == 0) return;
              Navigator.pop(dctx);
              setState(() {});
              final isOut = type == 'Cash out';
              demo.addCashMovement(
                type: type ?? 'Cash in',
                amount: isOut ? -v : v,
                note: note.text.trim().isEmpty ? '—' : note.text.trim(),
              );
              showToast(
                context,
                '${type ?? 'Cash in'} recorded',
                subtitle: fmt(v),
                icon: AppIcons.cash,
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showOpenShiftDialog() {
    final floatCtrl = TextEditingController(text: '0');
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Open shift'),
        content: TextField(
          controller: floatCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'OPENING FLOAT (€)',
            hintText: 'e.g. 150.00',
            prefixIcon: Icon(AppIcons.cash, size: 18),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final v = double.tryParse(floatCtrl.text.replaceAll(',', '.')) ?? 0;
              Navigator.pop(dctx);
              await demo.openShift(float: v);
              if (mounted) setState(() {});
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  /// All paid orders settled since this shift opened (fallback: today).
  List<DemoOrder> get _shiftOrders {
    final opened = demo.shift['openedAt'] as DateTime?;
    final from = opened ?? DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return demo.orders
        .where((o) =>
            (o.status == 'Paid' || o.status == 'Refunded') &&
            o.createdAt != null &&
            !o.createdAt!.isBefore(from))
        .toList();
  }

  void _showZReport(double expected) {
    final d = demo;
    final sh = d.shift;
    final cashSales = sh['cashSales'] as double? ?? 0;
    final cashRefunds = sh['cashRefunds'] as double? ?? 0;
    final cashInOut = sh['cashInOut'] as double? ?? 0;
    final float = sh['float'] as double? ?? 0;
    final shiftOrders = _shiftOrders;
    final total =
        shiftOrders.fold<double>(0, (s, o) => s + o.total + o.tip);
    final counted = double.tryParse(
          _counted.text.replaceAll(',', '.'),
        ) ??
        expected;
    final variance = counted - expected;

    AppModal.show(
      context,
      AppModal(
        title: 'Close Day · Z-Report',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ZStat(label: 'Total revenue', value: fmt(total)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ZStat(
                    label: 'Orders',
                    value: '${shiftOrders.length}',
                    color: AppColors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            TotalRow('Cash sales', fmt(cashSales)),
            TotalRow('Cash refunds', '−${fmt(cashRefunds)}'),
            TotalRow('Cash in / out', fmt(cashInOut)),
            TotalRow('Opening float', fmt(float)),
            TotalRow('Expected in drawer', fmt(expected), total: true),
            TotalRow('Counted in drawer', fmt(counted)),
            TotalRow(
              'Variance',
              '${variance >= 0 ? '+' : ''}${fmt(variance)}',
              total: true,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brandT,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Z-Report for ${demo.dateNow} · generated by ${d.shift['cashier']}. '
                'Closing the shift locks the cash drawer totals and records '
                'the result in the audit log.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.brand,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await Printing.layoutPdf(
                  name: 'Z-Report ${demo.dateNow}',
                  onLayout: (format) => _buildZReportPdf(
                    expected: expected,
                    counted: counted,
                    total: total,
                    orderCount: shiftOrders.length,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  showToast(
                    context,
                    'Could not export: $e',
                    icon: AppIcons.x,
                    kind: 'err',
                  );
                }
              }
            },
            icon: const Icon(AppIcons.download, size: 16),
            label: const Text('Export PDF'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await demo.closeShift(counted: counted);
              if (mounted) setState(() {});
              demo.addNotif(
                'Day closed · Z-Report generated',
                'Cash ${fmt(counted)} · ${shiftOrders.length} orders · '
                    'Variance ${fmt(variance)}',
                'ok',
              );
              if (mounted) {
                showToast(
                  context,
                  'Day closed — Z-Report saved',
                  icon: AppIcons.check,
                );
              }
            },
            child: const Text('Close Day'),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _buildZReportPdf({
    required double expected,
    required double counted,
    required double total,
    required int orderCount,
  }) {
    final sh = demo.shift;
    final doc = pw.Document();

    pw.TableRow row(String label, String value, {bool bold = false}) {
      final style = pw.TextStyle(
        fontSize: 11,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      );
      return pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(label, style: style),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(value, style: style),
            ),
          ),
        ],
      );
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Z-Report', style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(
                '${RestaurantInfo.name} · ${demo.dateNow}',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.Text(
                'Branch: ${RestaurantInfo.branchLabel}',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.Text(
                'Cashier: ${sh['cashier']}',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  row('Orders settled', '$orderCount'),
                  row('Total revenue', fmt(total)),
                  row('Cash sales', fmt((sh['cashSales'] as num?)?.toDouble() ?? 0)),
                  row('Cash refunds',
                      '-${fmt((sh['cashRefunds'] as num?)?.toDouble() ?? 0)}'),
                  row('Cash in / out', fmt((sh['cashInOut'] as num?)?.toDouble() ?? 0)),
                  row('Opening float', fmt((sh['float'] as num?)?.toDouble() ?? 0)),
                  row('Expected in drawer', fmt(expected), bold: true),
                  row('Counted in drawer', fmt(counted)),
                  row(
                    'Variance',
                    '${counted - expected >= 0 ? '+' : ''}${fmt(counted - expected)}',
                    bold: true,
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Generated by DashTab POS at ${demo.timeNow}.',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }
}

class _ZStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ZStat({required this.label, required this.value, this.color = AppColors.brand});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkText2
                  : AppColors.text2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _CashRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText2 : AppColors.text2,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              fontSize: bold ? 15 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
