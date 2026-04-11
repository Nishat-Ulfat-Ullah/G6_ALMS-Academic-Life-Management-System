import 'dart:convert';
import 'dart:io'; // <-- Required to check Platform (Android vs iOS)
import 'package:http/http.dart' as http;

class StudyAnalyzerService {
  
  // Dynamically get the base URL depending on the platform
  static String get baseUrl {
    final host = Platform.isAndroid ? "10.0.2.2" : "127.0.0.1";
    return "http://$host:8000";
  }

  static Future<bool> addTask({
    required String userId,
    required String title,
    required String courseName,
    required String taskType,
    required String dueDate,
    required int estimatedHours,
  }) async {
    final url = Uri.parse('$baseUrl/api/tasks/add');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'title': title,
          'course_name': courseName,
          'task_type': taskType,
          'due_date': dueDate,
          'estimated_hours': estimatedHours,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error adding task: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getStudyLoad(String userId) async {
    final url = Uri.parse('$baseUrl/api/study_load/$userId');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      print('Error fetching study load: $e');
      return null;
    }
  }

  // --- NEW: Function to delete a task ---
  static Future<bool> deleteTask(String userId, String title) async {
    // Note how we use Uri parameters to send user_id and title to the backend
    final url = Uri.parse('$baseUrl/api/tasks/delete?user_id=$userId&title=$title');
    
    try {
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error deleting task: $e');
      return false;
    }
  }
}