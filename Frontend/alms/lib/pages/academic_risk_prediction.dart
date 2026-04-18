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
  Map<String, dynamic>? riskData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRiskData();
  }

  Future<void> fetchRiskData() async {
    try {
      final host = Platform.isAndroid ? "10.0.2.2" : "127.0.0.1";
      final response = await http.get(Uri.parse('http://$host:8000/api/academic_risk/${widget.userId}'));
      
      if (response.statusCode == 200) {
        setState(() {
          riskData = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching risk: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Adding the background pattern color to match Figma
      backgroundColor: const Color(0xFFFDFCFB), 
      appBar: AppBar(
        backgroundColor: const Color(0xFFF58A8A),
        elevation: 0,
        // --- FIX: Wrapped Icon in IconButton to enable navigation ---
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {
            // Navigates back to the HomePage where focus mode etc. are located
            Navigator.pop(context); 
          },
        ),
        title: const Text(
          'Academic Risk Prediction', 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Container(
            // Optional: Background image pattern if you have the asset
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/pattern_bg.png"), // Ensure this is in pubspec if used
                opacity: 0.05,
                fit: BoxFit.cover,
              ),
            ),
            child: SingleChildScrollView(
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
                  ],
                ),
              ),
          ),
    );
  }

  Widget _buildRiskZoneCard() {
    double riskScore = (riskData!['risk_score'] as num).toDouble();
    
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFFF58A8A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Triangle Icon from Figma
              const Icon(Icons.change_history_rounded, size: 60, color: Color(0xFF632B2B)),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Risk Zone", style: TextStyle(fontSize: 18, color: Colors.black87)),
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
                  gradient: const LinearGradient(
                    colors: [Colors.orange, Colors.red, Color(0xFF8B0000)],
                  ),
                ),
              ),
              // The moving white indicator bar
              Positioned(
                // Dynamic positioning based on the risk score
                left: (MediaQuery.of(context).size.width - 90) * (riskScore / 100),
                child: Container(
                  width: 6,
                  height: 35,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]
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
          Text(
            riskData!['suggestion'], 
            style: const TextStyle(fontSize: 14, color: Colors.black87)
          ),
        ],
      ),
    );
  }
}