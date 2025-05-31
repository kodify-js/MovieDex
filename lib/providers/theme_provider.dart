import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider extends ChangeNotifier {
  late Box _settingsBox;
  bool _amoledMode = false;
  Color _accentColor = Colors.blue;
  String _fontFamily = 'Inter'; // Add font family

  ThemeProvider() {
    _initSettings();
  }

  bool get amoledMode => _amoledMode;
  Color get accentColor => _accentColor;
  String get fontFamily => _fontFamily; // Add getter

  Future<void> _initSettings() async {
    _settingsBox = await Hive.openBox('settings');
    _amoledMode = _settingsBox.get('amoledMode', defaultValue: false);
    _accentColor =
        Color(_settingsBox.get('accentColor', defaultValue: Colors.blue.value));
    _fontFamily = _settingsBox.get('fontFamily', defaultValue: 'Inter');
    notifyListeners();
  }

  ThemeData getTheme(BuildContext context) {
    final isDark = true; // Always dark theme

    final colorScheme = ColorScheme.fromSeed(
      seedColor: _accentColor, // Use _accentColor directly
      brightness: Brightness.dark,
      primary: _accentColor, // Use _accentColor directly
      surface: _amoledMode ? Colors.black : null,
      background: _amoledMode ? Colors.black : const Color(0xFF0A0A0A),
      onBackground: Colors.white,
      surfaceVariant:
          _amoledMode ? Colors.black : Colors.black.withOpacity(0.3),
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: _fontFamily, // Add font family to theme
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.onSurface.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          color: Colors.white,
          fontFamily: _fontFamily,
        ),
        bodyMedium: TextStyle(
          color: Colors.white70,
          fontFamily: _fontFamily,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
          fontFamily: _fontFamily,
        ),
      ).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
        fontFamily: _fontFamily,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _amoledMode ? Colors.black : null,
        selectedItemColor: _accentColor,
        unselectedItemColor: Colors.white60,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _amoledMode ? Colors.black : null,
        foregroundColor: Colors.white,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: _amoledMode ? Colors.black : null,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _amoledMode ? Colors.black : const Color(0xFF1E1E1E),
      ),
      cardColor: Color(0xFF1E1E1E),
      listTileTheme: ListTileThemeData(
        textColor: Colors.white,
        iconColor: Colors.white,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.onSurface.withOpacity(0.1),
      ),
    );
  }

  void setAmoledMode(bool value) {
    _amoledMode = value;
    _settingsBox.put('amoledMode', value);
    notifyListeners();
  }

  void setAccentColor(Color color) {
    _accentColor = color;
    _settingsBox.put('accentColor', color.value);
    notifyListeners();
  }

  void setFontFamily(String fontFamily) {
    _fontFamily = fontFamily;
    _settingsBox.put('fontFamily', fontFamily);
    notifyListeners();
  }
}
