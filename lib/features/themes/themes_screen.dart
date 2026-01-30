import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/terminal_theme.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/repositories/theme_repository.dart';
import 'theme_editor_screen.dart';

class ThemesScreen extends ConsumerStatefulWidget {
  const ThemesScreen({super.key});

  @override
  ConsumerState<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends ConsumerState<ThemesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTab = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteTheme(TerminalTheme theme) async {
    if (theme.isBuiltIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('内置主题不能删除'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除主题'),
        content: Text('确定要删除主题 "${theme.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final notifier = ref.read(themeNotifierProvider.notifier);
      await notifier.deleteTheme(theme.id);
      setState(() {});
    }
  }

  Future<void> _duplicateTheme(TerminalTheme theme) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: '${theme.name} 副本');
        return AlertDialog(
          title: const Text('复制主题'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '新主题名称',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty) {
      final notifier = ref.read(themeNotifierProvider.notifier);
      await notifier.duplicateTheme(theme.id, newName);
      setState(() {});
    }
  }

  Future<void> _setDefaultTheme(TerminalTheme theme) async {
    final notifier = ref.read(themeNotifierProvider.notifier);
    await notifier.setDefaultTheme(theme.id);
    setState(() {});
  }

  Widget _buildThemeCard(TerminalTheme theme) {
    final currentTheme = ref.watch(themeNotifierProvider);
    final isCurrentTheme = theme.id == currentTheme.id;
    final isDefaultTheme = theme.isDefault;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isCurrentTheme ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Color(int.parse(theme.background.substring(1), radix: 16) + 0xFF000000),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Color(int.parse(theme.foreground.substring(1), radix: 16) + 0xFF000000),
              width: 2,
            ),
          ),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Color(int.parse(theme.cursor.substring(1), radix: 16) + 0xFF000000),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(theme.name),
            if (theme.isBuiltIn)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '内置',
                  style: TextStyle(fontSize: 10, color: Colors.blue),
                ),
              ),
            if (isDefaultTheme)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '默认',
                  style: TextStyle(fontSize: 10, color: Colors.green),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('前景色: ${theme.foreground}'),
            Text('背景色: ${theme.background}'),
            Text('光标色: ${theme.cursor}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCurrentTheme)
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: () {
                  final notifier = ref.read(themeNotifierProvider.notifier);
                  notifier.setTheme(theme);
                },
              ),
            PopupMenuButton(
              itemBuilder: (context) => [
                if (!theme.isBuiltIn)
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('编辑'),
                    ),
                  ),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: ListTile(
                    leading: Icon(Icons.copy),
                    title: Text('复制'),
                  ),
                ),
                if (!isDefaultTheme)
                  const PopupMenuItem(
                    value: 'set_default',
                    child: ListTile(
                      leading: Icon(Icons.star),
                      title: Text('设为默认'),
                    ),
                  ),
                if (!theme.isBuiltIn)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('删除', style: TextStyle(color: Colors.red)),
                    ),
                  ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    context.push('/themes/edit/${theme.id}');
                    break;
                  case 'duplicate':
                    _duplicateTheme(theme);
                    break;
                  case 'set_default':
                    _setDefaultTheme(theme);
                    break;
                  case 'delete':
                    _deleteTheme(theme);
                    break;
                }
              },
            ),
          ],
        ),
        onTap: () {
          final notifier = ref.read(themeNotifierProvider.notifier);
          notifier.setTheme(theme);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themesAsync = ref.watch(themesProvider);
    final builtInThemesAsync = ref.watch(builtInThemesProvider);
    final userThemesAsync = ref.watch(userThemesProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('主题管理'),
          bottom: TabBar(
            tabs: const [
              Tab(text: '全部'),
              Tab(text: '内置'),
              Tab(text: '自定义'),
            ],
            onTap: (index) {
              setState(() {
                _selectedTab = ['all', 'builtin', 'user'][index];
              });
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                context.push('/themes/new');
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索主题...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Expanded(
              child: themesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('加载失败: $error'),
                    ],
                  ),
                ),
                data: (allThemes) {
                  List<TerminalTheme> themes;
                  switch (_selectedTab) {
                    case 'builtin':
                      themes = builtInThemesAsync.valueOrNull ?? [];
                      break;
                    case 'user':
                      themes = userThemesAsync.valueOrNull ?? [];
                      break;
                    default:
                      themes = allThemes;
                  }

                  final filteredThemes = _searchQuery.isEmpty
                      ? themes
                      : themes.where((theme) {
                          return theme.name.toLowerCase().contains(_searchQuery.toLowerCase());
                        }).toList();

                  if (filteredThemes.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.color_lens, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _selectedTab == 'user'
                                ? '暂无自定义主题'
                                : '没有找到匹配的主题',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          if (_selectedTab == 'user')
                            ElevatedButton(
                              onPressed: () {
                                context.push('/themes/new');
                              },
                              child: const Text('创建新主题'),
                            ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredThemes.length,
                    itemBuilder: (context, index) {
                      return _buildThemeCard(filteredThemes[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            context.push('/themes/new');
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}