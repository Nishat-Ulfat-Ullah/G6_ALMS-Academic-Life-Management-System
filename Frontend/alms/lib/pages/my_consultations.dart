import 'dart:convert';
// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; 
import 'package:alms/widgets/app_drawer.dart';
import 'package:alms/services/notification_service.dart';

class MyConsultations extends StatefulWidget {
  final String userId;

  const MyConsultations({super.key, required this.userId});

  @override
  State<MyConsultations> createState() => _MyConsultationsState();
}

class _MyConsultationsState extends State<MyConsultations> {
  String userRole = "student"; 
  List<dynamic> consultations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // String get _host => Platform.isAndroid ? "10.0.2.2" : "127.0.0.1";
  String get _host => "g6-alms-academic-life-management-system.onrender.com";

  Future<void> _fetchData() async {
    try {
      final roleResponse = await http.get(Uri.parse('http://$_host:8000/role/${widget.userId}'));
      if (roleResponse.statusCode == 200) {
        final roleData = jsonDecode(roleResponse.body);
        if (roleData['success'] == true) {
          userRole = roleData['role'];
        }
      }

      final consResponse = await http.get(Uri.parse('http://$_host:8000/my_consultations/${widget.userId}?role=$userRole'));
      if (consResponse.statusCode == 200) {
        final consData = jsonDecode(consResponse.body);
        if (consData['success'] == true) {
          setState(() {
            consultations = consData['data'];
            isLoading = false;
          });
          
          // ADDED: Schedule the reminders right after fetching the data!
          scheduleAllReminders(consultations);
          
          return;
        }
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
    
    setState(() => isLoading = false);
  }

  Future<void> _updateStatus(int bookingId, String newStatus, [String? summaryText]) async {
    try {
      final response = await http.post(
        Uri.parse('http://$_host:8000/update_consultation_status'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "booking_id": bookingId,
          "status": newStatus,
          "summary": summaryText, 
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (newStatus == 'Rejected') {
            setState(() {
              consultations.removeWhere((c) => c['booking_id'].toString() == bookingId.toString());
            });
          } else {
            _fetchData();
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Consultation $newStatus')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${data['error']}')));
        }
      }
    } catch (e) {
      print("Error updating status: $e");
    }
  }

  DateTime combineDateAndTime(String dateStr, String timeStr) {
    List<String> dateParts = dateStr.split('-');
    int year = int.parse(dateParts[0]);
    int month = int.parse(dateParts[1]);
    int day = int.parse(dateParts[2]);

    List<String> timeParts = timeStr.split(' '); 
    List<String> hm = timeParts[0].split(':');   
    
    int hour = int.parse(hm[0]);
    int minute = int.parse(hm[1]);
    String ampm = timeParts[1].toUpperCase();

    if (ampm == 'PM' && hour != 12) {
      hour += 12;
    } else if (ampm == 'AM' && hour == 12) {
      hour = 0;
    }

    return DateTime(year, month, day, hour, minute);
  }

  void scheduleAllReminders(List<dynamic> bookingsData) {
    for (var booking in bookingsData) {
      if (booking['status'] == 'Accepted' || booking['status'] == 'Pending') {
        if (booking['con_date'] != null && booking['time_slot'] != null) {
          try {
            String dateStr = booking['con_date'].toString(); 
            String timeStr = booking['time_slot'].toString(); 
            
            DateTime exactTime = combineDateAndTime(dateStr, timeStr);
            
            NotificationService().scheduleConsultationReminder(
              id: int.parse(booking['booking_id'].toString()), 
              courseName: booking['course_name'] ?? 'your course',
              consultationTime: exactTime,
            );
          } catch (e) {
            print("Error scheduling notification for booking ${booking['booking_id']}: $e");
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 138, 201, 243),
        title: const Text("MY CONSULTATIONS"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (String value) {
                if (value == 'profile') {
                  print('View Profile Clicked');
                } else if (value == 'settings') {
                  Navigator.pushNamed(context, '/settingspage', arguments: widget.userId);
                } else if (value == 'logout') {
                  Navigator.pushNamed(context, '/loginpage');
                  print('Logout Clicked');
                }
              },
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                backgroundImage: AssetImage('assets/tdp.png'),
              ),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, color: Colors.black, size: 20),
                      SizedBox(width: 12),
                      Text('View profile'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, color: Colors.black, size: 20),
                      SizedBox(width: 12),
                      Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red, size: 20),
                      SizedBox(width: 12),
                      Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(), 
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Image.asset('assets/bg.png', fit: BoxFit.cover),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                children: [
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : consultations.isEmpty
                            ? const Center(
                                child: Text(
                                  "No consultations found.",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                ),
                              )
                            : ListView.separated(
                                itemCount: consultations.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final item = consultations[index];
                                  return ConsultationCard(
                                    data: item,
                                    userRole: userRole,
                                    onUpdateStatus: _updateStatus,
                                  );
                                },
                              ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  CustomActionButton(
                    text: (userRole == 'faculty' || userRole == 'tutor')
                        ? 'Set Consultations'
                        : 'Book Consultations',
                    onTap: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        (userRole == 'faculty' || userRole == 'tutor')
                            ? '/set_consultations'
                            : '/bookconsultations',
                        arguments: widget.userId,
                      );
                      
                      if (result == true) {
                        setState(() {
                          isLoading = true; 
                        });
                        _fetchData(); 
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomActionButton(
                    text: 'View History',
                    onTap: () {
                      Navigator.pushNamed(context, '/history', arguments: widget.userId);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConsultationCard extends StatelessWidget {
  final Map<dynamic, dynamic> data;
  final String userRole;
  final Function(int, String, [String?]) onUpdateStatus;

  const ConsultationCard({
    super.key,
    required this.data,
    required this.userRole,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    String currentStatus = data['status'];
    bool isPending = currentStatus == 'Pending';
    bool isAccepted = currentStatus == 'Accepted';
    
    Color statusColor;
    if (isPending) {
      statusColor = Colors.pinkAccent; 
    } else if (isAccepted) {
      statusColor = const Color(0xFF00BFA5); 
    } else {
      statusColor = Colors.blue.shade700; 
    }

    String personLabel = userRole == 'student' ? 'Faculty' : 'Student';
    String personName = userRole == 'student' ? data['provider_id'] : data['student_id'];

    String displayDate = 'Unknown Date';
    if (data['con_date'] != null) {
      try {
        DateTime parsedDate = DateTime.parse(data['con_date'].toString());
        displayDate = DateFormat('MMMM d, yyyy').format(parsedDate);
      } catch (e) {
        displayDate = data['con_date'].toString(); 
      }
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F5FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 4),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Course', data['course_name'], isValueBold: true),
          const SizedBox(height: 12),
          _buildInfoRow(personLabel, personName),
          const SizedBox(height: 12),
          _buildInfoRow('Time', data['time_slot']),
          const SizedBox(height: 12),
          _buildInfoRow('Date', displayDate), 
          const SizedBox(height: 12),
          _buildInfoRow('Status', currentStatus, valueColor: statusColor),

          if (userRole == 'faculty' || userRole == 'tutor') ...[
            
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        int bId = int.parse(data['booking_id'].toString());
                        onUpdateStatus(bId, 'Rejected');
                      },
                      child: const Text('Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade500,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        int bId = int.parse(data['booking_id'].toString());
                        onUpdateStatus(bId, 'Accepted');
                      },
                      child: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],

            if (isAccepted) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                     int bId = int.parse(data['booking_id'].toString());
                     TextEditingController summaryController = TextEditingController();

                     showDialog(
                       context: context,
                       builder: (context) => AlertDialog(
                         title: const Text("Consultation Summary", style: TextStyle(fontFamily: 'Gabarito', fontWeight: FontWeight.bold)),
                         content: TextField(
                           controller: summaryController,
                           maxLines: 4,
                           decoration: const InputDecoration(
                             hintText: "Enter key topics discussed...",
                             border: OutlineInputBorder(),
                           ),
                         ),
                         actions: [
                           TextButton(
                             onPressed: () => Navigator.pop(context),
                             child: const Text("Cancel", style: TextStyle(color: Colors.red)),
                           ),
                           ElevatedButton(
                             style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
                             onPressed: () {
                               if (summaryController.text.trim().isEmpty) {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a summary.")));
                                 return;
                               }
                               Navigator.pop(context); 
                               onUpdateStatus(bId, 'Completed', summaryController.text.trim());
                             },
                             child: const Text("Submit & Complete", style: TextStyle(color: Colors.white)),
                           ),
                         ],
                       ),
                     );
                  },
                  child: const Text(
                    'Mark as Completed', 
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)
                  ),
                ),
              )
            ],
          ]
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor, bool isValueBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 65,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ),
        const Text(
          ' :  ',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isValueBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}

class CustomActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const CustomActionButton({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        decoration: BoxDecoration(
          color: const Color(0xFFE4F5FD),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              offset: Offset(0, 4),
              blurRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}