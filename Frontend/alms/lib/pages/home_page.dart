import 'package:flutter/material.dart';
import 'package:alms/widgets/app_drawer.dart';
import 'package:alms/widgets/user_session.dart';

class HomePage extends StatelessWidget {
  final String? userId;

  const HomePage({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    print("HomePage userId: $userId");
    return Scaffold(
   
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 138, 201, 243),
        title: Text("Home Page"),
      ),
      drawer: AppDrawer(),
      body: Center(
        child: Text(
          userId != null
              ? 'Welcome, $userId'
              : 'Welcome to Home Page',
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}