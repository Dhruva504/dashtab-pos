import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/floor.dart';
import '../../../core/network/api_provider.dart';

class FloorNotifier extends AsyncNotifier<List<Floor>> {
  @override
  Future<List<Floor>> build() async {
    try {
      final response = await ref.read(apiClientProvider).dio.get('/floors');
      return (response.data as List).map((f) => Floor.fromJson(f)).toList();
    } catch (e) {
      // Fallback for empty DB during development
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

final floorProvider = AsyncNotifierProvider<FloorNotifier, List<Floor>>(FloorNotifier.new);
