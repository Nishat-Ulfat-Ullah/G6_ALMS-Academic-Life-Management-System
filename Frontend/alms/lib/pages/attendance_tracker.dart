import 'package:flutter/material.dart';
import 'dart:math';
import 'package:alms/widgets/app_background.dart'; 

class AttendanceTrackerScreen extends StatefulWidget {
  final String userId;
  const AttendanceTrackerScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _AttendanceTrackerScreenState createState() => _AttendanceTrackerScreenState();
}

class _AttendanceTrackerScreenState extends State<AttendanceTrackerScreen> {
  final TextEditingController _totalClassesController = TextEditingController();
  final TextEditingController _attendedClassesController = TextEditingController();

  Map<String, dynamic>? attendanceData;
  bool isCalculating = false;

  void calculateAttendance() {
    FocusScope.of(context).unfocus(); 
    
    int total = int.tryParse(_totalClassesController.text) ?? 0;
    int attended = int.tryParse(_attendedClassesController.text) ?? 0;

    if (total == 0 || attended > total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid class numbers.')),
      );
      return;
    }

    setState(() {
      isCalculating = true;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      double percentage = (attended / total) * 100;
      
      int canMiss = ((attended / 0.70) - total).floor();
      int needToAttend = ((0.70 * total - attended) / 0.30).ceil(); 

      String status = "";
      String suggestion = "";
      String missableText = "";

      if (percentage >= 90) {
        status = "Very Good";
        suggestion = "Great job! You have excellent attendance.";
      } else if (percentage >= 70) {
        status = "Safe";
        suggestion = "You are above the 70% minimum limit. Keep it up!";
      } else {
        status = "Warning";
        suggestion = "Warning! Your attendance is below the 70% requirement.";
      }

      if (canMiss > 0) {
        missableText = "You can safely miss $canMiss upcoming classes.";
      } else if (canMiss == 0 && percentage >= 70) {
        missableText = "You are exactly at the limit. Do not miss the next class!";
      } else {
        missableText = "You must attend $needToAttend more classes in a row to reach 70%.";
      }

      setState(() {
        attendanceData = {
          'percentage': percentage,
          'total': total,
          'attended': attended,
          'status': status,
          'suggestion': suggestion,
          'missable_text': missableText,
        };
        isCalculating = false;
      });
    });
  }

  void _resetForm() {
    setState(() {
      attendanceData = null;
      _totalClassesController.clear();
      _attendedClassesController.clear();
    });
  }

  @override
  void dispose() {
    _totalClassesController.dispose();
    _attendedClassesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      // 1. Extend body behind AppBar so the background starts at the very top
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        // Using slight transparency so the background pattern is visible behind the blue
        backgroundColor: const Color(0xFF8CB9F5).withOpacity(0.9), 
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context), 
        ),
        title: const Text(
          'Attendance Tracker', 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
      ),
      // 2. Wrap with SizedBox.expand to ensure the background fills the entire screen
      body: SizedBox.expand(
        child: AppBackground(
          // 3. Use SafeArea to keep content from getting stuck behind the AppBar
          child: SafeArea(
            child: isCalculating 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8CB9F5)))
                : (attendanceData == null) 
                    ? _buildInputForm() 
                    : _buildResultsDashboard(),
          ),
        ),
      ),
    );
  }

  Widget _buildInputForm() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Check your attendance status:", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildInputField("Total Classes Held", "e.g., 20", _totalClassesController),
          _buildInputField("Classes Attended", "e.g., 16", _attendedClassesController),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: calculateAttendance,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8CB9F5),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text("Calculate", 
              style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, String hint, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFF8CB9F5).withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsDashboard() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildAttendanceCard(),
          const SizedBox(height: 30),
          _buildStatTile("Current Percentage", "${attendanceData!['percentage'].toStringAsFixed(1)}%"),
          _buildStatTile("Attended vs Total", "${attendanceData!['attended']} / ${attendanceData!['total']}"),
          const SizedBox(height: 20),
          _buildSuggestionCard(),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _resetForm,
            icon: const Icon(Icons.refresh, color: Colors.black),
            label: const Text("Start Over", style: TextStyle(color: Colors.black, fontSize: 16)),
          )
        ],
      ),
    );
  }

  Widget _buildAttendanceCard() {
    double percentage = attendanceData!['percentage'];
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF8CB9F5).withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fact_check, size: 50, color: Color(0xFF1E3A8A)),
              const SizedBox(width: 15),
              const Text("Your Status", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
            ],
          ),
          const SizedBox(height: 25),
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 20,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(colors: [Colors.red, Colors.orange, Colors.green]),
                ),
              ),
              Positioned(
                left: (MediaQuery.of(context).size.width - 90) * (percentage.clamp(0, 100) / 100),
                child: Container(
                  width: 4,
                  height: 25,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard() {
    Color statusColor = attendanceData!['percentage'] >= 70 ? Colors.green.shade700 : Colors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF8CB9F5).withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("RESULT: ${attendanceData!['status']}", 
            style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 16)),
          const SizedBox(height: 8),
          Text(attendanceData!['suggestion'], style: const TextStyle(fontSize: 14)),
          const Divider(height: 25),
          Text(attendanceData!['missable_text'], 
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        ],
      ),
    );
  }
}