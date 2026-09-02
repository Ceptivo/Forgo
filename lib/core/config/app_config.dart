import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central place for runtime configuration loaded from the bundled `.env`
/// file. Keep secrets out of source: `.env` is gitignored, `.env.example`
/// documents the required keys.
class AppConfig {
  AppConfig._();

  static String get supabaseUrl => _require('SUPABASE_URL');
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');

  static Future<void> load() => dotenv.load(fileName: '.env');

  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing "$key" in .env. Copy .env.example to .env and fill in '
        'your Supabase project credentials.',
      );
    }
    return value;
  }
}
