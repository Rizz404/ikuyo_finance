import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ikuyo_finance/core/theme/cubit/theme_cubit.dart';

/// Example widget untuk switch theme
/// Bisa dipakai di Settings page atau AppBar
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, state) {
        final cubit = context.read<ThemeCubit>();

        return IconButton(
          icon: Icon(cubit.isDarkMode ? Icons.light_mode : Icons.dark_mode),
          onPressed: () => cubit.toggleTheme(),
          tooltip: cubit.isDarkMode ? 'Switch to Light' : 'Switch to Dark',
        );
      },
    );
  }
}

/// Example dropdown untuk pilih theme mode (Light/Dark/System)
class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, state) {
        final cubit = context.read<ThemeCubit>();

        return SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.light,
              label: Text('Light'),
              icon: Icon(Icons.light_mode),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text('Dark'),
              icon: Icon(Icons.dark_mode),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              label: Text('System'),
              icon: Icon(Icons.brightness_auto),
            ),
          ],
          selected: {state.themeMode},
          onSelectionChanged: (Set<ThemeMode> newSelection) {
            cubit.setThemeMode(newSelection.first);
          },
        );
      },
    );
  }
}
