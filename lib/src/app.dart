import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'routes.dart';
import 'screens/splash_screen.dart';

class PathfinderApp extends StatefulWidget {
  const PathfinderApp({super.key});

  static _PathfinderAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_PathfinderAppState>();
  }

  @override
  State<PathfinderApp> createState() => _PathfinderAppState();
}

class _PathfinderAppState extends State<PathfinderApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  void toggleTheme() {
    _toggleTheme();
  }

  static ThemeData _buildTheme(bool isDark) {
    // Erdei zöld alapszín + meleg barna akcentus
    const seed = Color(0xFF2F6B3E); // mély erdei zöld
    final brightness = isDark ? Brightness.dark : Brightness.light;

    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
      useMaterial3: true,
    );

    // Finomhangolás
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF1A1A1A) // sötét háttér
          : const Color(0xFFEFF7F1), // halvány mohazöld
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E3A2F),
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF404040) : const Color(0xFFD6E4DA),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF404040) : const Color(0xFFD6E4DA),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2F6B3E) : const Color(0xFF2F6B3E),
            width: 1.4,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark
              ? const Color(0xFF855E42).withOpacity(0.9) // sötétebb barna
              : const Color(0xFF855E42), // meleg barna
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2F6B3E), // zöld CTA
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor:
            isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE7F1EA),
        labelStyle: TextStyle(
          color:
              isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF2F6B3E),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pathfinder',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(false),
      darkTheme: _buildTheme(true),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routes: appRoutes,
      initialRoute: SplashScreen.routeName,
    );
  }
}
