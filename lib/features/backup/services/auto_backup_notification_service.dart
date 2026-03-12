import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ikuyo_finance/core/utils/logger.dart';

class AutoBackupNotificationService {
  static const _channelId = 'auto_backup';
  static const _channelName = 'Auto Backup';
  static const _notifIdSuccess = 3001;
  static const _notifIdFailure = 3002;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('ic_launcher_foreground');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    await _createChannel();
    logService('AutoBackupNotificationService diinisialisasi');
  }

  Future<void> initializeForBackground() async {
    const android = AndroidInitializationSettings('ic_launcher_foreground');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    await _createChannel();
  }

  Future<void> showSuccess(String filePath) async {
    await _plugin.show(
      id: _notifIdSuccess,
      title: 'Auto Backup Berhasil',
      body: 'Data berhasil dicadangkan ke: $filePath',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> showFailure(String errorMessage) async {
    await _plugin.show(
      id: _notifIdFailure,
      title: 'Auto Backup Gagal',
      body: 'Gagal mencadangkan data: $errorMessage',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> _createChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }
}
