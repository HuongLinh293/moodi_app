import 'package:flutter/material.dart';

import '../state/mindra_state.dart';
import '../core/theme/colors.dart';

class AppLockView extends StatefulWidget {
  const AppLockView({super.key, required this.state});
  final MindraState state;
  @override
  State<AppLockView> createState() => _AppLockViewState();
}

class _AppLockViewState extends State<AppLockView> {
  bool _busy = false;
  String? _error;
  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final unlocked = await widget.state.unlockApplication();
    if (mounted) {
      setState(() {
        _busy = false;
        if (!unlocked) _error = 'Chưa xác thực được. Hãy thử lại bằng sinh trắc học hoặc mã khóa của thiết bị.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.paper,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 24),
              Text(
                'Không gian riêng của bạn',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Dùng Face ID, vân tay hoặc mã khóa thiết bị để tiếp tục.',
                textAlign: TextAlign.center,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _unlock,
                icon: const Icon(Icons.fingerprint),
                label: Text(_busy ? 'Đang xác thực…' : 'Mở khóa Moodi'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : widget.state.signOutFromLock,
                child: const Text('Không mở được? Đăng xuất và tắt khóa'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
