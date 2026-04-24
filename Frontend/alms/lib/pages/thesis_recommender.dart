import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart'; 
import '../widgets/app_drawer.dart';
import '../widgets/user_session.dart';

class ThesisDiscoveryPage extends StatefulWidget {
  const ThesisDiscoveryPage({super.key});

  @override
  State<ThesisDiscoveryPage> createState() => _ThesisDiscoveryPageState();
}

class _ThesisDiscoveryPageState extends State<ThesisDiscoveryPage> {
  List<dynamic> _recommendations = [];
  bool _loading = true;
  final String _host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('http://$_host:8000/api/recommend_thesis/${UserSession.userId}'));
      final data = jsonDecode(res.body);
      if (data['success']) {
        setState(() {
          _recommendations = data['recommendations'];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  // Improved Link Opener
  Future<void> _handleLink(String urlString) async {
    // If it's an ArXiv abstract link, we can try to force it to PDF if preferred
    // but standard launchUrl is safest
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening link: $e')),
      );
    }
  }

  void _showInterestSelector() {
    List<String> options = ['AI', 'Cybersecurity', 'Blockchain', 'Web Development', 'Machine Learning', 'Data Science', 'NLP', 'Robotics'];
    List<String> selected = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Select Research Interests"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((tag) => CheckboxListTile(
                title: Text(tag),
                value: selected.contains(tag),
                onChanged: (val) => setDialogState(() => val! ? selected.add(tag) : selected.remove(tag)),
              )).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                await http.post(
                  Uri.parse('http://$_host:8000/api/interests/update'),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({"user_id": UserSession.userId.toString(), "interests": selected}),
                );
                Navigator.pop(context);
                _fetchRecommendations();
              },
              child: const Text("Save & Search"),
            )
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Thesis Discovery"),
        backgroundColor: const Color.fromARGB(255, 138, 201, 243),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _showInterestSelector),
        ],
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // Background Restored
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Image.asset('assets/bg.png', fit: BoxFit.cover),
            ),
          ),
          _loading 
            ? const Center(child: CircularProgressIndicator()) 
            : _recommendations.isEmpty
              ? const Center(child: Text("No recommendations found. Try adding interests!"))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, 
                    childAspectRatio: 0.72, 
                    crossAxisSpacing: 12, 
                    mainAxisSpacing: 12
                  ),
                  itemCount: _recommendations.length,
                  itemBuilder: (context, i) {
                    final item = _recommendations[i];
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['domain'].toString().toUpperCase(),
                              style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                item['topic'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, height: 1.2),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("92% Match", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                InkWell(
                                  onTap: () => _handleLink(item['url']),
                                  child: const Icon(Icons.open_in_new, size: 20, color: Colors.blue),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}