part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

final class AuthBlocState {
  const AuthBlocState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  final AuthStatus status;
  final supabase.User? user;
  final String? errorMessage;

  AuthBlocState copyWith({
    AuthStatus? status,
    supabase.User? user,
    String? errorMessage,
  }) {
    return AuthBlocState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
