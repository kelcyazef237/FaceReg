import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:face_reg_app/services/auth_provider.dart';
import 'package:face_reg_app/screens/auth/face_id_screen.dart';
import 'package:face_reg_app/screens/auth/register_screen.dart';
import 'package:face_reg_app/screens/settings/settings_screen.dart';

/// Login screen — user enters their name, then is taken to automatic Face ID scan.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  static const route = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onProceed() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    // Navigate to Face ID auto-scan
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FaceIdScreen(name: name, isReauth: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        centerTitle: true,
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(16),
              Text(
                'Welcome back 👋',
                style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Gap(4),
              Text(
                'Enter your name to verify with your face.',
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(140),
                    ),
              ),
              const Gap(32),
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0),
                  child: child,
                ),
                child: TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _onProceed(),
                ),
              ),
              const Gap(8),
              if (auth.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: theme.colorScheme.error.withAlpha(100)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: theme.colorScheme.error, size: 18),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          auth.error!,
                          style: TextStyle(
                              color: theme.colorScheme.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const Gap(24),
              _FaceScanButton(onPressed: _onProceed),
              const Gap(16),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, RegisterScreen.route),
                  child: const Text("Don't have an account? Register"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaceScanButton extends StatelessWidget {
  const _FaceScanButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.primary.withBlue(220)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withAlpha(90),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.face_unlock_rounded,
                color: Colors.white, size: 22),
            const Gap(10),
            Text(
              'Scan Face to Sign In',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
