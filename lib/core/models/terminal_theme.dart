import 'package:hive/hive.dart';

part 'terminal_theme.g.dart';

@HiveType(typeId: 2)
class TerminalTheme extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String foreground;

  @HiveField(3)
  String background;

  @HiveField(4)
  String cursor;

  @HiveField(5)
  String selection;

  @HiveField(6)
  List<String> colors;

  @HiveField(7)
  bool isBuiltIn;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  bool isDefault;

  TerminalTheme({
    required this.id,
    required this.name,
    required this.foreground,
    required this.background,
    required this.cursor,
    required this.selection,
    required this.colors,
    this.isBuiltIn = false,
    required this.createdAt,
    this.isDefault = false,
  });

  factory TerminalTheme.create({
    required String name,
    required String foreground,
    required String background,
    required String cursor,
    required String selection,
    required List<String> colors,
    bool isBuiltIn = false,
  }) {
    return TerminalTheme(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      foreground: foreground,
      background: background,
      cursor: cursor,
      selection: selection,
      colors: colors,
      isBuiltIn: isBuiltIn,
      createdAt: DateTime.now(),
      isDefault: false,
    );
  }

  factory TerminalTheme.defaultTheme() {
    return TerminalTheme(
      id: 'default',
      name: '默认',
      foreground: '#ffffff',
      background: '#000000',
      cursor: '#00ff00',
      selection: '#0000ff80',
      colors: [
        '#000000', // 0: 黑色
        '#ff0000', // 1: 红色
        '#00ff00', // 2: 绿色
        '#ffff00', // 3: 黄色
        '#0000ff', // 4: 蓝色
        '#ff00ff', // 5: 洋红
        '#00ffff', // 6: 青色
        '#ffffff', // 7: 白色
        '#808080', // 8: 亮黑
        '#ff8080', // 9: 亮红
        '#80ff80', // 10: 亮绿
        '#ffff80', // 11: 亮黄
        '#8080ff', // 12: 亮蓝
        '#ff80ff', // 13: 亮洋红
        '#80ffff', // 14: 亮青
        '#ffffff', // 15: 亮白
      ],
      isBuiltIn: true,
      createdAt: DateTime.now(),
      isDefault: true,
    );
  }

  factory TerminalTheme.solarizedDark() {
    return TerminalTheme(
      id: 'solarized-dark',
      name: 'Solarized 深色',
      foreground: '#839496',
      background: '#002b36',
      cursor: '#d33682',
      selection: '#073642',
      colors: [
        '#073642',
        '#dc322f',
        '#859900',
        '#b58900',
        '#268bd2',
        '#d33682',
        '#2aa198',
        '#eee8d5',
        '#002b36',
        '#cb4b16',
        '#586e75',
        '#657b83',
        '#839496',
        '#6c71c4',
        '#93a1a1',
        '#fdf6e3',
      ],
      isBuiltIn: true,
      createdAt: DateTime.now(),
      isDefault: false,
    );
  }

  factory TerminalTheme.dracula() {
    return TerminalTheme(
      id: 'dracula',
      name: 'Dracula',
      foreground: '#f8f8f2',
      background: '#282a36',
      cursor: '#f8f8f2',
      selection: '#44475a',
      colors: [
        '#000000',
        '#ff5555',
        '#50fa7b',
        '#f1fa8c',
        '#bd93f9',
        '#ff79c6',
        '#8be9fd',
        '#bbbbbb',
        '#555555',
        '#ff5555',
        '#50fa7b',
        '#f1fa8c',
        '#bd93f9',
        '#ff79c6',
        '#8be9fd',
        '#ffffff',
      ],
      isBuiltIn: true,
      createdAt: DateTime.now(),
      isDefault: false,
    );
  }

  factory TerminalTheme.monokai() {
    return TerminalTheme(
      id: 'monokai',
      name: 'Monokai',
      foreground: '#f8f8f2',
      background: '#272822',
      cursor: '#f8f8f2',
      selection: '#49483e',
      colors: [
        '#272822',
        '#f92672',
        '#a6e22e',
        '#f4bf75',
        '#66d9ef',
        '#ae81ff',
        '#a1efe4',
        '#f8f8f2',
        '#75715e',
        '#f92672',
        '#a6e22e',
        '#f4bf75',
        '#66d9ef',
        '#ae81ff',
        '#a1efe4',
        '#f9f8f5',
      ],
      isBuiltIn: true,
      createdAt: DateTime.now(),
      isDefault: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'foreground': foreground,
      'background': background,
      'cursor': cursor,
      'selection': selection,
      'colors': colors,
      'isBuiltIn': isBuiltIn,
      'createdAt': createdAt.toIso8601String(),
      'isDefault': isDefault,
    };
  }

  TerminalTheme copyWith({
    String? id,
    String? name,
    String? foreground,
    String? background,
    String? cursor,
    String? selection,
    List<String>? colors,
    bool? isBuiltIn,
    DateTime? createdAt,
    bool? isDefault,
  }) {
    return TerminalTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      foreground: foreground ?? this.foreground,
      background: background ?? this.background,
      cursor: cursor ?? this.cursor,
      selection: selection ?? this.selection,
      colors: colors ?? List.from(this.colors),
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  String toString() {
    return 'TerminalTheme{name: $name, id: $id}';
  }
}