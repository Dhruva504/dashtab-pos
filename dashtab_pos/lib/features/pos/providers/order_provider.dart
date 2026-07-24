import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_provider.dart';

class OrderItemDto {
  final String productId;
  final int quantity;
  final String? notes;

  OrderItemDto({required this.productId, required this.quantity, this.notes});

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'notes': notes,
      };
}

class CreateOrderCommand {
  final String? tableId;
  final int orderType; // 0 = DineIn
  final List<OrderItemDto> items;

  CreateOrderCommand({this.tableId, required this.orderType, required this.items});

  Map<String, dynamic> toJson() => {
        'tableId': tableId,
        'orderType': orderType,
        'items': items.map((i) => i.toJson()).toList(),
      };
}

class OrderNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> submitOrder(CreateOrderCommand command) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(apiClientProvider).dio.post('/orders', data: command.toJson());
    });
    
    return !state.hasError;
  }
}

final orderProvider = AsyncNotifierProvider<OrderNotifier, void>(OrderNotifier.new);
