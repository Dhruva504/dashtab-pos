import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_provider.dart';

class KitchenItemDto {
  final String id;
  final String productName;
  final int quantity;
  final String? notes;
  final int status; // 0=Pending, 1=SentToKitchen, etc.

  KitchenItemDto({
    required this.id,
    required this.productName,
    required this.quantity,
    this.notes,
    required this.status,
  });

  factory KitchenItemDto.fromJson(Map<String, dynamic> json) {
    return KitchenItemDto(
      id: json['id'],
      productName: json['productName'],
      quantity: json['quantity'],
      notes: json['notes'],
      status: json['status'],
    );
  }
}

class KitchenTicketDto {
  final String id;
  final String ticketNumber;
  final int status;
  final String orderNumber;
  final String? tableName;
  final DateTime createdAt;
  final List<KitchenItemDto> items;

  KitchenTicketDto({
    required this.id,
    required this.ticketNumber,
    required this.status,
    required this.orderNumber,
    this.tableName,
    required this.createdAt,
    required this.items,
  });

  factory KitchenTicketDto.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List? ?? [];
    return KitchenTicketDto(
      id: json['id'],
      ticketNumber: json['ticketNumber'],
      status: json['status'],
      orderNumber: json['orderNumber'],
      tableName: json['tableName'],
      createdAt: DateTime.parse(json['createdAt']),
      items: itemsList.map((i) => KitchenItemDto.fromJson(i)).toList(),
    );
  }
}

class KitchenNotifier extends AsyncNotifier<List<KitchenTicketDto>> {
  @override
  Future<List<KitchenTicketDto>> build() async {
    try {
      final response = await ref.read(apiClientProvider).dio.get('/kitchen/tickets');
      return (response.data as List).map((t) => KitchenTicketDto.fromJson(t)).toList();
    } catch (e) {
      return [];
    }
  }
}

final kitchenProvider = AsyncNotifierProvider<KitchenNotifier, List<KitchenTicketDto>>(KitchenNotifier.new);
