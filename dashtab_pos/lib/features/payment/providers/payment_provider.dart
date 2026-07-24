import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_provider.dart';

class PaymentMethodDto {
  final String id;
  final String name;
  final int type; // 0=Cash, 1=Card, 2=Digital

  PaymentMethodDto({required this.id, required this.name, required this.type});

  factory PaymentMethodDto.fromJson(Map<String, dynamic> json) {
    return PaymentMethodDto(
      id: json['id'],
      name: json['name'],
      type: json['type'],
    );
  }
}

class ProcessPaymentCommand {
  final String orderId;
  final String paymentMethodId;
  final double amount;
  final double tipAmount;

  ProcessPaymentCommand({
    required this.orderId,
    required this.paymentMethodId,
    required this.amount,
    required this.tipAmount,
  });

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'paymentMethodId': paymentMethodId,
        'amount': amount,
        'tipAmount': tipAmount,
      };
}

class PaymentNotifier extends AsyncNotifier<List<PaymentMethodDto>> {
  @override
  Future<List<PaymentMethodDto>> build() async {
    try {
      final response = await ref.read(apiClientProvider).dio.get('/payments/methods');
      return (response.data as List).map((p) => PaymentMethodDto.fromJson(p)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> processPayment(ProcessPaymentCommand command) async {
    try {
      await ref.read(apiClientProvider).dio.post('/payments', data: command.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }
}

final paymentProvider = AsyncNotifierProvider<PaymentNotifier, List<PaymentMethodDto>>(PaymentNotifier.new);
