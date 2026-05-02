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
  double targetGoal = 3.5;

  // Market Data Variables
  int jobCount = 0;
  double avgSalary = 0;

  final List<String> mainCategories = [
    'University Core',
    'GenEd Electives',
    'School Core',
    'Program Core',
    'Program Elective',
    'Project/Internship/Thesis',
    'Other'
  ];

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
    setState(() => isLoading = true);
    try {
      final data = await _service.getProgress(UserSession.userId!);
      final market = await _service.getMarketData(selectedMajor);
      setState(() {
        if (data != null) courses = data['courses'];
        if (market != null) {
          jobCount = (market['job_count'] ?? 0).toInt();
          avgSalary = (market['avg_salary'] ?? 0.0).toDouble();
        }
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading data: $e");
      setState(() => isLoading = false);
    }
  }

  // --- Calculations ---
  int get targetCredits => selectedMajor == 'CSE' ? 136 : 124;
  int get totalCoursesCount => selectedMajor == 'CSE' ? 45 : 41;

  int get completedCredits {
    int total = 0;
    for (var c in courses) {
      if (c['status'] == 'Completed') {
        total += (c['credits'] as num).toInt();
      }
    }
    return total;
  }

  int get creditShortfall => targetCredits - completedCredits;

  double get currentCGPA {
    var completed = courses.where((c) => c['status'] == 'Completed').toList();
    if (completed.isEmpty) return 0.0;
    double sumGP = completed.fold(0.0, (sum, c) => sum + (c['grade_point'] ?? 0.0));
    return sumGP / completed.length;
  }

  String get estimatedGraduation {
    if (creditShortfall <= 0) return "Ready to Graduate!";
    double avgCreditsPerSem = 12.0;
    int semesters = (creditShortfall / avgCreditsPerSem).ceil();
    DateTime now = DateTime.now();
    List<String> cycle = ['Spring', 'Summer', 'Fall'];
    int currentIdx = now.month <= 5 ? 0 : (now.month <= 8 ? 1 : 2);
    int targetIdx = (currentIdx + semesters) % 3;
    int yearsToAdd = (currentIdx + semesters) ~/ 3;
    return "${cycle[targetIdx]} ${now.year + yearsToAdd}";
  }

  String get requiredGradeForecast {
    int completedCount = courses.where((c) => c['status'] == 'Completed').length;
    int remainingCount = totalCoursesCount - completedCount;
    if (remainingCount <= 0) return "Goal Achieved!";
    double currentSumGP = courses.where((c) => c['status'] == 'Completed').fold(0.0, (sum, c) => sum + (c['grade_point'] ?? 0.0));
    double requiredGP = ((targetGoal * totalCoursesCount) - currentSumGP) / remainingCount;
    if (requiredGP > 4.0) return "Goal Unreachable (${requiredGP.toStringAsFixed(2)} avg needed)";
    if (requiredGP < 0) return "Goal secured!";
    return "Need avg ${requiredGP.toStringAsFixed(2)} in remaining courses";
  }

  // --- Logic Methods ---

void _showAddCourseDialog({Map? existingCourse, bool forceComplete = false}) {
  final nameController = TextEditingController(text: existingCourse?['course_name'] ?? '');
  final codeController = TextEditingController(text: existingCourse?['course_code'] ?? '');
  final creditController = TextEditingController(text: existingCourse?['credits']?.toString() ?? '3');
  final gradeController = TextEditingController(text: existingCourse?['grade_point']?.toString() ?? '4.0');
  
  String status = forceComplete ? 'Completed' : (existingCourse?['status'] ?? 'Remaining');
  
  // Initial logic to determine if the course is a Uni Core stream or a main category
  String initialStream = existingCourse?['stream'] ?? 'Program Core';
  String selectedMainCategory = uniCoreStreams.contains(initialStream) ? 'University Core' : initialStream;
  String currentStream = initialStream;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(existingCourse == null ? "Add Course" : "Update Course"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeController, decoration: const InputDecoration(labelText: "Course Code")),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Course Name")),
              TextField(controller: creditController, decoration: const InputDecoration(labelText: "Credits"), keyboardType: TextInputType.number),
              if (status == 'Completed')
                TextField(controller: gradeController, decoration: const InputDecoration(labelText: "Grade Point (0.0-4.0)"), keyboardType: TextInputType.number),
              const SizedBox(height: 15),
              
              // First Dropdown: Primary Categories (Other removed)
              DropdownButtonFormField<String>(
                value: selectedMainCategory,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  'University Core',
                  'GenEd Electives',
                  'School Core',
                  'Program Core',
                  'Program Elective',
                  'Project/Internship/Thesis',
                ].map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat, style: const TextStyle(fontSize: 14)),
                )).toList(),
                onChanged: (v) {
                  setDialogState(() {
                    selectedMainCategory = v!;
                    if (selectedMainCategory == 'University Core') {
                      currentStream = uniCoreStreams.first;
                    } else {
                      currentStream = selectedMainCategory;
                    }
                  });
                },
              ),

              // Second Dropdown: Specific Streams
              if (selectedMainCategory == 'University Core') ...[
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: uniCoreStreams.contains(currentStream) ? currentStream : uniCoreStreams.first,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Select Stream",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: uniCoreStreams.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s.replaceAll('Uni Core - ', ''),
                      style: const TextStyle(fontSize: 13),
                    ),
                  )).toList(),
                  onChanged: (v) {
                    setDialogState(() => currentStream = v!);
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (existingCourse != null)
            TextButton(
              onPressed: () async {
                await _service.deleteCourse(UserSession.userId!, existingCourse['course_code']);
                Navigator.pop(context);
                _loadData();
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final courseData = {
                "user_id": UserSession.userId,
                "course_code": codeController.text.toUpperCase(),
                "course_name": nameController.text,
                "stream": currentStream, 
                "status": status,
                "credits": int.tryParse(creditController.text) ?? 3,
                "grade_point": double.tryParse(gradeController.text) ?? 0.0,
              };
              await _service.updateCourse(courseData);
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

  // --- UI Builders ---

  Widget _buildCGPAPlanner() {
    final TextEditingController targetController = TextEditingController(text: targetGoal.toString());
    targetController.selection = TextSelection.fromPosition(TextPosition(offset: targetController.text.length));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Current CGPA", style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(currentCGPA.toStringAsFixed(2), style: const TextStyle(color: Colors.blue, fontSize: 28, fontWeight: FontWeight.bold)),
                ]),
              ),
              Container(height: 40, width: 1, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 16)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Target Goal", style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
                  Row(children: [
                    const Icon(Icons.edit, size: 14, color: Colors.blueAccent),
                    const SizedBox(width: 6),
                    SizedBox(width: 60, child: TextField(
                      controller: targetController,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final val = double.tryParse(v);
                        if (val != null) setState(() => targetGoal = val);
                      },
                    )),
                  ]),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.auto_graph_rounded, color: Colors.orange.shade800, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(requiredGradeForecast, style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600, fontSize: 13))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketMotivation() {
    bool hasShortfall = creditShortfall > 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasShortfall ? Colors.red.shade100 : Colors.green.shade100),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Credit Shortfall", style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
              Text("$creditShortfall Credits", style: TextStyle(color: hasShortfall ? Colors.red.shade700 : Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
            ])),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text("Est. Graduation", style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(estimatedGraduation, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ])),
          ]),
          const Divider(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Market Demand", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              Text("$jobCount Openings", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text("Avg. Starting Salary", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              Text("£${avgSalary.toStringAsFixed(0)} / yr", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ]),
          ]),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map course) {
    final bool isDone = course['status'] == 'Completed';

    return Dismissible(
      key: Key(course['course_code']),
      // Swipe Left (Red Delete)
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Confirm Delete
          bool confirm = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Delete Course"),
              content: Text("Are you sure you want to remove ${course['course_code']}?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
              ],
            ),
          );
          if (confirm) {
            await _service.deleteCourse(UserSession.userId!, course['course_code']);
            _loadData();
          }
          return confirm;
        } else {
          // Swipe Right (Edit)
          _showAddCourseDialog(existingCourse: course);
          return false; // Don't actually dismiss the widget
        }
      },
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
      child: Card(
        elevation: isDone ? 0 : 2,
        color: isDone ? Colors.green.shade50 : Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          title: Text(
            course['course_code'],
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDone ? Colors.green.shade700 : Colors.black87),
          ),
          subtitle: Text(
              "${course['course_name']} • ${course['credits']} Cr ${isDone ? '\nGrade: ${course['grade_point']}' : ''}"),
          isThreeLine: isDone,
          trailing: IconButton(
            icon: Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isDone ? Colors.green : Colors.orange),
            onPressed: () async {
              if (isDone) {
                await _service.updateCourse({
                  ...course,
                  "user_id": UserSession.userId,
                  "status": "Remaining",
                  "grade_point": 0.0
                });
                _loadData();
              } else {
                _showAddCourseDialog(existingCourse: course, forceComplete: true);
              }
            },
          ),
        ),
      ),
    );
  }

  Map<String, List<dynamic>> get groupedCourses {
    Map<String, List<dynamic>> map = {};
    for (var cat in mainCategories) map[cat] = [];
    for (var stream in uniCoreStreams) map[stream] = [];
    for (var c in courses) {
      String stream = c['stream'];
      if (map.containsKey(stream)) {
        map[stream]!.add(c);
      } else {
        map['Other']?.add(c);
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    double progressPercent = (completedCredits / targetCredits).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Degree Progress"),
        actions: [
          DropdownButton<String>(
            value: selectedMajor,
            underline: Container(),
            items: ['CSE', 'CS'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
            onChanged: (v) {
              setState(() => selectedMajor = v!);
              _loadData();
            },
          ),
          const SizedBox(width: 15),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddCourseDialog(), child: const Icon(Icons.add)),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.blue.shade50,
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text("$selectedMajor Progress", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("$completedCredits / $targetCredits", style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: progressPercent, minHeight: 10, borderRadius: BorderRadius.circular(10)),
                  ]),
                ),
                _buildCGPAPlanner(),
                _buildMarketMotivation(),
                Expanded(
                  child: ListView(
                    children: mainCategories.map((category) {
                      if (category == 'University Core') {
                        return ExpansionTile(
                          title: const Text('University Core', style: TextStyle(fontWeight: FontWeight.bold)),
                          children: uniCoreStreams.map((stream) {
                            List streamCourses = groupedCourses[stream] ?? [];
                            if (streamCourses.isEmpty) return const SizedBox.shrink();
                            return ExpansionTile(
                              title: Text(stream.replaceAll('Uni Core - ', ''), style: const TextStyle(fontSize: 14)),
                              children: streamCourses.map((c) => _buildCourseCard(c)).toList(),
                            );
                          }).toList(),
                        );
                      } else {
                        List catCourses = groupedCourses[category] ?? [];
                        if (catCourses.isEmpty) return const SizedBox.shrink();
                        return ExpansionTile(
                          title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
                          children: catCourses.map((c) => _buildCourseCard(c)).toList(),
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