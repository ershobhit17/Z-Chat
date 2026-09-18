import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/block_service.dart';
import 'services/chat_service.dart';
import 'services/follow_service.dart';
import 'services/media_storage_service.dart';
import 'services/moment_service.dart';
import 'services/post_service.dart';
import 'services/presence_service.dart';
import 'dart:ui';
import 'services/in_app_notification_manager.dart';
import 'services/youtube_service.dart';
import 'services/app_version_service.dart';
import 'theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Protect against unhandled Flutter/Platform crashes causing black screen
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Error caught: $error');
    return true; // Prevents app crash
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      color: const Color(0xFF0F1015),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.refresh_rounded, color: Colors.white70, size: 36),
          const SizedBox(height: 10),
          const Text(
            'Something went wrong. Please switch tabs to refresh.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13, decoration: TextDecoration.none),
          ),
        ],
      ),
    );
  };

  // Initialize Supabase Client
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey, // ignore: deprecated_member_use
    realtimeClientOptions: const RealtimeClientOptions(
      eventsPerSecond: 10,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => PresenceService()),
        Provider<MediaStorageService>(create: (_) => ImageKitStorageService()),
        ChangeNotifierProvider(create: (_) => PostService()),
        ChangeNotifierProvider(create: (_) => FollowService()),
        ChangeNotifierProvider(create: (_) => MomentService()),
        ChangeNotifierProvider(create: (_) => YouTubeService()),
        ChangeNotifierProvider(create: (_) => BlockService()),
      ],
      child: const ZChatApp(),
    ),
  );
}

class ZChatApp extends StatelessWidget {
  const ZChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currentTheme = themeProvider.theme;

    return MaterialApp(
      navigatorKey: InAppNotificationManager.instance.navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: currentTheme.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: currentTheme.background,
        colorScheme: ColorScheme.light(
          primary: currentTheme.primary,
          secondary: currentTheme.secondary,
          surface: currentTheme.surface,
          error: Colors.redAccent,
        ),
        textTheme: ThemeData.light().textTheme.apply(
              fontFamily: currentTheme.fontFamily.name,
              bodyColor: currentTheme.text,
              displayColor: currentTheme.text,
            ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: currentTheme.background,
        colorScheme: ColorScheme.dark(
          primary: currentTheme.primary,
          secondary: currentTheme.secondary,
          surface: currentTheme.surface,
          error: Colors.redAccent,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: currentTheme.fontFamily.name,
              bodyColor: currentTheme.text,
              displayColor: currentTheme.text,
            ),
      ),
      home: const AppVersionGate(child: AuthWrapper()),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final theme = context.watch<ThemeProvider>().theme;

    if (authService.isLoading) {
      return Scaffold(
        backgroundColor: theme.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    'Z',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: theme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.primary,
              ),
            ],
          ),
        ),
      );
    }

    if (authService.isAuthenticated) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}
