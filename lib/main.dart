import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/theme_provider.dart';
import 'widgets/theme_switcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyCClQslo0S6qgGk8Eoz1ukYaah2coNHghA',
      appId: '107851080483',
      messagingSenderId: '107851080483',
      projectId: 'l1nia-9eb87',
    ),
  );

  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().themeMode;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Чат',
      themeMode: themeMode,
      home: ThemeSwitcher(
        themeMode: themeMode,
        child: Consumer<AuthService>(
          builder: (context, authService, _) {
            if (authService.currentUser != null) {
              return const HomeScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
