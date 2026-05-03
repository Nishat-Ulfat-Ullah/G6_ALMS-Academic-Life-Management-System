import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'dart:io';

class CourseOutlineService {
  // final String baseUrl = Platform.isAndroid ? "http://10.0.2.2:8000" : "http://localhost:8000";
  final String baseUrl = "http://g6-alms-academic-life-management-system.onrender.com:8000";

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

  // --- STEP 3: EXTERNAL API CALL ---
  Future<Map<String, dynamic>?> getMarketData(String major) async {
    try {
      // This matches your @app.get("/api/market-data/{major}") backend route
      final response = await http.get(
        Uri.parse("$baseUrl/api/market-data/$major"),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching market data: $e");
    }
    return null;
  }
}