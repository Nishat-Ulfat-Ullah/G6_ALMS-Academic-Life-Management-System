import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io'; 

class SetConsultations extends StatefulWidget {
  final String currentUserID;
  const SetConsultations({super.key, required this.currentUserID});

  @override
  State<SetConsultations> createState() => _SetConsultationsState();
}

class _SetConsultationsState extends State<SetConsultations> {
  final List<String> days = [
    'SUNDAY',
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'SATURDAY'
  ];

  final List<String> timeSlots = [
    '10:00 am', '11:00 am', '12:00 pm', 
    '01:00 pm', '02:00 pm', '03:00 pm'
  ];

  //Track the selected slots for each day
  final Map<String, Set<String>> selectedSchedule = {};

  @override
  void initState() {
    super.initState();
    for (var day in days) {
      selectedSchedule[day] = {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 138, 201, 243), 
        title: const Text("Set Consultations"),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              child: Icon(Icons.favorite, size: 48),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('H O M E'),
              onTap: () {
                Navigator.pushNamed(context, '/homepage');
              },
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('MY NOTES'),
              onTap: (){
                Navigator.pushNamed(context, '/mynotespage');
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('MY CONSULTATIONS'),
              onTap: () {
                Navigator.pushNamed(context, '/myconsultations');
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('BOOK CONSULTATIONS'),
              onTap: () {
                Navigator.pushNamed(context, '/bookconsultations');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('S E T T I N G S'),
              onTap: (){
                Navigator.pushNamed(context, '/settingspage');
              },
            )
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 80, top: 20),
            itemCount: days.length,
            separatorBuilder: (context, index) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              return _buildDayCard(days[index]);
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          print("--- 1. SAVE BUTTON CLICKED ---");
          
          Map<String, List<String>> apiReadySchedule = {};
          selectedSchedule.forEach((day, times) {
            if (times.isNotEmpty) {
              apiReadySchedule[day] = times.toList();
            }
          });

          Map<String, dynamic> payload = {
            "provider_id": widget.currentUserID,
            "routine": apiReadySchedule,
          };
          
          print("--- 2. PAYLOAD READY: $payload ---");

          try {
            print("--- 3. SENDING HTTP POST REQUEST... ---");
            
            // Dynamic host selection!
            final host = Platform.isAndroid ? "10.0.2.2" : "127.0.0.1";
            final url = Uri.parse('http://$host:8000/save_routine');
            
            final response = await http.post(
              url, 
              headers: {"Content-Type": "application/json"},
              body: jsonEncode(payload),
            );

            print("--- 4. RESPONSE RECEIVED! Status Code: ${response.statusCode} ---");
            print("--- 5. RESPONSE BODY: ${response.body} ---");

            if (response.statusCode == 200) {
              final responseData = jsonDecode(response.body);
              
              if (responseData['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Routine Saved Successfully!')),
                );
                
                if (mounted) {
                  Navigator.pushReplacementNamed(
                    context, 
                    '/myconsultations',
                    arguments: widget.currentUserID,
                  );
                }
              } else {
                print("--- BACKEND LOGIC ERROR: ${responseData['error']} ---");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Database Error: ${responseData['error']}')),
                );
              }
            } else {
              print("--- SERVER RETURNED BAD STATUS CODE ---");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Server Error: ${response.statusCode}')),
              );
            }
          } catch (e) {
            print("--- CRITICAL NETWORK ERROR: $e ---");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Network error: Could not reach server.')),
            );
          }
        },
        label: const Text('Save Routine'),
        icon: const Icon(Icons.save),
        backgroundColor: const Color.fromARGB(255, 138, 201, 243),
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildDayCard(String day) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: const Color(0xFFD9F5FF), 
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Colors.black12),
          borderRadius: BorderRadius.circular(22),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x1F000000), 
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            day,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontFamily: 'Gabarito',
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: timeSlots.map((time) => _buildSelectableTimeSlot(day, time)).toList(),
          ),
        ],
      ),
    );
  }
  Widget _buildSelectableTimeSlot(String day, String time) {
    bool isSelected = selectedSchedule[day]!.contains(time);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedSchedule[day]!.remove(time); 
          } else {
            selectedSchedule[day]!.add(time); 
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: ShapeDecoration(
          color: isSelected ? Colors.blue.shade700 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: BorderSide(
              color: isSelected ? Colors.blue.shade900 : Colors.transparent,
              width: 1,
            )
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 2,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Text(
          time,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 16,
            fontFamily: 'Gabarito',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}