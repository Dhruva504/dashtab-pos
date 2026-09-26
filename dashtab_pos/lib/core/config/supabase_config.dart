class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kiufyhsuwolgpksjnlqk.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtpdWZ5aHN1d29sZ3Brc2pubHFrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ4MjIwMzMsImV4cCI6MjEwMDM5ODAzM30.RlTTe_vVDj67mLR0fZ_iD87CSDEvp3dvN5h0APlaRCg',
  );
}
