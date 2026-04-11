import 'package:flutter/material.dart';
import 'package:alms/widgets/app_drawer.dart';


class MyNotes extends StatelessWidget{
  const MyNotes({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color.fromARGB(255, 138, 201, 243), title: Text("MY Notes")),
      drawer: const AppDrawer(),
    );
  }
}