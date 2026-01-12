import 'package:flutter/material.dart';
import '../services/api_services.dart';
import '../services/offline_service.dart';
import '../models/gate_response.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<GateResponse> _localStudents = [];
  List<Map<String, dynamic>> _queue = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    final students = await OfflineService.getAllStudents();
    final queue = await OfflineService.getQueue();
    setState(() {
      _localStudents = students;
      _queue = queue;
      _isLoading = false;
    });
  }

  void _runSync() async {
    setState(() => _isLoading = true);
    final msg = await ApiService.downloadDatabase();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("System Diagnostics"),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.white,
          tabs: [
            Tab(text: "DATABASE (${_localStudents.length})"),
            Tab(text: "QUEUE (${_queue.length})"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _runSync,
            tooltip: "Download Database",
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: LOCAL DATABASE
              ListView.builder(
                itemCount: _localStudents.length,
                itemBuilder: (ctx, i) {
                  final s = _localStudents[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: s.img != null ? NetworkImage(s.img!) : null,
                      child: s.img == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(s.name ?? "Unknown"),
                    subtitle: Text("UID: ${s.rfidUid} | Bal: \$${s.balance}"),
                    trailing: s.warning != null 
                        ? const Icon(Icons.warning, color: Colors.red) 
                        : const Icon(Icons.check_circle, color: Colors.green),
                  );
                },
              ),
              
              // TAB 2: OFFLINE QUEUE
              ListView.builder(
                itemCount: _queue.length,
                itemBuilder: (ctx, i) {
                  final item = _queue[i];
                  return ListTile(
                    leading: const Icon(Icons.cloud_upload, color: Colors.blueGrey),
                    title: Text("Tag: ${item['nfcUid']}"),
                    subtitle: Text("Time: ${item['time']}"),
                    trailing: Text(item['mode'] ?? ""),
                  );
                },
              ),
            ],
          ),
    );
  }
}