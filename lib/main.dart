import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ikuyo_finance/di/commons.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables dari file .env
  await dotenv.load(fileName: '.env');

  // Setup semua dependency injection
  await setupCommons();

  // Tunggu sampai semua async singleton ready
  // await getIt.allReady(); // Uncomment jika ada async singleton yang perlu ditunggu

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
