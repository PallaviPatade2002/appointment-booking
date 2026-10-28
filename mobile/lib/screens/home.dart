import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import 'book.dart';
import 'bookings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _bookingsVersion = 0;

  void _booked() {
    setState(() {
      _tab = 1;
      _bookingsVersion++;
    });
    snack(context, 'Booking confirmed 🎉');
  }

  Future<void> _logout() async {
    await Api.instance.logout();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final user = Api.instance.user!;
    final titles = ['Book appointment', 'My bookings', 'Profile'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: IndexedStack(
        index: _tab,
        children: [
          BookScreen(onBooked: _booked),
          BookingsScreen(key: ValueKey(_bookingsVersion)),
          _Profile(name: user.name, phone: user.phone, onLogout: _logout),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Book'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.name, required this.phone, required this.onLogout});
  final String name;
  final String phone;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: primarySoft,
                  child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: primary)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(phone, style: const TextStyle(color: muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
