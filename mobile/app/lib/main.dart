import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_config.dart';
import 'app/app_theme.dart';
import 'features/dashboard/dashboard_controller.dart';
import 'features/dashboard/dashboard_repository.dart';
import 'features/dashboard/dashboard_shell.dart';
import 'features/auth/auth_screen.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.initialize();
  runApp(const RaabtaApp());
}

class RaabtaApp extends StatefulWidget {
  const RaabtaApp({super.key});

  @override
  State<RaabtaApp> createState() => _RaabtaAppState();
}

class _RaabtaAppState extends State<RaabtaApp> {
  final ApiService _apiService = ApiService();
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = _apiService.isAuthenticated;
  }

  void _handleAuthenticated() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardController(DashboardRepository()),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Raabta AI',
        theme: RaabtaTheme.dark(),
        home: _isAuthenticated
            ? const RaabtaDashboardShell()
            : AuthScreen(onAuthenticated: _handleAuthenticated),
      ),
    );
  }
}
