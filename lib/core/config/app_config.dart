import 'env.dart';

/// Application Configuration
class AppConfig {
  // Voice Transcription API (Supabase Edge Function)
  static String get voiceTranscribeUrl => 
      '${Env.supabaseUrl}/functions/v1/transcribe-voice-order';
  
  // API Timeouts
  static const Duration apiTimeout = Duration(seconds: 60);
  
  // Environment
  static const String environment = String.fromEnvironment('ENV', defaultValue: 'production');
  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
}

