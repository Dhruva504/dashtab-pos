import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_provider.dart';

class DailySalesReportDto {
  final DateTime date;
  final double totalRevenue;
  final int orderCount;
  final double averageTicketSize;

  DailySalesReportDto({
    required this.date,
    required this.totalRevenue,
    required this.orderCount,
    required this.averageTicketSize,
  });

  factory DailySalesReportDto.fromJson(Map<String, dynamic> json) {
    return DailySalesReportDto(
      date: DateTime.parse(json['date']),
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      orderCount: json['orderCount'],
      averageTicketSize: (json['averageTicketSize'] as num).toDouble(),
    );
  }
}

class ReportsNotifier extends AsyncNotifier<List<DailySalesReportDto>> {
  @override
  Future<List<DailySalesReportDto>> build() async {
    try {
      final to = DateTime.now().toIso8601String();
      final from = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      
      final response = await ref.read(apiClientProvider).dio.get('/reports/daily-sales?from=$from&to=$to');
      return (response.data as List).map((r) => DailySalesReportDto.fromJson(r)).toList();
    } catch (e) {
      return [];
    }
  }
}

final reportsProvider = AsyncNotifierProvider<ReportsNotifier, List<DailySalesReportDto>>(ReportsNotifier.new);
