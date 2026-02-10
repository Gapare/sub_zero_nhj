import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_services.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});
  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  List<dynamic> _allStudents = [];
  List<dynamic> _filteredStudents = [];
  bool _isUploading = false;
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
      appBar: AppBar(
        title: Text("DATABASE (${_allStudents.length})"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterSearch,
              decoration: InputDecoration(
                hintText: "Search name or ID...",
                prefixIcon: const Icon(Icons.search),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: _filteredStudents.length,
        itemBuilder: (context, i) {
          final s = _filteredStudents[i];
          bool isLinked =
              s['rfidUid'] != null && s['rfidUid'].toString().isNotEmpty;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isLinked
                  ? Colors.green.shade100
                  : Colors.orange.shade100,
              child: Text(
                s['name'][0],
                style: TextStyle(
                  color: isLinked ? Colors.green : Colors.orange,
                ),
              ),
            ),
            title: Text(
              s['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("ID: ${s['admission']} | ${s['class']}"),
            trailing: isLinked
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Text(
                    "UNLINKED",
                    style: TextStyle(color: Colors.orange, fontSize: 10),
                  ),
          );
        },
      ),
    );
  }
}
