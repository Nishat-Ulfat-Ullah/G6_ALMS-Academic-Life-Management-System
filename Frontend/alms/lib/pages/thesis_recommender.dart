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
  // This persists the selections while the app is open
  List<String> _currentlySelectedInterests = [];
  final String _host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  // New: Combined loader to get interests AND recommendations
  Future<void> _initialLoad() async {
    await _fetchSavedInterests();
    await _fetchRecommendations();
  }

  Future<void> _fetchSavedInterests() async {
    try {
      final res = await http.get(Uri.parse('http://$_host:8000/api/interests/${UserSession.userId}'));
      final data = jsonDecode(res.body);
      if (data['success']) {
        setState(() {
          _currentlySelectedInterests = List<String>.from(data['interests']);
        });
      }
    } catch (e) {
      debugPrint("Error loading interests: $e");
    }
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

  Future<void> _handleLink(String urlString) async {
    final Uri url = Uri.parse(urlString.trim());
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showInterestSelector() {
    List<String> options = ['AI', 'Cybersecurity', 'Blockchain', 'Web Development', 'Machine Learning', 'Data Science', 'NLP', 'Robotics'];
    
    // This local list starts as a copy of our persistent list
    List<String> tempSelected = List.from(_currentlySelectedInterests);

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
                value: tempSelected.contains(tag),
                onChanged: (val) {
                  setDialogState(() {
                    if (val == true) {
                      tempSelected.add(tag);
                    } else {
                      tempSelected.remove(tag);
                    }
                  });
                },
              )).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                // Save to Backend
                await http.post(
                  Uri.parse('http://$_host:8000/api/interests/update'),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "user_id": UserSession.userId.toString(), 
                    "interests": tempSelected
                  }),
                );

                // Update Local UI State so next time it shows correctly
                setState(() {
                  _currentlySelectedInterests = List.from(tempSelected);
                });

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
                    crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 12, mainAxisSpacing: 12
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
                            Text(item['domain'].toString().toUpperCase(),
                              style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(item['topic'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, height: 1.2),
                                maxLines: 5, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("${item['match_percentage']}% Match", 
                                  style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
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