import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  final bool isSetup;
  const LoginScreen({super.key, this.isSetup = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  bool _confirmMode = false;
  String _firstPin = '';
  late AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _onKey(String v) {
    if (v == 'del') {
      if (_pin.isNotEmpty) setState(() { _pin = _pin.substring(0, _pin.length - 1); _error = null; });
      return;
    }
    if (_pin.length >= 6) return;
    setState(() { _pin += v; _error = null; });
    if (_pin.length == 6) _submit();
  }

  Future<void> _submit() async {
    final storage = context.read<StorageService>();
    if (widget.isSetup) {
      if (!_confirmMode) {
        setState(() { _firstPin = _pin; _pin = ''; _confirmMode = true; });
        return;
      }
      if (_pin != _firstPin) {
        _shake.forward(from: 0);
        setState(() { _error = '两次 PIN 不一致'; _pin = ''; _confirmMode = false; _firstPin = ''; });
        return;
      }
      await storage.setPin(_pin);
      if (!mounted) return;
      _goHome();
    } else {
      if (await storage.verifyPin(_pin)) {
        _goHome();
      } else {
        _shake.forward(from: 0);
        setState(() { _error = 'PIN 不正确'; _pin = ''; });
      }
    }
  }

  void _goHome() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isSetup
        ? (_confirmMode ? '确认 PIN' : '设置登录 PIN')
        : '输入 PIN 解锁';

    return Scaffold(
      backgroundColor: C.ink,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: AnimatedBuilder(
              animation: _shake,
              builder: (ctx, child) {
                final s = _shake.value;
                final off = s < 0.5 ? s * 24 : (1 - s) * 24;
                return Transform.translate(
                  offset: Offset(off * (s < 0.25 ? 1 : s < 0.5 ? -1 : s < 0.75 ? 1 : -1), 0),
                  child: child,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: C.lime, width: 2),
                    ),
                    child: const Icon(Icons.monitor_heart, color: C.lime, size: 36),
                  ),
                  const SizedBox(height: 24),
                  Text(title, style: T.h2.copyWith(color: Colors.white)),
                  const SizedBox(height: 6),
                  Text('减重助手', style: T.bodyS.copyWith(color: C.slate)),
                  const SizedBox(height: 32),
                  // PIN dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length ? C.lime : C.ink2,
                        border: Border.all(color: i < _pin.length ? C.lime : C.slate.withOpacity(0.3)),
                      ),
                    )),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: T.bodyS.copyWith(color: C.coral)),
                  ],
                  const SizedBox(height: 40),
                  _keypad(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _keypad() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        for (final k in ['1','2','3','4','5','6','7','8','9','','0','del']) _key(k),
      ],
    );
  }

  Widget _key(String k) {
    if (k.isEmpty) return const SizedBox.shrink();
    final isDel = k == 'del';
    return Material(
      color: C.ink2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _onKey(k),
        child: Center(
          child: isDel
              ? const Icon(Icons.backspace_outlined, color: C.slate)
              : Text(k, style: T.numMd.copyWith(color: Colors.white, fontSize: 24)),
        ),
      ),
    );
  }
}
