import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:battery_plus/battery_plus.dart';

import 'sos_screen.dart';
import 'map_screen.dart';
import 'guardian_screen.dart';
import 'chatbot_screen.dart';
import '../services/sos_service.dart';
import '../services/voice_service.dart';
import '../services/battery_service.dart';
import '../widgets/sos_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _batteryLevel = 100;
  bool _voiceActive = false;
  late AnimationController _pulseController;

  final _pages = const [
    _DashboardPage(),
    MapScreen(),
    GuardianScreen(),
    ChatbotScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _initServices();
  }

  Future<void> _initServices() async {
    // Battery
    _batteryLevel = await Battery().batteryLevel;
    setState(() {});
    await BatteryService.startMonitoring();

    // Voice
    final ok = await VoiceService.initialize();
    if (ok) {
      await VoiceService.startContinuousListening();
      setState(() => _voiceActive = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(
              icon: Icon(Icons.people), label: 'Guardians'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline), label: 'Help'),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.large(
              backgroundColor: Colors.red,
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SOSScreen())),
              child: const Icon(Icons.sos, size: 40, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 28),
            const SizedBox(width: 8),
            const Text('Shakti'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {/* Settings */},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(),
          const SizedBox(height: 16),
          _QuickActionsRow(),
          const SizedBox(height: 16),
          _NearbyAlertCard(),
          const SizedBox(height: 16),
          _ActivityCard(),
          const SizedBox(height: 80), // space for FAB
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green[50],
      child: ListTile(
        leading: const Icon(Icons.shield, color: Colors.green, size: 36),
        title: const Text('You are Safe',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: const Text('All systems active · Voice monitoring ON'),
        trailing: const Icon(Icons.mic, color: Colors.green),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.sos,
            label: 'SOS',
            color: Colors.red,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SOSScreen())),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            icon: Icons.map,
            label: 'Safe Map',
            color: Colors.blue,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MapScreen())),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            icon: Icons.phone,
            label: 'Call Help',
            color: Colors.orange,
            onTap: () => SOSService.autoCallGuardian(),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon, required this.label,
       required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _NearbyAlertCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚠️ Nearby Risk Zones',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _RiskItem('Majestic Bus Terminal', 'High harassment reports', '1.2 km'),
            _RiskItem('KR Market', 'Sexual assault cases reported', '2.4 km'),
          ],
        ),
      ),
    );
  }
}

class _RiskItem extends StatelessWidget {
  final String name;
  final String issue;
  final String distance;
  const _RiskItem(this.name, this.issue, this.distance);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(issue,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text(distance,
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🤖 AI Activity Monitor',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Routine learned. Monitoring for anomalies.',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: 0.85,
              color: Colors.green,
              backgroundColor: Colors.green.withOpacity(0.2),
            ),
            const SizedBox(height: 4),
            const Text('85% routine data collected',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
