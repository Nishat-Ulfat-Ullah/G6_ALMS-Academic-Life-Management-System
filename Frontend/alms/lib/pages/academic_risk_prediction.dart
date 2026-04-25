import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class AcademicRiskScreen extends StatefulWidget {
  final String userId;
  const AcademicRiskScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _AcademicRiskScreenState createState() => _AcademicRiskScreenState();
}

class _AcademicRiskScreenState extends State<AcademicRiskScreen> {
  // --- NEW: Controllers to grab the user's manual input ---
  final TextEditingController _attendanceController = TextEditingController();
  final TextEditingController _totalClassesController = TextEditingController();
  final TextEditingController _cgpaController = TextEditingController();
  final TextEditingController _missedDeadlinesController = TextEditingController();
  final TextEditingController _lowQuizController = TextEditingController();

  Map<String, dynamic>? riskData;
  bool isCalculating = false;

  // --- NEW: The function that sends manual inputs to the backend ---
  Future<void> calculateRisk() async {
    setState(() {
      isCalculating = true; // Shows a loading spinner while waiting for the backend
    });

    try {
      final host = Platform.isAndroid ? "10.0.2.2" : "127.0.0.1";
      // Notice we changed this from GET to POST, pointing to a calculation endpoint
      final url = Uri.parse('http://$host:8000/api/calculate_risk'); 
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': widget.userId,
          'attendance': int.tryParse(_attendanceController.text) ?? 0,
          'total_classes': int.tryParse(_totalClassesController.text) ?? 20,
          'cgpa': double.tryParse(_cgpaController.text) ?? 0.0,
          'missed_deadlines': int.tryParse(_missedDeadlinesController.text) ?? 0,
          'low_quizzes': int.tryParse(_lowQuizController.text) ?? 0,
        }),
      );
      
      if (response.statusCode == 200) {
        setState(() {
          riskData = json.decode(response.body); // Save the results
          isCalculating = false;
        });
      } else {
        // Handle error if backend fails
        setState(() { isCalculating = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to calculate risk.')),
        );
      }
    } catch (e) {
      debugPrint("Error calculating risk: $e");
      setState(() { isCalculating = false; });
    }
  }

  // --- NEW: Function to reset the form ---
  void _resetForm() {
    setState(() {
      riskData = null; // Clearing this makes the form show up again
    });
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _attendanceController.dispose();
    _totalClassesController.dispose();
    _cgpaController.dispose();
    _missedDeadlinesController.dispose();
    _lowQuizController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB), 
      appBar: AppBar(
        backgroundColor: const Color(0xFFF58A8A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () => Navigator.pop(context), 
        ),
        title: const Text(
          'Academic Risk Prediction', 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/bg.png"), 
            opacity: 0.05,
            fit: BoxFit.cover,
          ),
        ),
        // --- NEW: Logic to switch between Input Form and Results ---
        child: isCalculating 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFF58A8A)))
            : (riskData == null) 
                ? _buildInputForm()  // If no data yet, show the form
                : _buildResultsDashboard(), // If we have data, show the graph
      ),
    );
  }

  // ==========================================
  // UI: THE INPUT FORM (Shows First)
  // ==========================================
  Widget _buildInputForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Enter your current academic details:", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          _buildInputField("Current CGPA", "e.g., 3.11", _cgpaController),
          Row(
            children: [
              Expanded(child: _buildInputField("Classes Attended", "e.g., 15", _attendanceController)),
              const SizedBox(width: 10),
              Expanded(child: _buildInputField("Total Classes", "e.g., 20", _totalClassesController)),
            ],
          ),
          _buildInputField("Missed Deadlines", "e.g., 2", _missedDeadlinesController),
          _buildInputField("Low Quiz Scores", "e.g., 2", _lowQuizController),
          
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: calculateRisk, // Triggers the POST request
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF58A8A),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text("Calculate Risk Score", 
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
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF58A8A).withOpacity(0.2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // UI: THE RESULTS DASHBOARD (Shows after calculation)
  // ==========================================
  Widget _buildResultsDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildRiskZoneCard(),
          const SizedBox(height: 30),
          _buildStatTile("Attendance", "${riskData!['details']['attendance']}/${riskData!['details']['total_classes']}"),
          _buildStatTile("CGPA", "${riskData!['details']['cgpa']}"),
          _buildStatTile("Missed Deadlines", "${riskData!['details']['missed_deadlines']}/${riskData!['details']['total_deadlines']}"),
          _buildStatTile("Low quiz performance", "${riskData!['details']['low_quizzes']}/${riskData!['details']['total_quizzes']}"),
          
          const SizedBox(height: 20),
          _buildSuggestionCard(),
          const SizedBox(height: 20),
          
          // Button to go back and calculate again
          TextButton.icon(
            onPressed: _resetForm,
            icon: const Icon(Icons.refresh, color: Colors.black),
            label: const Text("Recalculate", style: TextStyle(color: Colors.black, fontSize: 16)),
          )
        ],
      ),
    );
  }

  // (Keep your existing _buildRiskZoneCard, _buildStatTile, and _buildSuggestionCard exactly as they were here)
  Widget _buildRiskZoneCard() {
    double riskScore = (riskData!['risk_score'] as num).toDouble();
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFFF58A8A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning, size: 60, color: Color.fromARGB(255, 134, 15, 6)),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Risk Zone", style: TextStyle(fontSize: 26,fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text("Calculation", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black)),
                ],
              )
            ],
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("low", style: TextStyle(fontWeight: FontWeight.w500)), 
              Text("high", style: TextStyle(fontWeight: FontWeight.w500))
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 30,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(colors: [Colors.orange, Colors.red, Color(0xFF8B0000)]),
                ),
              ),
              Positioned(
                left: (MediaQuery.of(context).size.width - 90) * (riskScore / 100),
                child: Container(
                  width: 6,
                  height: 35,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
                  ),
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
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF58A8A).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Prediction: ${riskData!['zone']} Risk", 
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
          const SizedBox(height: 5),
          Text(riskData!['suggestion'], style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }
}