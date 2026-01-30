import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/theme_repository.dart';
import '../models/terminal_theme.dart';

final themeRepositoryProvider = Provider<ThemeRepository>((ref) {
  final repository = ThemeRepository();
  repository.init();
  ref.onDispose(() => repository.close());
  return repository;
});

final themesProvider = FutureProvider<List<TerminalTheme>>((ref) async {
  final repository = ref.watch(themeRepositoryProvider);
  return await repository.getAllThemes();
});

final builtInThemesProvider = FutureProvider<List<TerminalTheme>>((ref) async {
  final repository = ref.watch(themeRepositoryProvider);
  return await repository.getBuiltInThemes();
});

final userThemesProvider = FutureProvider<List<TerminalTheme>>((ref) async {
  final repository = ref.watch(themeRepositoryProvider);
  return await repository.getUserThemes();
});

final defaultThemeProvider = FutureProvider<TerminalTheme>((ref) async {
  final repository = ref.watch(themeRepositoryProvider);
  return await repository.getDefaultTheme() ?? TerminalTheme.defaultTheme();
});

final currentThemeProvider = StateProvider<TerminalTheme?>((ref) => null);

class ThemeNotifier extends StateNotifier<TerminalTheme> {
  final Ref ref;
  final ThemeRepository repository;

  ThemeNotifier(this.ref, this.repository) : super(TerminalTheme.defaultTheme()) {
    _loadDefaultTheme();
  }

  Future<void> _loadDefaultTheme() async {
    final defaultTheme = await repository.getDefaultTheme();
    if (defaultTheme != null) {
      state = defaultTheme;
    }
  }

  Future<void> setTheme(TerminalTheme theme) async {
    state = theme;
    ref.read(currentThemeProvider.notifier).state = theme;
  }

  Future<void> setDefaultTheme(String id) async {
    await repository.setDefaultTheme(id);
    final theme = await repository.getTheme(id);
    if (theme != null) {
      state = theme;
      ref.read(currentThemeProvider.notifier).state = theme;
    }
  }

  Future<void> createTheme({
    required String name,
    required String foreground,
    required String background,
    required String cursor,
    required String selection,
    required List<String> colors,
  }) async {
    final theme = TerminalTheme.create(
      name: name,
      foreground: foreground,
      background: background,
      cursor: cursor,
      selection: selection,
      colors: colors,
    );

    await repository.saveTheme(theme);
  }

  Future<void> updateTheme(TerminalTheme theme) async {
    await repository.updateTheme(theme);
    if (theme.id == state.id) {
      state = theme;
      ref.read(currentThemeProvider.notifier).state = theme;
    }
  }

  Future<void> deleteTheme(String id) async {
    if (id == state.id) {
      // 如果要删除当前主题，先切换到默认主题
      final defaultTheme = await repository.getDefaultTheme();
      if (defaultTheme != null) {
        state = defaultTheme;
        ref.read(currentThemeProvider.notifier).state = defaultTheme;
      }
    }
    await repository.deleteTheme(id);
  }

  Future<void> duplicateTheme(String sourceId, String newName) async {
    await repository.duplicateTheme(sourceId, newName);
  }

  TerminalTheme get currentTheme => state;
}

final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, TerminalTheme>((ref) {
  final repository = ref.watch(themeRepositoryProvider);
  return ThemeNotifier(ref, repository);
});