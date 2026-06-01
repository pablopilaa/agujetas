import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

enum AgujetasNotificationResult {
  scheduledExact,
  scheduledInexact,
  shown,
  permissionDenied,
  disabled,
}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _disabled = false;

  static Future<void> initialize() async {
    if (_initialized || _disabled) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
      );
    } catch (_) {
      _disabled = true;
      return;
    }
    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
    }
    _initialized = true;
  }

  static Future<bool> _requestNotificationPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  static Future<AgujetasNotificationResult> showSessionSaved() async {
    await initialize();
    if (!_initialized) return AgujetasNotificationResult.disabled;
    final canNotify = await _requestNotificationPermission();
    if (!canNotify) return AgujetasNotificationResult.permissionDenied;
    await _plugin.show(
      id: 101,
      title: 'Sesión guardada',
      body: 'Tu entrenamiento quedo sincronizado en Agujetas.',
      notificationDetails: _details(
        channelId: 'session_status',
        channelName: 'Sesiones',
      ),
    );
    return AgujetasNotificationResult.shown;
  }

  static Future<AgujetasNotificationResult> scheduleRestFinished(
    Duration duration,
  ) async {
    await initialize();
    if (!_initialized) return AgujetasNotificationResult.disabled;
    final canNotify = await _requestNotificationPermission();
    if (!canNotify) return AgujetasNotificationResult.permissionDenied;
    final when = tz.TZDateTime.now(tz.local).add(duration);
    return _scheduleWithFallback(
      id: 201,
      title: 'Descanso terminado',
      body: 'Volver a la siguiente serie.',
      scheduledDate: when,
      channelId: 'rest_timer',
      channelName: 'Descansos',
    );
  }

  static Future<AgujetasNotificationResult> scheduleBodyWeightReminder({
    required int hour,
    required int minute,
  }) async {
    await initialize();
    if (!_initialized) return AgujetasNotificationResult.disabled;
    final canNotify = await _requestNotificationPermission();
    if (!canNotify) return AgujetasNotificationResult.permissionDenied;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return _scheduleWithFallback(
      id: 301,
      title: 'Registrar peso',
      body: 'Anota tu peso corporal para mantener el seguimiento semanal.',
      scheduledDate: scheduled,
      channelId: 'body_weight',
      channelName: 'Peso corporal',
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<AgujetasNotificationResult> _scheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String channelId,
    required String channelName,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final notificationDetails = _details(
      channelId: channelId,
      channelName: channelName,
    );
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
      );
      return AgujetasNotificationResult.scheduledExact;
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: matchDateTimeComponents,
        );
        return AgujetasNotificationResult.scheduledInexact;
      } catch (_) {
        return AgujetasNotificationResult.disabled;
      }
    }
  }

  static NotificationDetails _details({
    required String channelId,
    required String channelName,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Alertas locales de Agujetas',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
