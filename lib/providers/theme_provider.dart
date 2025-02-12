import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider extends ChangeNotifier {
  late Box _settingsBox;
  bool _amoledMode = false;
  Color _accentColor = Colors.blue;

  ThemeProvider() {
    _initSettings();
  }

  bool get amoledMode => _amoledMode;
  Color get accentColor => _accentColor;
  Color get effectiveColor => _accentColor;

  Future<void> _initSettings() async {
    _settingsBox = await Hive.openBox('settings');
    _amoledMode = _settingsBox.get('amoledMode', defaultValue: false);
    _accentColor = Color(_settingsBox.get('accentColor', defaultValue: Colors.blue.value));
    notifyListeners();
  }

  ThemeData getTheme(BuildContext context) {
    final isDark = true; // Always dark theme
    
    final colorScheme = ColorScheme.fromSeed(
      seedColor: effectiveColor,
      brightness: Brightness.dark,
      primary: effectiveColor,
      surface: _amoledMode ? Colors.black : null,
      background: _amoledMode ? Colors.black : const Color(0xFF0A0A0A),
      onBackground: Colors.white,
      surfaceVariant: _amoledMode ? Colors.black : Colors.black.withOpacity(0.3),
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: CardTheme(
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
        ),
        bodyMedium: TextStyle(
          color: Colors.white70,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
        ),
      ).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _amoledMode ? Colors.black : null,
        selectedItemColor: effectiveColor,
        unselectedItemColor: Colors.white60,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _amoledMode ? Colors.black : null,
        foregroundColor: Colors.white,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: colorScheme.surfaceVariant,
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
        color: colorScheme.onBackground.withOpacity(0.1),
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
}
