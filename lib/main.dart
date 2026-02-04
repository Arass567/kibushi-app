import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/kibushi_state.dart';
import 'ui/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => KibushiState(),
      child: const KibushiApp(),
    ),
  );
}

class KibushiApp extends StatelessWidget {
  const KibushiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kibushi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      ),
      home: const MainScreen(),
    );
  }
}
