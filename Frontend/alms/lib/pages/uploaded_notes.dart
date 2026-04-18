import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:alms/widgets/user_session.dart';
import 'package:alms/widgets/note_card.dart';
import 'package:alms/widgets/app_background.dart';

class UploadedNotesPage extends StatefulWidget {
  const UploadedNotesPage({super.key});

  @override
  State<UploadedNotesPage> createState() =>
      _UploadedNotesPageState();
}

class _UploadedNotesPageState extends State<UploadedNotesPage> {
  List<Map<String, dynamic>> _myNotes = [];
  bool _loading = true;

  final String _host =
      Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';

  Future<void> _fetchMyNotes() async {
    setState(() => _loading = true);

    try {
      final res = await http.get(
      Uri.parse('http://$_host:8000/api/notes/all/${UserSession.userId}'),
      );

      final data = jsonDecode(res.body);

      if (data['success'] == true) {
        final uid = UserSession.userId;

        setState(() {
          _myNotes =
              List<Map<String, dynamic>>.from(data['notes'])
                  .where((n) => n['uploaded_by'] == uid)
                  .toList();

          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshAll() async {
    await _fetchMyNotes();
  }

  @override
  void initState() {
    super.initState();
    _fetchMyNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Uploaded Notes"),
        backgroundColor: const Color.fromARGB(255, 138, 201, 243),
        elevation: 0,
      ),

      body: AppBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _myNotes.isEmpty
                ? const Center(child: Text("No uploaded notes"))
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
                      itemCount: _myNotes.length,
                      itemBuilder: (_, i) {
                        final note = _myNotes[i];

                        return NoteCard(
                          note: note,
                          isSaved: false,
                          onToggleSave: () {},
                          onRefresh: _refreshAll,
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}