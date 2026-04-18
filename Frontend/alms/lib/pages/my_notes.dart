import 'package:flutter/material.dart';
import 'package:alms/widgets/app_drawer.dart';
import 'package:alms/pages/uploaded_notes.dart';
import 'package:alms/pages/saved_notes.dart';

class MyNotes extends StatelessWidget {
  const MyNotes({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 138, 201, 243),
        title: const Text("My Notes"),
      ),
      drawer: const AppDrawer(),

      body: Column(
        children: const [

          SizedBox(height: 20),

          // ================= UPLOADED =================
          _MenuTile(
            title: "My Uploaded Notes",
            icon: Icons.upload_file,
            page: UploadedNotesPage(),
          ),

          Divider(),

          // ================= SAVED =================
          _MenuTile(
            title: "Saved Notes",
            icon: Icons.bookmark,
            page: SavedNotesPage(),
          ),
        ],
      ),
    );
  }
}

// ================= REUSABLE TILE =================
class _MenuTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget page;

  const _MenuTile({
    required this.title,
    required this.icon,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
    );
  }
}