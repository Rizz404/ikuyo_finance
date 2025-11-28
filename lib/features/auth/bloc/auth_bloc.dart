import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/features/auth/models/sign_in_with_email_params.dart';
import 'package:ikuyo_finance/features/auth/models/sign_up_with_email_params.dart';
import 'package:ikuyo_finance/features/auth/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    as supabase
    show AuthChangeEvent, AuthState, User;

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._authRepository) : super(const AuthState()) {
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthStateChanged>(_onAuthStateChanged);

    // * Subscribe to auth state changes
    _authStateSubscription = _authRepository.authStateChanges.listen(
      (supabaseAuthState) => add(AuthStateChanged(supabaseAuthState)),
    );
  }

  final AuthRepository _authRepository;
  StreamSubscription<supabase.AuthState>? _authStateSubscription;

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    final result = await _authRepository
        .signInWithEmail(
          SignInWithEmailParams(email: event.email, password: event.password),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: () => success.data?.user,
          errorMessage: () => null,
        ),
      ),
    );
  }

  Future<void> _onSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    final result = await _authRepository
        .signUpWithEmail(
          SignUpWithEmailParams(email: event.email, password: event.password),
        )
        .run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: () => success.data?.user,
          errorMessage: () => null,
        ),
      ),
    );
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    final result = await _authRepository.signOut().run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: () => failure.message,
        ),
      ),
      (_) => emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          user: () => null,
          errorMessage: () => null,
        ),
      ),
    );
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    final result = await _authRepository.getCurrentUser().run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          user: () => null,
          errorMessage: () => null,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: () => success.data,
          errorMessage: () => null,
        ),
      ),
    );
  }

  void _onAuthStateChanged(AuthStateChanged event, Emitter<AuthState> emit) {
    switch (event.supabaseAuthState.event) {
      case supabase.AuthChangeEvent.initialSession:
      case supabase.AuthChangeEvent.signedIn:
      case supabase.AuthChangeEvent.tokenRefreshed:
      case supabase.AuthChangeEvent.userUpdated:
        final user = event.supabaseAuthState.session?.user;
        if (user != null) {
          emit(
            state.copyWith(
              status: AuthStatus.authenticated,
              user: () => user,
              errorMessage: () => null,
            ),
          );
        }
        break;
      case supabase.AuthChangeEvent.signedOut:
      case supabase.AuthChangeEvent.userDeleted:
        emit(
          state.copyWith(
            status: AuthStatus.unauthenticated,
            user: () => null,
            errorMessage: () => null,
          ),
        );
        break;
      case supabase.AuthChangeEvent.mfaChallengeVerified:
      case supabase.AuthChangeEvent.passwordRecovery:
        // * Handle these cases if needed
        break;
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
