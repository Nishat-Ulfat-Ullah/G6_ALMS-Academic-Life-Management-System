import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:alms/widgets/app_drawer.dart';
import 'package:alms/widgets/user_session.dart';
import 'package:alms/widgets/note_card.dart';
import 'package:alms/widgets/upload_note.dart';

class BrowseNotes extends StatefulWidget {
  const BrowseNotes({super.key});

  @override
  State<BrowseNotes> createState() => _BrowseNotesState();
}

class _BrowseNotesState extends State<BrowseNotes> {
  String _filter = 'All';
  String _search = '';
  List<Map<String, dynamic>> _notes = [];
  Set<int> _saved = {};
  bool _loading = true;

  final String _host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';

  @override
  void initState() { super.initState(); _loadAll(); }

Future<void> _loadAll() =>
    Future.wait([_fetchNotes()]);

  Future<void> _fetchNotes() async {
    try {
      final res  = await http.get(Uri.parse('http://$_host:8000/api/notes/all'));
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() { _notes = List<Map<String, dynamic>>.from(data['notes']); _loading = false; });
      }
    } catch (_) { setState(() => _loading = false); }
  }

  // Future<void> _fetchSaved() async {
  //   final uid = UserSession.userId;
  //   if (uid == null) return;
  //   try {
  //     final res  = await http.get(Uri.parse('http://$_host:8000/api/notes/saved/$uid'));
  //     final data = jsonDecode(res.body);
  //     if (data['success'] == true) {
  //       setState(() => _saved = List.from(data['notes']).map((n) => n['id'] as int).toSet());
  //     }
  //   } catch (_) {}
  // }

  Future<void> _toggleSave(int id) async {
    final uid     = UserSession.userId; if (uid == null) return;
    final wasSaved = _saved.contains(id);
    setState(() => wasSaved ? _saved.remove(id) : _saved.add(id));
    try {
      if (wasSaved) {
        await http.delete(Uri.parse('http://$_host:8000/api/notes/unsave/$uid/$id'));
      } else {
        await http.post(Uri.parse('http://$_host:8000/api/notes/save'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': uid, 'note_id': id}));
      }
    } catch (_) {
      setState(() => wasSaved ? _saved.add(id) : _saved.remove(id));
    }
  }

  List<Map<String, dynamic>> get _filtered => _notes.where((n) =>
    (_filter == 'All' || (n['course'] ?? '').toString().toUpperCase().contains(_filter)) &&
    (n['title'] ?? '').toLowerCase().contains(_search.toLowerCase())
  ).toList();

void _openUpload() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: UploadNoteSheet(onUploaded: _fetchNotes),
      );
    },
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 138, 201, 243),
        title: const Text('Browse Notes'),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openUpload,
        backgroundColor: const Color.fromARGB(255, 138, 201, 243),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Stack(children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.4,
            child: Image.asset('assets/bg.png', fit: BoxFit.cover),
          ),
        ),
        Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (v) => setState(() => _filter = v),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Text(_filter),
                    const Icon(Icons.arrow_drop_down),
                  ]),
                ),
                itemBuilder: (_) =>
                    ['All', 'CSE', 'CHE', 'PHY', 'MAT', 'BIO']
                        .map((e) => PopupMenuItem(value: e, child: Text(e)))
                        .toList(),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(
                        child: Text('No notes available.',
                            style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: _loadAll,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, crossAxisSpacing: 10,
                            mainAxisSpacing: 10, childAspectRatio: 0.75,
                          ),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final note = _filtered[i];
                            final id = note['note_id'];
                            return NoteCard(
                              note: note,
                              isSaved: _saved.contains(id),
                              onToggleSave: () => _toggleSave(id),
                            );
                          },
                        ),
                      ),
          ),
        ]),
      ]),
    );
  }
}