part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, failure }

final class AuthState extends Equatable {
  final AuthStatus status;
  final supabase.User? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  // * Factory constructors for cleaner state creation
  const AuthState.initial() : this();

  const AuthState.loading() : this(status: AuthStatus.loading);

  const AuthState.authenticated(supabase.User user)
    : this(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  AuthState copyWith({
    AuthStatus? status,
    supabase.User? Function()? user,
    String? Function()? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user != null ? user() : this.user,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage];
}
