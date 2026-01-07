import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:toastification/toastification.dart';
import 'services/supabase_service.dart';

import 'providers/navigation_provider.dart';
import 'providers/auth_provider.dart';
import 'services/locale_service.dart';
import 'screens/main_layout.dart';
import 'screens/mobile/mobile_main_screen.dart';
import 'screens/login_screen.dart';
import 'utils/app_theme.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService.initialize();

  // Initialize Locale Service
  final localeService = LocaleService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => localeService),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeService = Provider.of<LocaleService>(context);

    return MaterialApp(
      title: 'Samsat Palu Inventory',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      // Locale Config
      locale: localeService.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('id'), // Indonesian
      ],

      builder: (context, child) {
        return ToastificationWrapper(child: child!);
      },
      home: const PlatformShell(),
    );
  }
}

class PlatformShell extends StatelessWidget {
  const PlatformShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Show loading while checking auth status
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Show login screen if not authenticated
        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }

        // Show main app based on screen size
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return const MobileMainScreen();
            }
            return const MainLayout();
          },
        );
      },
    );
  }
}
