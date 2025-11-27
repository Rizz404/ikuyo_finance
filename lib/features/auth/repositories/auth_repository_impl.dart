import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/auth/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;

  const AuthRepositoryImpl(this._supabase);

  @override
  TaskEither<Failure, Success<AuthResponse>> signInWithEmail({
    required String email,
    required String password,
  }) {
    return TaskEither.tryCatch(
      () async {
        logService('Sign in with email', email);
        final response = await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        logInfo('Sign in successful');
        return Success(message: 'Sign in successful', data: response);
      },
      (error, stackTrace) {
        logError('Sign in failed', error, stackTrace);
        return Failure(
          message: error is AuthException
              ? error.message
              : 'Failed to sign in. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<AuthResponse>> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return TaskEither.tryCatch(
      () async {
        logService('Sign up with email', email);
        final response = await _supabase.auth.signUp(
          email: email,
          password: password,
        );
        logInfo('Sign up successful');
        return Success(message: 'Sign up successful', data: response);
      },
      (error, stackTrace) {
        logError('Sign up failed', error, stackTrace);
        return Failure(
          message: error is AuthException
              ? error.message
              : 'Failed to sign up. Please try again.',
        );
      },
    );
  }

  // ! jangan dipake dulu
  @override
  TaskEither<Failure, Success<AuthResponse>> signInWithGoogle() {
    return TaskEither.tryCatch(
      () async {
        logService('Sign in with Google');
        await _supabase.auth.signInWithOAuth(OAuthProvider.google);

        // TODO: Handle OAuth callback and get auth response
        // ! OAuth requires deep linking setup
        final user = _supabase.auth.currentUser;
        final session = _supabase.auth.currentSession;

        if (user == null || session == null) {
          throw const AuthException('OAuth sign in incomplete');
        }

        final response = AuthResponse(session: session, user: user);
        logInfo('Google sign in successful');
        return Success(message: 'Google sign in successful', data: response);
      },
      (error, stackTrace) {
        logError('Google sign in failed', error, stackTrace);
        return Failure(
          message: error is AuthException
              ? error.message
              : 'Failed to sign in with Google. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> signOut() {
    return TaskEither.tryCatch(
      () async {
        logService('Sign out');
        await _supabase.auth.signOut();
        logInfo('Sign out successful');
        return const ActionSuccess(message: 'Sign out successful');
      },
      (error, stackTrace) {
        logError('Sign out failed', error, stackTrace);
        return Failure(
          message: error is AuthException
              ? error.message
              : 'Failed to sign out. Please try again.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<User>> getCurrentUser() {
    return TaskEither.tryCatch(
      () async {
        logService('Get current user');
        final user = _supabase.auth.currentUser;
        if (user == null) {
          throw const AuthException('No user signed in');
        }
        logInfo('Current user retrieved');
        return Success(message: 'User retrieved', data: user);
      },
      (error, stackTrace) {
        logError('Get current user failed', error, stackTrace);
        return Failure(
          message: error is AuthException
              ? error.message
              : 'Failed to get current user.',
        );
      },
    );
  }

  @override
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
