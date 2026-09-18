class AppConstants {
  static const String appName = 'Z Chat';
  static const String appTagline = 'Your chats. Your style. Your rules.';
  
  // Supabase Configuration (can be overridden via --dart-define)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://nmjdkxviodpnnconlygg.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5tamRreHZpb2Rwbm5jb25seWdnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0ODUxODQsImV4cCI6MjEwNTA2MTE4NH0.S9hq5zSeIZ6A5Jm994boNvAMHR8wgPGaecDf4uA5KbU',
  );
  
  // Storage Buckets
  static const String bucketAvatars = 'avatars';
  static const String bucketAttachments = 'attachments';
  static const String bucketVoice = 'voice_messages';

  // Internal domain for username-based Supabase Auth
  static const String internalAuthDomain = 'zchat.internal';
}
