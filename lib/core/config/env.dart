class Env {
  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bvtoxmmiitznagsbubhg.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2dG94bW1paXR6bmFnc2J1YmhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwNzk5MTcsImV4cCI6MjA2NzY1NTkxN30.WjdQh_cvOebwL0TG0bzDLZimWCLC4YuP__jtvBD_xv0',
  );
  // Removed service role key from client app for security
  
  // Mapbox Configuration
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );
  static const String mapboxSecretToken = String.fromEnvironment(
    'MAPBOX_SECRET_TOKEN',
    defaultValue: '',
  );
  
  // SMS Service Configuration (handled by Supabase + Twilio integration)
  // No need for direct Twilio credentials - Supabase handles this
  
  // Firebase Configuration
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'hur-app',
  );
  
  // Environment
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );
  
  // API Configuration
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://api.hur.delivery',
  );
}
