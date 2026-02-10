import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/offline_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isLoading = true;
  int _localStudentCount = 0;
  int _pendingSyncCount = 0;
  String _lastSyncStr = "Never";
  int _totalPresent = 0;

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  Future<void> _calculateStats() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    String? studentData = prefs.getString("local_students");
    List<dynamic> students = studentData != null ? jsonDecode(studentData) : [];

    List<String> pending = prefs.getStringList("pending_taps") ?? [];
    String lastSync = prefs.getString("last_sync_date") ?? "Never";

    // Logic: Calculate unique attendance based on today's taps
    Set<String> uniqueUids = {};
    for (var t in pending) {
      try {
        uniqueUids.add(jsonDecode(t)['nfcUid']);
      } catch (_) {}
    }

    setState(() {
      _localStudentCount = students.length;
      _pendingSyncCount = pending.length;
      _lastSyncStr = lastSync;
      _totalPresent = uniqueUids.length;
      _isLoading = false;
    });
  }

  Future<void> _forceSync() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🚀 Pushing Priority Sync to Vercel...")),
    );
    await OfflineService.syncPendingTaps();
    await _calculateStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "SYSTEM DASHBOARD",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _calculateStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("HARDWARE & CLOUD HEALTH"),
                  const SizedBox(height: 10),
                  _buildSyncCard(),
                  const SizedBox(height: 25),
                  _buildSectionTitle("TODAY'S ATTENDANCE (LOCAL)"),
                  const SizedBox(height: 10),
                  _buildAttendanceGrid(),
                  const SizedBox(height: 30),
                  _buildSectionTitle("SYSTEM INFO"),
                  _buildInfoTile(
                    Icons.storage,
                    "Students in memory",
                    "$_localStudentCount",
                  ),
                  _buildInfoTile(
                    Icons.history,
                    "Last DB Refresh",
                    _lastSyncStr,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _forceSync,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text("FORCE CLOUD SYNC"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSyncCard() {
    bool isHealthy = _pendingSyncCount == 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHealthy ? Colors.green.shade600 : Colors.orange.shade700,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: (isHealthy ? Colors.green : Colors.orange).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.cloud_done : Icons.cloud_off,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHealthy
                      ? "PORTAL UPDATED"
                      : "$_pendingSyncCount TAPS QUEUED",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isHealthy
                      ? "All students reflected in portal"
                      : "Syncing every 13s via Starlink...",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("PRESENT", "$_totalPresent", Colors.blue.shade700),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          _buildStatItem(
            "ABSENT",
            "${_localStudentCount - _totalPresent}",
            Colors.red.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueGrey.shade400),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
      ),
    );
  }
}
