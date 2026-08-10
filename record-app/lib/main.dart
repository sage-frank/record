import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/api_service.dart';
import 'services/location_service.dart';
import 'services/storage_service.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RecordApp());
}

class RecordApp extends StatelessWidget {
  const RecordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => ApiService()),
        Provider(create: (_) => StorageService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
      ],
      child: MaterialApp(
        title: '减重助手',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: context.read<StorageService>().hasPin(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(backgroundColor: C.ink, body: Center(child: CircularProgressIndicator(color: C.lime)));
        }
        if (snap.data == true) return const LoginScreen();
        return const LoginScreen(isSetup: true);
      },
    );
  }
}
