// services/courier_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/database_helper.dart';
import './user_service.dart';
import './rescue_service.dart';
import './osrm_service.dart';

class CourierService {
  final RescueService _rescueService;
  final UserService _userService;
  final OSRMService _osrmService;
  final DatabaseHelper _databaseHelper;

  CourierService(
    this._rescueService,
    this._userService,
    this._osrmService,
    this._databaseHelper,
  );

  // **************************
  // LÓGICA DEL CLIENTE
  // **************************

  /// Solicitar auxilio mecánico
  Future<String> requestMechanicHelp({
    required int vehicleId,
    required String problemDescription,
    required LatLng location,
  }) async {
    try {
      final user = await _userService.getCurrentUser();
      
      // Crear solicitud en Firestore
      final rescueId = await _rescueService.createRescueRequest(
        location.latitude,
        location.longitude,
      );

      // Obtener información del vehículo
      final vehicle = await _getVehicleInfo(vehicleId);
      
      // Actualizar Firestore con información completa
      await FirebaseFirestore.instance
          .collection('rescues')
          .doc(rescueId)
          .update({
            'userId': user.id,
            'userName': user.name,
            'userPhone': user.phone,
            'vehicleInfo': '${vehicle.marca} ${vehicle.modelo} - ${vehicle.placas}',
            'problemDescription': problemDescription,
            'vehicleId': vehicleId,
            'userCodPersona': user.codPersona,
            'status': 'PENDING',
          });

      // Registrar en la tabla local de auxilios mecánicos
      await _registerLocalRescue(rescueId, user.codPersona, vehicleId, location, problemDescription);

      return rescueId;
    } catch (e) {
      print('Error en requestMechanicHelp: $e');
      rethrow;
    }
  }

  /// Registrar auxilio en SQLite
  Future<void> _registerLocalRescue(
    String rescueId, 
    int codPersona, 
    int vehicleId, 
    LatLng location,
    String problemDescription,
  ) async {
    final db = await _databaseHelper.database;
    
    // Obtener cod_cliente desde cod_persona
    final clienteData = await db.query(
      'cliente',
      where: 'cod_persona = ?',
      whereArgs: [codPersona],
    );

    if (clienteData.isNotEmpty) {
      final codCliente = clienteData.first['cod_cliente'] as int;
      
      await db.insert('registro_auxilio_mecanico', {
        'fecha': DateTime.now().toIso8601String(),
        'ubicacion_cliente': '${location.latitude}, ${location.longitude}',
        'cod_cliente': codCliente,
        'firebase_rescue_id': rescueId,
        'descripcion_problema': problemDescription,
        'cod_vehiculo': vehicleId,
        'estado_auxilio': 'PENDIENTE',
      });
    }
  }

  /// Obtener información del vehículo
  Future<Vehicle> _getVehicleInfo(int vehicleId) async {
    final db = await _databaseHelper.database;
    
    final vehicleData = await db.rawQuery('''
      SELECT 
        v.cod_vehiculo,
        v.placas,
        v.kilometraje,
        v.color,
        v.numero_serie,
        mv.descripcion as marca,
        modv.descripcion_modelo as modelo,
        modv.anio_modelo as anio
      FROM vehiculo v
      JOIN marca_vehiculo mv ON mv.cod_marca_veh = v.cod_marca_veh
      JOIN modelo_vehiculo modv ON modv.cod_modelo_veh = v.cod_modelo_veh
      WHERE v.cod_vehiculo = ?
    ''', [vehicleId]);

    if (vehicleData.isEmpty) {
      throw Exception('Vehículo no encontrado');
    }

    return Vehicle.fromMap(vehicleData.first);
  }

  /// Escuchar actualizaciones del rescate desde Firebase
  Stream<RescueRequest> getRescueUpdates(String rescueId) {
    return _rescueService.getRescueStream(rescueId).map((snapshot) {
      if (snapshot.exists) {
        return RescueRequest.fromFirestore(
          snapshot.data() as Map<String, dynamic>,
          snapshot.id,
        );
      }
      throw Exception('Rescate no encontrado');
    });
  }

  /// Cancelar solicitud de auxilio
  Future<void> cancelRescue(String rescueId) async {
    try {
      // Actualizar estado en Firebase
      await _rescueService.updateRescueStatus(rescueId, 'CANCELLED');
      
      // Actualizar estado en SQLite
      await _updateLocalRescueStatus(rescueId, RescueStatus.cancelled);
    } catch (e) {
      print('Error cancelando rescate: $e');
      rethrow;
    }
  }

  // **************************
  // LÓGICA DEL MECÁNICO
  // **************************

  /// Obtener solicitudes pendientes desde Firebase
  Stream<List<RescueRequest>> getPendingRescues() {
    return FirebaseFirestore.instance
        .collection('rescues')
        .where('status', isEqualTo: 'PENDING')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RescueRequest.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Obtener solicitudes activas (pendientes y aceptadas)
  Stream<List<RescueRequest>> getActiveRescues() {
    return FirebaseFirestore.instance
        .collection('rescues')
        .where('status', whereIn: ['PENDING', 'ACCEPTED', 'EN_ROUTE'])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RescueRequest.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Aceptar un rescate
  Future<void> acceptRescue(String rescueId) async {
    try {
      final mechanic = await _userService.getCurrentUser();
      
      if (!(await _userService.isMechanic())) {
        throw Exception('Solo los mecánicos pueden aceptar rescates');
      }

      // Aceptar en Firebase
      await _rescueService.acceptRescue(rescueId, mechanic.id);
      
      // Registrar en la base de datos local
      await _registerMechanicAcceptance(rescueId, mechanic.codPersona);
    } catch (e) {
      print('Error aceptando rescate: $e');
      rethrow;
    }
  }

  /// Registrar aceptación del mecánico en SQLite
  Future<void> _registerMechanicAcceptance(String rescueId, int codPersona) async {
    final db = await _databaseHelper.database;
    
    // Obtener cod_empleado desde cod_persona
    final empleadoData = await db.query(
      'empleado',
      where: 'cod_persona = ?',
      whereArgs: [codPersona],
    );

    if (empleadoData.isNotEmpty) {
      final codEmpleado = empleadoData.first['cod_empleado'] as int;
      
      // Actualizar el registro de auxilio con el mecánico asignado
      await db.update(
        'registro_auxilio_mecanico',
        {
          'cod_empleado': codEmpleado,
          'estado_auxilio': 'ACEPTADO',
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        },
        where: 'firebase_rescue_id = ?',
        whereArgs: [rescueId],
      );
    }
  }

  /// Iniciar seguimiento del mecánico - CORREGIDO
  Stream<Position> startMechanicTracking(String rescueId) async* {
    final user = await _userService.getCurrentUser();
    final stream = _rescueService.startMechanicTracking(rescueId, user.id);
    yield* stream;
  }

  /// Calcular ruta hacia el cliente - CORREGIDO
  Future<List<LatLng>?> calculateRouteToClient(
      LatLng mechanicLocation, LatLng clientLocation) async {
    try {
      final route = await _osrmService.getRoute(mechanicLocation, clientLocation);
      if (route != null && route.routes.isNotEmpty) {
        return route.routes.first.geometryDecoded;
      }
      return null;
    } catch (e) {
      print('Error calculando ruta: $e');
      return null;
    }
  }

  /// Calcular ETA (Tiempo Estimado de Llegada)
  Future<Duration?> calculateETA(LatLng from, LatLng to) async {
    try {
      final route = await _osrmService.getRoute(from, to);
      if (route != null && route.routes.isNotEmpty) {
        return Duration(seconds: route.routes.first.duration.toInt());
      }
      return null;
    } catch (e) {
      print('Error calculando ETA: $e');
      return null;
    }
  }

  /// Actualizar estado del rescate
  Future<void> updateRescueStatus(String rescueId, RescueStatus status) async {
    try {
      // Actualizar en Firebase
      await _rescueService.updateRescueStatus(rescueId, status.name.toUpperCase());
      
      // Actualizar también en SQLite
      await _updateLocalRescueStatus(rescueId, status);

      // Si el estado es completado, registrar trabajo realizado
      if (status == RescueStatus.completed) {
        await _registerCompletedWork(rescueId);
      }
    } catch (e) {
      print('Error actualizando estado del rescate: $e');
      rethrow;
    }
  }

  Future<void> _updateLocalRescueStatus(String rescueId, RescueStatus status) async {
    final db = await _databaseHelper.database;
    
    await db.update(
      'registro_auxilio_mecanico',
      {
        'estado_auxilio': status.name.toUpperCase(),
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      where: 'firebase_rescue_id = ?',
      whereArgs: [rescueId],
    );
  }

  /// Registrar trabajo completado en auxilio mecánico
  Future<void> _registerCompletedWork(String rescueId) async {
    final db = await _databaseHelper.database;
    
    // Obtener datos del rescate desde SQLite
    final rescueData = await db.query(
      'registro_auxilio_mecanico',
      where: 'firebase_rescue_id = ?',
      whereArgs: [rescueId],
    );

    if (rescueData.isNotEmpty) {
      final rescue = rescueData.first;
      final codEmpleado = rescue['cod_empleado'] as int?;
      
      if (codEmpleado != null) {
        // Registrar en la tabla de trabajos de auxilio (si existe)
        // Esto puede expandirse según tus necesidades
        await db.insert('reg_aux_mec_tipo_trabajo', {
          'cod_reg_auxilio': rescue['cod_reg_auxilio'],
          'cod_tipo_trabajo': 1, // Por defecto, puede ajustarse
          'detalles': 'Auxilio mecánico completado - ${rescue['descripcion_problema']}',
          'costo': 0.0, // Puede calcularse según el trabajo
        });
      }
    }
  }

  // **************************
  // HISTORIAL Y CONSULTAS
  // **************************

  /// Obtener historial de auxilios del usuario actual
  Future<List<LocalRescueRecord>> getRescueHistory() async {
    final db = await _databaseHelper.database;
    final user = await _userService.getCurrentUser();
    
    final history = await db.rawQuery('''
      SELECT 
        ram.cod_reg_auxilio,
        ram.fecha,
        ram.ubicacion_cliente,
        ram.descripcion_problema,
        ram.estado_auxilio,
        ram.firebase_rescue_id,
        v.placas,
        mv.descripcion as marca,
        modv.descripcion_modelo as modelo,
        p.nombre || ' ' || p.apellidos as cliente_nombre
      FROM registro_auxilio_mecanico ram
      JOIN cliente c ON c.cod_cliente = ram.cod_cliente
      JOIN persona p ON p.cod_persona = c.cod_persona
      JOIN vehiculo v ON v.cod_vehiculo = ram.cod_vehiculo
      JOIN marca_vehiculo mv ON mv.cod_marca_veh = v.cod_marca_veh
      JOIN modelo_vehiculo modv ON modv.cod_modelo_veh = v.cod_modelo_veh
      WHERE p.cod_persona = ?
      ORDER BY ram.fecha DESC
      LIMIT 50
    ''', [user.codPersona]);

    return history.map((record) => LocalRescueRecord.fromMap(record)).toList();
  }

  /// Obtener auxilios asignados al mecánico actual
  Future<List<LocalRescueRecord>> getAssignedRescues() async {
    final db = await _databaseHelper.database;
    
    if (!(await _userService.isMechanic())) {
      return [];
    }

    final employeeId = await _userService.getUserEmployeeId();
    if (employeeId == null) return [];

    final rescues = await db.rawQuery('''
      SELECT 
        ram.cod_reg_auxilio,
        ram.fecha,
        ram.ubicacion_cliente,
        ram.descripcion_problema,
        ram.estado_auxilio,
        ram.firebase_rescue_id,
        v.placas,
        mv.descripcion as marca,
        modv.descripcion_modelo as modelo,
        p.nombre || ' ' || p.apellidos as cliente_nombre
      FROM registro_auxilio_mecanico ram
      JOIN cliente c ON c.cod_cliente = ram.cod_cliente
      JOIN persona p ON p.cod_persona = c.cod_persona
      JOIN vehiculo v ON v.cod_vehiculo = ram.cod_vehiculo
      JOIN marca_vehiculo mv ON mv.cod_marca_veh = v.cod_marca_veh
      JOIN modelo_vehiculo modv ON modv.cod_modelo_veh = v.cod_modelo_veh
      WHERE ram.cod_empleado = ? 
        AND ram.estado_auxilio IN ('ACEPTADO', 'EN_CAMINO', 'EN_PROGRESO')
      ORDER BY ram.fecha DESC
    ''', [employeeId]);

    return rescues.map((record) => LocalRescueRecord.fromMap(record)).toList();
  }

  // **************************
  // UTILIDADES
  // **************************

  /// Obtener detalles completos de un rescate
  Future<RescueDetails> getRescueDetails(String rescueId) async {
    try {
      // Obtener datos de Firebase
      final firestoreDoc = await FirebaseFirestore.instance
          .collection('rescues')
          .doc(rescueId)
          .get();

      if (!firestoreDoc.exists) {
        throw Exception('Rescate no encontrado en Firebase');
      }

      final firebaseData = RescueRequest.fromFirestore(
        firestoreDoc.data()!,
        firestoreDoc.id,
      );

      // Obtener datos locales de SQLite
      final db = await _databaseHelper.database;
      final localData = await db.query(
        'registro_auxilio_mecanico',
        where: 'firebase_rescue_id = ?',
        whereArgs: [rescueId],
      );

      LocalRescueRecord? localRecord;
      if (localData.isNotEmpty) {
        localRecord = LocalRescueRecord.fromMap(localData.first);
      }

      return RescueDetails(
        firebaseData: firebaseData,
        localRecord: localRecord,
      );
    } catch (e) {
      print('Error obteniendo detalles del rescate: $e');
      rethrow;
    }
  }

  /// Detener todos los trackings activos
  void stopAllTracking() {
    _rescueService.stopMechanicTracking();
  }

  /// Dispose para limpiar recursos
  void dispose() {
    stopAllTracking();
  }
}

// **************************
// MODELOS
// **************************

class RescueRequest {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final LatLng clientLocation;
  final String vehicleInfo;
  final String problemDescription;
  final DateTime createdAt;
  final RescueStatus status;
  final String? mechanicId;
  final LatLng? mechanicLocation;
  final int? vehicleId;
  final int? userCodPersona;

  RescueRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.clientLocation,
    required this.vehicleInfo,
    required this.problemDescription,
    required this.createdAt,
    this.status = RescueStatus.pending,
    this.mechanicId,
    this.mechanicLocation,
    this.vehicleId,
    this.userCodPersona,
  });

  factory RescueRequest.fromFirestore(Map<String, dynamic> data, String id) {
    return RescueRequest(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhone: data['userPhone'] ?? '',
      clientLocation: LatLng(
        (data['clientLat'] ?? 0.0).toDouble(),
        (data['clientLng'] ?? 0.0).toDouble(),
      ),
      vehicleInfo: data['vehicleInfo'] ?? '',
      problemDescription: data['problemDescription'] ?? '',
      createdAt: (data['timestamp'] as Timestamp).toDate(),
      status: _parseStatus(data['status'] ?? 'pending'),
      mechanicId: data['mechanicId'],
      mechanicLocation: data['mechanicLat'] != null && data['mechanicLng'] != null
          ? LatLng(
              (data['mechanicLat'] ?? 0.0).toDouble(),
              (data['mechanicLng'] ?? 0.0).toDouble(),
            )
          : null,
      vehicleId: data['vehicleId'],
      userCodPersona: data['userCodPersona'],
    );
  }

  static RescueStatus _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return RescueStatus.pending;
      case 'ACCEPTED':
        return RescueStatus.accepted;
      case 'EN_ROUTE':
        return RescueStatus.enRoute;
      case 'ARRIVED':
        return RescueStatus.arrived;
      case 'IN_PROGRESS':
        return RescueStatus.inProgress;
      case 'COMPLETED':
        return RescueStatus.completed;
      case 'CANCELLED':
        return RescueStatus.cancelled;
      default:
        return RescueStatus.pending;
    }
  }

  bool get isActive => status.index <= RescueStatus.inProgress.index;
  bool get isCompleted => status == RescueStatus.completed;
  bool get isCancelled => status == RescueStatus.cancelled;
}

enum RescueStatus {
  pending,    // Esperando mecánico
  accepted,   // Mecánico aceptó
  enRoute,    // Mecánico en camino
  arrived,    // Mecánico llegó
  inProgress, // En reparación
  completed,  // Completado
  cancelled,  // Cancelado
}

class LocalRescueRecord {
  final int codRegAuxilio;
  final DateTime fecha;
  final String ubicacionCliente;
  final String descripcionProblema;
  final String estadoAuxilio;
  final String firebaseRescueId;
  final String placas;
  final String marca;
  final String modelo;
  final String clienteNombre;

  LocalRescueRecord({
    required this.codRegAuxilio,
    required this.fecha,
    required this.ubicacionCliente,
    required this.descripcionProblema,
    required this.estadoAuxilio,
    required this.firebaseRescueId,
    required this.placas,
    required this.marca,
    required this.modelo,
    required this.clienteNombre,
  });

  factory LocalRescueRecord.fromMap(Map<String, dynamic> map) {
    return LocalRescueRecord(
      codRegAuxilio: map['cod_reg_auxilio'] as int,
      fecha: DateTime.parse(map['fecha'] as String),
      ubicacionCliente: map['ubicacion_cliente'] as String,
      descripcionProblema: map['descripcion_problema'] as String? ?? '',
      estadoAuxilio: map['estado_auxilio'] as String,
      firebaseRescueId: map['firebase_rescue_id'] as String,
      placas: map['placas'] as String,
      marca: map['marca'] as String,
      modelo: map['modelo'] as String,
      clienteNombre: map['cliente_nombre'] as String,
    );
  }

  String get vehiculoDescripcion => '$marca $modelo - $placas';
}

class RescueDetails {
  final RescueRequest firebaseData;
  final LocalRescueRecord? localRecord;

  RescueDetails({
    required this.firebaseData,
    this.localRecord,
  });

  bool get hasLocalData => localRecord != null;
}

// Modelo Vehicle 
class Vehicle {
  final int id;
  final String placas;
  final String marca;
  final String modelo;
  final String color;
  final int kilometraje;
  final String? numeroSerie;
  final int? anio;

  Vehicle({
    required this.id,
    required this.placas,
    required this.marca,
    required this.modelo,
    required this.color,
    required this.kilometraje,
    this.numeroSerie,
    this.anio,
  });

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['cod_vehiculo'] as int,
      placas: map['placas'] as String,
      marca: map['marca'] as String,
      modelo: map['modelo'] as String,
      color: map['color'] as String? ?? 'N/A',
      kilometraje: map['kilometraje'] as int? ?? 0,
      numeroSerie: map['numero_serie'] as String?,
      anio: map['anio'] as int?,
    );
  }

  String get descripcionCompleta => '$marca $modelo - $placas';

  @override
  String toString() {
    return 'Vehicle{id: $id, placas: $placas, marca: $marca, modelo: $modelo}';
  }
}