// services/local_notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Configuración de Plataformas
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); 
    
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

    // 2. Inicializar el plugin
    await _notificationsPlugin.initialize(initializationSettings);
  }

  // 3. Método FÁCIL para mostrar la notificación
  Future<void> showNewRescueNotification(String rescueId) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'nuevo_auxilio_channel_id', 
      'Nuevos Auxilios', 
      channelDescription: 'Notificaciones de nuevos auxilios disponibles',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    // 4. Mostrar
    await _notificationsPlugin.show(
      0, // ID de la notificación
      '🚨 ¡Nuevo Auxilio Recibido!', // Título
      'Se ha recibido una solicitud de auxilio de emergencia.', // Cuerpo
      platformDetails,
      payload: rescueId, 
    );
  }
}