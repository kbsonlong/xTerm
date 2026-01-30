import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/models/ssh_connection.dart';
import '../../core/providers/file_transfer_provider.dart';
import '../../core/providers/ssh_provider.dart';
import '../../core/repositories/ssh_repository.dart';

class FileTransferScreen extends ConsumerStatefulWidget {
  final String? connectionId;

  const FileTransferScreen({super.key, this.connectionId});

  @override
  ConsumerState<FileTransferScreen> createState() => _FileTransferScreenState();
}

class _FileTransferScreenState extends ConsumerState<FileTransferScreen> {
  SshConnection? _connection;
  String _currentRemotePath = '~';
  String _currentLocalPath = '';
  List<Map<String, dynamic>> _remoteFiles = [];
  List<FileSystemEntity> _localFiles = [];
  bool _isLoading = false;
  String _selectedRemoteFile = '';
  String _selectedLocalFile = '';

  @override
  void initState() {
    super.initState();
    _loadConnection();
    _loadLocalFiles();
  }

  Future<void> _loadConnection() async {
    if (widget.connectionId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(sshRepositoryProvider);
      final connection = await repository.getConnection(widget.connectionId!);
      if (connection != null) {
        _connection = connection;
        await _connectToSsh();
        await _loadRemoteFiles();
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLocalFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    _currentLocalPath = directory.path;

    final dir = Directory(_currentLocalPath);
    final files = await dir.list().toList();

    setState(() {
      _localFiles = files;
    });
  }

  Future<void> _connectToSsh() async {
    if (_connection == null) return;

    try {
      final notifier = ref.read(fileTransferNotifierProvider.notifier);
      await notifier.connect(_connection!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('连接失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadRemoteFiles() async {
    final notifier = ref.read(fileTransferNotifierProvider.notifier);
    final isConnected = ref.read(fileTransferNotifierProvider);

    if (!isConnected) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final files = await notifier.listDirectory(_currentRemotePath);
      setState(() {
        _remoteFiles = files;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载文件列表失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedLocalFile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择要上传的文件'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final fileName = _selectedLocalFile.split('/').last;
    final remotePath = '$_currentRemotePath/$fileName';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('上传文件'),
        content: Text('确定要上传文件 "$fileName" 到 "$_currentRemotePath" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final notifier = ref.read(fileTransferNotifierProvider.notifier);
      await notifier.uploadFile(
        localPath: _selectedLocalFile,
        remotePath: remotePath,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('文件上传成功'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadRemoteFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('上传失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadFile() async {
    if (_selectedRemoteFile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择要下载的文件'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final fileName = _selectedRemoteFile;
    final localPath = '$_currentLocalPath/$fileName';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('下载文件'),
        content: Text('确定要下载文件 "$fileName" 到 "$_currentLocalPath" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final notifier = ref.read(fileTransferNotifierProvider.notifier);
      await notifier.downloadFile(
        remotePath: '$_currentRemotePath/$_selectedRemoteFile',
        localPath: localPath,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('文件下载成功'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadLocalFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('下载失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createRemoteDirectory() async {
    final directoryName = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('创建目录'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '目录名称',
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

    if (directoryName == null || directoryName.isEmpty) return;

    try {
      final notifier = ref.read(fileTransferNotifierProvider.notifier);
      await notifier.createDirectory('$_currentRemotePath/$directoryName');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('目录创建成功'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadRemoteFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('创建目录失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteRemoteFile() async {
    if (_selectedRemoteFile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择要删除的文件'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('确定要删除文件 "$_selectedRemoteFile" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final notifier = ref.read(fileTransferNotifierProvider.notifier);
      await notifier.deleteFile('$_currentRemotePath/$_selectedRemoteFile');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('文件删除成功'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadRemoteFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除文件失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildRemoteFileList() {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: () {
                    final parts = _currentRemotePath.split('/');
                    if (parts.length > 1) {
                      parts.removeLast();
                      _currentRemotePath = parts.join('/');
                      if (_currentRemotePath.isEmpty) _currentRemotePath = '/';
                      _loadRemoteFiles();
                    }
                  },
                ),
                Expanded(
                  child: Text(
                    '远程目录: $_currentRemotePath',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadRemoteFiles,
                ),
                IconButton(
                  icon: const Icon(Icons.create_new_folder),
                  onPressed: _createRemoteDirectory,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _remoteFiles.length,
                    itemBuilder: (context, index) {
                      final file = _remoteFiles[index];
                      final isSelected = _selectedRemoteFile == file['name'];
                      final isDirectory = file['isDirectory'];

                      return ListTile(
                        leading: Icon(
                          isDirectory ? Icons.folder : Icons.insert_drive_file,
                          color: isDirectory ? Colors.amber : Colors.blue,
                        ),
                        title: Text(file['name']),
                        subtitle: Text(
                          isDirectory
                              ? '目录'
                              : '${file['size']} bytes • ${file['permissions']}',
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () {
                          if (isDirectory) {
                            _currentRemotePath = '$_currentRemotePath/${file['name']}';
                            _loadRemoteFiles();
                          } else {
                            setState(() {
                              _selectedRemoteFile = file['name'];
                            });
                          }
                        },
                        onLongPress: () {
                          if (!isDirectory) {
                            _selectedRemoteFile = file['name'];
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.download),
                                      title: const Text('下载文件'),
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        _downloadFile();
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete, color: Colors.red),
                                      title: const Text('删除文件', style: TextStyle(color: Colors.red)),
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        _deleteRemoteFile();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalFileList() {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: () {
                    final dir = Directory(_currentLocalPath);
                    if (dir.parent.path != _currentLocalPath) {
                      _currentLocalPath = dir.parent.path;
                      _loadLocalFiles();
                    }
                  },
                ),
                Expanded(
                  child: Text(
                    '本地目录: $_currentLocalPath',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadLocalFiles,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _localFiles.length,
              itemBuilder: (context, index) {
                final file = _localFiles[index];
                final isDirectory = file is Directory;
                final fileName = file.path.split('/').last;
                final isSelected = _selectedLocalFile == file.path;

                return ListTile(
                  leading: Icon(
                    isDirectory ? Icons.folder : Icons.insert_drive_file,
                    color: isDirectory ? Colors.amber : Colors.blue,
                  ),
                  title: Text(fileName),
                  subtitle: isDirectory
                      ? const Text('目录')
                      : FutureBuilder<FileStat>(
                          future: File(file.path).stat(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final size = snapshot.data!.size;
                              return Text('${_formatFileSize(size)} • ${_formatDate(snapshot.data!.modified)}');
                            }
                            return const Text('加载中...');
                          },
                        ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    if (isDirectory) {
                      _currentLocalPath = file.path;
                      _loadLocalFiles();
                    } else {
                      setState(() {
                        _selectedLocalFile = file.path;
                      });
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(fileTransferNotifierProvider);
    final progress = ref.watch(fileTransferProgressProvider);
    final status = ref.watch(fileTransferStatusProvider);
    final isActive = ref.watch(fileTransferIsActiveProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_connection?.name ?? '文件传输'),
        actions: [
          if (_connection != null)
            IconButton(
              icon: Icon(isConnected ? Icons.wifi : Icons.wifi_off),
              onPressed: () {
                if (isConnected) {
                  final notifier = ref.read(fileTransferNotifierProvider.notifier);
                  notifier.disconnect();
                } else {
                  _connectToSsh();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (isActive)
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          if (status.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).cardColor,
              child: Row(
                children: [
                  const Icon(Icons.info, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(status)),
                ],
              ),
            ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildRemoteFileList(),
                ),
                Container(
                  width: 100,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: isConnected ? _uploadFile : null,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_upward),
                            SizedBox(height: 4),
                            Text('上传'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: isConnected ? _downloadFile : null,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_downward),
                            SizedBox(height: 4),
                            Text('下载'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildLocalFileList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}