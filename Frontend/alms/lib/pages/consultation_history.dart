import 'dart:convert';
// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Added for date formatting

class ConsultationHistory extends StatefulWidget {
  final String userId;

  const ConsultationHistory({super.key, required this.userId});

  @override
  State<ConsultationHistory> createState() => _ConsultationHistoryState();
}

class _ConsultationHistoryState extends State<ConsultationHistory> {
  String userRole = "student";
  List<dynamic> historyData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  // String get _host => Platform.isAndroid ? "10.0.2.2" : "127.0.0.1";
  String get _host => "g6-alms-academic-life-management-system.onrender.com";

  Future<void> _fetchHistory() async {
    try {
      // 1. Get role
      // final roleResponse = await http.get(Uri.parse('http://$_host:8000/role/${widget.userId}'));
      final roleResponse = await http.get(Uri.parse('https://$_host/role/${widget.userId}'));
      if (roleResponse.statusCode == 200) {
        final roleData = jsonDecode(roleResponse.body);
        if (roleData['success'] == true) {
          userRole = roleData['role'];
        }
      }

      // 2. Fetch history (Completed/Rejected)
      // final histResponse = await http.get(Uri.parse('http://$_host:8000/consultation_history/${widget.userId}?role=$userRole'));
      final histResponse = await http.get(Uri.parse('https://$_host/consultation_history/${widget.userId}?role=$userRole'));
      if (histResponse.statusCode == 200) {
        final histJson = jsonDecode(histResponse.body);
        if (histJson['success'] == true) {
          setState(() {
            historyData = histJson['data'];
            isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      print("Error fetching history: $e");
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 138, 201, 243),
        title: const Text("CONSULTATION HISTORY"),
      ),
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
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : historyData.isEmpty
                      ? const Center(
                          child: Text(
                            "No history found.",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                        )
                      : ListView.separated(
                          itemCount: historyData.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final item = historyData[index];
                            return HistoryCard(data: item, userRole: userRole);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// Read-only Card for History with Clickable Summary Popup
class HistoryCard extends StatelessWidget {
  final Map<dynamic, dynamic> data;
  final String userRole;

  const HistoryCard({super.key, required this.data, required this.userRole});

  void _showSummaryDialog(BuildContext context, String? summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Consultation Summary", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          summary != null && summary.isNotEmpty 
            ? summary 
            : "No summary provided for this consultation.",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentStatus = data['status'];
    Color statusColor = currentStatus == 'Completed' ? Colors.blue.shade700 : Colors.red.shade400;

    String personLabel = userRole == 'student' ? 'Faculty' : 'Student';
    String personName = userRole == 'student' ? data['provider_id'] : data['student_id'];

    // FIX: Parse and format the new con_date instead of day_of_week
    String displayDate = 'Unknown Date';
    if (data['con_date'] != null) {
      try {
        DateTime parsedDate = DateTime.parse(data['con_date'].toString());
        displayDate = DateFormat('MMMM d, yyyy').format(parsedDate);
      } catch (e) {
        displayDate = data['con_date'].toString(); // Fallback if parsing fails
      }
    }

    return InkWell(
      onTap: () {
        // Only show the summary popup if it was completed
        if (currentStatus == 'Completed') {
          _showSummaryDialog(context, data['summary']?.toString());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No summary available for rejected consultations.')),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFFE4F5FD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 1.2),
          boxShadow: const [
            BoxShadow(color: Colors.black12, offset: Offset(0, 4), blurRadius: 4),
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
            // FIX: Label changed to Date, passing displayDate
            _buildInfoRow('Date', displayDate),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildInfoRow('Status', currentStatus, valueColor: statusColor)),
                if (currentStatus == 'Completed') 
                  const Icon(Icons.info_outline, color: Colors.blueGrey, size: 20),
              ],
            ),
          ],
        ),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black),
          ),
        ),
        const Text(
          ' :  ',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
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