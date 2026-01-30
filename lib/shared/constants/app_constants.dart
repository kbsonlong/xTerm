class AppConstants {
  // App info
  static const String appName = 'xTerm';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Cross-platform terminal application';

  // Terminal settings
  static const int defaultTerminalRows = 24;
  static const int defaultTerminalCols = 80;
  static const int maxTerminalHistory = 10000;

  // Font sizes
  static const List<int> availableFontSizes = [12, 14, 16, 18, 20];
  static const int defaultFontSize = 14;

  // Themes
  static const List<String> availableThemes = [
    'default',
    'solarized',
    'dracula',
    'monokai',
    'gruvbox',
  ];

  // Storage keys
  static const String storageThemeKey = 'theme';
  static const String storageFontSizeKey = 'font_size';
  static const String storageDarkModeKey = 'dark_mode';
  static const String storageConnectionsKey = 'connections';

  // API endpoints (if needed)
  static const String githubRepo = 'https://github.com/yourusername/xterm';
  static const String issuesUrl = '$githubRepo/issues';
  static const String releasesUrl = '$githubRepo/releases';
}