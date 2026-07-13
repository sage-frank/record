import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../services/storage_service.dart';
import '../models/diet_record.dart';
import '../models/user_profile.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({super.key});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  List<DietRecord> _records = [];
  UserProfile? _profile;
  bool _loading = true;

  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
  static const _mealIcons = {
    'breakfast': Icons.wb_sunny,
    'lunch': Icons.wb_cloudy,
    'dinner': Icons.nights_stay,
    'snack': Icons.cookie,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = context.read<StorageService>();
    final records = await storage.loadDietRecords();
    final profile = await storage.loadProfile();
    if (!mounted) return;
    setState(() {
      _records = records;
      _profile = profile;
      _loading = false;
    });
  }

  double get _todayCalories {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _records
        .where((r) => DateFormat('yyyy-MM-dd').format(r.date) == today)
        .fold(0.0, (sum, r) => sum + r.calories);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final goal = _profile?.dailyCalorieGoal ?? 2000;
    final todayKcal = _todayCalories;
    final remaining = goal - todayKcal.toInt();

    return Scaffold(
      appBar: AppBar(
        title: const Text('饮食记录'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 今日卡路里概览
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.tertiaryContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('今日摄入', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      '$todayKcal',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '目标 $goal kcal',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: remaining >= 0
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    remaining >= 0 ? '还可 $remaining kcal' : '超出 ${-remaining} kcal',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: remaining >= 0 ? Colors.green[800] : Colors.red[800],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 餐食分组
          Expanded(
            child: _records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('暂无饮食记录', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final mt in _mealTypes)
                        _buildMealGroup(mt),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        icon: const Icon(Icons.add),
        label: const Text('记录饮食'),
      ),
    );
  }

  Widget _buildMealGroup(String mealType) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final items = _records
        .where((r) =>
            r.mealType == mealType &&
            DateFormat('yyyy-MM-dd').format(r.date) == today)
        .toList();

    if (items.isEmpty) return const SizedBox.shrink();

    final totalCal = items.fold(0.0, (sum, r) => sum + r.calories);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(_mealIcons[mealType], size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              items.first.mealTypeLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Spacer(),
            Text(
              '${totalCal.toInt()} kcal',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map(
          (r) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text(r.foodName, style: const TextStyle(fontSize: 14)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${r.calories.toInt()} kcal',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _deleteRecord(r.id),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteRecord(String id) async {
    await context.read<StorageService>().deleteDietRecord(id);
    await _load();
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    String mealType = 'breakfast';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('记录饮食', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // 餐食类型选择
              Row(
                children: _mealTypes.map((mt) {
                  final selected = mealType == mt;
                  final label = mt == 'breakfast'
                      ? '早餐'
                      : mt == 'lunch'
                          ? '午餐'
                          : mt == 'dinner'
                              ? '晚餐'
                              : '加餐';
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: Text(label, style: const TextStyle(fontSize: 12)),
                        selected: selected,
                        onSelected: (_) => setSheetState(() => mealType = mt),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '食物名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: calCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '卡路里 (kcal)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final cal = double.tryParse(calCtrl.text.trim());
                    if (name.isEmpty || cal == null) return;

                    final record = DietRecord(
                      id: const Uuid().v4(),
                      date: DateTime.now(),
                      mealType: mealType,
                      foodName: name,
                      calories: cal,
                    );
                    await context.read<StorageService>().addDietRecord(record);
                    Navigator.pop(ctx);
                    await _load();
                  },
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
