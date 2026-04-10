import 'package:flutter/material.dart';
import 'package:alms/app_drawer.dart';

class BookConsultations extends StatelessWidget{
  const BookConsultations({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color.fromARGB(255, 138, 201, 243), title: Text("Book Consultations")),
      drawer: const AppDrawer(),
    );
  }
}