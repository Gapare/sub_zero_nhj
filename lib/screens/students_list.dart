import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});
  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  List<dynamic> _allStudents = [];
  List<dynamic> _filteredStudents = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLocalStudents();
  }

  Future<void> _loadLocalStudents() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString("local_students");
    if (data != null) {
      setState(() {
        _allStudents = jsonDecode(data);
        _filteredStudents = _allStudents;
      });
    }
  }

  // 🔥 THE AUDIT ENGINE: Find local taps for a specific UID
  Future<void> _showStudentAudit(dynamic student) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pending = prefs.getStringList("pending_taps") ?? [];

    // Filter taps for this specific student
    List<dynamic> studentTaps = pending
        .map((t) => jsonDecode(t))
        .where(
          (t) =>
              t['nfcUid'] == student['rfidUid'] ||
              t['admission'] == student['admission'],
        )
        .toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              student['name'].toString().toUpperCase(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              "Admission: ${student['admission']}",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "LOCAL CACHED LOGS",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
            ),
            Expanded(
              child: studentTaps.isEmpty
                  ? const Center(
                      child: Text("No local taps found for this student."),
                    )
                  : ListView.builder(
                      itemCount: studentTaps.length,
                      itemBuilder: (context, index) {
                        final tap = studentTaps[index];
                        final DateTime time = DateTime.parse(tap['timestamp']);
                        final bool isEntry = tap['status'] == "CHECK_IN";

                        return ListTile(
                          leading: Icon(
                            isEntry ? Icons.login : Icons.logout,
                            color: isEntry ? Colors.green : Colors.orange,
                          ),
                          title: Text(isEntry ? "ENTRY" : "EXIT"),
                          subtitle: Text(
                            DateFormat('EEEE, dd MMM - HH:mm').format(time),
                          ),
                          trailing: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 16,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _filterSearch(String query) {
    setState(() {
      _filteredStudents = _allStudents
          .where(
            (s) =>
                s['name'].toString().toLowerCase().contains(
                  query.toLowerCase(),
                ) ||
                s['admission'].toString().contains(query),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "DATABASE (${_allStudents.length})",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _filterSearch,
              decoration: InputDecoration(
                hintText: "Search student or admission...",
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                fillColor: Colors.grey[200],
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _filteredStudents.isEmpty
          ? const Center(child: Text("No students found."))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _filteredStudents.length,
              itemBuilder: (context, i) {
                final s = _filteredStudents[i];
                bool isLinked =
                    s['rfidUid'] != null && s['rfidUid'].toString().isNotEmpty;

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: ListTile(
                    onTap: () => _showStudentAudit(s), // 🔥 Open Audit
                    leading: CircleAvatar(
                      backgroundColor: isLinked
                          ? Colors.green[50]
                          : Colors.orange[50],
                      child: Text(
                        s['name'][0],
                        style: TextStyle(
                          color: isLinked ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      s['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "${s['admission']} • ${s['class'] ?? 'No Class'}",
                    ),
                    trailing: isLinked
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "UNLINKED",
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
