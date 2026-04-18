import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:alms/widgets/user_session.dart';

class NotePreviewPage extends StatefulWidget {
  final Map<String, dynamic> note;

  const NotePreviewPage({super.key, required this.note});

  @override
  State<NotePreviewPage> createState() => _NotePreviewPageState();
}

class _NotePreviewPageState extends State<NotePreviewPage> {
  final String _host = "10.0.2.2";

  List comments = [];
  late bool isLiked;
  late int upvotes;

  final TextEditingController commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    isLiked = widget.note['isLiked'] == 1 || widget.note['isLiked'] == true;
    upvotes = widget.note['upvotes'] ?? 0;
    loadComments();
  }

  // ================= LOAD COMMENTS =================
  Future<void> loadComments() async {
    try {
      final res = await http.get(
        Uri.parse(
          "http://$_host:8000/api/notes/comments/${widget.note['note_id']}",
        ),
      );

      final data = jsonDecode(res.body);

      setState(() {
        comments = data['comments'];
      });
    } catch (_) {}
  }

  // ================= TOGGLE UPVOTE =================
  Future<void> toggleUpvote() async {
    try {
      final res = await http.post(
        Uri.parse("http://$_host:8000/api/notes/upvote"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "note_id": widget.note['note_id'],
          "user_id": UserSession.userId,
        }),
      );

      final data = jsonDecode(res.body);

      setState(() {
        isLiked = data['liked'];

        if (isLiked) {
          upvotes++;
        } else {
          upvotes = upvotes > 0 ? upvotes - 1 : 0;
        }
      });
    } catch (_) {}
  }

  // ================= ADD COMMENT =================
  Future<void> sendComment() async {
    if (commentController.text.isEmpty) return;

    try {
      await http.post(
        Uri.parse("http://$_host:8000/api/notes/comment"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "note_id": widget.note['note_id'],
          "user_id": UserSession.userId,
          "comment": commentController.text,
        }),
      );

      commentController.clear();
      loadComments();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;

    final String title = note['title'] ?? '';
    final String course = note['course'] ?? '';
    final String filename = note['filename'] ?? '';
    final String filePath = note['file_path'] ?? '';

    final String imageUrl = "http://$_host:8000/$filePath";

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
              height: 280,
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

            const SizedBox(height: 16),

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

            const SizedBox(height: 6),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Course: $course",
                style: const TextStyle(color: Colors.grey),
              ),
            ),

            const SizedBox(height: 10),

            // ================= UPVOTE =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isLiked
                          ? Icons.thumb_up
                          : Icons.thumb_up_alt_outlined,
                      color: isLiked ? Colors.blue : Colors.grey,
                    ),
                    onPressed: toggleUpvote,
                  ),
                  Text("$upvotes"),
                ],
              ),
            ),

            const SizedBox(height: 10),

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

            const SizedBox(height: 10),

            // ================= FEEDBACK =================
            if (feedback.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(feedback),
                ),
              ),

            const SizedBox(height: 20),

            // ================= COMMENTS TITLE =================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Comments",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ================= COMMENTS LIST =================
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              itemBuilder: (context, i) {
              final c = comments[i];

              return ListTile(
                title: Text(c['user_name']),
                subtitle: Text("${c['comment']}\n${c['created_at']}"),
              );
              },
            ),

            const SizedBox(height: 10),

            // ================= COMMENT BOX =================
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      decoration: const InputDecoration(
                        hintText: "Write a comment...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: sendComment,
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}