import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Initializes the Supabase client once at app startup.
Future<void> initializeSupabase() async {
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabaseAnonKey,
  );
}

/// Riverpod provider exposing the singleton Supabase client.
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
