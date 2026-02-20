import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:face_reg_app/services/auth_provider.dart';
import 'package:face_reg_app/widgets/face_capture/face_capture_widget.dart';
import 'package:face_reg_app/screens/auth/login_screen.dart';
import 'package:face_reg_app/screens/home/home_screen.dart';
import 'package:face_reg_app/screens/settings/settings_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  static const route = '/register';

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _step2 = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _goToFaceCapture() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _step2 = true);
  }

  Future<void> _onFaceCaptured(List<File> frames, AuthProvider auth) async {
    final ok = await auth.registerWithFace(
      name: _nameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      image: frames.first,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, HomeScreen.route);
    }
    // On failure auth.error is set, which the UI shows
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_step2 ? 'Scan Your Face' : 'Create Account'),
        centerTitle: true,
        actions: [
          if (!_step2) ...[
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: 'Settings',
              onPressed: () =>
                  Navigator.pushNamed(context, SettingsScreen.route),
            ),
            const Gap(4),
          ],
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: _step2 ? _buildFaceStep(auth) : _buildFormStep(auth),
        ),
      ),
    );
  }

  Widget _buildFormStep(AuthProvider auth) => SingleChildScrollView(
        key: const ValueKey('form'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome 👋',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Gap(4),
              Text(
                'Enter your details, then scan your face to register.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(140),
                    ),
              ),
              const Gap(28),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Min 2 characters' : null,
              ),
              const Gap(14),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 6) ? 'Enter a valid number' : null,
              ),
              const Gap(8),
              if (auth.error != null) _ErrorBanner(auth.error!),
              const Gap(20),
              ElevatedButton(
                onPressed: auth.loading ? null : _goToFaceCapture,
                child: auth.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Continue →'),
              ),
              const Gap(20),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, LoginScreen.route),
                  child: const Text('Already have an account? Sign in'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildFaceStep(AuthProvider auth) => Padding(
        key: const ValueKey('face'),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (auth.error != null) ...[
              _ErrorBanner(auth.error!),
              const Gap(12),
            ],
            Expanded(
              child: FaceCaptureWidget(
                mode: CaptureMode.enroll,
                onCaptureDone: (frames) => _onFaceCaptured(frames, auth),
                onCancel: () => setState(() => _step2 = false),
              ),
            ),
            if (auth.loading) ...[
              const Gap(12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Theme.of(context).colorScheme.error.withAlpha(100)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error, size: 18),
            const Gap(8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 13),
              ),
            ),
          ],
        ),
      );
}
