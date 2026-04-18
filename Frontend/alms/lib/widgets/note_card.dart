import 'package:flutter/material.dart';
import 'package:alms/pages/note_preview.dart';

class NoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final bool isSaved;
  final VoidCallback onToggleSave;
  final Future<void> Function()? onRefresh;

  const NoteCard({
    super.key,
    required this.note,
    required this.isSaved,
    required this.onToggleSave,
    this.onRefresh,
  });

  String _ext(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'FILE';
  }

  Color _extColor(String ext) {
    switch (ext) {
      case 'PDF':
        return const Color(0xFFE24B4A);
      case 'DOC':
      case 'DOCX':
        return const Color(0xFF185FA5);
      case 'PPT':
      case 'PPTX':
        return const Color(0xFFBA7517);
      default:
        return const Color(0xFF888780);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String filename = (note['filename'] ?? '') as String;
    final String filePath = (note['file_path'] ?? '') as String;

    final String ext = _ext(filename);
    final Color color = _extColor(ext);

    final String imageUrl = "http://10.0.2.2:8000/$filePath";

    final int upvotes = note['upvotes'] ?? 0;
    final int comments = note['comments'] ?? 0;

    final int? aiScore = note['ai_score'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotePreviewPage(note: note),
          ),
        ).then((_) async {
          if (onRefresh != null) {
            await onRefresh!();
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              offset: Offset(0, 4),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ================= IMAGE =================
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: (filename.toLowerCase().endsWith('.jpg') ||
                              filename.toLowerCase().endsWith('.jpeg') ||
                              filename.toLowerCase().endsWith('.png'))
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image, size: 40),
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  ext == 'PDF'
                                      ? Icons.picture_as_pdf
                                      : ext == 'DOC' || ext == 'DOCX'
                                          ? Icons.description
                                          : ext == 'PPT' || ext == 'PPTX'
                                              ? Icons.slideshow
                                              : Icons.insert_drive_file,
                                  size: 48,
                                  color: color,
                                ),
                                const SizedBox(height: 6),
                                Text(ext),
                              ],
                            ),
                    ),

                    // ================= UPLOADER =================
                    if (note['uploader_name'] != null)
                      Positioned(
                        top: 6,
                        left: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            note['uploader_name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                    // ================= SAVE BUTTON =================
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: onToggleSave,
                        child: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved ? Colors.blue : Colors.white,
                        ),
                      ),
                    ),

                    // ================= AI SCORE =================
                    if (aiScore != null)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: aiScore >= 80
                                ? Colors.green
                                : aiScore >= 60
                                    ? Colors.orange
                                    : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "AI: $aiScore",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ================= TITLE + STATS =================
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    note['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  Text(
                    note['course'] ?? '',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      const Icon(Icons.thumb_up_alt_outlined,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text("$upvotes"),

                      const SizedBox(width: 12),

                      const Icon(Icons.comment,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text("$comments"),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}