import 'package:flutter/material.dart';

class ThemeSwitcher extends StatelessWidget {
  final Widget child;
  final ThemeMode themeMode;

  const ThemeSwitcher({
    super.key,
    required this.child,
    required this.themeMode,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedTheme(
      data: themeMode == ThemeMode.dark
          ? ThemeData(
              colorScheme: ColorScheme.dark(
                primary: const Color(0xFF2AABEE),
                secondary: Colors.blueAccent,
                surface: const Color(0xFF1E1E1E),
                background: const Color(0xFF121212),
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onSurface: Colors.white,
                onBackground: Colors.white,
              ),
              scaffoldBackgroundColor: const Color(0xFF121212),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              cardColor: const Color(0xFF1E1E1E),
              dividerColor: Colors.white24,
              textTheme: Typography.material2021().white,
              iconTheme: const IconThemeData(color: Colors.white),
              listTileTheme: const ListTileThemeData(
                tileColor: Color(0xFF1E1E1E),
                textColor: Colors.white,
                iconColor: Colors.white,
              ),
              dialogTheme: const DialogTheme(
                backgroundColor: Color(0xFF1E1E1E),
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
                contentTextStyle: TextStyle(color: Colors.white70),
              ),
              bottomSheetTheme: const BottomSheetThemeData(
                backgroundColor: Color(0xFF1E1E1E),
              ),
              useMaterial3: true,
            )
          : ThemeData(
              colorScheme: ColorScheme.light(
                primary: const Color(0xFF2AABEE),
                secondary: Colors.blueAccent,
                surface: Colors.white,
                background: const Color(0xFFF5F5F5),
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onSurface: Colors.black,
                onBackground: Colors.black,
              ),
              scaffoldBackgroundColor: const Color(0xFFF5F5F5),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
              cardColor: Colors.white,
              dividerColor: Colors.black12,
              textTheme: Typography.material2021().black,
              iconTheme: const IconThemeData(color: Colors.black),
              listTileTheme: const ListTileThemeData(
                tileColor: Colors.white,
                textColor: Colors.black,
                iconColor: Colors.black,
              ),
              dialogTheme: const DialogTheme(
                backgroundColor: Colors.white,
                titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
                contentTextStyle: TextStyle(color: Colors.black87),
              ),
              bottomSheetTheme: const BottomSheetThemeData(
                backgroundColor: Colors.white,
              ),
              useMaterial3: true,
            ),
      duration: const Duration(milliseconds: 300),
      child: child,
    );
  }
} 