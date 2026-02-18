import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> {
  List<dynamic> _allLogs = [];
  List<dynamic> _filteredLogs = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawLogs = prefs.getStringList("admin_audit_logs") ?? [];
    setState(() {
      _allLogs = rawLogs.map((e) => jsonDecode(e)).toList();
      _filteredLogs = _allLogs;
    });
  }

  void _filterLogs(String query) {
    setState(() {
      _filteredLogs = _allLogs.where((log) {
        final content = "${log['title']} ${log['decision']} ${log['action']}"
            .toLowerCase();
        return content.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          "FORENSIC AUDIT ENGINE",
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.greenAccent,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterLogs,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search by Name, UID, or Action...",
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Colors.greenAccent),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _filteredLogs.isEmpty
          ? const Center(
              child: Text(
                "No audit records match your query.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _filteredLogs.length,
              padding: const EdgeInsets.all(10),
              itemBuilder: (context, index) {
                final log = _filteredLogs[index];
                final dt = DateTime.parse(log['time']);
                final time = DateFormat('HH:mm:ss').format(dt);
                final date = DateFormat('yyyy-MM-dd').format(dt);

                return Card(
                  color: const Color(0xFF151515),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: _getLogColor(log['title']).withAlpha(50),
                      width: 1,
                    ),
                  ),
                  child: ExpansionTile(
                    leading: Icon(
                      Icons.security,
                      color: _getLogColor(log['title']),
                    ),
                    title: Text(
                      log['title'].toUpperCase(),
                      style: TextStyle(
                        color: _getLogColor(log['title']),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    subtitle: Text(
                      "$date | $time",
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    expandedAlignment: Alignment.topLeft,
                    children: [
                      _buildDetailRow("WHO/WHAT:", log['decision']),
                      const Divider(color: Colors.white10),
                      _buildDetailRow("LOGIC/HOW:", log['action']),
                      const SizedBox(height: 8),
                      const Text(
                        "FORENSIC TRACE: Verified by Sub-Zero Kernel v1.1",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Color _getLogColor(String title) {
    String t = title.toUpperCase();
    if (t.contains("DENIED") || t.contains("LOCKED") || t.contains("REJECTED"))
      return Colors.redAccent;
    if (t.contains("SWEEP")) return Colors.orangeAccent;
    if (t.contains("SYNC")) return Colors.greenAccent;
    return Colors.blueAccent;
  }
}
