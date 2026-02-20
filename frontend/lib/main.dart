import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:face_reg_app/services/auth_provider.dart';
import 'package:face_reg_app/services/settings_service.dart';
import 'package:face_reg_app/screens/auth/onboarding_screen.dart';
import 'package:face_reg_app/screens/auth/login_screen.dart';
import 'package:face_reg_app/screens/auth/register_screen.dart';
import 'package:face_reg_app/screens/auth/face_id_screen.dart';
import 'package:face_reg_app/screens/home/home_screen.dart';
import 'package:face_reg_app/screens/settings/settings_screen.dart';
import 'package:face_reg_app/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.load();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..checkAuth(),
      child: const FaceRegApp(),
    ),
  );
}

class FaceRegApp extends StatelessWidget {
  const FaceRegApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FaceReg',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routes: {
        OnboardingScreen.route: (_) => const OnboardingScreen(),
        RegisterScreen.route: (_) => const RegisterScreen(),
        LoginScreen.route: (_) => const LoginScreen(),
        HomeScreen.route: (_) => const HomeScreen(),
        SettingsScreen.route: (_) => const SettingsScreen(),
      },
      home: const _Splash(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: switch (auth.status) {
        AuthStatus.unknown => const _SplashScreen(),
        AuthStatus.authenticated => const HomeScreen(),
        AuthStatus.needsReauth => FaceIdScreen(
            name: auth.savedName!,
            isReauth: true,
          ),
        AuthStatus.unauthenticated => const OnboardingScreen(),
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.face_retouching_natural_rounded, size: 72, color: cs.primary),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: cs.primary, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}
