import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
        title: const Text('User Management'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () {}), // placeholder for create user
        ],
      ),
      body: ListView(
        children: const [
          ListTile(leading: CircleAvatar(child: Icon(Icons.person)), title: Text('admin'), subtitle: Text('Role: Manager')),
          ListTile(leading: CircleAvatar(child: Icon(Icons.person)), title: Text('cashier'), subtitle: Text('Role: Cashier')),
          ListTile(leading: CircleAvatar(child: Icon(Icons.person)), title: Text('kitchen'), subtitle: Text('Role: Kitchen')),
        ],
      ),
    );
  }
}
