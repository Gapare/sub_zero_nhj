import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AdminAuditScreen extends StatelessWidget {
  const AdminAuditScreen({super.key});

  Future<List<dynamic>> _getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawLogs = prefs.getStringList("admin_audit_logs") ?? [];
    return rawLogs.map((e) => jsonDecode(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          "ENGINEER'S AUDIT LOG",
          style: TextStyle(fontFamily: 'monospace', fontSize: 14),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.greenAccent,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _getLogs(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "No logic logs found.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ), // ✅ Fixed
            itemBuilder: (context, index) {
              final log = snapshot.data![index];
              final time = DateFormat(
                'HH:mm:ss',
              ).format(DateTime.parse(log['time']));

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  border: Border(
                    left: BorderSide(
                      color: _getLogColor(log['title']),
                      width: 4,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween, // ✅ Fixed
                      children: [
                        Text(
                          log['title'].toUpperCase(),
                          style: TextStyle(
                            color: _getLogColor(log['title']),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          time,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "🧠 Decision: ${log['decision']}",
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "📡 Action: ${log['action']}",
                      style: TextStyle(
                        color: Colors.greenAccent.withAlpha(
                          180,
                        ), // ✅ Fixed with modern standard
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getLogColor(String title) {
    if (title.toUpperCase().contains("SWEEP")) return Colors.orangeAccent;
    if (title.toUpperCase().contains("TAP")) return Colors.blueAccent;
    if (title.toUpperCase().contains("SYNC")) return Colors.greenAccent;
    return Colors.white;
  }
}
