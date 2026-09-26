import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// X-axis labels for a rolling n-day window ending today. Weekday names
/// for ≤7 days; day-of-month numbers for longer ranges (where weekday
/// names would repeat and confuse).
List<String> dayLabelsFor(int count) {
  final now = DateTime.now();
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  if (count <= 7) {
    return [
      for (var i = count - 1; i >= 0; i--)
        names[now.subtract(Duration(days: i)).weekday - 1],
    ];
  }
  return [
    for (var i = count - 1; i >= 0; i--)
      now.subtract(Duration(days: i)).day.toString(),
  ];
}

/// Rounds a max value up to a clean axis bound (e.g. 137 → 150) and picks
/// ~4 evenly spaced steps so y labels are human numbers, not decimals.
(double, double) axisFor(double maxV) {
  final raw = maxV * 1.15;
  if (raw <= 0) return (1.0, 1.0);
  final mag = pow(10, (log(raw) / ln10).floor()).toDouble();
  final step = (raw / mag * 4).ceil() / 4 * mag; // quarter-magnitude steps
  final niceStep = switch (step) {
    < 1 => 0.25,
    < 2 => 0.5,
    < 5 => 1.0,
    < 10 => 2.0,
    < 20 => 5.0,
    < 50 => 10.0,
    < 100 => 25.0,
    < 200 => 50.0,
    < 500 => 100.0,
    < 1000 => 250.0,
    _ => (step / 500).ceil() * 500.0,
  };
  final top = (raw / niceStep).ceil() * niceStep;
  return (niceStep, top);
}

/// Interactive area (line) chart with hover/tap tooltips, axis labels and
/// entrance animation. Replaces the old static CustomPaint area chart.
class InteractiveAreaChart extends StatefulWidget {
  final List<double> values;
  final List<String> xLabels;
  final Color color;
  final bool isDark;
  final String emptyLabel;
  final String Function(double value)? valueFormatter;

  /// Optional extra line per x-index shown under the tooltip value,
  /// e.g. "Dine-in €120 · Takeaway €45".
  final List<String>? tooltipDetails;

  /// Show every nth x label (raise on dense charts, e.g. 5 for 30 days).
  final int xLabelInterval;

  const InteractiveAreaChart({
    super.key,
    required this.values,
    required this.xLabels,
    required this.color,
    required this.isDark,
    this.emptyLabel = 'No data yet',
    this.valueFormatter,
    this.tooltipDetails,
    this.xLabelInterval = 1,
  });

  @override
  State<InteractiveAreaChart> createState() => _InteractiveAreaChartState();
}

class _InteractiveAreaChartState extends State<InteractiveAreaChart> {
  @override
  void didUpdateWidget(InteractiveAreaChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nothing cached — spots are rebuilt from widget.values on every build so
    // range switchers (7d/14d/30d) and data refreshes update the chart.
  }

  List<FlSpot> get _spots => [
        for (var i = 0; i < widget.values.length; i++)
          FlSpot(i.toDouble(), widget.values[i]),
      ];

  String _fmt(double v) {
    if (widget.valueFormatter != null) return widget.valueFormatter!(v);
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  }


  @override
  Widget build(BuildContext context) {
    final grid = widget.isDark ? AppColors.darkLine2 : AppColors.line2;
    final text3 = widget.isDark ? AppColors.darkText3 : AppColors.text3;

    final maxV = widget.values.isEmpty ? 0.0 : widget.values.reduce((a, b) => a > b ? a : b);
    if (maxV <= 0 || widget.values.length < 2) {
      return Center(
        child: Text(
          widget.emptyLabel,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: text3),
        ),
      );
    }

    final (yStep, yMax) = axisFor(maxV);
    return LineChart(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      LineChartData(
        minY: 0,
        maxY: yMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yStep,
          getDrawingHorizontalLine: (v) => FlLine(color: grid, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: yStep,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _fmt(v),
                  style: TextStyle(fontSize: 10, color: text3),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: widget.xLabelInterval.toDouble(),
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= widget.xLabels.length) return const SizedBox.shrink();
                // Nudge the first/last labels inward so they stay inside
                // the card (fl_chart centers them on the plot edge).
                final shift = i == 0
                    ? 9.0
                    : i == widget.xLabels.length - 1
                        ? -9.0
                        : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Transform.translate(
                    offset: Offset(shift, 0),
                    child: Text(
                      widget.xLabels[i],
                      style: TextStyle(fontSize: 10, color: text3),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => widget.isDark ? AppColors.darkCard : Colors.white,
            tooltipBorderRadius: BorderRadius.circular(10),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tooltipBorder: BorderSide(color: grid),
            getTooltipItems: (spots) => spots
                .map(
                  (s) {
                    final i = s.x.toInt();
                    final detail =
                        (widget.tooltipDetails != null && i >= 0 && i < widget.tooltipDetails!.length)
                            ? widget.tooltipDetails![i]
                            : null;
                    return LineTooltipItem(
                      _fmt(s.y),
                      TextStyle(
                        color: widget.color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                      children: (detail == null || detail.isEmpty)
                          ? null
                          : [
                              const TextSpan(text: '\n'),
                              TextSpan(
                                text: detail,
                                style: TextStyle(
                                  color: text3,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                    );
                  },
                )
                .toList(),
          ),
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (data, indexes) => indexes
              .map(
                (i) => TouchedSpotIndicatorData(
                  FlLine(
                    color: widget.color.withValues(alpha: 0.4),
                    strokeWidth: 1.5,
                    dashArray: [4, 3],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                      radius: 5,
                      color: widget.color,
                      strokeColor: widget.isDark ? AppColors.darkCard : Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: _spots,
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            barWidth: 2.6,
            color: widget.color,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: spot.x == _spots.last.x ? 5 : 3,
                color: widget.color,
                strokeColor: widget.isDark ? AppColors.darkCard : Colors.white,
                strokeWidth: spot.x == _spots.last.x ? 2.5 : 1.5,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.color.withValues(alpha: 0.28),
                  widget.color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive bar chart with hover/tap tooltips and axis labels — used for
/// the hourly sales distribution.
class InteractiveBarChart extends StatefulWidget {
  final List<double> values;
  final List<String> xLabels;
  final Color color;
  final bool isDark;
  final String emptyLabel;
  final String Function(double value)? valueFormatter;

  const InteractiveBarChart({
    super.key,
    required this.values,
    required this.xLabels,
    required this.color,
    required this.isDark,
    this.emptyLabel = 'No data yet',
    this.valueFormatter,
  });

  @override
  State<InteractiveBarChart> createState() => _InteractiveBarChartState();
}

class _InteractiveBarChartState extends State<InteractiveBarChart> {
  String _fmt(double v) {
    if (widget.valueFormatter != null) return widget.valueFormatter!(v);
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  }

  @override
  Widget build(BuildContext context) {
    final grid = widget.isDark ? AppColors.darkLine2 : AppColors.line2;
    final text3 = widget.isDark ? AppColors.darkText3 : AppColors.text3;

    final maxV = widget.values.isEmpty ? 0.0 : widget.values.reduce((a, b) => a > b ? a : b);
    if (maxV <= 0) {
      return Center(
        child: Text(
          widget.emptyLabel,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: text3),
        ),
      );
    }

    final (yStep, yMax) = axisFor(maxV);
    return BarChart(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      BarChartData(
        maxY: yMax,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yStep,
          getDrawingHorizontalLine: (v) => FlLine(color: grid, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: yStep,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _fmt(v),
                  style: TextStyle(fontSize: 10, color: text3),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= widget.xLabels.length) return const SizedBox.shrink();
                final shift = i == 0
                    ? 9.0
                    : i == widget.xLabels.length - 1
                        ? -9.0
                        : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Transform.translate(
                    offset: Offset(shift, 0),
                    child: Text(
                      widget.xLabels[i],
                      style: TextStyle(fontSize: 10, color: text3),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => widget.isDark ? AppColors.darkCard : Colors.white,
            tooltipBorderRadius: BorderRadius.circular(10),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tooltipBorder: BorderSide(color: grid),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = groupIndex < widget.xLabels.length
                  ? widget.xLabels[groupIndex]
                  : '';
              return BarTooltipItem(
                '$label  ·  ${_fmt(rod.toY)}',
                TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              );
            },
          ),
          handleBuiltInTouches: true,
        ),
        barGroups: [
          for (var i = 0; i < widget.values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: widget.values[i],
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      widget.color.withValues(alpha: 0.45),
                      widget.color,
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
