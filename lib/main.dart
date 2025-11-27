import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';
import 'package:ikuyo_finance/di/injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await setupDependencies();

  talker.info('🚀 Ikuyo Finance started');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ikuyo Finance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('Ikuyo Finance - Storage Setup Complete')),
      ),
    );
  }
}
