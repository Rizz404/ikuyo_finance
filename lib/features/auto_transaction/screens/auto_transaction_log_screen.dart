import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/locale/locale_keys.dart';
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:ikuyo_finance/features/auto_transaction/bloc/auto_transaction_bloc.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/widgets/auto_log_tile.dart';
import 'package:ikuyo_finance/shared/widgets/app_text.dart';
import 'package:ikuyo_finance/shared/widgets/screen_wrapper.dart';

class AutoTransactionLogScreen extends StatefulWidget {
  final AutoTransactionGroup group;

  const AutoTransactionLogScreen({super.key, required this.group});

  @override
  State<AutoTransactionLogScreen> createState() =>
      _AutoTransactionLogScreenState();
}

class _AutoTransactionLogScreenState extends State<AutoTransactionLogScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AutoTransactionBloc>().add(
      AutoLogsFetched(groupUlid: widget.group.ulid),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AutoTransactionBloc, AutoTransactionState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: AppText(
              LocaleKeys.autoTransactionLogTitle.tr(),
              style: AppTextStyle.titleLarge,
              fontWeight: FontWeight.bold,
            ),
            centerTitle: true,
          ),
          body: ScreenWrapper(child: _buildBody(context, state)),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AutoTransactionState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.currentLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_outlined,
              size: 64,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            AppText(
              LocaleKeys.autoTransactionLogEmptyTitle.tr(),
              style: AppTextStyle.bodyLarge,
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: state.currentLogs.length,
      itemBuilder: (context, index) =>
          AutoLogTile(log: state.currentLogs[index]),
    );
  }
}
