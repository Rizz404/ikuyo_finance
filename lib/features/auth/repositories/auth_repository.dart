import 'package:fpdart/fpdart.dart';
import 'package:ikuyo_finance/core/wrapper/failure.dart';
import 'package:ikuyo_finance/core/wrapper/success.dart';
import 'package:ikuyo_finance/features/auth/models/sign_in_with_email_params.dart';
import 'package:ikuyo_finance/features/auth/models/sign_up_with_email_params.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  TaskEither<Failure, Success<AuthResponse>> signInWithEmail(
    SignInWithEmailParams params,
  );
  TaskEither<Failure, Success<AuthResponse>> signUpWithEmail(
    SignUpWithEmailParams params,
  );
  // ! jangan dipake dulu
  TaskEither<Failure, Success<AuthResponse>> signInWithGoogle();
  TaskEither<Failure, ActionSuccess> signOut();
  TaskEither<Failure, Success<User>> getCurrentUser();
  Stream<AuthState> get authStateChanges;
}
