import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Nhắc check-in hằng ngày bằng thông báo cục bộ (không cần server).
///
/// Không lưu cài đặt riêng: lịch đang chờ trong hệ điều hành là nguồn sự thật,
/// giờ nhắc nằm trong payload. Mở lại app chỉ cần đọc [load].
class ReminderService {
  ReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _id = 2100;
  static const _channelId = 'daily_checkin';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _init;

  Future<void> _ensureInit() => _init ??= () async {
    tz_data.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (e) {
      debugPrint('ReminderService: timezone fallback: $e');
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Chỉ xin quyền khi người dùng bật nhắc nhở, không phải lúc mở app.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }();

  /// Giờ nhắc đang được lên lịch ("HH:mm"), hoặc null nếu đang tắt.
  Future<String?> load() async {
    try {
      await _ensureInit();
      final pending = await _plugin.pendingNotificationRequests();
      for (final r in pending) {
        if (r.id == _id) return r.payload;
      }
    } catch (e) {
      debugPrint('ReminderService: load error: $e');
    }
    return null;
  }

  /// Trả false khi người dùng không cấp quyền thông báo.
  Future<bool> schedule(String time) async {
    await _ensureInit();
    if (!await _requestPermission()) return false;
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: _id,
      title: 'Hôm nay bạn thấy thế nào?',
      body: 'Dành 30 giây ghi lại cảm xúc, nhẹ nhàng thôi.',
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Nhắc check-in hằng ngày',
          channelDescription: 'Lời nhắc nhẹ để ghi lại cảm xúc mỗi ngày',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Không cần quyền báo thức chính xác; lệch vài phút là chấp nhận được.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: time,
    );
    return true;
  }

  Future<void> cancel() async {
    try {
      await _ensureInit();
      await _plugin.cancel(id: _id);
    } catch (e) {
      debugPrint('ReminderService: cancel error: $e');
    }
  }

  Future<bool> _requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }
}
