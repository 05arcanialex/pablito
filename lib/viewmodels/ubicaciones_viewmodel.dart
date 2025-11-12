import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import '../models/database_helper.dart';

class UbicacionesViewModel extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

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

  // CLIENTE AUTO-DETECTADO (SI NO LLEGA CODIGO)
  int? _codClienteSel;
  String? _clienteNombreSel;

  // GETTERS
  bool get loading => _loading;
  String? get error => _error;
  LatLng? get currentLatLng => _currentLatLng;
  LatLng? get pickedLatLng => _pickedLatLng;
  bool get siguiendo => _siguiendo;
  String get direccion =>
      _direccionManual?.trim().isNotEmpty == true ? _direccionManual! : _direccion;
  int? get codRegistro => _codRegistro;
  int? get codClienteSel => _codClienteSel;
  String get clienteNombreSel => _clienteNombreSel ?? 'SIN CLIENTE';

  // ================= INIT =================
  Future<void> init() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _ensureAuxilioDDL();
      await _ensurePermisos();
      await _ensureClienteSeleccionado();

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

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  // ================= DDL =================
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

  // ================= PERMISOS =================
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

  // ================= CLIENTE =================
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

    // CREA UN CLIENTE DEMO SI LA BD ESTÁ VACÍA (EVITA CRASH)
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

  // ================= STREAM =================
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

  // ================= UI =================
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

  // ================= GUARDAR =================
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
