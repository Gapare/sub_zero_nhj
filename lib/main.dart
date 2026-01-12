import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/daily_gate_screen.dart';
import 'screens/fee_check_screen.dart';
import 'screens/identity_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const NjeleleApp());
}

class NjeleleApp extends StatelessWidget {
  const NjeleleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Njelele Gate',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // We don't create the list here anymore to avoid keeping them alive
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically build ONLY the selected screen
    Widget activeScreen;
    switch (_selectedIndex) {
      case 0:
        activeScreen = const DailyGateScreen();
        break;
      case 1:
        activeScreen = const FeeCheckScreen();
        break;
      case 2:
        activeScreen = const IdentityScreen();
        break;
      default:
        activeScreen = const DailyGateScreen();
    }

    return Scaffold(
      // ❌ REMOVED: IndexedStack
      // ✅ ADDED: Direct widget rendering (Kill old, Start new)
      body: activeScreen, 
      
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Daily Gate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Fees',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_search),
            label: 'Identity',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[800],
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        elevation: 10,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}