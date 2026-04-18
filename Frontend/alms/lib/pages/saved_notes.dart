import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:alms/widgets/note_card.dart';
import 'package:alms/widgets/user_session.dart';
import 'package:alms/widgets/app_background.dart';

class SavedNotesPage extends StatefulWidget {
  const SavedNotesPage({super.key});

  @override
  State<SavedNotesPage> createState() => _SavedNotesPageState();
}

class _SavedNotesPageState extends State<SavedNotesPage> {
  List<Map<String, dynamic>> _savedNotes = [];
  bool _loading = true;

  final String _host =
      Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';

  @override
  void initState() {
    super.initState();
    _fetchSavedNotes();
  }

  Future<void> _fetchSavedNotes() async {
    final uid = UserSession.userId;
    if (uid == null) return;

    setState(() => _loading = true);

    try {
      final res = await http.get(
        Uri.parse('http://$_host:8000/api/notes/saved/$uid'),
      );

      final data = jsonDecode(res.body);

      if (data['success'] == true) {
        setState(() {
          _savedNotes =
              List<Map<String, dynamic>>.from(data['notes']);
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _unsaveNote(int noteId) async {
    final uid = UserSession.userId;
    if (uid == null) return;

    try {
      await http.post(
        Uri.parse('http://$_host:8000/api/notes/unsave'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": uid,
          "note_id": noteId,
        }),
      );

      await _fetchSavedNotes();
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    await _fetchSavedNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Notes"),
        backgroundColor: const Color.fromARGB(255, 138, 201, 243),
        elevation: 0,
      ),

      body: AppBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _savedNotes.isEmpty
                ? const Center(child: Text("No saved notes"))
                : RefreshIndicator(
                    onRefresh: _refreshAll,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _savedNotes.length,
                      itemBuilder: (_, i) {
                        final note = _savedNotes[i];

                        return NoteCard(
                          note: note,
                          isSaved: true,
                          onToggleSave: () =>
                              _unsaveNote(note['note_id']),
                          onRefresh: _refreshAll,
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}