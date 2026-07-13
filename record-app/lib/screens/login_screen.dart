import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/storage_service.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  final bool isSetup;
  const LoginScreen({super.key, this.isSetup = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  String _pin = '';
  String? _error;
  bool _confirmMode = false;
  String _firstPin = '';
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyTap(String value) {
    if (value == 'del') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _error = null;
        });
      }
      return;
    }
    if (_pin.length >= 6) return;
    setState(() {
      _pin += value;
      _error = null;
    });

    if (_pin.length == 6) {
      _submit();
    }
  }

  Future<void> _submit() async {
    final storage = context.read<StorageService>();

    if (widget.isSetup) {
      // 首次设置 PIN
      if (!_confirmMode) {
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _confirmMode = true;
        });
        return;
      }
      if (_pin != _firstPin) {
        _shake();
        setState(() {
          _error = '两次 PIN 不一致，请重试';
          _pin = '';
          _confirmMode = false;
          _firstPin = '';
        });
        return;
      }
      await storage.setPin(_pin);
      if (!mounted) return;
      _goHome();
    } else {
      // 验证 PIN
      final ok = await storage.verifyPin(_pin);
      if (!ok) {
        _shake();
        setState(() {
          _error = 'PIN 不正确';
          _pin = '';
        });
        return;
      }
      _goHome();
    }
  }

  void _shake() {
    _shakeController.forward(from: 0);
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.isSetup ? (_confirmMode ? '确认 PIN' : '设置登录 PIN') : '输入 PIN 解锁';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final shake = _shakeController.value;
                final offset = shake < 0.5 ? shake * 30 : (1 - shake) * 30;
                return Transform.translate(
                  offset: Offset(
                    offset *
                        (shake < 0.25
                            ? 1
                            : shake < 0.5
                            ? -1
                            : shake < 0.75
                            ? 1
                            : -1),
                    0,
                  ),
                  child: child,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.tertiary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.monitor_heart,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '减重助手',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 32),
                  // PIN dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              i < _pin.length
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[300],
                        ),
                      );
                    }),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(color: Colors.red[700], fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 40),
                  // Keypad
                  _buildKeypad(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2,
      children: [
        for (final key in [
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
          'clear',
          '0',
          'del',
        ])
          _buildKey(key),
      ],
    );
  }

  Widget _buildKey(String key) {
    if (key == 'clear') return const SizedBox.shrink();

    final isDelete = key == 'del';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onKeyTap(key),
        child: Center(
          child:
              isDelete
                  ? Icon(Icons.backspace_outlined, color: Colors.grey[600])
                  : Text(
                    key,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
        ),
      ),
    );
  }
}
