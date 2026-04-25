import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Added for date formatting
import 'package:alms/widgets/app_drawer.dart';

class MyConsultations extends StatefulWidget {
  final String userId;

  const MyConsultations({super.key, required this.userId});

  @override
  State<MyConsultations> createState() => _MyConsultationsState();
}

class _MyConsultationsState extends State<MyConsultations> {
  String userRole = "student"; // Default to student
  List<dynamic> consultations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Determine host for emulator/simulator
  String get _host => Platform.isAndroid ? "10.0.2.2" : "127.0.0.1";

  Future<void> _fetchData() async {
    try {
      // 1. Get the user's role first
      final roleResponse = await http.get(Uri.parse('http://$_host:8000/role/${widget.userId}'));
      if (roleResponse.statusCode == 200) {
        final roleData = jsonDecode(roleResponse.body);
        if (roleData['success'] == true) {
          userRole = roleData['role'];
        }
      }

      // 2. Fetch the consultations based on role
      final consResponse = await http.get(Uri.parse('http://$_host:8000/my_consultations/${widget.userId}?role=$userRole'));
      if (consResponse.statusCode == 200) {
        final consData = jsonDecode(consResponse.body);
        if (consData['success'] == true) {
          setState(() {
            consultations = consData['data'];
            isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
    
    // If it fails, stop loading
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
          // FIX 1: Removed the invalid '?' before summaryText
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

    // FIX 2: Parse and format the new con_date instead of day_of_week
    String displayDate = 'Unknown Date';
    if (data['con_date'] != null) {
      try {
        DateTime parsedDate = DateTime.parse(data['con_date'].toString());
        displayDate = DateFormat('MMMM d, yyyy').format(parsedDate);
      } catch (e) {
        displayDate = data['con_date'].toString(); // Fallback if parsing fails
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
          // FIX 2: Label changed to Date, passing displayDate
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