import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'osc_service.dart';
import 'screens/settings_page.dart';
import 'screens/surface_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(OscService());
  await state.init();
  runApp(OscMagicianApp(state: state));
}

class OscMagicianApp extends StatelessWidget {
  const OscMagicianApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        title: 'OSC Magician',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hideTabBar = state.hideBars && !state.editMode && _tab == 0;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [SurfacePage(), SettingsPage()],
      ),
      bottomNavigationBar: hideTabBar
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              height: 56,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.grid_view), label: 'Controls'),
                NavigationDestination(
                    icon: Icon(Icons.settings), label: 'Settings'),
              ],
            ),
    );
  }
}
