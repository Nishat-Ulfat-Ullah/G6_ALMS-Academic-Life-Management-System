import 'package:flutter/material.dart';
import '../services/study_analyzer_service.dart';
import 'add_task_screen.dart';

class StudyDashboardScreen extends StatefulWidget {
  final String userId;

  const StudyDashboardScreen({super.key, required this.userId});

  @override
  _StudyDashboardScreenState createState() => _StudyDashboardScreenState();
}

class _StudyDashboardScreenState extends State<StudyDashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final data = await StudyAnalyzerService.getStudyLoad(widget.userId);
    setState(() {
      _dashboardData = data;
      _isLoading = false;
    });
  }

  Color _getUrgencyColor(String urgency) {
    return urgency == 'High' ? Colors.redAccent : Colors.orangeAccent;
  }

  Color _getStatusColor(String status) {
    if (status.contains('Critical')) return Colors.red.shade100;
    if (status.contains('Moderate')) return Colors.orange.shade100;
    return Colors.green.shade100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Study Load'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildDashboardBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddTaskScreen(userId: widget.userId),
            ),
          );
          _fetchData(); // Refresh data after coming back from Add Task
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  Widget _buildDashboardBody() {
    if (_dashboardData == null ||
        _dashboardData!['distribution_plan'] == null ||
        (_dashboardData!['distribution_plan'] as List).isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            const Center(
              child: Text(
                'No upcoming deadlines.\nEnjoy your free time!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    final summary = _dashboardData!['summary'];
    final plan = _dashboardData!['distribution_plan'] as List<dynamic>;

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // AI Workload Summary Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(summary['workload_status']),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    summary['workload_status'],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stat Cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard('Exams', '${summary['upcoming_exams']}'),
              _buildStatCard('Tasks', '${summary['total_deadlines']}'),
              _buildStatCard('Hrs/Day', '${summary['recommended_daily_study_hours']}'),
            ],
          ),
          const SizedBox(height: 24),

          const Text(
            'Recommended Action Plan',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Swipe left to mark a task as done',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // Task List with Swipe-to-Delete
          ...plan.map((task) {
            final taskKey = Key('${task['task']}_${task['course']}');

            return Dismissible(
              key: taskKey,
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "DONE",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.check_circle, color: Colors.white),
                  ],
                ),
              ),
              onDismissed: (direction) async {
                // Call backend to delete
                final success = await StudyAnalyzerService.deleteTask(
                  widget.userId,
                  task['task'],
                );

                if (success) {
                  // Re-fetch to let the AI recalculate the new workload summary
                  _fetchData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${task['task']} completed!')),
                  );
                } else {
                  // Refresh to bring the card back if deletion failed
                  _fetchData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error updating task status')),
                  );
                }
              },
              child: Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: _getUrgencyColor(task['urgency']), width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  title: Text(
                    task['task'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${task['course']} • ${task['type']}'),
                      const SizedBox(height: 4),
                      Text(
                        task['suggested_action'],
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${task['days_left']}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Text('Days Left', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(title, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}