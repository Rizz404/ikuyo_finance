import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/auth/bloc/auth_bloc.dart';
import 'package:ikuyo_finance/features/auth/models/sign_in_with_email_params.dart';
import 'package:ikuyo_finance/features/auth/models/sign_up_with_email_params.dart';
import 'package:ikuyo_finance/features/auth/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class MockAuthRepository extends Mock implements AuthRepository {}

supabase.User _buildUser({String id = 'user-1', String? email = 'user@example.com'}) {
  return supabase.User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime(2024, 1, 1).toIso8601String(),
    email: email,
  );
}

supabase.Session _buildSession(supabase.User user) {
  return supabase.Session(accessToken: 'access-token', tokenType: 'bearer', user: user);
}

void main() {
  setUpAll(() {
    // * Needed by mocktail whenever `any()` is used for these argument
    // * types in when()/verify().
    registerFallbackValue(const SignInWithEmailParams(email: '', password: ''));
    registerFallbackValue(const SignUpWithEmailParams(email: '', password: ''));
  });

  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    // * AuthBloc's constructor subscribes to `authStateChanges` immediately,
    // * so every test needs this stubbed before the bloc is built. Tests
    // * that specifically exercise the stream override this in `build`.
    when(
      () => mockAuthRepository.authStateChanges,
    ).thenAnswer((_) => const Stream.empty());
  });

  test('initial state is AuthState.initial', () {
    final bloc = AuthBloc(mockAuthRepository);
    expect(bloc.state, const AuthState());
    expect(bloc.state.status, AuthStatus.initial);
    expect(bloc.state.user, isNull);
    expect(bloc.state.errorMessage, isNull);
    bloc.close();
  });

  group('AuthSignInRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] on success',
      build: () {
        final user = _buildUser();
        when(() => mockAuthRepository.signInWithEmail(any())).thenAnswer(
          (_) => TaskEither.right(
            Success(message: 'Berhasil masuk', data: supabase.AuthResponse(session: _buildSession(user), user: user)),
          ),
        );
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(
        const AuthSignInRequested(email: 'user@example.com', password: 'secret123'),
      ),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.loading),
        predicate<AuthState>(
          (s) => s.status == AuthStatus.authenticated && s.user?.id == 'user-1' && s.errorMessage == null,
        ),
      ],
      verify: (_) {
        verify(() => mockAuthRepository.signInWithEmail(any())).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits authenticated with a null user when the response carries no user',
      build: () {
        when(() => mockAuthRepository.signInWithEmail(any())).thenAnswer(
          (_) => TaskEither.right(
            Success(message: 'Berhasil masuk', data: supabase.AuthResponse()),
          ),
        );
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(
        const AuthSignInRequested(email: 'user@example.com', password: 'secret123'),
      ),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.loading),
        predicate<AuthState>((s) => s.status == AuthStatus.authenticated && s.user == null),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, failure] with the repository message on failure',
      build: () {
        when(() => mockAuthRepository.signInWithEmail(any())).thenAnswer(
          (_) => TaskEither.left(const Failure(message: 'Email atau kata sandi salah')),
        );
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(
        const AuthSignInRequested(email: 'user@example.com', password: 'wrong'),
      ),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.loading),
        predicate<AuthState>(
          (s) => s.status == AuthStatus.failure && s.errorMessage == 'Email atau kata sandi salah',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'clears a previously seeded error message on a fresh success',
      seed: () => const AuthState(status: AuthStatus.failure, errorMessage: 'old error'),
      build: () {
        final user = _buildUser();
        when(() => mockAuthRepository.signInWithEmail(any())).thenAnswer(
          (_) => TaskEither.right(
            Success(message: 'ok', data: supabase.AuthResponse(session: _buildSession(user), user: user)),
          ),
        );
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(
        const AuthSignInRequested(email: 'user@example.com', password: 'secret123'),
      ),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.loading),
        predicate<AuthState>((s) => s.status == AuthStatus.authenticated && s.errorMessage == null),
      ],
    );
  });

  group('AuthSignUpRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] on success',
      build: () {
        final user = _buildUser(id: 'new-user');
        when(() => mockAuthRepository.signUpWithEmail(any())).thenAnswer(
          (_) => TaskEither.right(
            Success(message: 'Berhasil daftar', data: supabase.AuthResponse(session: _buildSession(user), user: user)),
          ),
        );
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(
        const AuthSignUpRequested(email: 'new@example.com', password: 'secret123'),
      ),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.loading),
        predicate<AuthState>((s) => s.status == AuthStatus.authenticated && s.user?.id == 'new-user'),
      ],
      verify: (_) {
        verify(() => mockAuthRepository.signUpWithEmail(any())).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, failure] with the repository message on failure',
      build: () {
        when(() => mockAuthRepository.signUpWithEmail(any())).thenAnswer(
          (_) => TaskEither.left(const Failure(message: 'Email sudah terdaftar')),
        );
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(
        const AuthSignUpRequested(email: 'existing@example.com', password: 'secret123'),
      ),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.loading),
        predicate<AuthState>(
          (s) => s.status == AuthStatus.failure && s.errorMessage == 'Email sudah terdaftar',
        ),
      ],
    );
  });

  group('AuthSignOutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [loading, unauthenticated] on success and clears the user',
      seed: () => AuthState(status: AuthStatus.authenticated, user: _buildUser()),
      build: () {
        when(() => mockAuthRepository.signOut()).thenAnswer(
          (_) => TaskEither.right(const ActionSuccess(message: 'Berhasil keluar')),
        );
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(const AuthSignOutRequested()),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.loading),
        predicate<AuthState>((s) => s.status == AuthStatus.unauthenticated && s.user == null),
      ],
      verify: (_) {
        verify(() => mockAuthRepository.signOut()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, failure] when the repository fails to sign out',
      build: () {
        when(() => mockAuthRepository.signOut()).thenAnswer(
          (_) => TaskEither.left(const Failure(message: 'Gagal keluar. Silakan coba lagi.')),
        );
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(const AuthSignOutRequested()),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.loading),
        predicate<AuthState>(
          (s) => s.status == AuthStatus.failure && s.errorMessage == 'Gagal keluar. Silakan coba lagi.',
        ),
      ],
    );
  });

  group('AuthCheckRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] with the current user on success',
      build: () {
        final user = _buildUser();
        when(() => mockAuthRepository.getCurrentUser()).thenAnswer(
          (_) => TaskEither.right(Success(message: 'ok', data: user)),
        );
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.loading),
        predicate<AuthState>((s) => s.status == AuthStatus.authenticated && s.user?.id == 'user-1'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, unauthenticated] (not failure) when there is no session',
      build: () {
        when(() => mockAuthRepository.getCurrentUser()).thenAnswer(
          (_) => TaskEither.left(const Failure(message: 'Tidak ada pengguna yang masuk')),
        );
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.loading),
        predicate<AuthState>(
          (s) => s.status == AuthStatus.unauthenticated && s.user == null && s.errorMessage == null,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'discards a previously seeded error message even on failure',
      seed: () => const AuthState(status: AuthStatus.failure, errorMessage: 'stale error'),
      build: () {
        when(() => mockAuthRepository.getCurrentUser()).thenAnswer(
          (_) => TaskEither.left(const Failure(message: 'no session')),
        );
        return AuthBloc(mockAuthRepository);
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.loading),
        predicate<AuthState>((s) => s.status == AuthStatus.unauthenticated && s.errorMessage == null),
      ],
    );
  });

  group('AuthStateChanged (added directly)', () {
    blocTest<AuthBloc, AuthState>(
      'signedIn with a session emits authenticated',
      build: () => AuthBloc(mockAuthRepository),
      act: (bloc) => bloc.add(
        AuthStateChanged(
          supabase.AuthState(supabase.AuthChangeEvent.signedIn, _buildSession(_buildUser())),
        ),
      ),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.authenticated && s.user?.id == 'user-1'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'initialSession with a session emits authenticated',
      build: () => AuthBloc(mockAuthRepository),
      act: (bloc) => bloc.add(
        AuthStateChanged(
          supabase.AuthState(supabase.AuthChangeEvent.initialSession, _buildSession(_buildUser())),
        ),
      ),
      expect: () => [predicate<AuthState>((s) => s.status == AuthStatus.authenticated)],
    );

    blocTest<AuthBloc, AuthState>(
      'tokenRefreshed with a session emits authenticated',
      build: () => AuthBloc(mockAuthRepository),
      act: (bloc) => bloc.add(
        AuthStateChanged(
          supabase.AuthState(supabase.AuthChangeEvent.tokenRefreshed, _buildSession(_buildUser())),
        ),
      ),
      expect: () => [predicate<AuthState>((s) => s.status == AuthStatus.authenticated)],
    );

    blocTest<AuthBloc, AuthState>(
      'userUpdated with a session emits authenticated',
      build: () => AuthBloc(mockAuthRepository),
      act: (bloc) => bloc.add(
        AuthStateChanged(
          supabase.AuthState(supabase.AuthChangeEvent.userUpdated, _buildSession(_buildUser())),
        ),
      ),
      expect: () => [predicate<AuthState>((s) => s.status == AuthStatus.authenticated)],
    );

    blocTest<AuthBloc, AuthState>(
      'signedIn with no session does not emit (no user to authenticate)',
      build: () => AuthBloc(mockAuthRepository),
      act: (bloc) => bloc.add(
        const AuthStateChanged(supabase.AuthState(supabase.AuthChangeEvent.signedIn, null)),
      ),
      expect: () => [],
    );

    blocTest<AuthBloc, AuthState>(
      'signedOut emits unauthenticated',
      seed: () => AuthState(status: AuthStatus.authenticated, user: _buildUser()),
      build: () => AuthBloc(mockAuthRepository),
      act: (bloc) => bloc.add(
        const AuthStateChanged(supabase.AuthState(supabase.AuthChangeEvent.signedOut, null)),
      ),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.unauthenticated && s.user == null),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'userDeleted emits unauthenticated',
      seed: () => AuthState(status: AuthStatus.authenticated, user: _buildUser()),
      build: () => AuthBloc(mockAuthRepository),
      // ignore: deprecated_member_use
      act: (bloc) => bloc.add(
        // ignore: deprecated_member_use
        const AuthStateChanged(supabase.AuthState(supabase.AuthChangeEvent.userDeleted, null)),
      ),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.unauthenticated && s.user == null),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'mfaChallengeVerified does not emit',
      build: () => AuthBloc(mockAuthRepository),
      act: (bloc) => bloc.add(
        const AuthStateChanged(supabase.AuthState(supabase.AuthChangeEvent.mfaChallengeVerified, null)),
      ),
      expect: () => [],
    );

    blocTest<AuthBloc, AuthState>(
      'passwordRecovery does not emit',
      build: () => AuthBloc(mockAuthRepository),
      act: (bloc) => bloc.add(
        const AuthStateChanged(supabase.AuthState(supabase.AuthChangeEvent.passwordRecovery, null)),
      ),
      expect: () => [],
    );
  });

  group('authStateChanges stream subscription', () {
    blocTest<AuthBloc, AuthState>(
      'automatically becomes authenticated when the repository stream emits signedIn',
      build: () {
        final user = _buildUser(id: 'stream-user');
        when(() => mockAuthRepository.authStateChanges).thenAnswer(
          (_) => Stream.value(
            supabase.AuthState(supabase.AuthChangeEvent.signedIn, _buildSession(user)),
          ),
        );
        return AuthBloc(mockAuthRepository);
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.authenticated && s.user?.id == 'stream-user'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'automatically becomes unauthenticated when the repository stream emits signedOut',
      seed: () => AuthState(status: AuthStatus.authenticated, user: _buildUser()),
      build: () {
        when(() => mockAuthRepository.authStateChanges).thenAnswer(
          (_) => Stream.value(const supabase.AuthState(supabase.AuthChangeEvent.signedOut, null)),
        );
        return AuthBloc(mockAuthRepository);
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.unauthenticated),
      ],
    );
  });

  test('close cancels the auth state subscription without throwing', () async {
    final controller = StreamController<supabase.AuthState>();
    when(() => mockAuthRepository.authStateChanges).thenAnswer((_) => controller.stream);

    final bloc = AuthBloc(mockAuthRepository);
    await bloc.close();

    expect(controller.hasListener, isFalse);
    await controller.close();
  });
}
