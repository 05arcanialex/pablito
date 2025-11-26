// viewmodels/ubicaciones_viewmodel.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:latlong2/latlong.dart';
import '../models/database_helper.dart';
import '../services/courier_service.dart' as courier_service;
import '../services/user_service.dart' as user_service;
import '../services/rescue_service.dart';
import '../services/osrm_service.dart';

class UbicacionesViewModel extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  
  // CORRECCIÓN: Inicializar en el constructor, no con 'late'
  final user_service.UserService _userService;
  late final courier_service.CourierService _courierService;

  bool _loading = false;
  String? _error;

  // GPS
  LatLng? _currentLatLng;
  LatLng? _pickedLatLng;
  bool _siguiendo = true;
  StreamSubscription<Position>? _posSub;

  // DIRECCIÓN
  String _direccion = '';
  String? _direccionManual;

  // REGISTRO
  int? _codRegistro;

  // CLIENTE AUTO-DETECTADO
  int? _codClienteSel;
  String? _clienteNombreSel;

  // COURRIER - NUEVAS PROPIEDADES
  String? _currentRescueId;
  StreamSubscription<courier_service.RescueRequest>? _rescueSubscription;
  List<user_service.Vehicle> _userVehicles = [];
  List<LatLng>? _routePolyline;
  LatLng? _mechanicLocation;

  // CONSTRUCTOR CORREGIDO
  UbicacionesViewModel() : _userService = user_service.UserService(DatabaseHelper.instance) {
    // Inicializar CourierService en el constructor
    _courierService = courier_service.CourierService(
      RescueService(),
      _userService,
      OSRMService(),
      _db,
    );
  }

  // GETTERS
  bool get loading => _loading;
  String? get error => _error;
  LatLng? get currentLatLng => _currentLatLng;
  LatLng? get pickedLatLng => _pickedLatLng;
  bool get siguiendo => _siguiendo;
  String get direccion => _direccionManual?.trim().isNotEmpty == true ? _direccionManual! : _direccion;
  int? get codRegistro => _codRegistro;
  int? get codClienteSel => _codClienteSel;
  String get clienteNombreSel => _clienteNombreSel ?? 'SIN CLIENTE';
  
  // COURRIER GETTERS
  List<user_service.Vehicle> get userVehicles => _userVehicles;
  List<LatLng>? get routePolyline => _routePolyline;
  LatLng? get mechanicLocation => _mechanicLocation;
  String? get currentRescueId => _currentRescueId;

  // ================= INIT CON COURRIER =================
  Future<void> init() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // ELIMINADO: _initializeServices() - ya no es necesario
      
      await _ensureAuxilioDDL();
      await _ensurePermisos();
      await _ensureClienteSeleccionado();

      // Cargar vehículos del usuario
      await _loadUserVehicles();

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLatLng = LatLng(pos.latitude, pos.longitude);
      _pickedLatLng = _currentLatLng;
      await _reverseGeocode(_pickedLatLng!);
      _startPosStream();
    } catch (e) {
      _error = 'ERROR: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ELIMINADO: _initializeServices() - ya no es necesario

  Future<void> _loadUserVehicles() async {
  try {
    if (_codClienteSel != null) {
      print('🔍 Cargando vehículos para cliente: $_codClienteSel');
      _userVehicles = await _userService.getClientVehicles(_codClienteSel!);
      print('✅ Vehículos cargados: ${_userVehicles.length}');
    } else {
      _userVehicles = [];
      print('⚠️ No hay cliente seleccionado para cargar vehículos');
    }
  } catch (e) {
    print('Error cargando vehículos: $e');
    _userVehicles = [];
  }
}

  @override
  void dispose() {
    _posSub?.cancel();
    _rescueSubscription?.cancel();
    _courierService.dispose();
    super.dispose();
  }

  // ================= SERVICIOS COURRIER =================

  /// Solicitar auxilio usando el sistema Courrier
  Future<String> solicitarAuxilioCourrier({
    required int vehicleId,
    required String problema,
  }) async {
    try {
      final ubicacion = _pickedLatLng ?? _currentLatLng;
      if (ubicacion == null) throw Exception('No hay ubicación seleccionada');
      
      _loading = true;
      notifyListeners();

      final rescueId = await _courierService.requestMechanicHelp(
        vehicleId: vehicleId,
        problemDescription: problema,
        location: ubicacion,
      );

      _currentRescueId = rescueId;
      
      // Escuchar actualizaciones del rescate en tiempo real
      _startRescueListener(rescueId);
      
      _loading = false;
      notifyListeners();
      
      return rescueId;
    } catch (e) {
      _loading = false;
      _error = 'Error solicitando auxilio: $e';
      notifyListeners();
      rethrow;
    }
  }

  void _startRescueListener(String rescueId) {
    _rescueSubscription?.cancel();
    _rescueSubscription = _courierService.getRescueUpdates(rescueId).listen(
      (rescue) {
        _handleRescueUpdate(rescue);
      },
      onError: (error) {
        print('Error en stream de rescate: $error');
        _error = 'Error en seguimiento: $error';
        notifyListeners();
      }
    );
  }

  void _handleRescueUpdate(courier_service.RescueRequest rescue) {
    print('Actualización de rescate: ${rescue.status}');
    
    // Actualizar ubicación del mecánico
    if (rescue.mechanicLocation != null) {
      _mechanicLocation = rescue.mechanicLocation;
      
      // Calcular ruta si tenemos ambas ubicaciones
      if (_currentLatLng != null) {
        _calculateRouteToMechanic();
      }
    }
    
    notifyListeners();
    
    // Manejar diferentes estados
    switch (rescue.status) {
      case courier_service.RescueStatus.accepted:
        _onRescueAccepted(rescue);
        break;
      case courier_service.RescueStatus.enRoute:
        _onMechanicEnRoute(rescue);
        break;
      case courier_service.RescueStatus.arrived:
        _onMechanicArrived(rescue);
        break;
      case courier_service.RescueStatus.completed:
        _onRescueCompleted(rescue);
        break;
      case courier_service.RescueStatus.cancelled:
        _onRescueCancelled(rescue);
        break;
      default:
        break;
    }
  }

  Future<void> _calculateRouteToMechanic() async {
    if (_currentLatLng == null || _mechanicLocation == null) return;
    
    try {
      _routePolyline = await _courierService.calculateRouteToClient(
        _mechanicLocation!,
        _currentLatLng!,
      );
      notifyListeners();
    } catch (e) {
      print('Error calculando ruta: $e');
    }
  }

  void _onRescueAccepted(courier_service.RescueRequest rescue) {
    print('Mecánico aceptó el rescate: ${rescue.mechanicId}');
    // Podrías mostrar notificación aquí
  }

  void _onMechanicEnRoute(courier_service.RescueRequest rescue) {
    print('Mecánico en camino');
    // Actualizar UI para mostrar "Mecánico en camino"
  }

  void _onMechanicArrived(courier_service.RescueRequest rescue) {
    print('Mecánico llegó a la ubicación');
    // Mostrar que el mecánico llegó
  }

  void _onRescueCompleted(courier_service.RescueRequest rescue) {
    print('Rescate completado');
    _cleanupRescue();
  }

  void _onRescueCancelled(courier_service.RescueRequest rescue) {
    print('Rescate cancelado');
    _cleanupRescue();
  }

  void _cleanupRescue() {
    _currentRescueId = null;
    _mechanicLocation = null;
    _routePolyline = null;
    _rescueSubscription?.cancel();
    notifyListeners();
  }

  /// Cancelar rescate actual
  Future<void> cancelarRescateActual() async {
    if (_currentRescueId != null) {
      await _courierService.cancelRescue(_currentRescueId!);
      _cleanupRescue();
    }
  }

  /// Obtener ETA del mecánico
  Future<Duration?> obtenerETA() async {
    if (_currentLatLng == null || _mechanicLocation == null) return null;
    
    return await _courierService.calculateETA(
      _mechanicLocation!,
      _currentLatLng!,
    );
  }

  // ================= MÉTODOS EXISTENTES (MANTENIDOS) =================
  
  Future<void> _ensureAuxilioDDL() async {
    await _db.rawQuery('''
      CREATE TABLE IF NOT EXISTS auxilio_posicion(
        cod_aux_pos INTEGER PRIMARY KEY AUTOINCREMENT,
        cod_reg_auxilio INTEGER NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        precision_m REAL,
        creado_en TEXT NOT NULL,
        FOREIGN KEY(cod_reg_auxilio) REFERENCES registro_auxilio_mecanico(cod_reg_auxilio)
          ON UPDATE CASCADE ON DELETE CASCADE
      );
    ''');
  }

  Future<void> _ensurePermisos() async {
    final service = await Geolocator.isLocationServiceEnabled();
    if (!service) throw 'GPS DESACTIVADO';
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw 'PERMISOS DE UBICACIÓN DENEGADOS';
    }
  }

  Future<void> _ensureClienteSeleccionado() async {
    final rows = await _db.rawQuery('''
      SELECT c.cod_cliente, (p.nombre || ' ' || p.apellidos) AS nombre
      FROM cliente c
      JOIN persona p ON p.cod_persona = c.cod_persona
      ORDER BY c.cod_cliente ASC
      LIMIT 1;
    ''');

    if (rows.isNotEmpty) {
      _codClienteSel = rows.first['cod_cliente'] as int;
      _clienteNombreSel = (rows.first['nombre'] ?? '') as String;
      return;
    }

    final idPers = await _db.rawInsert(
      'INSERT INTO persona(nombre, apellidos, telefono, email) VALUES(?,?,?,?)',
      ['CLIENTE', 'DEMO', '70000000', 'demo@example.com'],
    );
    final idCliente = await _db.rawInsert(
      'INSERT INTO cliente(cod_persona) VALUES(?)',
      [idPers],
    );
    _codClienteSel = idCliente;
    _clienteNombreSel = 'CLIENTE DEMO';
  }

  void _startPosStream() {
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen(
      (pos) {
        if (_siguiendo) {
          _currentLatLng = LatLng(pos.latitude, pos.longitude);
          _pickedLatLng ??= _currentLatLng;
          notifyListeners();
        }
      },
      onError: (e) {
        _error = 'STREAM GPS: $e';
        notifyListeners();
      },
      cancelOnError: false,
    );
  }

  void toggleSeguir() {
    _siguiendo = !_siguiendo;
    notifyListeners();
  }

  Future<void> onDragMarker(LatLng p) async {
    _pickedLatLng = p;
    await _reverseGeocode(p);
    notifyListeners();
  }

  void setDireccionManual(String v) {
    _direccionManual = v;
    notifyListeners();
  }

  Future<void> _reverseGeocode(LatLng p) async {
    try {
      final placemarks = await geo.placemarkFromCoordinates(p.latitude, p.longitude);
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        _direccion =
            '${pm.street ?? ''}, ${pm.locality ?? ''}, ${pm.administrativeArea ?? ''}, ${pm.country ?? ''}'
                .replaceAll(RegExp(r'(,\s*)+'), ', ')
                .trim();
      }
    } catch (_) {
      _direccion = 'DIRECCIÓN NO DISPONIBLE';
    }
  }

  // MÉTODO LEGACY - Mantener para compatibilidad
  Future<bool> confirmarSolicitud({int? codCliente}) async {
    final c = codCliente ?? _codClienteSel;
    if (c == null) {
      _error = 'NO HAY CLIENTE SELECCIONADO';
      notifyListeners();
      return false;
    }
    if (_pickedLatLng == null) {
      _error = 'NO HAY COORDENADAS';
      notifyListeners();
      return false;
    }

    _loading = true;
    notifyListeners();

    try {
      final now = DateTime.now().toIso8601String();
      final ubic = direccion;

      final idReg = await _db.rawInsert('''
        INSERT INTO registro_auxilio_mecanico(fecha, ubicacion_cliente, cod_cliente)
        VALUES(?,?,?)
      ''', [now, ubic, c]);

      final pos = _pickedLatLng!;
      await _db.rawInsert('''
        INSERT INTO auxilio_posicion(cod_reg_auxilio, lat, lng, precision_m, creado_en)
        VALUES(?,?,?,?,?)
      ''', [idReg, pos.latitude, pos.longitude, null, now]);

      _codRegistro = idReg;
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'ERROR AL GUARDAR: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }
}