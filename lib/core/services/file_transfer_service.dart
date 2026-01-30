import 'dart:async';
import 'dart:io';

import 'package:ssh2/ssh2.dart';

import '../models/ssh_connection.dart';

class FileTransferService {
  SSHClient? _sshClient;
  bool _isConnected = false;

  Future<void> connect(SshConnection connection) async {
    try {
      _sshClient = SSHClient(
        host: connection.host,
        port: connection.port,
        username: connection.username,
        passwordOrKey: connection.password ??
            (connection.privateKeyPath != null
                ? {
                    'privateKey': File(connection.privateKeyPath!).readAsStringSync(),
                    'passphrase': connection.passphrase,
                  }
                : null),
      );

      await _sshClient!.connect();
      _isConnected = true;
    } catch (e) {
      await disconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      await _sshClient?.disconnect();
      _sshClient = null;
      _isConnected = false;
    } catch (e) {
      // 忽略断开连接时的错误
    }
  }

  Future<void> uploadFile({
    required String localPath,
    required String remotePath,
    void Function(double progress)? onProgress,
  }) async {
    if (_sshClient == null || !_isConnected) {
      throw Exception('未连接到 SSH 服务器');
    }

    final localFile = File(localPath);
    if (!await localFile.exists()) {
      throw Exception('本地文件不存在: $localPath');
    }

    final fileSize = await localFile.length();
    final stream = localFile.openRead();

    try {
      await _sshClient!.uploadFile(
        stream: stream,
        remotePath: remotePath,
        fileSize: fileSize,
        onProgress: onProgress,
      );
    } catch (e) {
      throw Exception('文件上传失败: $e');
    }
  }

  Future<void> downloadFile({
    required String remotePath,
    required String localPath,
    void Function(double progress)? onProgress,
  }) async {
    if (_sshClient == null || !_isConnected) {
      throw Exception('未连接到 SSH 服务器');
    }

    final localFile = File(localPath);
    final sink = localFile.openWrite();

    try {
      await _sshClient!.downloadFile(
        remotePath: remotePath,
        sink: sink,
        onProgress: onProgress,
      );
      await sink.close();
    } catch (e) {
      await sink.close();
      throw Exception('文件下载失败: $e');
    }
  }

  Future<List<Map<String, dynamic>>> listDirectory(String remotePath) async {
    if (_sshClient == null || !_isConnected) {
      throw Exception('未连接到 SSH 服务器');
    }

    try {
      final result = await _sshClient!.execute('ls -la "$remotePath"');
      final lines = result.split('\n');
      final files = <Map<String, dynamic>>[];

      for (final line in lines) {
        if (line.trim().isEmpty || line.startsWith('total')) continue;

        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 9) {
          final permissions = parts[0];
          final links = parts[1];
          final owner = parts[2];
          final group = parts[3];
          final size = parts[4];
          final month = parts[5];
          final day = parts[6];
          final timeOrYear = parts[7];
          final name = parts.sublist(8).join(' ');

          files.add({
            'name': name,
            'permissions': permissions,
            'links': int.tryParse(links) ?? 0,
            'owner': owner,
            'group': group,
            'size': int.tryParse(size) ?? 0,
            'date': '$month $day $timeOrYear',
            'isDirectory': permissions.startsWith('d'),
            'isLink': permissions.startsWith('l'),
            'isFile': permissions.startsWith('-'),
          });
        }
      }

      return files;
    } catch (e) {
      throw Exception('目录列表获取失败: $e');
    }
  }

  Future<void> createDirectory(String remotePath) async {
    if (_sshClient == null || !_isConnected) {
      throw Exception('未连接到 SSH 服务器');
    }

    try {
      await _sshClient!.execute('mkdir -p "$remotePath"');
    } catch (e) {
      throw Exception('创建目录失败: $e');
    }
  }

  Future<void> deleteFile(String remotePath) async {
    if (_sshClient == null || !_isConnected) {
      throw Exception('未连接到 SSH 服务器');
    }

    try {
      await _sshClient!.execute('rm -f "$remotePath"');
    } catch (e) {
      throw Exception('删除文件失败: $e');
    }
  }

  Future<void> deleteDirectory(String remotePath) async {
    if (_sshClient == null || !_isConnected) {
      throw Exception('未连接到 SSH 服务器');
    }

    try {
      await _sshClient!.execute('rm -rf "$remotePath"');
    } catch (e) {
      throw Exception('删除目录失败: $e');
    }
  }

  Future<void> renameFile(String oldPath, String newPath) async {
    if (_sshClient == null || !_isConnected) {
      throw Exception('未连接到 SSH 服务器');
    }

    try {
      await _sshClient!.execute('mv "$oldPath" "$newPath"');
    } catch (e) {
      throw Exception('重命名文件失败: $e');
    }
  }

  Future<String> getFilePermissions(String remotePath) async {
    if (_sshClient == null || !_isConnected) {
      throw Exception('未连接到 SSH 服务器');
    }

    try {
      final result = await _sshClient!.execute('stat -c "%a" "$remotePath"');
      return result.trim();
    } catch (e) {
      throw Exception('获取文件权限失败: $e');
    }
  }

  Future<void> setFilePermissions(String remotePath, String permissions) async {
    if (_sshClient == null || !_isConnected) {
      throw Exception('未连接到 SSH 服务器');
    }

    try {
      await _sshClient!.execute('chmod $permissions "$remotePath"');
    } catch (e) {
      throw Exception('设置文件权限失败: $e');
    }
  }

  Future<int> getFileSize(String remotePath) async {
    if (_sshClient == null || !_isConnected) {
      throw Exception('未连接到 SSH 服务器');
    }

    try {
      final result = await _sshClient!.execute('stat -c "%s" "$remotePath"');
      return int.tryParse(result.trim()) ?? 0;
    } catch (e) {
      throw Exception('获取文件大小失败: $e');
    }
  }

  Future<String> getCurrentDirectory() async {
    if (_sshClient == null || !_isConnected) {
      throw Exception('未连接到 SSH 服务器');
    }

    try {
      final result = await _sshClient!.execute('pwd');
      return result.trim();
    } catch (e) {
      throw Exception('获取当前目录失败: $e');
    }
  }

  Future<void> changeDirectory(String remotePath) async {
    if (_sshClient == null || !_isConnected) {
      throw Exception('未连接到 SSH 服务器');
    }

    try {
      await _sshClient!.execute('cd "$remotePath"');
    } catch (e) {
      throw Exception('切换目录失败: $e');
    }
  }

  bool get isConnected => _isConnected;
}