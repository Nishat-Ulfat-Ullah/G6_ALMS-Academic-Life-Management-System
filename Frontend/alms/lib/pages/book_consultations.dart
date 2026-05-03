import 'dart:convert';
// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Added for date formatting

class BookConsultations extends StatefulWidget {
  const BookConsultations({super.key});

  @override
  State<BookConsultations> createState() => _BookConsultationsState();
}

class _BookConsultationsState extends State<BookConsultations> {
  // String get _host => Platform.isAndroid ? "10.0.2.2" : "127.0.0.1";
  String get _host => "g6-alms-academic-life-management-system.onrender.com"; 
  
  List<dynamic> courses = [];
  List<dynamic> providers = [];
  List<dynamic> availableRoutines = [];

  String? selectedCourse;
  String? selectedProvider;
  String? selectedDate; // Changed from selectedDay
  String? selectedTime;
  int? selectedRoutineId;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      // final courseRes = await http.get(Uri.parse('http://$_host:8000/api/courses'));
      // final providerRes = await http.get(Uri.parse('http://$_host:8000/api/providers'));
      final courseRes = await http.get(Uri.parse('https://$_host/api/courses'));
      final providerRes = await http.get(Uri.parse('https://$_host/api/providers'));

      if (courseRes.statusCode == 200 && providerRes.statusCode == 200) {
        setState(() {
          courses = jsonDecode(courseRes.body)['data'];
          providers = jsonDecode(providerRes.body)['data'];
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading form data: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchRoutineForProvider(String providerId) async {
    setState(() {
      selectedDate = null;
      selectedTime = null;
      selectedRoutineId = null;
      availableRoutines = [];
    });
    
    try {
      // final response = await http.get(Uri.parse('http://$_host:8000/api/routines/$providerId'));
      final response = await http.get(Uri.parse('https://$_host/api/routines/$providerId'));
      if (response.statusCode == 200) {
        setState(() {
          availableRoutines = jsonDecode(response.body)['data'];
        });
      }
    } catch (e) {
      print("Error fetching routines: $e");
    }
  }

  Future<void> _submitBooking(String studentId) async {
    if (selectedCourse == null || selectedProvider == null || selectedDate == null || selectedTime == null || selectedRoutineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    try {
      final response = await http.post(
        // Uri.parse('http://$_host:8000/book_consultation'),
        Uri.parse('https://$_host/book_consultation'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "student_id": studentId,
          "provider_id": selectedProvider,
          "course_name": selectedCourse,
          "con_date": selectedDate, // Changed from day_of_week
          "time_slot": selectedTime,
          "routine_id": selectedRoutineId, 
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent!')));
          
          Navigator.pop(context, true); 
          
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${data['error']}')));
        }
      }
    } catch (e) {
      print("Error booking: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentId = ModalRoute.of(context)?.settings.arguments as String? ?? "Unknown";

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB3EAFF),
        title: const Text(
          'Request Consultations',
          style: TextStyle(color: Colors.black, fontFamily: 'Gabarito'),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 4,
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFD9F5FF),
                border: Border.all(width: 2, color: Colors.black),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(2, 6))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Course:'),
                  _buildDropdown(
                    value: selectedCourse,
                    items: courses.map((c) => DropdownMenuItem(
                      value: c['course_name'].toString(),
                      child: Text("${c['course_code']}: ${c['course_name']}"),
                    )).toList(),
                    onChanged: (val) => setState(() => selectedCourse = val as String),
                    hint: 'Select Course',
                  ),
                  const SizedBox(height: 16),
                  
                  _buildLabel('Faculty/Student Tutor:'),
                  _buildDropdown(
                    value: selectedProvider,
                    items: providers.map((p) => DropdownMenuItem(
                      value: p['provider_id'].toString(),
                      child: Text(p['provider_id'].toString()),
                    )).toList(),
                    onChanged: (val) {
                      setState(() => selectedProvider = val as String);
                      _fetchRoutineForProvider(selectedProvider!);
                    },
                    hint: 'Select Provider',
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Date:'), // Changed text
                  _buildDropdown(
                    value: selectedDate,
                    // Now parsing con_date and formatting it nicely for the user
                    items: availableRoutines.map((r) => r['con_date'].toString()).toSet().map((dateStr) {
                      DateTime parsedDate = DateTime.parse(dateStr);
                      String displayDate = DateFormat('MMMM d, yyyy').format(parsedDate);
                      return DropdownMenuItem(
                        value: dateStr,
                        child: Text(displayDate),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedDate = val as String;
                        selectedTime = null; 
                        selectedRoutineId = null;
                      });
                    },
                    hint: selectedProvider == null ? 'Select Provider first' : 'Select Date',
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Time:'),
                  _buildDropdown(
                    value: selectedTime,
                    // Filter times based on selected con_date
                    items: availableRoutines.where((r) => r['con_date'] == selectedDate).map((r) => DropdownMenuItem(
                      value: r['time_slot'].toString(),
                      child: Text(r['time_slot'].toString()),
                    )).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedTime = val as String;
                        // Find the routine_id matching the specific date and time
                        final routine = availableRoutines.firstWhere(
                          (r) => r['con_date'] == selectedDate && r['time_slot'] == selectedTime
                        );
                        selectedRoutineId = routine['routine_id'];
                      });
                    },
                    hint: selectedDate == null ? 'Select Date first' : 'Select Time',
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9EFFD2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                          side: const BorderSide(color: Colors.black),
                        ),
                      ),
                      onPressed: () => _submitBooking(studentId),
                      child: const Text('Confirm Request', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB6B7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                          side: const BorderSide(color: Colors.black),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel Request', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontFamily: 'Gabarito', fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildDropdown({required String? value, required List<DropdownMenuItem<String>> items, required Function(dynamic) onChanged, required String hint}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF9FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}