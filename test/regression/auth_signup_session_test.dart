// Regression: AAOB-12. Sign-up that returns no session (e.g. email
// confirmation pending) must not mark the user authenticated. The auth
// repository wraps the Supabase network boundary, so it is mocked.
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/auth/bloc/auth_bloc.dart';
import 'package:ikuyo_finance/features/auth/models/sign_up_with_email_params.dart';
import 'package:ikuyo_finance/features/auth/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const SignUpWithEmailParams(email: '', password: ''));
  });

  late _MockAuthRepository repo;
  setUp(() {
    repo = _MockAuthRepository();
    when(() => repo.authStateChanges).thenAnswer((_) => const Stream.empty());
  });

  blocTest<AuthBloc, AuthState>(
    'sign-up without a session ends unauthenticated, not authenticated',
    build: () {
      final user = supabase.User(
        id: 'pending',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime(2026).toIso8601String(),
      );
      when(() => repo.signUpWithEmail(any())).thenAnswer(
        (_) => TaskEither.right(
          Success(
            message: 'Berhasil daftar',
            data: supabase.AuthResponse(user: user),
          ),
        ),
      );
      return AuthBloc(repo);
    },
    act: (bloc) => bloc.add(
      const AuthSignUpRequested(email: 'a@example.com', password: 'secret123'),
    ),
    expect: () => [
      predicate<AuthState>((s) => s.status == AuthStatus.loading),
      predicate<AuthState>(
        (s) => s.status == AuthStatus.unauthenticated && s.user == null,
      ),
    ],
  );
}
