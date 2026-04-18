import 'package:flutter/material.dart';
import '../services/course_outline_service.dart';
import '../widgets/user_session.dart';

class CourseOutlinePage extends StatefulWidget {
  const CourseOutlinePage({super.key});

  @override
  _CourseOutlinePageState createState() => _CourseOutlinePageState();
}

class _CourseOutlinePageState extends State<CourseOutlinePage> {
  final _service = CourseOutlineService();
  List courses = [];
  bool isLoading = true;
  String selectedMajor = 'CSE'; 

  // Main high-level categories
  final List<String> mainCategories = [
    'University Core',
    'GenEd Electives',
    'School Core',
    'Program Core',
    'Program Elective',
    'Project/Internship/Thesis',
    'Other'
  ];

  // Sub-streams specifically for University Core
  final List<String> uniCoreStreams = [
    'Uni Core - Stream 1: Writing',
    'Uni Core - Stream 2: Math & Nat Sci',
    'Uni Core - Stream 3: Arts & Humanities',
    'Uni Core - Stream 4: Social Sciences',
    'Uni Core - Stream 5: Communities',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final data = await _service.getProgress(UserSession.userId!);
    if (data != null) {
      setState(() {
        courses = data['courses'];
        isLoading = false;
      });
    }
  }

  int get targetCredits => selectedMajor == 'CSE' ? 136 : 124;

  int get completedCredits {
    int total = 0;
    for (var c in courses) {
      if (c['status'] == 'Completed') {
        total += (c['credits'] as num).toInt();
      }
    }
    return total;
  }

  // --- Organizes courses into their respective categories ---
  Map<String, List<dynamic>> get groupedCourses {
    Map<String, List<dynamic>> map = {};
    for (var cat in mainCategories) map[cat] = [];
    for (var stream in uniCoreStreams) map[stream] = [];

    for (var c in courses) {
      String stream = c['stream'];
      if (map.containsKey(stream)) {
        map[stream]!.add(c);
      } else if (stream.startsWith('Uni Core')) {
        map['University Core']!.add(c); // Fallback
      } else {
        map['Other']!.add(c); 
      }
    }
    return map;
  }

  // --- UI for the Add/Edit Dialog ---
  void _showAddCourseDialog({Map? existingCourse}) {
    final bool isEditing = existingCourse != null;
    
    String code = existingCourse?['course_code'] ?? '';
    String name = existingCourse?['course_name'] ?? '';
    int credits = existingCourse?['credits'] ?? 3;
    bool isCompleted = existingCourse?['status'] == 'Completed';

    // Figure out the initial dropdown values based on existing database data
    String dbStream = existingCourse?['stream'] ?? 'School Core';
    String mainCategory = 'School Core';
    String subStream = uniCoreStreams[0];

    if (dbStream.startsWith('Uni Core')) {
      mainCategory = 'University Core';
      subStream = uniCoreStreams.contains(dbStream) ? dbStream : uniCoreStreams[0];
    } else if (mainCategories.contains(dbStream)) {
      mainCategory = dbStream;
    } else {
      mainCategory = 'Other';
    }

    final codeController = TextEditingController(text: code);
    final nameController = TextEditingController(text: name);
    final creditsController = TextEditingController(text: credits.toString());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? "Edit Course" : "Add New Course"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  enabled: !isEditing, 
                  onChanged: (v) => code = v, 
                  decoration: InputDecoration(
                    labelText: "Course Code (e.g. CSE470)",
                    helperText: isEditing ? "Code cannot be changed." : null,
                  )
                ),
                TextField(
                  controller: nameController,
                  onChanged: (v) => name = v, 
                  decoration: const InputDecoration(labelText: "Course Name")
                ),
                TextField(
                  controller: creditsController,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => credits = int.tryParse(v) ?? 3, 
                  decoration: const InputDecoration(labelText: "Credits (e.g. 1, 3, 4)")
                ),
                const SizedBox(height: 10),
                
                // --- First Dropdown: Main Category ---
                DropdownButtonFormField<String>(
                  isExpanded: true, 
                  value: mainCategory,
                  decoration: const InputDecoration(labelText: "Course Category"),
                  items: mainCategories.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) {
                    setDialogState(() {
                      mainCategory = v!;
                    });
                  },
                ),
                
                // --- Second Dropdown: Only shows if 'University Core' is selected ---
                if (mainCategory == 'University Core') ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: subStream,
                    decoration: const InputDecoration(labelText: "Select Stream"),
                    items: uniCoreStreams.map((s) => DropdownMenuItem(
                      value: s, 
                      // Remove the "Uni Core -" text in the UI to make it look cleaner
                      child: Text(s.replaceAll('Uni Core - ', ''), style: const TextStyle(fontSize: 14))
                    )).toList(),
                    onChanged: (v) => setDialogState(() => subStream = v!),
                  ),
                ],

                SwitchListTile(
                  title: const Text("Completed?"),
                  value: isCompleted,
                  onChanged: (v) => setDialogState(() => isCompleted = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                // Determine the exact string to save to the database
                String finalStreamToSave = mainCategory == 'University Core' ? subStream : mainCategory;

                await _service.updateCourse({
                  "user_id": UserSession.userId,
                  "course_code": code,
                  "course_name": name,
                  "stream": finalStreamToSave,
                  "status": isCompleted ? "Completed" : "Remaining",
                  "credits": credits 
                });
                Navigator.pop(context);
                _loadData();
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper function to build a course card, keeps the code clean! ---
  Widget _buildCourseCard(Map course) {
    final bool isDone = course['status'] == 'Completed';
    return Dismissible(
      key: Key(course['course_code']), 
      background: Container(
        color: Colors.blue,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _showAddCourseDialog(existingCourse: course);
          return false; 
        } else if (direction == DismissDirection.endToStart) {
          bool? confirm = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Delete"),
              content: Text("Delete ${course['course_code']}?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true), 
                  child: const Text("Delete", style: TextStyle(color: Colors.white))
                ),
              ],
            ),
          );
          if (confirm == true) {
            await _service.deleteCourse(UserSession.userId!, course['course_code']);
            _loadData(); 
            return true; 
          }
        }
        return false;
      },
      child: Card(
        elevation: isDone ? 0 : 2,
        color: isDone ? Colors.green.shade50 : Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          title: Text(
            course['course_code'],
            style: TextStyle(fontWeight: FontWeight.bold, color: isDone ? Colors.green.shade700 : Colors.black87),
          ),
          subtitle: Text("${course['course_name']} • ${course['credits']} Credits"),
          trailing: IconButton(
            icon: Icon(
              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isDone ? Colors.green : Colors.orange,
            ),
            onPressed: () async {
              String newStatus = isDone ? "Remaining" : "Completed";
              await _service.updateCourse({
                "user_id": UserSession.userId,
                "course_code": course['course_code'],
                "course_name": course['course_name'],
                "stream": course['stream'],
                "status": newStatus,
                "credits": course['credits']
              });
              _loadData(); 
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double progressPercent = completedCredits / targetCredits;
    if (progressPercent > 1.0) progressPercent = 1.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Degree Progress"),
        actions: [
          DropdownButton<String>(
            value: selectedMajor,
            dropdownColor: Colors.white,
            underline: Container(),
            items: ['CSE', 'CS'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                selectedMajor = newValue!;
              });
            },
          ),
          const SizedBox(width: 15),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCourseDialog(), 
        child: const Icon(Icons.add)
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // --- Progress Header ---
              Container(
                padding: const EdgeInsets.all(20.0),
                color: Colors.blue.shade50,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("$selectedMajor Progress", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("$completedCredits / $targetCredits Credits", style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progressPercent, 
                      minHeight: 12,
                      backgroundColor: Colors.grey.shade300,
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ],
                ),
              ),
              
              // --- Grouped Course List ---
              Expanded(
                child: ListView(
                  children: mainCategories.map((category) {
                    
                    // --- Special Nested Logic for University Core ---
                    if (category == 'University Core') {
                      bool hasUniCoreCourses = uniCoreStreams.any((stream) => groupedCourses[stream]!.isNotEmpty);
                      if (!hasUniCoreCourses) return const SizedBox.shrink();

                      int totalUniCoreCredits = 0;
                      for (var stream in uniCoreStreams) {
                         totalUniCoreCredits += groupedCourses[stream]!.where((c) => c['status'] == 'Completed').fold(0, (sum, c) => sum + (c['credits'] as num).toInt());
                      }

                      return ExpansionTile(
                        title: const Text('University Core', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text("$totalUniCoreCredits credits earned", style: TextStyle(color: Colors.grey.shade700)),
                        children: uniCoreStreams.map((stream) {
                          List streamCourses = groupedCourses[stream]!;
                          if (streamCourses.isEmpty) return const SizedBox.shrink();

                          int streamCredits = streamCourses.where((c) => c['status'] == 'Completed').fold(0, (sum, c) => sum + (c['credits'] as num).toInt());

                          // Nested ExpansionTile for the specific stream
                          return Padding(
                            padding: const EdgeInsets.only(left: 16.0), // Indent to show hierarchy
                            child: ExpansionTile(
                              title: Text(stream.replaceAll('Uni Core - ', ''), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text("$streamCredits credits earned"),
                              children: streamCourses.map((course) => _buildCourseCard(course)).toList(),
                            ),
                          );
                        }).toList(),
                      );
                    } 
                    
                    // --- Logic for all other normal categories ---
                    else {
                      List catCourses = groupedCourses[category]!;
                      if (catCourses.isEmpty) return const SizedBox.shrink();

                      int catCredits = catCourses.where((c) => c['status'] == 'Completed').fold(0, (sum, c) => sum + (c['credits'] as num).toInt());

                      return ExpansionTile(
                        title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text("$catCredits credits earned", style: TextStyle(color: Colors.grey.shade700)),
                        children: catCourses.map((course) => _buildCourseCard(course)).toList(),
                      );
                    }
                  }).toList(),
                ),
              ),
            ],
          ),
    );
  }
}