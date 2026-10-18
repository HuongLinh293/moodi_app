import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

String gardenErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' => 'Hãy đăng nhập để sử dụng vườn chung.',
      'permission-denied' => 'Bạn không còn quyền truy cập khu vườn này.',
      'resource-exhausted' =>
        'Vườn đã đủ hai thành viên hoặc đang bận. Hãy thử lại sau.',
      'not-found' =>
        'Không tìm thấy vườn hoặc mã mời đã cũ. Hãy nhờ bạn gửi mã mới.',
      'failed-precondition' =>
        error.message ?? 'Chưa thể thực hiện. Hãy thử lại.',
      _ => 'Chưa lưu được thay đổi. Kiểm tra kết nối và thử lại.',
    };
  }
  if (error is StateError) return error.message.toString();
  return 'Chưa lưu được thay đổi. Kiểm tra kết nối và thử lại.';
}

Future<bool> runGardenAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(gardenErrorMessage(error))));
    }
    return false;
  }
}
