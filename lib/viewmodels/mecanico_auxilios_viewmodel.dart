// viewmodels/mecanico_auxilios_viewmodel.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

// Importaciones de tus servicios y modelos
import '../models/database_helper.dart';
import '../services/courier_service.dart' as courier_service;
import '../services/user_service.dart' as user_service;
import '../services/rescue_service.dart';
import '../services/osrm_service.dart';

// 🔔 NUEVA IMPORTACIÓN DEL SERVICIO DE NOTIFICACIONES
import '../services/local_notification_service.dart'; 

class MecanicoAuxiliosViewModel extends ChangeNotifier {
  final DatabaseHelper _db;
  late final courier_service.CourierService _courierService;
  
  // 🔔 NUEVO: Instancia del servicio de notificaciones
  late final LocalNotificationService _notificationService; 

  // ESTADOS
  bool _loading = false;
  String? _error;
  MecanicoUIState _uiState = MecanicoUIState.buscandoAuxilios;
  bool _auxilioCompletado = false; 

  // LISTAS
  List<courier_service.RescueRequest> _auxiliosDisponibles = [];
  List<courier_service.RescueRequest> _auxiliosActivos = [];
  List<courier_service.LocalRescueRecord> _auxiliosAsignados = [];

  // AUXILIO SELECCIONADO
  courier_service.RescueRequest? _auxilioSeleccionado;
  courier_service.RescueDetails? _detallesAuxilio;

  // SEGUIMIENTO
  StreamSubscription<courier_service.RescueRequest>? _rescueSubscription;
  StreamSubscription<Position>? _trackingSubscription;
  List<LatLng>? _rutaAlCliente;
  Duration? _eta;
  LatLng? _currentMechanicLocation;

  // CONSTRUCTOR
  MecanicoAuxiliosViewModel() : _db = DatabaseHelper.instance {
    // 🔔 Inicializar y configurar el servicio de notificaciones
    _notificationService = LocalNotificationService();
    _notificationService.initialize();

    // Inicialización de servicios existentes
    _courierService = courier_service.CourierService(
      RescueService(),
      user_service.UserService(DatabaseHelper.instance),
      OSRMService(),
      _db,
    );
  }

  // GETTERS
  bool get loading => _loading;
  String? get error => _error;
  MecanicoUIState get uiState => _uiState;
  List<courier_service.RescueRequest> get auxiliosDisponibles => _auxiliosDisponibles;
  List<courier_service.RescueRequest> get auxiliosActivos => _auxiliosActivos;
  List<courier_service.LocalRescueRecord> get auxiliosAsignados => _auxiliosAsignados;
  courier_service.RescueRequest? get auxilioSeleccionado => _auxilioSeleccionado;
  courier_service.RescueDetails? get detallesAuxilio => _detallesAuxilio;
  List<LatLng>? get rutaAlCliente => _rutaAlCliente;
  Duration? get eta => _eta;
  LatLng? get currentMechanicLocation => _currentMechanicLocation;
  bool get auxilioCompletado => _auxilioCompletado;
  bool get tieneAuxilioActivo => _auxilioSeleccionado != null;
  bool get mostrarRuta => _rutaAlCliente != null && _rutaAlCliente!.isNotEmpty;

  // ================= INICIALIZACIÓN =================
  Future<void> init() async {
    _loading = true;
    _error = null;
    _auxilioCompletado = false;
    notifyListeners();

    try {
      await _ensurePermisosGPS();
      await _cargarUbicacionActual();
      await _cargarAuxiliosDisponibles();
      await _cargarAuxiliosAsignados();
      await _cargarAuxiliosActivos();

      if (_auxiliosActivos.isNotEmpty) {
        await seleccionarAuxilio(_auxiliosActivos.first.id);
      }

      _uiState = MecanicoUIState.buscandoAuxilios;
    } catch (e) {
      _error = 'Error inicializando: ${_getErrorMessage(e)}';
      _uiState = MecanicoUIState.error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorString = error.toString();
    
    if (errorString.contains('Solo los mecánicos') || 
        errorString.contains('rol') || 
        errorString.contains('mecánico') ||
        errorString.contains('isMechanic') ||
        errorString.contains('mechanic')) {
      return 'Servicio de auxilio disponible para todos los usuarios';
    }
    
    return errorString;
  }

  Future<void> _ensurePermisosGPS() async {
    final service = await Geolocator.isLocationServiceEnabled();
    if (!service) throw 'GPS desactivado. Activa la ubicación para usar el servicio de auxilio.';
    
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw 'Permisos de ubicación denegados. Necesitas permisos de ubicación para usar el servicio de auxilio.';
    }
  }

  Future<void> _cargarUbicacionActual() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentMechanicLocation = LatLng(position.latitude, position.longitude);
      print('📍 Ubicación actual cargada: $_currentMechanicLocation');
    } catch (e) {
      print('⚠️ Error cargando ubicación actual: $e');
    }
  }

  // ================= CARGA DE AUXILIOS (MODIFICADO CON NOTIFICACIÓN) =================
  Future<void> _cargarAuxiliosDisponibles() async {
    try {
      print('🔄 Cargando auxilios disponibles...');
      
      _courierService.getPendingRescues().listen((auxilios) {
        
        // **⭐ Lógica de Notificación ⭐**
        final bool yaTeniaAuxilios = _auxiliosDisponibles.isNotEmpty;
        final bool hayAuxiliosNuevos = auxilios.isNotEmpty;
        
        _auxiliosDisponibles = auxilios;
        
        // Disparar notificación si antes NO había y ahora SÍ hay
        if (!yaTeniaAuxilios && hayAuxiliosNuevos) {
            // Llama al servicio de notificación
            _notificationService.showNewRescueNotification(auxilios.first.id); 
        }

        print('✅ ${auxilios.length} auxilio(s) disponible(s) cargado(s)');
        notifyListeners();
      }, onError: (error) {
        print('❌ Error en stream de auxilios disponibles: $error');
      });
    } catch (e) {
      print('❌ Error cargando auxilios disponibles: $e');
    }
  }

  Future<void> _cargarAuxiliosActivos() async {
    try {
      print('🔄 Cargando auxilios activos...');
      _courierService.getActiveRescues().listen((auxilios) {
        _auxiliosActivos = auxilios;
        print('✅ ${auxilios.length} auxilio(s) activo(s) cargado(s)');
        notifyListeners();
      }, onError: (error) {
        print('❌ Error en stream de auxilios activos: $error');
      });
    } catch (e) {
      print('❌ Error cargando auxilios activos: $e');
    }
  }

  Future<void> _cargarAuxiliosAsignados() async {
    try {
      _auxiliosAsignados = await _courierService.getAssignedRescues();
      print('✅ ${_auxiliosAsignados.length} auxilio(s) asignado(s) cargado(s)');
    } catch (e) {
      print('❌ Error cargando auxilios asignados: $e');
    }
  }

  // ================= SELECCIÓN DE AUXILIO =================
  Future<void> seleccionarAuxilio(String rescueId) async {
    try {
      print('🔄 Seleccionando auxilio: $rescueId');
      
      _auxilioSeleccionado = null;
      _detallesAuxilio = null;
      _rutaAlCliente = null;
      _eta = null;
      _auxilioCompletado = false; 

      _detallesAuxilio = await _courierService.getRescueDetails(rescueId);
      _auxilioSeleccionado = _detallesAuxilio!.firebaseData;

      if (_currentMechanicLocation != null && _auxilioSeleccionado != null) {
        await _calcularRutaAlCliente();
      }

      _iniciarEscuchaAuxilio(rescueId);

      print('✅ Auxilio seleccionado correctamente');
      notifyListeners();
    } catch (e) {
      print('❌ Error seleccionando auxilio: $e');
      _error = 'Error al cargar auxilio: ${_getErrorMessage(e)}';
      notifyListeners();
    }
  }

  // ================= OPERACIONES PRINCIPALES =================

  /// 1. ACEPTAR AUXILIO
  Future<void> aceptarAuxilio(String rescueId) async {
    print('🎯 ACEPTANDO AUXILIO: $rescueId');
    _loading = true;
    notifyListeners();

    try {
      await _courierService.acceptRescue(rescueId);
      await seleccionarAuxilio(rescueId);
      await _iniciarSeguimientoGPS(rescueId);
      
      _uiState = MecanicoUIState.auxilioAceptado;
      _error = null;
    } catch (e) {
      print('❌ ERROR ACEPTANDO AUXILIO: $e');
      _error = 'Error aceptando auxilio: ${_getErrorMessage(e)}';
      _uiState = MecanicoUIState.error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 2. INICIAR SEGUIMIENTO GPS
  Future<void> _iniciarSeguimientoGPS(String rescueId) async {
    _trackingSubscription?.cancel();
    
    _trackingSubscription = _courierService.startMechanicTracking(rescueId).listen(
      (position) {
        _currentMechanicLocation = LatLng(position.latitude, position.longitude);
        
        if (_auxilioSeleccionado != null) {
          _calcularRutaAlCliente();
        }
        
        notifyListeners();
      },
      onError: (error) {
        print('❌ Error en seguimiento GPS: $error');
      }
    );
  }

  /// 3. CALCULAR RUTA AL CLIENTE
  Future<void> _calcularRutaAlCliente() async {
    if (_currentMechanicLocation == null || _auxilioSeleccionado == null) {
      return;
    }

    try {
      _rutaAlCliente = await _courierService.calculateRouteToClient(
        _currentMechanicLocation!,
        _auxilioSeleccionado!.clientLocation,
      );

      _eta = await _courierService.calculateETA(
        _currentMechanicLocation!,
        _auxilioSeleccionado!.clientLocation,
      );

      notifyListeners();
    } catch (e) {
      print('❌ Error calculando ruta: $e');
    }
  }

  /// 4. ACTUALIZAR ESTADO DEL AUXILIO
  Future<void> actualizarEstadoAuxilio(courier_service.RescueStatus nuevoEstado) async {
    if (_auxilioSeleccionado == null) return;

    _loading = true;
    notifyListeners();

    try {
      await _courierService.updateRescueStatus(
        _auxilioSeleccionado!.id,
        nuevoEstado,
      );

      _actualizarUIStatePorEstado(nuevoEstado);
      _error = null;
    } catch (e) {
      _error = 'Error actualizando estado: ${_getErrorMessage(e)}';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _actualizarUIStatePorEstado(courier_service.RescueStatus estado) {
    switch (estado) {
      case courier_service.RescueStatus.enRoute:
        _uiState = MecanicoUIState.enCamino;
        break;
      case courier_service.RescueStatus.arrived:
        _uiState = MecanicoUIState.llegadoUbicacion;
        break;
      case courier_service.RescueStatus.inProgress:
        _uiState = MecanicoUIState.enReparacion;
        break;
      case courier_service.RescueStatus.completed:
        _uiState = MecanicoUIState.completado;
        _limpiarAuxilioActual(); 
        break;
      case courier_service.RescueStatus.cancelled:
        _uiState = MecanicoUIState.buscandoAuxilios;
        _limpiarAuxilioActual();
        break;
      default:
        _uiState = MecanicoUIState.auxilioAceptado;
    }
  }

  /// 5. LLAMAR AL CLIENTE
  Future<void> llamarCliente() async {
    if (_auxilioSeleccionado == null) return;

    final telefono = _auxilioSeleccionado!.userPhone;
    if (telefono.isEmpty) {
      await _realizarLlamada('73289783'); // Número por defecto si no está
      return;
    }

    await _realizarLlamada(telefono);
  }

  Future<void> _realizarLlamada(String telefono) async {
    final url = Uri.parse('tel:$telefono');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _error = 'No se pudo realizar la llamada';
        notifyListeners();
      }
    } catch (e) {
      _error = 'Error al realizar llamada: $e';
      notifyListeners();
    }
  }

  /// 6. INICIAR NAVEGACIÓN
  Future<void> iniciarNavegacion() async {
    if (_auxilioSeleccionado == null) return;

    final destino = _auxilioSeleccionado!.clientLocation;
    // URL Corregida para Google Maps
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${destino.latitude},${destino.longitude}&travelmode=driving'
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _error = 'No se pudo abrir la aplicación de mapas';
        notifyListeners();
      }
    } catch (e) {
      _error = 'Error al abrir mapas: $e';
      notifyListeners();
    }
  }

  // ================= MANEJO DE STREAMS =================
  void _iniciarEscuchaAuxilio(String rescueId) {
    _rescueSubscription?.cancel();
    
    _rescueSubscription = _courierService.getRescueUpdates(rescueId).listen(
      (rescue) {
        _auxilioSeleccionado = rescue;
        _detallesAuxilio = courier_service.RescueDetails(
          firebaseData: rescue,
          localRecord: _detallesAuxilio?.localRecord,
        );
        notifyListeners();
      },
      onError: (error) {
        print('❌ Error en stream de auxilio: $error');
        _error = 'Error en seguimiento: ${_getErrorMessage(error)}';
        notifyListeners();
      }
    );
  }

  // ================= LIMPIEZA =================
  void _limpiarAuxilioActual() {
    _auxilioSeleccionado = null;
    _detallesAuxilio = null;
    _rutaAlCliente = null;
    _eta = null;
    _rescueSubscription?.cancel();
    _trackingSubscription?.cancel();
    
    _auxilioCompletado = true;
    
    Future.delayed(const Duration(milliseconds: 500), () {
      _auxilioCompletado = false;
      notifyListeners(); 
    });
    
    print('✅ Auxilio actual limpiado, flag de completado activado');
  }

  void resetearFlagCompletado() {
    _auxilioCompletado = false;
    notifyListeners();
  }

  Future<void> cancelarAuxilio() async {
    if (_auxilioSeleccionado != null) {
      await actualizarEstadoAuxilio(courier_service.RescueStatus.cancelled);
    }
  }

  void limpiarError() {
    _error = null;
    notifyListeners();
  }

  Future<void> recargar() async {
    await init();
  }

  @override
  void dispose() {
    _rescueSubscription?.cancel();
    _trackingSubscription?.cancel();
    _courierService.dispose();
    super.dispose();
  }
}

// ENUM PARA ESTADOS DE UI
enum MecanicoUIState {
  buscandoAuxilios,
  auxilioAceptado,
  enCamino,
  llegadoUbicacion,
  enReparacion,
  completado,
  error
}