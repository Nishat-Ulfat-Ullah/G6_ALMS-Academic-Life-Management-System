import 'package:flutter/material.dart';
import 'package:alms/pages/my_consultations.dart';
import 'package:alms/pages/study_dashboard_screen.dart';
import 'package:alms/pages/course_outline_page.dart'; // <-- Added this import
import 'package:alms/widgets/user_session.dart';

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
            leading: const Icon(Icons.book),
            title: const Text('MY NOTES'),
            onTap: () => Navigator.pushNamed(context, '/mynotespage'),
          ),
          ListTile(
            leading: const Icon(Icons.school), // Graduation cap icon
            title: const Text('COURSE OUTLINE'),
            onTap: () {
              if (UserSession.userId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CourseOutlinePage(),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('MY CONSULTATIONS'),
            onTap: () {
              if (UserSession.userId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MyConsultations(userId: UserSession.userId!),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('BOOK CONSULTATIONS'),
            onTap: () => Navigator.pushNamed(context, '/bookconsultations'),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('BROWSE NOTES'),
            onTap: () => Navigator.pushNamed(context, '/browsenotes'),
          ),
          
          ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('STUDY LOAD ANALYZER'),
            onTap: () {
              if (UserSession.userId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudyDashboardScreen(userId: UserSession.userId!),
                  ),
                );
              }
            },
          ),

          ListTile(
            leading: const Icon(Icons.center_focus_strong), 
            title: const Text('FOCUS MODE'),
            onTap: () {
              if (UserSession.userId != null) {
                Navigator.pushNamed(
                  context, 
                  '/focusmode', 
                  arguments: UserSession.userId!, 
                );
              }
            },
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