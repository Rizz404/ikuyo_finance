import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/di/injection.dart';
import 'package:ikuyo_finance/features/auth/bloc/auth_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // * Initialize logger first
  initLogger();

  await dotenv.load(fileName: '.env');
  await setupDependencies();

  talker.info('Ikuyo Finance started');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AuthBloc>()..add(const AuthCheckRequested()),
      child: MaterialApp(
        title: 'Ikuyo Finance',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ikuyo Finance')),
      body: Center(
        child: BlocBuilder<AuthBloc, AuthBlocState>(
          builder: (context, state) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Auth Status: ${state.status.name}',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                if (state.user != null)
                  Text('User: ${state.user!.email ?? 'N/A'}')
                else
                  const Text('No user logged in'),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${state.errorMessage}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
