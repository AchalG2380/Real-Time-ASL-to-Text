import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'screens/login_screen.dart';
import 'screens/output_screen/output_view.dart';
import 'services/app_state.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const AslRetailApp(),
    ),
  );
}

class AslRetailApp extends StatelessWidget {
  const AslRetailApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maneora ASL Desk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Helvetica',
      ),
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({Key? key}) : super(key: key);

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                'Connecting to server...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                AppConstants.aslEngineHost != 'localhost'
                    ? 'Cashier mode — connecting to ${AppConstants.aslEngineHost}'
                    : 'First load may take up to 50 seconds',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              if (appState.errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  appState.errorMessage,
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ]
            ],
          ),
        ),
      );
    }

    // ── Device B (tablet/cashier): skip login → go straight to cashier output ──
    if (AppConstants.aslEngineHost != 'localhost') {
      return const OutputView(isAdmin: true);
    }

    // ── Device A: show normal login/role selection ──
    return const LoginScreen();
  }
}