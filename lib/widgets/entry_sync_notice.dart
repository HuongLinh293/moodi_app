import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../state/mindra_state.dart';

/// Visible status for writes that have not been acknowledged by the server.
class EntrySyncNotice extends StatelessWidget {
  final MindraState state;
  const EntrySyncNotice({super.key, required this.state});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final pending = state.pendingEntryCount;
      final failed = state.failedEntryCount;
      final session = state.sessionEntryCount;
      if (pending + failed + session == 0) return const SizedBox.shrink();
      final message = [
        if (failed > 0) '$failed ghi chép chưa đồng bộ được.',
        if (pending > 0) '$pending ghi chép đang chờ đồng bộ.',
        if (session > 0)
          '$session ghi chép chỉ có trong phiên này, chưa được lưu lâu dài.',
      ].join(' ');
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          key: const ValueKey('entry-sync-notice'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.creamDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: const TextStyle(color: AppColors.ink, height: 1.5),
                ),
              ),
              if (pending > 0 || failed > 0)
                const Text(
                  'Chưa xác nhận lưu trên tài khoản. Giữ ứng dụng mở và kiểm tra kết nối.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
              if (failed > 0 || (session > 0 && state.currentUserId != null))
                TextButton(
                  onPressed: state.retryEntrySync,
                  child: const Text('Thử đồng bộ lại'),
                ),
            ],
          ),
        ),
      );
    },
  );
}
