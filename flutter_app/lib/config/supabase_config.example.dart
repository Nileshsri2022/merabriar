// MeraBriar Flutter App Configuration
//
// SETUP INSTRUCTIONS:
// 1. Copy this file to supabase_config.dart
// 2. Replace the placeholder values with your actual Supabase credentials
// 3. Never commit supabase_config.dart to git!

class SupabaseConfig {
  // Get these from your Supabase project dashboard:
  // https://supabase.com/dashboard/project/YOUR_PROJECT/settings/api

  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // Database table names (no need to change)
  static const String usersTable = 'users';
  static const String messagesTable = 'messages';
  static const String prekeysTable = 'prekeys';
  static const String contactsTable = 'contacts';
  static const String groupsTable = 'groups';
  static const String groupMembersTable = 'group_members';
}
