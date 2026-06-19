import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/api_service.dart';
import 'services/location_service.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const RecordApp());
}

class RecordApp extends StatelessWidget {
  const RecordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
      ],
      child: MaterialApp(
        title: '运动记录',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
