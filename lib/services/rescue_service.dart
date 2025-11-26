import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async'; // Agregar este import para StreamSubscription

// El nombre de la colección que usamos en Firebase para las solicitudes de auxilio.
const String RESCUES_COLLECTION = 'rescues';

class RescueService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionSubscription;

  // **********************************************
  // LÓGICA DEL CLIENTE: CREAR SOLICITUD DE AUXILIO
  // **********************************************

  /// 1. Crea un nuevo documento de rescate en Firestore.
  ///    Esto se llama cuando el Cliente presiona "SOS".
  Future<String> createRescueRequest(double clientLat, double clientLng) async {
    try {
      // Genera un ID automáticamente por Firestore
      final docRef = await _firestore.collection(RESCUES_COLLECTION).add({
        'clientLat': clientLat,
        'clientLng': clientLng,
        'status': 'PENDING', // Estado inicial
        'timestamp': FieldValue.serverTimestamp(),
        // 'mechanicId': null, // Se asignará cuando un mecánico acepte
        // 'mechanicLat': null,
        // 'mechanicLng': null,
      });
      // Retorna el ID del documento para que el cliente pueda rastrearlo
      return docRef.id;
    } catch (e) {
      print('Error al crear solicitud de rescate: $e');
      rethrow;
    }
  }

  // **********************************************
  // LÓGICA DEL MECÁNICO: ENVÍO DE UBICACIÓN EN TIEMPO REAL
  // **********************************************

  /// 2. Inicia el seguimiento GPS y actualiza Firestore continuamente.
  ///    Esto se llama en la app del Mecánico cuando acepta el rescate.
  Stream<Position> startMechanicTracking(String rescueId, String mechanicId) {
    // 2.1. Configura la precisión del GPS
    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Actualiza cada 10 metros
    );

    // 2.2. Obtiene un Stream de actualizaciones de posición
    final positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    );

    // 2.3. Escucha el stream y actualiza Firebase por cada nueva posición
    _positionSubscription = positionStream.listen((Position position) async {
      try {
        await _firestore.collection(RESCUES_COLLECTION).doc(rescueId).update({
          'mechanicId': mechanicId,
          'mechanicLat': position.latitude,
          'mechanicLng': position.longitude,
          'status': 'EN_ROUTE',
          'lastUpdate': FieldValue.serverTimestamp(),
        });
      } catch (error) {
        print("Error al actualizar ubicación del mecánico ($rescueId): $error");
      }
    });

    // Retorna el stream original de posición si la app del mecánico quiere mostrar su propia ubicación
    return positionStream;
  }

  // **********************************************
  // LÓGICA DEL CLIENTE: RECEPCIÓN DE UBICACIÓN EN TIEMPO REAL
  // **********************************************

  /// 3. Devuelve un Stream de DocumentSnapshot para escuchar los cambios.
  ///    Esto se usa en el StreamBuilder del mapa del Cliente.
  Stream<DocumentSnapshot> getRescueStream(String rescueId) {
    return _firestore
        .collection(RESCUES_COLLECTION)
        .doc(rescueId)
        .snapshots();
  }

  // **********************************************
  // LÓGICA DEL MECÁNICO: ACEPTAR SOLICITUD
  // **********************************************

  /// 4. Permite a un mecánico aceptar una solicitud de rescate
  Future<void> acceptRescue(String rescueId, String mechanicId) async {
    try {
      await _firestore.collection(RESCUES_COLLECTION).doc(rescueId).update({
        'mechanicId': mechanicId,
        'status': 'ACCEPTED',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error al aceptar rescate: $e');
      rethrow;
    }
  }

  // **********************************************
  // LÓGICA GENERAL: ACTUALIZAR ESTADO
  // **********************************************

  /// 5. Actualiza el estado de un rescate
  Future<void> updateRescueStatus(String rescueId, String status) async {
    try {
      await _firestore.collection(RESCUES_COLLECTION).doc(rescueId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error al actualizar estado del rescate: $e');
      rethrow;
    }
  }

  // **********************************************
  // LÓGICA: CANCELAR SEGUIMIENTO
  // **********************************************

  /// 6. Detiene el seguimiento GPS y limpia recursos
  void stopMechanicTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// 7. Dispose para limpiar recursos cuando el servicio ya no se use
  void dispose() {
    stopMechanicTracking();
  }
}