import 'package:flutter/material.dart';

class NotePreviewPage extends StatelessWidget {
  final Map<String, dynamic> note;

  const NotePreviewPage({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    final String title = note['title'] ?? '';
    final String course = note['course'] ?? '';
    final String filename = note['filename'] ?? '';
    final String filePath = note['file_path'] ?? '';

    final String imageUrl = "http://10.0.2.2:8000/$filePath";

    final int? aiScore = note['ai_score'];
    final String feedback = note['feedback'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Note Preview"),
        backgroundColor: const Color.fromARGB(255, 138, 201, 243),
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ================= IMAGE =================
            Container(
              width: double.infinity,
              height: 300,
              color: Colors.grey[200],
              child: (filename.toLowerCase().endsWith('.jpg') ||
                      filename.toLowerCase().endsWith('.jpeg') ||
                      filename.toLowerCase().endsWith('.png'))
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 60),
                    )
                  : const Center(
                      child: Icon(Icons.insert_drive_file, size: 80),
                    ),
            ),

            const SizedBox(height: 20),

            // ================= TITLE =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ================= COURSE =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Course: $course",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ================= AI SCORE =================
            if (aiScore != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "AI Score: $aiScore",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: aiScore >= 80
                        ? Colors.green
                        : aiScore >= 60
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ================= FEEDBACK =================
            if (feedback.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(feedback),
                ),
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}