import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:alms/widgets/user_session.dart';
import 'package:alms/widgets/note_card.dart';

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

  Future<void> _fetchSavedNotes() async {
    final uid = UserSession.userId;
    if (uid == null) return;

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

  @override
  void initState() {
    super.initState();
    _fetchSavedNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Notes"),
        backgroundColor:
            const Color.fromARGB(255, 138, 201, 243),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _savedNotes.isEmpty
              ? const Center(child: Text("No saved notes"))
              : GridView.builder(
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
                      onToggleSave: () {},
                    );
                  },
                ),
    );
  }
}