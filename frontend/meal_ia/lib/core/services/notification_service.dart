import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
        // Manejar el clic en la notificación
      },
    );

    _initialized = true;
  }

  Future<void> scheduleStreakReminder(bool fulfilledToday) async {
    if (kIsWeb) return; // Not supported on web
    await init();

    // Cancelar cualquier recordatorio anterior para no duplicar
    await cancelStreakReminder();

    // Programar para hoy a las 22:00
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, 22, 0);

    if (fulfilledToday) {
       // Si ya cumplió hoy, programamos para mañana a las 22:00
       scheduledDate = scheduledDate.add(const Duration(days: 1));
    } else {
       // Si no ha cumplido hoy, pero ya pasaron las 22:00, lo pasamos a mañana
       if (scheduledDate.isBefore(now)) {
         scheduledDate = scheduledDate.add(const Duration(days: 1));
       }
    }

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: 0, // ID fijo para el recordatorio de racha
        title: '¡Tu racha está en peligro! 🔥',
        body: 'Genera tu receta del día antes de que termine el día para no perder tu progreso.',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'streak_channel',
            'Recordatorios de Racha',
            channelDescription: 'Avisa cuando estás a punto de perder la racha diaria',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // Repetir todos los días a la misma hora
      );
      debugPrint("Recordatorio de racha programado para: $scheduledDate");
    } catch (e) {
      debugPrint("Error programando notificación: $e");
    }
  }

  Future<void> cancelStreakReminder() async {
    if (kIsWeb) return;
    await init();
    try {
      await flutterLocalNotificationsPlugin.cancel(id: 0);
      debugPrint("Recordatorio de racha cancelado (Meta cumplida).");
    } catch (e) {
      debugPrint("Error cancelando notificación: $e");
    }
  }
}
