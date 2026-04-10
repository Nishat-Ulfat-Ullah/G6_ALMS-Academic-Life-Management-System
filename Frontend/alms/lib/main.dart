import 'package:flutter/material.dart';
import 'package:alms/pages/home_page.dart';
import 'package:alms/pages/first_page.dart';
import 'package:alms/pages/book_consultations.dart';
import 'package:alms/pages/my_consultations.dart';
import 'package:alms/pages/my_notes.dart';
import 'package:alms/pages/settings_page.dart';
import 'package:alms/pages/set_consultations.dart';
import 'package:alms/pages/login.dart';
import 'package:alms/pages/register.dart';
import 'package:alms/pages/browse_page.dart';

void main() {
  runApp(const ALMS());
}

class ALMS extends StatelessWidget {
  const ALMS({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/loginpage',
      routes: {
        '/firstpage' : (context) => FirstPage(),
        '/homepage' : (context) => HomePage(),
        '/settingspage' : (context) => SettingsPage(),
        '/browsenotes': (context) => const BrowseNotes(),
        '/mynotespage' : (context) => MyNotes(),
        '/myconsultations': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return MyConsultations(userId: userId);
        },
        '/bookconsultations' : (context) => BookConsultations(),
        '/set_consultations': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return SetConsultations(currentUserID: userId);
        },
        '/loginpage' : (context) => Loginpg(),
        '/registerpage' : (context) => RegisterPage(),
      },
    );
  }
}