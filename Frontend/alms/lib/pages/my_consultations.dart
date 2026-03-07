import 'package:flutter/material.dart';


class MyConsultations extends StatelessWidget{
  const MyConsultations({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color.fromARGB(255, 138, 201, 243), title: Text("MY CONSULTATIONS"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 50), 
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (String value) {
                // Handling clicks
                if (value == 'profile') {
                  // Navigator.pushNamed(context, '/profilepage');
                  print('View Profile Clicked');
                } else if (value == 'settings') {
                  Navigator.pushNamed(context, '/settingspage');
                } else if (value == 'logout') {
                  Navigator.pushNamed(context, '/registerpage');
                  
                  print('Logout Clicked');
                }
              },
              // The circular profile picture
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                backgroundImage: AssetImage('assets/tdp.png'), 
              ),
              // The dropdown menu items
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
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(child: 
            Icon(
              Icons.favorite,size: 48
              )
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('H O M E'),
              onTap: () {
                Navigator.pushNamed(context, '/homepage');
              },
            ),
            ListTile(
              leading: Icon(Icons.book),
              title: Text('MY NOTES'),
              onTap: (){
                Navigator.pushNamed(context, '/mynotespage');
              },
            ),
            ListTile(
              leading: Icon(Icons.timer),
              title: Text('MY CONSULTATIONS'),
              onTap: () {
                Navigator.pushNamed(context, '/myconsultations');
              },
            ),
            ListTile(
              leading: Icon(Icons.timer),
              title: Text('BOOK CONSULTATIONS'),
              onTap: () {
                Navigator.pushNamed(context, '/bookconsultations');
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('S E T T I N G S'),
              onTap: (){
                Navigator.pushNamed(context, '/settingspage');
              },
            )

          ],
        ),
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
              child: Column(
                children: [
                  // First Consultation Card
                  const ConsultationCard(
                    courseText: 'CSE471: System Analysis....',
                    facultyText: 'Mehedi Hasan Emo (MHDE)',
                    timeText: '11:00 am',
                    dayText: 'Saturday',
                    statusText: 'Pending',
                    statusColor: Colors.pinkAccent,
                  ),
                  const SizedBox(height: 16),
                  
                  // Second Consultation Card
                  const ConsultationCard(
                    courseText: 'HUM101: World Civilizati....',
                    facultyText: 'Rumi Akter (AKTR)',
                    timeText: '12:30 pm',
                    dayText: 'Sunday',
                    statusText: 'Accepted',
                    statusColor: Color(0xFF00BFA5), // Teal/Green color
                  ),
                  
                  // Spacer pushes the buttons to the bottom
                  const Spacer(),
                  
                  // Bottom Buttons
                  CustomActionButton(
                    text: 'Book Consultations',
                    onTap: () {
                      Navigator.pushNamed(context, '/bookconsultations');
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomActionButton(
                    text: 'View History',
                    onTap: () {
                      // Add logic for history or create a '/history' route
                    },
                  ),
                  const SizedBox(height: 10), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}



// reusable widgets

class ConsultationCard extends StatelessWidget {
  final String courseText;
  final String facultyText;
  final String timeText;
  final String dayText;
  final String statusText;
  final Color statusColor;

  const ConsultationCard({
    super.key,
    required this.courseText,
    required this.facultyText,
    required this.timeText,
    required this.dayText,
    required this.statusText,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F5FD), // Light blue card background
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
        children: [
          _buildInfoRow('Course', courseText, isValueBold: true),
          const SizedBox(height: 12),
          _buildInfoRow('Faculty', facultyText),
          const SizedBox(height: 12),
          _buildInfoRow('Time', timeText),
          const SizedBox(height: 12),
          _buildInfoRow('Day', dayText),
          const SizedBox(height: 12),
          _buildInfoRow('Status', statusText, valueColor: statusColor),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor, bool isValueBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 65, // Fixed width to align colons perfectly
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
          color: const Color(0xFFE4F5FD), // Light blue button background
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