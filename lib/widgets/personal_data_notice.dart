import 'package:flutter/material.dart';

import '../state/mindra_state.dart';

class PersonalDataNotice extends StatelessWidget {
  const PersonalDataNotice({super.key, required this.state});
  final MindraState state;
  @override
  Widget build(BuildContext context) {
    if (!state.loadingPersonalData &&
        state.personalDataError == null &&
        !state.cacheWriteFailed) {
      return const SizedBox.shrink();
    }
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (state.loadingPersonalData)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  state.cacheWriteFailed
                      ? 'Chưa lưu được bản trên máy. Hãy giữ app mở và kiểm tra trạng thái đồng bộ.'
                      : state.personalDataError ??
                            'Đang cập nhật dữ liệu của bạn…',
                ),
              ),
            ),
            if (!state.loadingPersonalData)
              IconButton(
                tooltip: 'Thử cập nhật dữ liệu',
                onPressed: state.syncFromApi,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
      ),
    );
  }
}
