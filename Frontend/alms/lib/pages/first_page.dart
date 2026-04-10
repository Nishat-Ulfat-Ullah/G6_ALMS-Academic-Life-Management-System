import 'package:flutter/material.dart';
import 'package:alms/app_drawer.dart';

class FirstPage extends StatelessWidget{
  const FirstPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color.fromARGB(255, 138, 201, 243), title: Text("First Page")),
      drawer: AppDrawer(),
    );
  }
}