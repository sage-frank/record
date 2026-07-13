import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/storage_service.dart';
import '../models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await context.read<StorageService>().loadProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final p = _profile!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 头像 & 名字
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name.isNotEmpty ? p.name : '未设置姓名',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '目标：${p.targetWeightKg.toStringAsFixed(1)} kg',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditDialog(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 身体数据
          const Text('身体数据', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _infoRow('当前体重', '${p.currentWeightKg.toStringAsFixed(1)} kg'),
                const Divider(height: 1, indent: 16),
                _infoRow('目标体重', '${p.targetWeightKg.toStringAsFixed(1)} kg'),
                const Divider(height: 1, indent: 16),
                _infoRow('还需减重', '${p.weightToLose.toStringAsFixed(1)} kg'),
                const Divider(height: 1, indent: 16),
                _infoRow('身高', '${p.heightCm.toStringAsFixed(0)} cm'),
                const Divider(height: 1, indent: 16),
                _infoRow('年龄', '${p.age} 岁'),
                const Divider(height: 1, indent: 16),
                _infoRow('性别', p.gender == 'male' ? '男' : '女'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 代谢 & 目标
          const Text('代谢与目标', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _infoRow('基础代谢 (BMR)', '${p.bmr} kcal/天'),
                const Divider(height: 1, indent: 16),
                _infoRow('每日摄入目标', '${p.dailyCalorieGoal} kcal'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 编辑按钮
          FilledButton.icon(
            onPressed: () => _showEditDialog(),
            icon: const Icon(Icons.edit),
            label: const Text('编辑个人资料'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showWeightDialog(),
            icon: const Icon(Icons.monitor_weight),
            label: const Text('更新体重'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  void _showEditDialog() {
    final p = _profile!;
    final nameCtrl = TextEditingController(text: p.name);
    final heightCtrl = TextEditingController(text: p.heightCm.toStringAsFixed(0));
    final ageCtrl = TextEditingController(text: p.age.toString());
    final targetCtrl = TextEditingController(text: p.targetWeightKg.toStringAsFixed(1));
    final calCtrl = TextEditingController(text: p.dailyCalorieGoal.toString());
    String gender = p.gender;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('编辑个人资料', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '姓名', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: heightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '身高 (cm)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '年龄', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: targetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '目标体重 (kg)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: calCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '每日卡路里目标', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('性别：'),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('男'),
                    selected: gender == 'male',
                    onSelected: (_) => setSheetState(() => gender = 'male'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('女'),
                    selected: gender == 'female',
                    onSelected: (_) => setSheetState(() => gender = 'female'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final updated = UserProfile(
                      name: nameCtrl.text.trim(),
                      heightCm: double.tryParse(heightCtrl.text) ?? p.heightCm,
                      age: int.tryParse(ageCtrl.text) ?? p.age,
                      targetWeightKg: double.tryParse(targetCtrl.text) ?? p.targetWeightKg,
                      dailyCalorieGoal: int.tryParse(calCtrl.text) ?? p.dailyCalorieGoal,
                      currentWeightKg: p.currentWeightKg,
                      gender: gender,
                    );
                    await context.read<StorageService>().saveProfile(updated);
                    Navigator.pop(ctx);
                    _load();
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

  void _showWeightDialog() {
    final ctrl = TextEditingController(text: _profile!.currentWeightKg.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('更新体重'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '当前体重 (kg)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final w = double.tryParse(ctrl.text);
              if (w == null) return;
              final updated = UserProfile(
                name: _profile!.name,
                currentWeightKg: w,
                targetWeightKg: _profile!.targetWeightKg,
                heightCm: _profile!.heightCm,
                age: _profile!.age,
                gender: _profile!.gender,
                dailyCalorieGoal: _profile!.dailyCalorieGoal,
              );
              await context.read<StorageService>().saveProfile(updated);
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
