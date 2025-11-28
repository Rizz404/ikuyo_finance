import 'package:flutter/material.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class TransactionScreen extends StatelessWidget {
  const TransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: ScreenWrapper(child: Text('TransactionScreen')));
  }
}
