import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class FocusModeScreen extends StatefulWidget {
  final String userId; 
  const FocusModeScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _FocusModeScreenState createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> {
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isRunning = false;

  // Format seconds to HH:MM:SS
  String get _formattedTime {
    int hours = _secondsElapsed ~/ 3600;
    int minutes = (_secondsElapsed % 3600) ~/ 60;
    int seconds = _secondsElapsed % 60;
    return '${hours.toString().padLeft(2, '0')} : ${minutes.toString().padLeft(2, '0')} : ${seconds.toString().padLeft(2, '0')}';
  }

  void _toggleTimer() {
    if (_isRunning) {
      _stopTimerAndSave();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  Future<void> _stopTimerAndSave() async {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });

    final int durationToSave = _secondsElapsed;

    try {
      // Dynamically select the correct localhost IP based on the platform
      final host = Platform.isAndroid ? "10.0.2.2" : "127.0.0.1";
      final url = Uri.parse('http://$host:8000/save_focus_session');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': widget.userId,
          'duration_seconds': durationToSave,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Focus session of $durationToSave seconds saved!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save session.')),
        );
      }
    } catch (e) {
      print("Error saving focus session: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')), // Good for debugging on the device
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Background pattern would go here
      appBar: AppBar(
        backgroundColor: Colors.pinkAccent.shade100,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          // Disable menu if running
          onPressed: _isRunning ? null : () {}, 
        ),
        title: const Text(
          'Focus Mode',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Warning Badges
            _buildWarningBadge('Notifications Blocked'),
            const SizedBox(height: 10),
            _buildWarningBadge('In-app Features Blocked'),
            const SizedBox(height: 50),

            // Timer Circle
            GestureDetector(
              onTap: _toggleTimer,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.pinkAccent.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.pink.shade50, width: 10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formattedTime,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRunning ? "Tap to Stop" : "Tap to Start",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 60),

            // Exit Button
            ElevatedButton.icon(
              // Disable button when timer is running by setting onPressed to null
              onPressed: _isRunning ? null : () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 16),
              label: const Text(
                'Exit Focus Mode',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent.shade100,
                disabledBackgroundColor: Colors.grey.shade400, // Grey out when disabled
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.pinkAccent.shade100,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}