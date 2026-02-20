import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:face_reg_app/services/auth_provider.dart';
import 'package:face_reg_app/screens/auth/onboarding_screen.dart';
import 'package:face_reg_app/screens/settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  static const route = '/home';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            automaticallyImplyLeading: false,
            backgroundColor: cs.surface,
            title: const Text('FaceReg'),
            leading: IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: 'Settings',
              onPressed: () =>
                  Navigator.pushNamed(context, SettingsScreen.route),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Sign out',
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(
                        context, OnboardingScreen.route);
                  }
                },
              ),
              const Gap(8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ProfileCard(user: user),
                const Gap(20),
                _StatusCard(faceEnrolled: user?.faceEnrolled ?? false),
                const Gap(20),
                Text(
                  'How it works',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Gap(12),
                const _InfoRow(
                  icon: Icons.face_retouching_natural_rounded,
                  title: 'SFace Embeddings',
                  subtitle: '128-d vector — fast and accurate face matching',
                ),
                const Gap(8),
                const _InfoRow(
                  icon: Icons.visibility_rounded,
                  title: 'Liveness Detection',
                  subtitle: 'Motion analysis blocks photo/screen replay',
                ),
                const Gap(8),
                const _InfoRow(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Adaptive Updates',
                  subtitle: 'Embedding improves with each successful login',
                ),
                const Gap(8),
                const _InfoRow(
                  icon: Icons.lock_rounded,
                  title: 'JWT Tokens',
                  subtitle: 'Short-lived access + long-lived refresh, stored securely',
                ),
                const Gap(40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = user?.name ?? '—';
    final phone = user?.phoneNumber ?? '';
    final initials = name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withAlpha(217),
            cs.primary.withBlue(200).withAlpha(190),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withAlpha(77),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                Text(
                  phone,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const Gap(4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '✓ Authenticated',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.faceEnrolled});
  final bool faceEnrolled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              faceEnrolled
                  ? Icons.verified_user_rounded
                  : Icons.warning_amber_rounded,
              color: faceEnrolled ? Colors.greenAccent : Colors.orangeAccent,
              size: 28,
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    faceEnrolled ? 'Face Enrolled' : 'Face Not Enrolled',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    faceEnrolled
                        ? 'Your face is registered. Re-authentication is automatic.'
                        : 'Face enrollment required.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(140)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: cs.primary, size: 18),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withAlpha(140))),
            ],
          ),
        ),
      ],
    );
  }
}
