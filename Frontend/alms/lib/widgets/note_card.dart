import 'package:flutter/material.dart';

class NoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final bool isSaved;
  final VoidCallback onToggleSave;

  const NoteCard({
    super.key,
    required this.note,
    required this.isSaved,
    required this.onToggleSave,
  });

  String _ext(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'FILE';
  }

  Color _extColor(String ext) {
    switch (ext) {
      case 'PDF':  return const Color(0xFFE24B4A);
      case 'DOC':
      case 'DOCX': return const Color(0xFF185FA5);
      case 'PPT':
      case 'PPTX': return const Color(0xFFBA7517);
      default:    return const Color(0xFF888780);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filename = (note['filename'] ?? '') as String;
    final ext = _ext(filename);
    final color = _extColor(ext);

    return GestureDetector(
      onTap: () { /* TODO: open/download */ },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
          boxShadow: const [
            BoxShadow(color: Colors.black12, offset: Offset(0, 4), blurRadius: 4),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                ),
                child: Stack(children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          ext == 'PDF' ? Icons.picture_as_pdf_rounded
                            : ext == 'DOC' || ext == 'DOCX' ? Icons.description_rounded
                            : ext == 'PPT' || ext == 'PPTX' ? Icons.slideshow_rounded
                            : Icons.insert_drive_file_rounded,
                          size: 48, color: color,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(ext,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                        ),
                      ],
                    ),
                  ),
                  if (note['uploader_name'] != null)
                    Positioned(
                      top: 6, left: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(note['uploader_name'],
                          style: const TextStyle(color: Colors.white, fontSize: 9),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(note['title'] ?? '',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(note['course'] ?? '',
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onToggleSave,
                  child: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    size: 18,
                    color: isSaved
                        ? const Color.fromARGB(255, 138, 201, 243)
                        : Colors.grey,
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}