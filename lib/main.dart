import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const BookLoggerApp());
}

class BookLoggerApp extends StatefulWidget {
  const BookLoggerApp({super.key});

  @override
  State<BookLoggerApp> createState() => _BookLoggerAppState();
}

class _BookLoggerAppState extends State<BookLoggerApp> {
  ShelfdTheme _theme = ShelfdTheme.defaultTheme;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  String _themeKey(String uid) => 'shelfd_theme_$uid';

  Future<void> _loadTheme() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _theme = ShelfdTheme.defaultTheme);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeKey(user.uid));
    if (mounted) {
      final t = saved != null
          ? ShelfdTheme.values.firstWhere(
              (v) => v.name == saved,
              orElse: () => ShelfdTheme.defaultTheme,
            )
          : ShelfdTheme.defaultTheme;
      setState(() => _theme = t);
    }
  }

  void _onAuthChanged(User? user) {
    if (user == null) {
      if (mounted) setState(() => _theme = ShelfdTheme.defaultTheme);
    } else {
      _loadTheme();
    }
  }

  void _onThemeChanged(ShelfdTheme t) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey(user.uid), t.name);
    }
    if (mounted) setState(() => _theme = t);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeData.colorsFor(_theme);
    return ShelfdThemeScope(
      theme: _theme,
      colors: colors,
      onThemeChanged: _onThemeChanged,
      child: MaterialApp(
        title: 'Book Logger',
        debugShowCheckedModeBanner: false,
        theme: AppThemeData.themeDataFor(_theme),
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // Login / register screens must always render with the default
            // theme so that a user's theme choice does not bleed into the
            // pre-auth flow.
            final defaultThemeData =
                AppThemeData.themeDataFor(ShelfdTheme.defaultTheme);

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Theme(
                data: defaultThemeData,
                child: const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (snapshot.hasData) {
              return const MainNavigationScreen();
            }
            return Theme(
              data: defaultThemeData,
              child: const LoginScreen(),
            );
          },
        ),
      ),
    );
  }
}
