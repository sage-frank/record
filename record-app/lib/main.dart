import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/error_repository.dart';
import 'data/services/error_reporter_service.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';
import 'services/storage_service.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'utils/error_reporter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化异常上报链路（分层：Service -> Repository -> 全局门面）
  final errorRepository = ErrorReportRepository(
    service: ErrorReporterService(baseUrl: ApiService.baseUrl),
  );
  ErrorReporter.init(errorRepository);
  // 补报上次离线期间积压的异常
  unawaited(errorRepository.flushPending());

  // 全局异常捕获：不允许吞掉异常，全部输出并上报
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorReporter.reportError(
      message: details.exceptionAsString(),
      source: 'flutter',
      error: details.exception,
      stackTrace: details.stack,
      context: {'library': details.library},
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorReporter.reportError(
      message: error.toString(),
      source: 'platform',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  runZonedGuarded(
    () => runApp(RecordApp(errorRepository: errorRepository)),
    (error, stack) {
      ErrorReporter.reportError(
        message: error.toString(),
        source: 'zone',
        error: error,
        stackTrace: stack,
      );
    },
  );
}

class RecordApp extends StatelessWidget {
  const RecordApp({super.key, required this.errorRepository});

  final ErrorReportRepository errorRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => errorRepository),
        Provider(create: (_) => ApiService(errorRepository: errorRepository)),
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
