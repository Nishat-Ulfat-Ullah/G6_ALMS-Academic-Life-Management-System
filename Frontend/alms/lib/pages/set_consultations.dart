import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'dart:io';
import 'package:intl/intl.dart';

class SetConsultations extends StatefulWidget {
  final String currentUserID;
  const SetConsultations({super.key, required this.currentUserID});

  @override
  State<SetConsultations> createState() => _SetConsultationsState();
}

class _SetConsultationsState extends State<SetConsultations> {
  bool isLoading = true;
  // Map to group slots by date: {'2026-04-30': [{routine_id: 1, time_slot: '10:00 AM', is_booked: 0}, ...]}
  Map<String, List<Map<String, dynamic>>> groupedRoutines = {};

  final List<String> availableTimeSlots = [
    '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM',
    '12:00 PM', '12:30 PM', '01:00 PM', '01:30 PM', '02:00 PM', '02:30 PM',
    '03:00 PM', '03:30 PM', '04:00 PM', '04:30 PM', '05:00 PM'
  ];

  // String get host => Platform.isAndroid ? "10.0.2.2" : "127.0.0.1";
  String get host => "g6-alms-academic-life-management-system.onrender.com";

  @override
  void initState() {
    super.initState();
    fetchRoutines();
  }

  Future<void> fetchRoutines() async {
    setState(() => isLoading = true);
    try {
      // final url = Uri.parse('http://$host:8000/api/routines/provider/${widget.currentUserID}');
      final url = Uri.parse('https://$host/api/routines/provider/${widget.currentUserID}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success']) {
          List<dynamic> data = responseData['data'];
          
          // Group data by date
          Map<String, List<Map<String, dynamic>>> tempGroup = {};
          for (var item in data) {
            String date = item['con_date'];
            if (!tempGroup.containsKey(date)) {
              tempGroup[date] = [];
            }
            tempGroup[date]!.add(item);
          }
          
          setState(() {
            groupedRoutines = tempGroup;
          });
        }
      }
    } catch (e) {
      print("Error fetching routines: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteSlot(int routineId) async {
    try {
      // final url = Uri.parse('http://$host:8000/api/routines/delete/$routineId');
      final url = Uri.parse('https://$host/api/routines/delete/$routineId');
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        fetchRoutines(); // Refresh list
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slot removed')));
      }
    } catch (e) {
      print("Delete error: $e");
    }
  }

  void _showAddDialog() {
    DateTime? selectedDate;
    Set<String> selectedSlots = {};

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text("Add Consultation Slots"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date Picker Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(), // Prevents picking past dates
                          lastDate: DateTime.now().add(const Duration(days: 60)),
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(selectedDate == null 
                          ? "Select Date" 
                          : DateFormat('yyyy-MM-dd').format(selectedDate!)),
                    ),
                    const SizedBox(height: 16),
                    
                    // Time Slot Grid
                    if (selectedDate != null) ...[
                      const Text("Select 30-min Intervals:"),
                      const SizedBox(height: 8),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: availableTimeSlots.map((time) {
                              bool isSelected = selectedSlots.contains(time);
                              return ChoiceChip(
                                label: Text(time),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    selected ? selectedSlots.add(time) : selectedSlots.remove(time);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: (selectedDate == null || selectedSlots.isEmpty) ? null : () async {
                    Navigator.pop(context); // Close dialog
                    await _saveNewRoutine(DateFormat('yyyy-MM-dd').format(selectedDate!), selectedSlots.toList());
                  },
                  child: const Text("Save"),
                )
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _saveNewRoutine(String date, List<String> slots) async {
    Map<String, dynamic> payload = {
      "provider_id": widget.currentUserID,
      "con_date": date,
      "time_slots": slots,
    };

    try {
      // final url = Uri.parse('http://$host:8000/api/routines/add');
      final url = Uri.parse('https://$host/api/routines/add');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slots added!')));
        fetchRoutines(); // Refresh UI
      }
    } catch (e) {
      print("Save error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort dates so upcoming is first
    List<String> sortedDates = groupedRoutines.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 138, 201, 243), 
        title: const Text("Set Consultations"),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : sortedDates.isEmpty 
          ? const Center(child: Text("No upcoming consultations. Click '+' to add."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                String dateStr = sortedDates[index];
                List<Map<String, dynamic>> slots = groupedRoutines[dateStr]!;
                
                // Format date for display (e.g., "April 30, 2026")
                DateTime parsedDate = DateTime.parse(dateStr);
                String displayDate = DateFormat('MMMM d, yyyy').format(parsedDate);

                return Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  color: const Color(0xFFD9F5FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayDate,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: slots.map((slotData) {
                            bool isBooked = slotData['is_booked'] == 1;
                            return Chip(
                              label: Text(slotData['time_slot']),
                              backgroundColor: isBooked ? Colors.grey.shade300 : Colors.white,
                              deleteIcon: isBooked ? null : const Icon(Icons.close, size: 18),
                              onDeleted: isBooked ? null : () => deleteSlot(slotData['routine_id']),
                            );
                          }).toList(),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: const Color.fromARGB(255, 138, 201, 243),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}