import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _darkMode = false;
  String _fontSize = '14';
  String _theme = 'default';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '外观',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('深色模式'),
                    value: _darkMode,
                    onChanged: (value) {
                      setState(() {
                        _darkMode = value;
                      });
                    },
                  ),
                  ListTile(
                    title: const Text('字体大小'),
                    subtitle: Text('$_fontSize px'),
                    trailing: DropdownButton<String>(
                      value: _fontSize,
                      items: const [
                        DropdownMenuItem(value: '12', child: Text('12')),
                        DropdownMenuItem(value: '14', child: Text('14')),
                        DropdownMenuItem(value: '16', child: Text('16')),
                        DropdownMenuItem(value: '18', child: Text('18')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _fontSize = value!;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('主题'),
                    subtitle: Text(_theme),
                    trailing: DropdownButton<String>(
                      value: _theme,
                      items: const [
                        DropdownMenuItem(value: 'default', child: Text('默认')),
                        DropdownMenuItem(value: 'solarized', child: Text('Solarized')),
                        DropdownMenuItem(value: 'dracula', child: Text('Dracula')),
                        DropdownMenuItem(value: 'monokai', child: Text('Monokai')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _theme = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '连接',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('SSH 连接'),
                    subtitle: const Text('管理 SSH 连接配置'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pushNamed('/ssh');
                    },
                  ),
                  ListTile(
                    title: const Text('WebSocket 连接'),
                    subtitle: const Text('管理 WebSocket 连接'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pushNamed('/websocket');
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '关于',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('版本'),
                    subtitle: const Text('1.0.0'),
                  ),
                  ListTile(
                    title: const Text('检查更新'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: 检查更新
                    },
                  ),
                  ListTile(
                    title: const Text('开源协议'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: 显示开源协议
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}