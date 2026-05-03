import 'dart:convert';
// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class ExamCountdownPage extends StatefulWidget {
  final String userId;

  const ExamCountdownPage({super.key, required this.userId});

  @override
  State<ExamCountdownPage> createState() => _ExamCountdownPageState();
}

class _ExamCountdownPageState extends State<ExamCountdownPage> {
  List<dynamic> exams = [];
  bool isLoading = true;
  // String get _host => Platform.isAndroid ? "10.0.2.2" : "127.0.0.1";
  String get _host => "g6-alms-academic-life-management-system.onrender.com";

  // Setup Google Sign In with Calendar scopes
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [calendar.CalendarApi.calendarEventsScope],
  );

  @override
  void initState() {
    super.initState();
    _fetchExams();
  }

  Future<void> _fetchExams() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('http://$_host:8000/api/exams/${widget.userId}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            exams = data['data'];
          });
        }
      }
    } catch (e) {
      print("Error fetching exams: $e");
    }
    setState(() => isLoading = false);
  }

  Future<void> _deleteExam(int id) async {
    try {
      final response = await http.delete(Uri.parse('http://$_host:8000/api/exams/delete/$id'));
      if (response.statusCode == 200) {
        _fetchExams(); // Refresh list
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Countdown deleted!')));
      }
    } catch (e) {
      print("Error deleting: $e");
    }
  }

  // --- GOOGLE CALENDAR LOGIC ---
  Future<String?> _addToGoogleCalendar(String title, String type, DateTime date) async {
    try {
      // 1. Sign the user in
      var account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();
      
      if (account == null) return null; // User cancelled login

      // 2. Get the authenticated HTTP client
      var httpClient = (await _googleSignIn.authenticatedClient())!;
      
      // 3. Initialize Calendar API
      var calendarApi = calendar.CalendarApi(httpClient);

      // 4. Create the Event
      var event = calendar.Event(
        summary: '$title ($type)',
        description: 'Exam Countdown Reminder',
        start: calendar.EventDateTime(
          date: date, 
          timeZone: "Asia/Dhaka", // Change to your timezone
        ),
        end: calendar.EventDateTime(
          date: date.add(const Duration(days: 1)), // All day event
          timeZone: "Asia/Dhaka",
        ),
        reminders: calendar.EventReminders(
          useDefault: false,
          overrides: [
            calendar.EventReminder(method: 'popup', minutes: 24 * 60), // 1 day before reminder
          ],
        ),
      );

      // 5. Insert into their primary calendar
      var insertedEvent = await calendarApi.events.insert(event, "primary");
      return insertedEvent.id; // Return the Google event ID to store in our DB
      
    } catch (e) {
      print("Google Calendar Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Calendar Error: $e')));
      return null;
    }
  }

  // --- ADD EXAM DIALOG ---
  void _showAddDialog() {
    TextEditingController titleController = TextEditingController();
    String? selectedType = 'Midterm';
    DateTime? selectedDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("New Exam Countdown", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Course / Exam Title'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Exam Type'),
                    items: ['Quiz', 'Midterm', 'Final', 'Lab-Mid'].map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedType = val),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Date: ${DateFormat('MMM d, yyyy').format(selectedDate!)}",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today, color: Colors.blue),
                        onPressed: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate!,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                      )
                    ],
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isEmpty) return;
                  
                  // 1. Close dialog and show loading indicator (optional but good practice)
                  Navigator.pop(context);
                  setState(() => isLoading = true);

                  // 2. Add to Google Calendar first
                  String? eventId = await _addToGoogleCalendar(
                    titleController.text, 
                    selectedType!, 
                    selectedDate!
                  );

                  // 3. Save to our FastAPI backend
                  final response = await http.post(
                    Uri.parse('http://$_host:8000/api/exams/add'),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({
                      "user_id": widget.userId,
                      "title": titleController.text,
                      "exam_type": selectedType,
                      "exam_date": DateFormat('yyyy-MM-dd').format(selectedDate!),
                      "calendar_event_id": eventId, 
                    }),
                  );

                  if (response.statusCode == 200) {
                    _fetchExams();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Countdown added to App & Calendar!')));
                  }
                },
                child: const Text("Save & Add to Calendar"),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB3EAFF),
        title: const Text("EXAM COUNTDOWNS", style: TextStyle(color: Colors.black)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF9EFFD2),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text("Add Exam", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Image.asset('assets/bg.png', fit: BoxFit.cover),
            ),
          ),
          isLoading 
            ? const Center(child: CircularProgressIndicator())
            : exams.isEmpty
              ? const Center(child: Text("No exams approaching! Relax ☕", style: TextStyle(fontSize: 18)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: exams.length,
                  itemBuilder: (context, index) {
                    final exam = exams[index];
                    final dateFormatted = DateFormat('MMMM d, yyyy').format(DateTime.parse(exam['exam_date']));
                    
                    return Card(
                      color: const Color(0xFFD9F5FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.black, width: 1),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          "${exam['title']} (${exam['exam_type']})", 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                        ),
                        subtitle: Text("Date: $dateFormatted\nDays Left: ${exam['days_left']}", style: const TextStyle(fontSize: 15)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteExam(exam['id']),
                        ),
                      ),
                    );
                  },
                )
        ],
      ),
    );
  }
}