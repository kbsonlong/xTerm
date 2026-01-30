import 'dart:async';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/terminal_theme.dart';

class ThemeRepository {
  static const String _boxName = 'terminal_themes';
  late Box<TerminalTheme> _box;

  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    Hive.init(appDir.path);

    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(TerminalThemeAdapter());
    }

    _box = await Hive.openBox<TerminalTheme>(_boxName);

    // 初始化内置主题
    await _initializeBuiltInThemes();
  }

  Future<void> _initializeBuiltInThemes() async {
    await _ensureInitialized();

    // 检查是否已经初始化过
    final hasDefaultTheme = _box.values.any((theme) => theme.id == 'default');
    if (hasDefaultTheme) return;

    // 添加内置主题
    final builtInThemes = [
      TerminalTheme.defaultTheme(),
      TerminalTheme.solarizedDark(),
      TerminalTheme.dracula(),
      TerminalTheme.monokai(),
    ];

    for (final theme in builtInThemes) {
      await _box.put(theme.id, theme);
    }
  }

  Future<List<TerminalTheme>> getAllThemes() async {
    await _ensureInitialized();
    return _box.values.toList();
  }

  Future<List<TerminalTheme>> getBuiltInThemes() async {
    await _ensureInitialized();
    return _box.values.where((theme) => theme.isBuiltIn).toList();
  }

  Future<List<TerminalTheme>> getUserThemes() async {
    await _ensureInitialized();
    return _box.values.where((theme) => !theme.isBuiltIn).toList();
  }

  Future<TerminalTheme?> getTheme(String id) async {
    await _ensureInitialized();
    return _box.get(id);
  }

  Future<TerminalTheme?> getDefaultTheme() async {
    await _ensureInitialized();
    return _box.values.firstWhere(
      (theme) => theme.isDefault,
      orElse: () => TerminalTheme.defaultTheme(),
    );
  }

  Future<void> saveTheme(TerminalTheme theme) async {
    await _ensureInitialized();
    await _box.put(theme.id, theme);
  }

  Future<void> deleteTheme(String id) async {
    await _ensureInitialized();
    final theme = await getTheme(id);
    if (theme != null && !theme.isBuiltIn) {
      await _box.delete(id);
    }
  }

  Future<void> setDefaultTheme(String id) async {
    await _ensureInitialized();

    // 重置所有主题的默认状态
    for (final theme in _box.values) {
      if (theme.isDefault) {
        final updatedTheme = theme.copyWith(isDefault: false);
        await saveTheme(updatedTheme);
      }
    }

    // 设置新的默认主题
    final theme = await getTheme(id);
    if (theme != null) {
      final updatedTheme = theme.copyWith(isDefault: true);
      await saveTheme(updatedTheme);
    }
  }

  Future<void> updateTheme(TerminalTheme theme) async {
    await _ensureInitialized();
    await saveTheme(theme);
  }

  Future<void> duplicateTheme(String sourceId, String newName) async {
    await _ensureInitialized();
    final sourceTheme = await getTheme(sourceId);
    if (sourceTheme != null) {
      final newTheme = sourceTheme.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: newName,
        isBuiltIn: false,
        isDefault: false,
        createdAt: DateTime.now(),
      );
      await saveTheme(newTheme);
    }
  }

  Future<List<TerminalTheme>> searchThemes(String query) async {
    await _ensureInitialized();
    final allThemes = await getAllThemes();

    return allThemes.where((theme) {
      return theme.name.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  Future<int> getThemeCount() async {
    await _ensureInitialized();
    return _box.length;
  }

  Future<void> _ensureInitialized() async {
    if (!_box.isOpen) {
      await init();
    }
  }

  Future<void> close() async {
    if (_box.isOpen) {
      await _box.close();
    }
  }
}