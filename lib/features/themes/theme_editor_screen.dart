import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/terminal_theme.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/repositories/theme_repository.dart';

class ThemeEditorScreen extends ConsumerStatefulWidget {
  final String? themeId;

  const ThemeEditorScreen({super.key, this.themeId});

  @override
  ConsumerState<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends ConsumerState<ThemeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _foregroundController = TextEditingController();
  final _backgroundController = TextEditingController();
  final _cursorController = TextEditingController();
  final _selectionController = TextEditingController();
  final List<TextEditingController> _colorControllers = List.generate(16, (_) => TextEditingController());

  bool _isLoading = false;
  TerminalTheme? _existingTheme;

  @override
  void initState() {
    super.initState();
    _loadExistingTheme();
  }

  Future<void> _loadExistingTheme() async {
    if (widget.themeId == null) {
      // 新建主题，使用默认值
      _setDefaultValues();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(themeRepositoryProvider);
      final theme = await repository.getTheme(widget.themeId!);

      if (theme != null) {
        _existingTheme = theme;
        _nameController.text = theme.name;
        _foregroundController.text = theme.foreground;
        _backgroundController.text = theme.background;
        _cursorController.text = theme.cursor;
        _selectionController.text = theme.selection;

        for (int i = 0; i < theme.colors.length && i < 16; i++) {
          _colorControllers[i].text = theme.colors[i];
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setDefaultValues() {
    final defaultTheme = TerminalTheme.defaultTheme();
    _nameController.text = '新主题';
    _foregroundController.text = defaultTheme.foreground;
    _backgroundController.text = defaultTheme.background;
    _cursorController.text = defaultTheme.cursor;
    _selectionController.text = defaultTheme.selection;

    for (int i = 0; i < defaultTheme.colors.length && i < 16; i++) {
      _colorControllers[i].text = defaultTheme.colors[i];
    }
  }

  bool _isValidColor(String color) {
    if (color.isEmpty) return false;
    final regex = RegExp(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$');
    return regex.hasMatch(color);
  }

  Future<void> _saveTheme() async {
    if (!_formKey.currentState!.validate()) return;

    // 验证所有颜色
    final colors = <String>[];
    for (int i = 0; i < 16; i++) {
      final color = _colorControllers[i].text.trim();
      if (!_isValidColor(color)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('颜色 ${i + 1} 格式无效，请使用 #RRGGBB 格式'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      colors.add(color);
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final notifier = ref.read(themeNotifierProvider.notifier);

      await notifier.createTheme(
        name: _nameController.text.trim(),
        foreground: _foregroundController.text.trim(),
        background: _backgroundController.text.trim(),
        cursor: _cursorController.text.trim(),
        selection: _selectionController.text.trim(),
        colors: colors,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('主题已保存'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTheme() async {
    if (!_formKey.currentState!.validate()) return;

    // 验证所有颜色
    final colors = <String>[];
    for (int i = 0; i < 16; i++) {
      final color = _colorControllers[i].text.trim();
      if (!_isValidColor(color)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('颜色 ${i + 1} 格式无效，请使用 #RRGGBB 格式'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      colors.add(color);
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_existingTheme != null) {
        final updatedTheme = _existingTheme!.copyWith(
          name: _nameController.text.trim(),
          foreground: _foregroundController.text.trim(),
          background: _backgroundController.text.trim(),
          cursor: _cursorController.text.trim(),
          selection: _selectionController.text.trim(),
          colors: colors,
        );

        final notifier = ref.read(themeNotifierProvider.notifier);
        await notifier.updateTheme(updatedTheme);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('主题已更新'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildColorField(int index, String label) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text('$label:'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _colorControllers[index],
            decoration: InputDecoration(
              hintText: '#RRGGBB',
              border: const OutlineInputBorder(),
              prefixIcon: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isValidColor(_colorControllers[index].text.trim())
                      ? Color(int.parse(_colorControllers[index].text.trim().substring(1), radix: 16) + 0xFF000000)
                      : Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入颜色值';
              }
              if (!_isValidColor(value.trim())) {
                return '请使用 #RRGGBB 格式';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existingTheme == null ? '新建主题' : '编辑主题'),
        actions: [
          if (_existingTheme != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('删除主题'),
                    content: const Text('确定要删除这个主题吗？'),
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

                if (confirmed == true && _existingTheme != null) {
                  final notifier = ref.read(themeNotifierProvider.notifier);
                  await notifier.deleteTheme(_existingTheme!.id);
                  if (mounted) {
                    context.pop();
                  }
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '主题名称',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入主题名称';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _foregroundController,
                      decoration: const InputDecoration(
                        labelText: '前景色',
                        hintText: '#FFFFFF',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入前景色';
                        }
                        if (!_isValidColor(value.trim())) {
                          return '请使用 #RRGGBB 格式';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _backgroundController,
                      decoration: const InputDecoration(
                        labelText: '背景色',
                        hintText: '#000000',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入背景色';
                        }
                        if (!_isValidColor(value.trim())) {
                          return '请使用 #RRGGBB 格式';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cursorController,
                      decoration: const InputDecoration(
                        labelText: '光标颜色',
                        hintText: '#00FF00',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入光标颜色';
                        }
                        if (!_isValidColor(value.trim())) {
                          return '请使用 #RRGGBB 格式';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _selectionController,
                      decoration: const InputDecoration(
                        labelText: '选中背景色',
                        hintText: '#0000FF80',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入选中背景色';
                        }
                        if (!_isValidColor(value.trim())) {
                          return '请使用 #RRGGBB 格式';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '颜色调色板 (16色)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 4,
                      ),
                      itemCount: 16,
                      itemBuilder: (context, index) {
                        final labels = [
                          '黑色 (0)', '红色 (1)', '绿色 (2)', '黄色 (3)',
                          '蓝色 (4)', '洋红 (5)', '青色 (6)', '白色 (7)',
                          '亮黑 (8)', '亮红 (9)', '亮绿 (10)', '亮黄 (11)',
                          '亮蓝 (12)', '亮洋红 (13)', '亮青 (14)', '亮白 (15)',
                        ];
                        return _buildColorField(index, labels[index]);
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _existingTheme == null
                              ? _saveTheme
                              : _updateTheme,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_existingTheme == null ? '创建主题' : '更新主题'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _foregroundController.dispose();
    _backgroundController.dispose();
    _cursorController.dispose();
    _selectionController.dispose();
    for (final controller in _colorControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}