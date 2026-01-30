import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/ssh_connection.dart';
import '../../core/repositories/ssh_repository.dart';

class SshConnectionFormScreen extends ConsumerStatefulWidget {
  final String? connectionId;

  const SshConnectionFormScreen({super.key, this.connectionId});

  @override
  ConsumerState<SshConnectionFormScreen> createState() => _SshConnectionFormScreenState();
}

class _SshConnectionFormScreenState extends ConsumerState<SshConnectionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _privateKeyPathController = TextEditingController();
  final _passphraseController = TextEditingController();

  bool _isLoading = false;
  bool _usePassword = true;
  SshConnection? _existingConnection;

  @override
  void initState() {
    super.initState();
    _loadExistingConnection();
  }

  Future<void> _loadExistingConnection() async {
    if (widget.connectionId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(sshRepositoryProvider);
      final connection = await repository.getConnection(widget.connectionId!);

      if (connection != null) {
        _existingConnection = connection;
        _nameController.text = connection.name;
        _hostController.text = connection.host;
        _portController.text = connection.port.toString();
        _usernameController.text = connection.username;
        _passwordController.text = connection.password ?? '';
        _privateKeyPathController.text = connection.privateKeyPath ?? '';
        _passphraseController.text = connection.passphrase ?? '';
        _usePassword = connection.password != null;
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(sshRepositoryProvider);

      final connection = SshConnection.create(
        name: _nameController.text.trim(),
        host: _hostController.text.trim(),
        port: int.tryParse(_portController.text.trim()) ?? 22,
        username: _usernameController.text.trim(),
        password: _usePassword ? _passwordController.text.trim() : null,
        privateKeyPath: !_usePassword ? _privateKeyPathController.text.trim() : null,
        passphrase: !_usePassword ? _passphraseController.text.trim() : null,
      );

      if (_existingConnection != null) {
        connection.id = _existingConnection!.id;
        connection.createdAt = _existingConnection!.createdAt;
        connection.lastConnectedAt = _existingConnection!.lastConnectedAt;
        connection.isFavorite = _existingConnection!.isFavorite;
      }

      await repository.saveConnection(connection);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_existingConnection == null ? '连接已创建' : '连接已更新'),
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

  Future<void> _pickPrivateKey() async {
    // TODO: 实现文件选择器
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('文件选择功能待实现')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existingConnection == null ? '新建 SSH 连接' : '编辑 SSH 连接'),
        actions: [
          if (_existingConnection != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('删除连接'),
                    content: const Text('确定要删除这个连接吗？'),
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
                  final repository = ref.read(sshRepositoryProvider);
                  await repository.deleteConnection(_existingConnection!.id);
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
                        labelText: '连接名称',
                        hintText: '例如：生产服务器',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入连接名称';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: '主机地址',
                        hintText: '例如：192.168.1.100 或 example.com',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入主机地址';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: '端口',
                        hintText: '默认：22',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入端口号';
                        }
                        final port = int.tryParse(value);
                        if (port == null || port < 1 || port > 65535) {
                          return '请输入有效的端口号 (1-65535)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        hintText: '例如：root',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入用户名';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '认证方式',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<bool>(
                                    title: const Text('密码认证'),
                                    value: true,
                                    groupValue: _usePassword,
                                    onChanged: (value) {
                                      setState(() {
                                        _usePassword = value!;
                                      });
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<bool>(
                                    title: const Text('密钥认证'),
                                    value: false,
                                    groupValue: _usePassword,
                                    onChanged: (value) {
                                      setState(() {
                                        _usePassword = value!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_usePassword)
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: '密码',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入密码';
                          }
                          return null;
                        },
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _privateKeyPathController,
                                  decoration: const InputDecoration(
                                    labelText: '私钥文件路径',
                                    border: OutlineInputBorder(),
                                  ),
                                  readOnly: true,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return '请选择私钥文件';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.folder_open),
                                onPressed: _pickPrivateKey,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passphraseController,
                            decoration: const InputDecoration(
                              labelText: '密钥密码（可选）',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                        ],
                      ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveConnection,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_existingConnection == null ? '创建连接' : '更新连接'),
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
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyPathController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }
}