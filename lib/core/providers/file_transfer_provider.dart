import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/file_transfer_service.dart';
import '../models/ssh_connection.dart';

final fileTransferServiceProvider = Provider<FileTransferService>((ref) {
  return FileTransferService();
});

final fileTransferConnectionProvider = StateProvider<SshConnection?>((ref) => null);

final fileTransferProgressProvider = StateProvider<double>((ref) => 0.0);

final fileTransferStatusProvider = StateProvider<String>((ref) => '空闲');

final fileTransferIsActiveProvider = StateProvider<bool>((ref) => false);

class FileTransferNotifier extends StateNotifier<bool> {
  final Ref ref;
  final FileTransferService fileTransferService;

  FileTransferNotifier(this.ref, this.fileTransferService) : super(false);

  Future<void> connect(SshConnection connection) async {
    ref.read(fileTransferStatusProvider.notifier).state = '连接中...';
    try {
      await fileTransferService.connect(connection);
      ref.read(fileTransferConnectionProvider.notifier).state = connection;
      ref.read(fileTransferStatusProvider.notifier).state = '已连接';
      state = true;
    } catch (e) {
      ref.read(fileTransferStatusProvider.notifier).state = '连接失败: $e';
      rethrow;
    }
  }

  Future<void> disconnect() async {
    ref.read(fileTransferStatusProvider.notifier).state = '断开连接中...';
    try {
      await fileTransferService.disconnect();
      ref.read(fileTransferConnectionProvider.notifier).state = null;
      ref.read(fileTransferStatusProvider.notifier).state = '已断开';
      ref.read(fileTransferProgressProvider.notifier).state = 0.0;
      state = false;
    } catch (e) {
      ref.read(fileTransferStatusProvider.notifier).state = '断开连接失败: $e';
    }
  }

  Future<void> uploadFile({
    required String localPath,
    required String remotePath,
  }) async {
    if (!state) {
      throw Exception('未连接到 SSH 服务器');
    }

    ref.read(fileTransferIsActiveProvider.notifier).state = true;
    ref.read(fileTransferStatusProvider.notifier).state = '上传文件中...';
    ref.read(fileTransferProgressProvider.notifier).state = 0.0;

    try {
      await fileTransferService.uploadFile(
        localPath: localPath,
        remotePath: remotePath,
        onProgress: (progress) {
          ref.read(fileTransferProgressProvider.notifier).state = progress;
          ref.read(fileTransferStatusProvider.notifier).state = '上传中: ${(progress * 100).toStringAsFixed(1)}%';
        },
      );

      ref.read(fileTransferStatusProvider.notifier).state = '上传完成';
      ref.read(fileTransferProgressProvider.notifier).state = 1.0;
    } catch (e) {
      ref.read(fileTransferStatusProvider.notifier).state = '上传失败: $e';
      ref.read(fileTransferProgressProvider.notifier).state = 0.0;
      rethrow;
    } finally {
      ref.read(fileTransferIsActiveProvider.notifier).state = false;
    }
  }

  Future<void> downloadFile({
    required String remotePath,
    required String localPath,
  }) async {
    if (!state) {
      throw Exception('未连接到 SSH 服务器');
    }

    ref.read(fileTransferIsActiveProvider.notifier).state = true;
    ref.read(fileTransferStatusProvider.notifier).state = '下载文件中...';
    ref.read(fileTransferProgressProvider.notifier).state = 0.0;

    try {
      await fileTransferService.downloadFile(
        remotePath: remotePath,
        localPath: localPath,
        onProgress: (progress) {
          ref.read(fileTransferProgressProvider.notifier).state = progress;
          ref.read(fileTransferStatusProvider.notifier).state = '下载中: ${(progress * 100).toStringAsFixed(1)}%';
        },
      );

      ref.read(fileTransferStatusProvider.notifier).state = '下载完成';
      ref.read(fileTransferProgressProvider.notifier).state = 1.0;
    } catch (e) {
      ref.read(fileTransferStatusProvider.notifier).state = '下载失败: $e';
      ref.read(fileTransferProgressProvider.notifier).state = 0.0;
      rethrow;
    } finally {
      ref.read(fileTransferIsActiveProvider.notifier).state = false;
    }
  }

  Future<List<Map<String, dynamic>>> listDirectory(String remotePath) async {
    if (!state) {
      throw Exception('未连接到 SSH 服务器');
    }

    ref.read(fileTransferStatusProvider.notifier).state = '获取目录列表...';
    try {
      final files = await fileTransferService.listDirectory(remotePath);
      ref.read(fileTransferStatusProvider.notifier).state = '获取完成';
      return files;
    } catch (e) {
      ref.read(fileTransferStatusProvider.notifier).state = '获取失败: $e';
      rethrow;
    }
  }

  Future<void> createDirectory(String remotePath) async {
    if (!state) {
      throw Exception('未连接到 SSH 服务器');
    }

    ref.read(fileTransferStatusProvider.notifier).state = '创建目录...';
    try {
      await fileTransferService.createDirectory(remotePath);
      ref.read(fileTransferStatusProvider.notifier).state = '目录创建完成';
    } catch (e) {
      ref.read(fileTransferStatusProvider.notifier).state = '创建失败: $e';
      rethrow;
    }
  }

  Future<void> deleteFile(String remotePath) async {
    if (!state) {
      throw Exception('未连接到 SSH 服务器');
    }

    ref.read(fileTransferStatusProvider.notifier).state = '删除文件...';
    try {
      await fileTransferService.deleteFile(remotePath);
      ref.read(fileTransferStatusProvider.notifier).state = '文件删除完成';
    } catch (e) {
      ref.read(fileTransferStatusProvider.notifier).state = '删除失败: $e';
      rethrow;
    }
  }

  Future<void> deleteDirectory(String remotePath) async {
    if (!state) {
      throw Exception('未连接到 SSH 服务器');
    }

    ref.read(fileTransferStatusProvider.notifier).state = '删除目录...';
    try {
      await fileTransferService.deleteDirectory(remotePath);
      ref.read(fileTransferStatusProvider.notifier).state = '目录删除完成';
    } catch (e) {
      ref.read(fileTransferStatusProvider.notifier).state = '删除失败: $e';
      rethrow;
    }
  }

  Future<String> getCurrentDirectory() async {
    if (!state) {
      throw Exception('未连接到 SSH 服务器');
    }

    try {
      return await fileTransferService.getCurrentDirectory();
    } catch (e) {
      ref.read(fileTransferStatusProvider.notifier).state = '获取当前目录失败: $e';
      rethrow;
    }
  }
}

final fileTransferNotifierProvider = StateNotifierProvider<FileTransferNotifier, bool>((ref) {
  final fileTransferService = ref.watch(fileTransferServiceProvider);
  return FileTransferNotifier(ref, fileTransferService);
});