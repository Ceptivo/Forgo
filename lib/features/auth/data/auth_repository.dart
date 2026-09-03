import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String username,
    required DateTime dateOfBirth,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'username': username,
        // Stored as an ISO date (yyyy-MM-dd) so the DB trigger/CHECK
        // constraint can parse it without timezone ambiguity.
        'date_of_birth': _isoDate(dateOfBirth),
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Accepts either an email or a username in [identifier] — Supabase
  /// Auth itself only signs in by email, so a bare username is resolved
  /// to its email first via get_email_for_username (see
  /// 0010_login_by_username.sql), then signed in as normal.
  Future<AuthResponse> signInWithIdentifier({
    required String identifier,
    required String password,
  }) async {
    final trimmed = identifier.trim();
    final email = trimmed.contains('@')
        ? trimmed
        : await _resolveEmailForUsername(trimmed);
    if (email == null) {
      throw const AuthException('No account found for that username.');
    }
    return signIn(email: email, password: password);
  }

  Future<String?> _resolveEmailForUsername(String username) async {
    final result = await _client.rpc(
      'get_email_for_username',
      params: {'p_username': username},
    );
    return result as String?;
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPasswordForEmail(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  String _isoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
