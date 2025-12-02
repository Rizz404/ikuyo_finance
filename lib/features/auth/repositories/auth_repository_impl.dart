import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/auth/models/sign_in_with_email_params.dart';
import 'package:ikuyo_finance/features/auth/models/sign_up_with_email_params.dart';
import 'package:ikuyo_finance/features/auth/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;

  const AuthRepositoryImpl(this._supabase);

  @override
  TaskEither<Failure, Success<AuthResponse>> signInWithEmail(
    SignInWithEmailParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService('Masuk dengan email', params.email);
        final response = await _supabase.auth.signInWithPassword(
          email: params.email,
          password: params.password,
        );
        logInfo('Berhasil masuk');
        return Success(message: 'Berhasil masuk', data: response);
      },
      (error, stackTrace) {
        logError('Gagal masuk', error, stackTrace);
        return Failure(
          message: error is AuthException
              ? error.message
              : 'Gagal masuk. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<AuthResponse>> signUpWithEmail(
    SignUpWithEmailParams params,
  ) {
    return TaskEither.tryCatch(
      () async {
        logService('Daftar dengan email', params.email);
        final response = await _supabase.auth.signUp(
          email: params.email,
          password: params.password,
        );
        logInfo('Berhasil daftar');
        return Success(message: 'Berhasil daftar', data: response);
      },
      (error, stackTrace) {
        logError('Gagal daftar', error, stackTrace);
        return Failure(
          message: error is AuthException
              ? error.message
              : 'Gagal daftar. Silakan coba lagi.',
        );
      },
    );
  }

  // ! jangan dipake dulu
  @override
  TaskEither<Failure, Success<AuthResponse>> signInWithGoogle() {
    return TaskEither.tryCatch(
      () async {
        logService('Masuk dengan Google');
        await _supabase.auth.signInWithOAuth(OAuthProvider.google);

        // TODO: Handle OAuth callback and get auth response
        // ! OAuth requires deep linking setup
        final user = _supabase.auth.currentUser;
        final session = _supabase.auth.currentSession;

        if (user == null || session == null) {
          throw const AuthException('Masuk OAuth tidak lengkap');
        }

        final response = AuthResponse(session: session, user: user);
        logInfo('Berhasil masuk dengan Google');
        return Success(message: 'Berhasil masuk dengan Google', data: response);
      },
      (error, stackTrace) {
        logError('Gagal masuk dengan Google', error, stackTrace);
        return Failure(
          message: error is AuthException
              ? error.message
              : 'Gagal masuk dengan Google. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, ActionSuccess> signOut() {
    return TaskEither.tryCatch(
      () async {
        logService('Keluar');
        await _supabase.auth.signOut();
        logInfo('Berhasil keluar');
        return const ActionSuccess(message: 'Berhasil keluar');
      },
      (error, stackTrace) {
        logError('Gagal keluar', error, stackTrace);
        return Failure(
          message: error is AuthException
              ? error.message
              : 'Gagal keluar. Silakan coba lagi.',
        );
      },
    );
  }

  @override
  TaskEither<Failure, Success<User>> getCurrentUser() {
    return TaskEither.tryCatch(
      () async {
        logService('Ambil pengguna saat ini');
        final user = _supabase.auth.currentUser;
        if (user == null) {
          throw const AuthException('Tidak ada pengguna yang masuk');
        }
        logInfo('Pengguna saat ini berhasil diambil');
        return Success(message: 'Pengguna berhasil diambil', data: user);
      },
      (error, stackTrace) {
        logError('Gagal mengambil pengguna saat ini', error, stackTrace);
        return Failure(
          message: error is AuthException
              ? error.message
              : 'Gagal mengambil pengguna saat ini.',
        );
      },
    );
  }

  @override
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
