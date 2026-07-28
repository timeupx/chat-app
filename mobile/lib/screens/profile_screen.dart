import 'package:flutter/material.dart';

import '../theme/bigo_theme.dart';
import '../utils/jwt_helper.dart';
import '../utils/secure_storage_helper.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'User';
  String _email = '';
  String _username = 'user';

  @override
  void initState() {
    super.initState();
    _loadProfileFromToken();
  }

  Future<void> _loadProfileFromToken() async {
    final token = await SecureStorageHelper.getToken();
    if (token == null) return;

    final payload = decodeJwtPayload(token);
    if (payload == null || !mounted) return;

    final email = payload['email'] as String? ?? '';
    setState(() {
      _name = payload['name'] as String? ?? 'User';
      _email = email;
      _username = email.contains('@') ? email.split('@').first : _name;
    });
  }

  Future<void> _handleLogout() async {
    await SecureStorageHelper.deleteToken();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BigoColors.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: BigoColors.appGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              const Text(
                'Me',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: BigoColors.ctaGradient,
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: BigoColors.primaryDeep,
                    child: Text(
                      _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@$_username',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 4),
              Text(
                _email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ProfileStat(label: 'Beans', value: '0'),
                    _ProfileStat(label: 'Fans', value: '0'),
                    _ProfileStat(label: 'Following', value: '0'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _menuCard([
                _MenuItem(
                  icon: Icons.edit_outlined,
                  title: 'Edit Profile',
                  onTap: () => _showComingSoon('Edit Profile'),
                ),
                _MenuItem(
                  icon: Icons.workspace_premium_outlined,
                  title: 'VIP / SVIP',
                  onTap: () => _showComingSoon('VIP'),
                ),
                _MenuItem(
                  icon: Icons.card_giftcard_outlined,
                  title: 'My Wallet',
                  onTap: () => _showComingSoon('Wallet'),
                ),
                _MenuItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => _showComingSoon('Settings'),
                ),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout, color: BigoColors.hot),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      color: BigoColors.hot,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: BigoColors.hot),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuCard(List<_MenuItem> items) {
    // Material (not a bare colored Container) so ListTile ink/splash paint
    // correctly — otherwise Flutter asserts "ink splashes may be invisible".
    return Material(
      color: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            ListTile(
              leading: Icon(items[i].icon, color: BigoColors.accent),
              title: Text(
                items[i].title,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: items[i].onTap,
            ),
            if (i < items.length - 1)
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
