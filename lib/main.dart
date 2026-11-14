import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/kit_provider.dart';
import 'providers/emergency_provider.dart';
import 'providers/monitoring_provider.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/kit_management_screen.dart';
import 'screens/disaster_guide_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'utils/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LifeCheckpointApp());
}

class LifeCheckpointApp extends StatelessWidget {
  const LifeCheckpointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => KitProvider()),
        ChangeNotifierProvider(create: (_) => EmergencyProvider()),
        ChangeNotifierProvider(create: (_) => MonitoringProvider()),
      ],
      child: MaterialApp(
        title: 'LifeCheckpoint',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainNavigationScreen(),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _onNavigateTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final kit = context.watch<KitProvider>();
    final alertCount = kit.expiredItemsCount + kit.expiringSoonItemsCount;

    final List<Widget> screens = [
      HomeDashboardScreen(onNavigateTab: _onNavigateTab),
      const KitManagementScreen(),
      const DisasterGuideScreen(),
      const EmergencyContactsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primaryCrimson.withAlpha(38),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppTheme.primaryCrimson),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: alertCount > 0
                ? Badge(
                    label: Text('$alertCount'),
                    backgroundColor: AppTheme.accentAlert,
                    child: const Icon(Icons.checklist_rtl_outlined),
                  )
                : const Icon(Icons.checklist_rtl_outlined),
            selectedIcon:
                const Icon(Icons.checklist_rtl, color: AppTheme.primaryCrimson),
            label: 'Emergency Kit',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book, color: AppTheme.primaryCrimson),
            label: 'Guides',
          ),
          const NavigationDestination(
            icon: Icon(Icons.phone_in_talk_outlined),
            selectedIcon:
                Icon(Icons.phone_in_talk, color: AppTheme.primaryCrimson),
            label: 'Plans & SOS',
          ),
        ],
      ),
    );
  }
}
