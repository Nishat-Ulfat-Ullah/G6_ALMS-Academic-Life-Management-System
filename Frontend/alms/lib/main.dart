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
import 'package:alms/pages/focusmode.dart';
import 'package:alms/pages/consultation_history.dart';
import 'package:alms/pages/academic_risk_prediction.dart';
import 'package:alms/pages/attendance_tracker.dart';
import 'package:alms/widgets/user_session.dart';


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
        '/homepage': (context) {
          final userId = ModalRoute.of(context)?.settings.arguments as String?;
          return HomePage(userId: userId);
        },
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
        '/focusmode': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return FocusModeScreen(userId: userId);
        },
        '/academicrisk': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return AcademicRiskScreen(userId: userId);
        },
        '/attendancetracker': (context) {
          // 1. Try to grab the argument from the navigation call
          final args = ModalRoute.of(context)?.settings.arguments;

          // 2. Check: Is it a String? If not, check UserSession. If both fail, use a fallback.
          final String userId = (args is String) 
              ? args 
              : (UserSession.userId ?? "unknown_user");

          return AttendanceTrackerScreen(userId: userId);
        },
        '/history': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String;
          return ConsultationHistory(userId: userId);
        },
      },
    );
  }
}