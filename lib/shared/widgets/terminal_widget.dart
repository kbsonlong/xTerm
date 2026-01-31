import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

class TerminalWidget extends ConsumerStatefulWidget {
  const TerminalWidget({super.key});

  @override
  ConsumerState<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends ConsumerState<TerminalWidget> {
  late Terminal terminal;
  late TerminalController controller;

  @override
  void initState() {
    super.initState();
    terminal = Terminal(
      maxLines: 10000,
    );
    controller = TerminalController();

    // 初始化终端
    _initializeTerminal();
  }

  void _initializeTerminal() {
    // 显示欢迎信息
    terminal.write('Welcome to xTerm!\r\n');
    terminal.write('Type "help" for available commands.\r\n\r\n');
    _showPrompt();
  }

  void _showPrompt() {
    terminal.write('\$ ');
  }

  void _handleInput(String input) {
    if (input.trim().isEmpty) {
      _showPrompt();
      return;
    }

    final command = input.trim();
    terminal.write('\r\n');

    // 处理命令
    switch (command) {
      case 'help':
        terminal.write('Available commands:\r\n');
        terminal.write('  help     - Show this help message\r\n');
        terminal.write('  clear    - Clear terminal screen\r\n');
        terminal.write('  echo     - Echo input text\r\n');
        terminal.write('  date     - Show current date and time\r\n');
        terminal.write('  version  - Show xTerm version\r\n');
        break;
      case 'clear':
        // terminal.clear(); // 暂时注释，需要检查 xterm 4.0.0 API
        terminal.write('\x1B[2J\x1B[0;0H'); // 使用 ANSI 转义序列清屏
        break;
      case 'date':
        final now = DateTime.now();
        terminal.write('Current date and time: ${now.toString()}\r\n');
        break;
      case 'version':
        terminal.write('xTerm v1.0.0\r\n');
        terminal.write('Flutter-based cross-platform terminal\r\n');
        break;
      default:
        if (command.startsWith('echo ')) {
          final text = command.substring(5);
          terminal.write('$text\r\n');
        } else {
          terminal.write('Command not found: $command\r\n');
          terminal.write('Type "help" for available commands.\r\n');
        }
    }

    _showPrompt();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: TerminalView(
        terminal,
        controller: controller,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}