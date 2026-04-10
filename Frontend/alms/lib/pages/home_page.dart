import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final String? studentId;

  const HomePage({super.key, this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 138, 201, 243),
        title: Text("Home Page"),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              child: Icon(
                Icons.favorite,
                size: 48,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('H O M E'),
              onTap: () {
                Navigator.pushNamed(context, '/homepage');
              },
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('MY NOTES'),
              onTap: () {
                Navigator.pushNamed(context, '/mynotespage');
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('MY CONSULTATIONS'),
              onTap: () {
                Navigator.pushNamed(context, '/myconsultations');
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('BOOK CONSULTATIONS'),
              onTap: () {
                Navigator.pushNamed(context, '/bookconsultations');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('S E T T I N G S'),
              onTap: () {
                Navigator.pushNamed(context, '/settingspage');
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Text(
          studentId != null
              ? 'Welcome, $studentId'
              : 'Welcome to Home Page',
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}