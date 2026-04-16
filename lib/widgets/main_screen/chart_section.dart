import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:motamayez/providers/sales_provider.dart';

class ChartSection extends StatelessWidget {
  final bool useExpanded;

  const ChartSection({super.key, this.useExpanded = true});

  @override
  Widget build(BuildContext context) {
    final salesProvider = context.watch<SalesProvider>();
    final weeklyData = salesProvider.weeklySalesChartData;
    final chartData =
        weeklyData.isEmpty
            ? List.generate(7, (index) => {'dayName': '-', 'sales': 0.0})
            : weeklyData;

    final maxSales = chartData.fold<double>(
      0.0,
      (maxValue, item) =>
          _max(maxValue, (item['sales'] as num?)?.toDouble() ?? 0.0),
    );
    final yInterval = _calculateYAxisInterval(maxSales);
    final maxY = _calculateChartMax(maxSales, yInterval);

    final chartContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: const Color(0xFF7C3AED).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          // ignore: deprecated_member_use
          color: const Color(0xFF7C3AED).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, color: Color(0xFF7C3AED), size: 20),
              SizedBox(width: 8),
              Text(
                'تحليل المبيعات',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E1B4B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: const Color(0xFF7C3AED),
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.all(10),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final dayName =
                          (chartData[group.x.toInt()]['dayName'] as String?) ??
                          '-';
                      return BarTooltipItem(
                        '$dayName\n${rod.toY.toStringAsFixed(2)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= chartData.length) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            chartData[index]['dayName'] as String? ?? '-',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                      reservedSize: 24,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Text(
                            _formatAxisValue(value),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(chartData.length, (index) {
                  final sales =
                      (chartData[index]['sales'] as num?)?.toDouble() ?? 0.0;
                  return _buildBarGroup(index, sales, maxY);
                }),
              ),
            ),
          ),
        ],
      ),
    );

    if (useExpanded) {
      return chartContent;
    }

    return SizedBox(height: 320, child: chartContent);
  }

  BarChartGroupData _buildBarGroup(int x, double y, double maxY) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: maxY,
            color: Colors.grey.shade100,
          ),
        ),
      ],
    );
  }

  double _calculateYAxisInterval(double maxSales) {
    // 5 قيم فقط: 0, interval, 2*interval, 3*interval, 4*interval
    if (maxSales <= 0) return 25;

    // interval = maxSales / 4 لنحصل على 5 قيم موزعة
    double rawInterval = maxSales / 4;

    // تقريب إلى أقرب قيمة مناسبة
    if (rawInterval <= 10) return 10;
    if (rawInterval <= 25) return 25;
    if (rawInterval <= 50) return 50;
    if (rawInterval <= 100) return 100;
    if (rawInterval <= 250) return 250;
    if (rawInterval <= 500) return 500;
    if (rawInterval <= 1000) return 1000;

    return (rawInterval / 1000).ceil() * 1000.0;
  }

  double _calculateChartMax(double maxSales, double interval) {
    if (maxSales <= 0) return 100;
    // 5 قيم فقط: 0, interval, 2*interval, 3*interval, 4*interval
    return 4 * interval;
  }

  String _formatAxisValue(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
    }
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  }

  double _max(double a, double b) => a > b ? a : b;
}
