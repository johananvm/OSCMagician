import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'osc_service.dart';
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
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const SurfacePage(),
      ),
    );
  }
}
