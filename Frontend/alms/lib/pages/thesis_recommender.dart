import 'dart:convert';
import 'dart:io';
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

  // Dynamic interest pool — fetched from backend or falls back to defaults
  List<String> _availableInterests = [];

  final String _host = Platform.isAndroid ? "10.0.2.2" : "127.0.0.1";

  // Default interests shown if backend returns nothing
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
      _loadSavedInterests(),   // load what user already picked
      _loadAvailableInterests(), // load the interest pool
    ]);
    await fetchRecommendations();
  }

  // Load saved interests from DB so checkboxes reflect real state
  Future<void> _loadSavedInterests() async {
    try {
      final res = await http.get(
        Uri.parse("http://$_host:8000/api/interests/${UserSession.userId}"),
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

  // Optionally load dynamic interest options from backend
  // Falls back to hardcoded defaults if endpoint doesn't exist
  Future<void> _loadAvailableInterests() async {
    try {
      final res = await http.get(
        Uri.parse("http://$_host:8000/api/interests/options"),
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
    // fallback
    setState(() => _availableInterests = _defaultInterests);
  }

  Future<void> fetchRecommendations() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse("http://$_host:8000/api/generate_thesis/${UserSession.userId}"),
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
                  // Custom interest input
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
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Scrollable checkbox list
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
                    Uri.parse("http://$_host:8000/api/interests/update"),
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
              // Title
              Text(
                item["title"] ?? "Untitled",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Difficulty badge
              _difficultyBadge(item["difficulty"]),
              const SizedBox(height: 16),

              // Description
              const Text("Description", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(item["description"] ?? "", style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),

              // Methodology
              if (item["methodology"] != null) ...[
                const Text("Methodology", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(item["methodology"], style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 16),
              ],

              // Tools
              const Text("Tools & Technologies", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: (item["tools"] ?? []).map<Widget>((t) => Chip(
                  label: Text(t.toString(), style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.blue.shade50,
                )).toList(),
              ),
              const SizedBox(height: 16),

              // Related papers with clickable links
              if (relatedResearch.isNotEmpty) ...[
                const Text("Related Research", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...List.generate(relatedResearch.length, (i) {
                  final url = i < paperUrls.length ? paperUrls[i] : null;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.article_outlined, size: 16),
                    title: Text(
                      relatedResearch[i].toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: url != null
                      ? IconButton(
                          icon: const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                          onPressed: () => openLink(url),
                        )
                      : null,
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _difficultyBadge(String? difficulty) {
    final colors = {
      "Low": Colors.green,
      "Medium": Colors.orange,
      "High": Colors.red,
    };
    final color = colors[difficulty] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        difficulty ?? "Unknown",
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ---------------- CARD ----------------
  Widget buildCard(dynamic item) {
    return GestureDetector(
      onTap: () => showThesisDetail(item),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                item["title"] ?? "Untitled",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Difficulty badge
              _difficultyBadge(item["difficulty"]),
              const SizedBox(height: 8),

              // Description — no Expanded needed, just let it flow
              Text(
                item["description"] ?? "",
                style: const TextStyle(fontSize: 11, color: Colors.black87),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              const Divider(height: 12),

              // Tools chips
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: (item["tools"] ?? []).take(3).map<Widget>((t) => Chip(
                  label: Text(t.toString(), style: const TextStyle(fontSize: 9)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                )).toList(),
              ),
              const SizedBox(height: 4),

              // Tap hint
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text("Tap for details", style: TextStyle(fontSize: 9, color: Colors.grey)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios, size: 9, color: Colors.grey),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Thesis Recommender"),
        backgroundColor: const Color.fromARGB(255, 138, 201, 243),
        actions: [
          // Show selected interest count as badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: showInterestDialog,
                tooltip: "Set Interests",
              ),
              if (_selectedInterests.isNotEmpty)
                Positioned(
                  right: 6, top: 6,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.red,
                    child: Text(
                      "${_selectedInterests.length}",
                      style: const TextStyle(fontSize: 9, color: Colors.white),
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
                  const Icon(Icons.lightbulb_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text("No recommendations yet.", style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: showInterestDialog,
                    icon: const Icon(Icons.add),
                    label: const Text("Set Your Interests"),
                  )
                ],
              ),
            )
          else
            GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: _recommendations.length,
              itemBuilder: (context, i) => buildCard(_recommendations[i]),
            ),
        ],
      ),
    );
  }
}