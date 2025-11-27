import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  TaskEither<Failure, Success<AuthResponse>> signInWithEmail({
    required String email,
    required String password,
  });
  TaskEither<Failure, Success<AuthResponse>> signUpWithEmail({
    required String email,
    required String password,
  });
  // ! jangan dipake dulu
  TaskEither<Failure, Success<AuthResponse>> signInWithGoogle();
  TaskEither<Failure, ActionSuccess> signOut();
  TaskEither<Failure, Success<User>> getCurrentUser();
  Stream<AuthState> get authStateChanges;
}
