import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_services.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();

    // 1. Get total student count
    String? studentData = prefs.getString("local_students");
    List<dynamic> allStudents = studentData != null
        ? jsonDecode(studentData)
        : [];
    int total = allStudents.length;

    // 2. Get Today's Taps from local cache
    List<String> pending = prefs.getStringList("pending_taps") ?? [];
    String today = DateTime.now().toIso8601String().split('T')[0];

    // 3. Calculate Present Students (Unique UIDs from today)
    Set<String> presentUids = {};
    int males = 0;
    int females = 0;
    Map<String, int> classStats = {};

    for (var tapJson in pending) {
      var tap = jsonDecode(tapJson);
      // Only count if it's a CHECK_IN from today
      if (tap['timestamp'].startsWith(today) && tap['status'] == "CHECK_IN") {
        presentUids.add(tap['nfcUid']);
      }
    }

    // 4. Cross-reference with Student Data for Gender/Class info
    for (String uid in presentUids) {
      final s = allStudents.firstWhere(
        (std) => std['rfidUid'] == uid,
        orElse: () => null,
      );
      if (s != null) {
        // Gender logic
        if (s['sex']?.toString().toUpperCase() == "M") males++;
        if (s['sex']?.toString().toUpperCase() == "F") females++;

        // Class logic
        String className = s['class'] ?? "Unknown";
        classStats[className] = (classStats[className] ?? 0) + 1;
      }
    }

    setState(() {
      _stats = {
        'total_students': total,
        'total_present': presentUids.length,
        'males_present': males,
        'females_present': females,
        'class_breakdown': classStats,
      };
      _isLoading = false;
    });
  }

  void _runSync() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Force syncing...")));
    ApiService();
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    int total = _stats['total_students'] ?? 0;
    int present = _stats['total_present'] ?? 0;
    int males = _stats['males_present'] ?? 0;
    int females = _stats['females_present'] ?? 0;
    Map<String, dynamic> classes = _stats['class_breakdown'] ?? {};

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Daily Attendance Stats"),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.green),
            onPressed: _runSync,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 🏆 BIG TOTAL CARD
                  _buildStatCard(
                    "Total Present",
                    "$present / $total",
                    Icons.people,
                    Colors.blue,
                  ),

                  const SizedBox(height: 15),

                  // 🚻 GENDER ROW
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          "Males",
                          "$males",
                          Icons.male,
                          Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildStatCard(
                          "Females",
                          "$females",
                          Icons.female,
                          Colors.pinkAccent,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),
                  const Text(
                    "CLASS BREAKDOWN",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 🏫 CLASS LIST
                  ...classes.entries.map(
                    (e) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.class_, color: Colors.green),
                        title: Text(e.key),
                        trailing: Text(
                          "${e.value}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
