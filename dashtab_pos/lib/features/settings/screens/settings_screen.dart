import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/floor'),
        ),
        title: const Text('Settings & Admin'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsTile(
            context,
            icon: Icons.analytics,
            title: 'Reports & Analytics',
            subtitle: 'View sales performance and metrics.',
            route: '/reports',
          ),
          _buildSettingsTile(
            context,
            icon: Icons.people,
            title: 'User Management',
            subtitle: 'Manage staff accounts and PINs.',
            route: '/users',
          ),
          _buildSettingsTile(
            context,
            icon: Icons.restaurant_menu,
            title: 'Menu Editor',
            subtitle: 'Add or modify categories and products.',
            route: '', // placeholder
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required String route}) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 36, color: Colors.blueGrey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          if (route.isNotEmpty) context.go(route);
        },
      ),
    );
  }
}
