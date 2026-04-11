import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:alms/widgets/user_session.dart';

class UploadNoteSheet extends StatefulWidget {
  final VoidCallback onUploaded;
  const UploadNoteSheet({super.key, required this.onUploaded});

  @override
  State<UploadNoteSheet> createState() => _UploadNoteSheetState();
}

class _UploadNoteSheetState extends State<UploadNoteSheet> {
  final _titleCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _courseCtrl = TextEditingController();
  File? _file;
  bool _uploading = false;

  final String _host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) return;

      setState(() {
        _file = File(result.files.single.path!);
      });

      print("Picked file: ${_file!.path}");
    } catch (e) {
      print("File picker error: $e");
    }
  }

  Future<void> _upload() async {
    final uid = UserSession.userId;

    if (uid == null) {
      _snack('Not logged in');
      return;
    }

    if (_titleCtrl.text.isEmpty ||
        _courseCtrl.text.isEmpty ||
        _file == null) {
      _snack('Please fill title, course and pick a file');
      return;
    }

    setState(() => _uploading = true);

    final req = http.MultipartRequest(
      'POST',
      Uri.parse('http://$_host:8000/api/notes/upload'),
    );

    req.fields['title'] = _titleCtrl.text.trim();
    req.fields['description'] = _descCtrl.text.trim();
    req.fields['course'] = _courseCtrl.text.trim();
    req.fields['uploader_id'] = uid.toString();

    req.files.add(
      await http.MultipartFile.fromPath('file', _file!.path),
    );

    try {
      final res = await http.Response.fromStream(await req.send());
      final data = jsonDecode(res.body);

      if (data['success'] == true) {
        widget.onUploaded(); // refresh notes list

        if (mounted) Navigator.pop(context);

        _snack('Note uploaded successfully');

        // ✅ OPTIONAL (DEBUG ONLY)
        // print("AI Score: ${data['ai_score']}");
      } else {
        _snack(data['error'] ?? 'Upload failed');
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Upload Note',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 12),
            _field(_titleCtrl, 'Title'),
            const SizedBox(height: 10),
            _field(_descCtrl, 'Description (optional)', maxLines: 2),
            const SizedBox(height: 10),
            _field(_courseCtrl, 'Course (e.g. CSE 101)'),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_file == null
                  ? 'Choose File'
                  : _file!.path.split('/').last),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(14)),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _uploading ? null : _upload,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(14),
                backgroundColor: const Color.fromARGB(255, 138, 201, 243),
              ),
              child: _uploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Upload',
                      style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}