import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/location_service.dart';
import 'history_screen.dart';
import 'tracking_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locService = context.watch<LocationService>();
    final isRecording = locService.state != RecordingState.idle;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App 图标
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.directions_run,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '运动记录',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '记录你的每一次运动轨迹',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 48),

                // 开始跑步按钮
                if (!isRecording)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrackingScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: const Text('开始跑步', style: TextStyle(fontSize: 18)),
                    ),
                  ),

                // 正在记录时显示提示
                if (isRecording)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrackingScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.fiber_manual_record, size: 28),
                      label: const Text('返回记录中...', style: TextStyle(fontSize: 18)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // 历史记录按钮
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HistoryScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.history),
                    label: const Text('历史记录', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
