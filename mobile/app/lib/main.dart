import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_config.dart';
import 'app/app_theme.dart';
import 'features/dashboard/dashboard_controller.dart';
import 'features/dashboard/dashboard_repository.dart';
import 'features/dashboard/dashboard_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.initialize();
  runApp(const RaabtaApp());
}

class RaabtaApp extends StatelessWidget {
  const RaabtaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardController(DashboardRepository()),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Raabta AI',
        theme: RaabtaTheme.dark(),
        home: const RaabtaDashboardShell(),
      ),
    );
  }
}
