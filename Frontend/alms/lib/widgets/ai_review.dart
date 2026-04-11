import 'dart:convert';
import 'package:http/http.dart' as http;

class AiReviewService {
  static const String baseUrl = "http://10.0.2.2:8000";

  // 🤖 optional direct AI call (not needed anymore but useful)
  static Future<Map<String, dynamic>> evaluateNote(String text) async {
    final response = await http.post(
      Uri.parse("$baseUrl/review"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"text": text}),
    );

    return jsonDecode(response.body);
  }


  static Future<http.Response> uploadNote({
    required String title,
    required String description,
    required String course,
    required String uploaderId,
    required String filePath,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/api/notes/upload"),
    );

    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['course'] = course;
    request.fields['uploader_id'] = uploaderId;

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      filePath,
    ));

    return await request.send().then(
      (response) => http.Response.fromStream(response),
    );
  }

  // 📥 get notes
  static Future<List<dynamic>> getNotes() async {
    final response = await http.get(
      Uri.parse("$baseUrl/api/notes/all"),
    );

    final data = jsonDecode(response.body);
    return data['notes'];
  }
}