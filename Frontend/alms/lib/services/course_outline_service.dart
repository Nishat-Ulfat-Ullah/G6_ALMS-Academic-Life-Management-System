import 'dart:convert';
import 'package:http/http.dart' as http;

class CourseOutlineService {
  final String baseUrl = "http://10.0.2.2:8000";

  Future<bool> updateCourse(Map<String, dynamic> courseData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/courses/update"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(courseData),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getProgress(String userId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/courses/progress/$userId"),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching progress: $e");
    }
    return null;
  }

  // --- NEW: Delete Course ---
  Future<bool> deleteCourse(String userId, String courseCode) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/courses/delete"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "course_code": courseCode}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}