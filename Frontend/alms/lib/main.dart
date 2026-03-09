import 'package:flutter/material.dart';
import 'package:alms/pages/home_page.dart';
import 'package:alms/pages/first_page.dart';
import 'package:alms/pages/book_consultations.dart';
import 'package:alms/pages/my_consultations.dart';
import 'package:alms/pages/my_notes.dart';
import 'package:alms/pages/settings_page.dart';
//import 'package:alms/pages/login.dart';
import 'package:alms/pages/register.dart';
import 'package:animated_splash_screen/animated_splash_screen.dart';

void main() {
  runApp(const ALMS());
}

class ALMS extends StatelessWidget {
  const ALMS({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
      routes: {
        '/firstpage' : (context) => FirstPage(),
        '/homepage' : (context) => HomePage(),
        '/settingspage' : (context) => SettingsPage(),
        '/mynotespage' : (context) => MyNotes(),
        '/myconsultations' : (context) => MyConsultations(),
        '/bookconsultations' : (context) => BookConsultations(),
        //'/loginpage' : (context) => Loginpg(),
        '/registerpage' : (context) => RegisterPage(),
      },
      
    );
  }
}
