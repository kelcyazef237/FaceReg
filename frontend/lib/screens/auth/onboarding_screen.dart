import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:face_reg_app/screens/auth/register_screen.dart';
import 'package:face_reg_app/screens/auth/login_screen.dart';
import 'package:face_reg_app/screens/settings/settings_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  static const route = '/onboarding';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeIn = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slideUp = Tween(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () =>
                Navigator.pushNamed(context, SettingsScreen.route),
          ),
          const Gap(4),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          cs.primary.withAlpha(64),
                          cs.primary.withAlpha(13),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.face_retouching_natural_rounded,
                      size: 100,
                      color: cs.primary,
                    ),
                  ),
                  const Gap(32),
                  Text(
                    'FaceReg',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Gap(12),
                  Text(
                    'Secure facial authentication.\nNo passwords. No compromises.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(153),
                      height: 1.5,
                    ),
                  ),
                  const Spacer(flex: 3),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: const [
                      _FeatureChip(icon: Icons.security, label: 'Liveness Detection'),
                      _FeatureChip(icon: Icons.bolt, label: 'Instant Login'),
                      _FeatureChip(icon: Icons.auto_awesome, label: 'Adaptive AI'),
                    ],
                  ),
                  const Spacer(flex: 2),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, RegisterScreen.route),
                    child: const Text('Create Account'),
                  ),
                  const Gap(12),
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, LoginScreen.route),
                    child: const Text('Sign In'),
                  ),
                  const Gap(32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withAlpha(64)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: cs.primary),
          const Gap(6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
