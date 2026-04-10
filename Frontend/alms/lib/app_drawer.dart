import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final String? userId;

  const AppDrawer({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            child: Icon(Icons.favorite, size: 48),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('H O M E'),
            onTap: () => Navigator.pushNamed(context, '/homepage'),
          ),
                    ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('BROWSE NOTES'),
            onTap: () => Navigator.pushNamed(context, '/browsenotes'),
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('MY NOTES'),
            onTap: () => Navigator.pushNamed(context, '/mynotespage'),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('MY CONSULTATIONS'),
            onTap: () => Navigator.pushNamed(context, '/myconsultations'),
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('BOOK CONSULTATIONS'),
            onTap: () => Navigator.pushNamed(context, '/bookconsultations'),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('S E T T I N G S'),
            onTap: () => Navigator.pushNamed(context, '/settingspage'),
          ),

        ],
      ),
    );
  }
}