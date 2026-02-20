import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:face_reg_app/services/settings_service.dart';
import 'package:face_reg_app/services/api_service.dart';
import 'package:face_reg_app/services/auth_provider.dart';
import 'package:face_reg_app/screens/auth/onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  static const route = '/settings';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _ipCtrl;
  late final TextEditingController _portCtrl;
  bool _saving = false;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _ipCtrl = TextEditingController(text: SettingsService.serverIp);
    _portCtrl = TextEditingController(text: SettingsService.serverPort.toString());
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveServer() async {
    final ip = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim());
    if (ip.isEmpty || port == null || port < 1 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid IP or port')),
      );
      return;
    }
    setState(() => _saving = true);
    await SettingsService.save(ip, port);
    ApiService.instance.updateBaseUrl();
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server settings saved')),
      );
    }
  }

  Future<void> _clearDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear database?'),
        content: const Text(
          'This will delete ALL registered users and face data. Cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearing = true);
    // Capture context-dependent references before async gaps
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await ApiService.instance.clearDatabase();
      await auth.logout();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Database cleared')),
        );
        nav.pushNamedAndRemoveUntil(
          OnboardingScreen.route,
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.toString().split('\n').first}')),
        );
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // ── Server ────────────────────────────────────────────────────────
          Text(
            'SERVER',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.primary,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _ipCtrl,
                    decoration: const InputDecoration(
                      labelText: 'IP Address',
                      hintText: '10.83.204.137',
                      prefixIcon: Icon(Icons.dns_rounded),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const Gap(12),
                  TextField(
                    controller: _portCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '8000',
                      prefixIcon: Icon(Icons.settings_ethernet_rounded),
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveServer(),
                  ),
                  const Gap(16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveServer,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(28),

          // ── Data ──────────────────────────────────────────────────────────
          Text(
            'DATA',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.primary,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(10),
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.redAccent,
                ),
              ),
              title: const Text('Clear Database'),
              subtitle: const Text('Delete all users and face data'),
              trailing: _clearing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: _clearing ? null : _clearDatabase,
            ),
          ),
        ],
      ),
    );
  }
}
