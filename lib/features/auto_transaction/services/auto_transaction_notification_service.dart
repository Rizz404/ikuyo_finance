import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ikuyo_finance/core/extensions/logger_extension.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_group.dart';
import 'package:ikuyo_finance/features/auto_transaction/models/auto_transaction_log_status.dart';

/// * Callback saat user tap notifikasi (set dari main.dart / router)
typedef NotificationTapCallback = void Function(String groupUlid);

class AutoTransactionNotificationService {
  static const _channelSuccess = 'auto_tx_success';
  static const _channelWarning = 'auto_tx_warning';
  static const _channelError = 'auto_tx_error';

  // * Diset dari main.dart untuk navigasi ke halaman log
  static NotificationTapCallback? onNotificationTap;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('ic_launcher_foreground');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleTap,
    );

    await _createChannels();
    logService('AutoTransactionNotificationService diinisialisasi');
  }

  // * Panggil ini dari Workmanager isolate (tanpa tap handler)
  Future<void> initializeForBackground() async {
    const android = AndroidInitializationSettings('ic_launcher_foreground');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings: settings);
    await _createChannels();
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// * Kirim notifikasi ringkasan hasil eksekusi satu grup
  Future<void> showExecutionResult(
    AutoTransactionGroup group,
    int totalSuccess,
    int totalFailure,
    int totalSkipped,
  ) async {
    final status = _resolveStatus(totalSuccess, totalFailure, totalSkipped);
    final notifId = group.id % 2000000000;

    final (title, body, channelId, channelName, importance) = switch (status) {
      AutoTransactionLogStatus.success => (
        'Auto Transaksi Berhasil',
        '${group.name}: $totalSuccess transaksi berhasil dibuat',
        _channelSuccess,
        'Auto Transaction',
        Importance.defaultImportance,
      ),
      AutoTransactionLogStatus.partial => (
        'Auto Transaksi Sebagian Berhasil',
        '${group.name}: $totalSuccess berhasil, $totalFailure gagal',
        _channelWarning,
        'Auto Transaction Peringatan',
        Importance.high,
      ),
      AutoTransactionLogStatus.failed => (
        'Auto Transaksi Gagal',
        '${group.name}: $totalFailure transaksi gagal dieksekusi',
        _channelError,
        'Auto Transaction Error',
        Importance.high,
      ),
      AutoTransactionLogStatus.skipped => (
        'Auto Transaksi Dilewati',
        '${group.name}: jadwal dilewati ($totalSkipped kali)',
        _channelWarning,
        'Auto Transaction Peringatan',
        Importance.defaultImportance,
      ),
    };

    await _plugin.show(
      id: notifId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: importance,
          priority: importance == Importance.high
              ? Priority.high
              : Priority.defaultPriority,
          styleInformation: const DefaultStyleInformation(true, true),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      payload: group.ulid,
    );
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  Future<void> _createChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelSuccess,
        'Auto Transaction',
        description: 'Notifikasi keberhasilan eksekusi auto transaksi',
        importance: Importance.defaultImportance,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelWarning,
        'Auto Transaction Peringatan',
        description: 'Notifikasi peringatan eksekusi auto transaksi',
        importance: Importance.high,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelError,
        'Auto Transaction Error',
        description: 'Notifikasi error eksekusi auto transaksi',
        importance: Importance.high,
      ),
    );
  }

  static void _handleTap(NotificationResponse response) {
    final groupUlid = response.payload;
    if (groupUlid != null && onNotificationTap != null) {
      onNotificationTap!(groupUlid);
    }
  }

  AutoTransactionLogStatus _resolveStatus(
    int success,
    int failure,
    int skipped,
  ) {
    if (success > 0 && failure == 0) return AutoTransactionLogStatus.success;
    if (success > 0 && failure > 0) return AutoTransactionLogStatus.partial;
    if (success == 0 && skipped > 0 && failure == 0) {
      return AutoTransactionLogStatus.skipped;
    }
    return AutoTransactionLogStatus.failed;
  }
}
