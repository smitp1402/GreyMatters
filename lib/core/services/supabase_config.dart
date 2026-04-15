// lib/core/services/supabase_config.dart

/// Supabase configuration for NeuroLearn.
///
/// The publishable key is safe to include in client code —
/// RLS policies control actual data access.
abstract final class SupabaseConfig {
  static const String url = 'https://bndmlibxzrnwzjrjjand.supabase.co';
  static const String anonKey = 'sb_publishable_kTE9VA6Gch3g3V4oKjIfIA_UgYVWibR';
}
