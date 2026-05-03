import 'dart:convert';
// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_drawer.dart';
import '../widgets/user_session.dart';

class ThesisRecommenderPage extends StatefulWidget {
  const ThesisRecommenderPage({super.key});

  @override
  State<ThesisRecommenderPage> createState() => _ThesisRecommenderPageState();
}

class _ThesisRecommenderPageState extends State<ThesisRecommenderPage> {
  List<dynamic> _recommendations = [];
  bool _loading = false;
  List<String> _selectedInterests = [];
  List<String> _availableInterests = [];

  // final String _host = Platform.isAndroid ? "10.0.2.2" : "127.0.0.1";
  final String _host = "g6-alms-academic-life-management-system.onrender.com";

  static const List<String> _defaultInterests = [
    "AI", "Machine Learning", "NLP", "Cybersecurity",
    "Blockchain", "Robotics", "Data Science", "Computer Vision",
    "IoT", "Cloud Computing", "Edge Computing", "Bioinformatics"
  ];

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    await Future.wait([
      _loadSavedInterests(),
      _loadAvailableInterests(),
    ]);
    await fetchRecommendations();
  }

  Future<void> _loadSavedInterests() async {
    try {
      final res = await http.get(
        // Uri.parse("http://$_host:8000/api/interests/${UserSession.userId}"),
        Uri.parse("https://$_host/api/interests/${UserSession.userId}"),
      );
      final data = jsonDecode(res.body);
      if (data["success"] == true) {
        setState(() {
          _selectedInterests = List<String>.from(data["interests"] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Failed to load interests: $e");
    }
  }

  Future<void> _loadAvailableInterests() async {
    try {
      final res = await http.get(
        // Uri.parse("http://$_host:8000/api/interests/options"),
        Uri.parse("https://$_host/api/interests/options"),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["options"] != null) {
          setState(() {
            _availableInterests = List<String>.from(data["options"]);
          });
          return;
        }
      }
    } catch (_) {}
    setState(() => _availableInterests = _defaultInterests);
  }

  Future<void> fetchRecommendations() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        // Uri.parse("http://$_host:8000/api/generate_thesis/${UserSession.userId}"),
        Uri.parse("https://$_host/api/generate_thesis/${UserSession.userId}"),
      );
      final data = jsonDecode(res.body);
      if (data["success"] == true) {
        setState(() => _recommendations = List.from(data["ideas"] ?? []));
      } else {
        setState(() => _recommendations = []);
        _showError(data["error"] ?? "Failed to load ideas");
      }
    } catch (e) {
      setState(() => _recommendations = []);
      _showError("Network error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> openLink(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      _showError("Could not open link");
    }
  }

  // ---------------- INTEREST DIALOG ----------------
  void showInterestDialog() {
    List<String> temp = List.from(_selectedInterests);
    final TextEditingController customController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Select Interests"),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customController,
                          decoration: const InputDecoration(
                            hintText: "Add custom interest...",
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final val = customController.text.trim();
                          if (val.isNotEmpty && !_availableInterests.contains(val)) {
                            setStateDialog(() {
                              _availableInterests.add(val);
                              temp.add(val);
                            });
                            customController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: _availableInterests.map((e) {
                          return CheckboxListTile(
                            dense: true,
                            title: Text(e),
                            value: temp.contains(e),
                            onChanged: (val) => setStateDialog(() {
                              val == true ? temp.add(e) : temp.remove(e);
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final res = await http.post(
                    // Uri.parse("http://$_host:8000/api/interests/update"),
                    Uri.parse("https://$_host/api/interests/update"),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({
                      "user_id": UserSession.userId.toString(),
                      "interests": temp,
                    }),
                  );
                  final data = jsonDecode(res.body);
                  if (data["success"] == true) {
                    setState(() => _selectedInterests = List.from(temp));
                    fetchRecommendations();
                  } else {
                    _showError("Failed to save interests");
                  }
                },
                child: const Text("Save & Regenerate"),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------- DETAIL BOTTOM SHEET ----------------
  void showThesisDetail(dynamic item) {
    final List paperUrls = item["paper_urls"] ?? [];
    final List relatedResearch = item["related_research"] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              Text(
                item["title"] ?? "Untitled",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _difficultyBadge(item["difficulty"]),
              const SizedBox(height: 16),

              _sectionLabel("Description"),
              const SizedBox(height: 4),
              Text(item["description"] ?? "",
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),

              if (item["methodology"] != null &&
                  item["methodology"].toString().isNotEmpty) ...[
                _sectionLabel("Methodology"),
                const SizedBox(height: 4),
                Text(item["methodology"].toString(),
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 16),
              ],

              _sectionLabel("Tools & Technologies"),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: (item["tools"] ?? [])
                    .map<Widget>((t) => Chip(
                          label: Text(t.toString(),
                              style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.blue.shade50,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),

              if (relatedResearch.isNotEmpty) ...[
                _sectionLabel("Related Research (${relatedResearch.length})"),
                const SizedBox(height: 6),
                ...List.generate(relatedResearch.length, (i) {
                  final url = i < paperUrls.length
                      ? paperUrls[i].toString()
                      : null;
                  final hasUrl = url != null && url.isNotEmpty;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.article_outlined,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            relatedResearch[i].toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        if (hasUrl)
                          GestureDetector(
                            onTap: () => openLink(url),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.open_in_new,
                                  size: 16, color: Colors.blue),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- HELPERS ----------------
  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13));
  }

  Widget _difficultyBadge(String? difficulty) {
    final colors = {
      "Low": Colors.green,
      "Medium": Colors.orange,
      "High": Colors.red,
    };
    final color = colors[difficulty] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        difficulty ?? "Unknown",
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ---------------- CARD ----------------
  Widget buildCard(dynamic item) {
    return GestureDetector(
      onTap: () => showThesisDetail(item),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item["title"] ?? "Untitled",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              _difficultyBadge(item["difficulty"]),
              const SizedBox(height: 6),
              Text(
                item["description"] ?? "",
                style: const TextStyle(fontSize: 10, color: Colors.black87),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              const Divider(height: 8),
              Wrap(
                spacing: 3,
                runSpacing: 2,
                children: (item["tools"] ?? [])
                    .take(2)
                    .map<Widget>((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Text(
                            t.toString(),
                            style: const TextStyle(
                                fontSize: 9, color: Colors.blue),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text("Tap for details",
                      style: TextStyle(fontSize: 9, color: Colors.grey)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios, size: 9, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    final cardWidth = (MediaQuery.of(context).size.width - 36) / 2;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Thesis Recommender"),
        backgroundColor: const Color.fromARGB(255, 138, 201, 243),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: showInterestDialog,
                tooltip: "Set Interests",
              ),
              if (_selectedInterests.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.red,
                    child: Text(
                      "${_selectedInterests.length}",
                      style: const TextStyle(
                          fontSize: 9, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchRecommendations,
            tooltip: "Regenerate",
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.asset("assets/bg.png", fit: BoxFit.cover),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_recommendations.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text("No recommendations yet.",
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: showInterestDialog,
                    icon: const Icon(Icons.add),
                    label: const Text("Set Your Interests"),
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _recommendations.map((item) {
                  return SizedBox(
                    width: cardWidth,
                    child: buildCard(item),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}