import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/database_helper.dart';

class ClienteLite {
  final int codCliente;
  final String nombre;
  final int vehiculos;
  ClienteLite({required this.codCliente, required this.nombre, required this.vehiculos});

  factory ClienteLite.fromRow(Map<String, Object?> r) => ClienteLite(
        codCliente: r['cod_cliente'] as int,
        nombre: (r['nombre'] ?? '') as String,
        vehiculos: (r['vehs'] as int?) ?? 0,
      );
}

class VehiculoLite {
  final int codVehiculo;
  final String label; // PLACAS • MARCA MODELO (AÑO)
  VehiculoLite({required this.codVehiculo, required this.label});
}

class InvItemVM {
  final int codRegInvVeh;
  final int codInvVeh;
  final String nombreItem;   // inventario_vehiculo.descripcion_inv
  final String descripcion;  // inventario_vehiculo.descripcion
  final int cantidad;
  final String? estado;
  final int codEmpleado;
  final String? fotoPath;

  InvItemVM({
    required this.codRegInvVeh,
    required this.codInvVeh,
    required this.nombreItem,
    required this.descripcion,
    required this.cantidad,
    required this.estado,
    required this.codEmpleado,
    required this.fotoPath,
  });

  factory InvItemVM.fromRow(Map<String, Object?> r) => InvItemVM(
        codRegInvVeh: r['cod_reg_inv_veh'] as int,
        codInvVeh: r['cod_inv_veh'] as int,
        nombreItem: (r['descripcion_inv'] ?? '') as String,
        descripcion: (r['descripcion'] ?? '') as String,
        cantidad: (r['cantidad'] as int?) ?? 0,
        estado: r['estado'] as String?,
        codEmpleado: (r['cod_empleado'] as int?) ?? 0,
        fotoPath: r['foto_path'] as String?,
      );
}

class ObjetosViewModel extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  final _picker = ImagePicker();

  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  List<ClienteLite> _clientes = [];
  List<VehiculoLite> _vehiculos = [];
  List<InvItemVM> _inventario = [];

  List<ClienteLite> get clientes => _filteredClientes();
  List<VehiculoLite> get vehiculos => _vehiculos;
  List<InvItemVM> get inventario => _filteredInventario();

  int? _selCliente;
  int? _selVehiculo;

  int? get clienteSeleccionado => _selCliente;
  int? get vehiculoSeleccionado => _selVehiculo;

  String _buscarCliente = '';
  String _buscarInventario = '';
  String _filtroEstado = 'TODOS';
  bool _vistaCards = false;

  String get buscarCliente => _buscarCliente;
  String get buscarInventario => _buscarInventario;
  String get filtroEstado => _filtroEstado;
  bool get vistaCards => _vistaCards;

  Future<void> init() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _ensureFotoColumn();
      await _loadClientes();
    } catch (e) {
      _error = 'ERROR AL INICIALIZAR: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _ensureFotoColumn() async {
    try {
      final cols = await _db.rawQuery("PRAGMA table_info(reg_inventario_vehiculo)");
      final hasFoto = cols.any((c) => (c['name'] as String).toLowerCase() == 'foto_path');
      if (!hasFoto) {
        await _db.rawUpdate('ALTER TABLE reg_inventario_vehiculo ADD COLUMN foto_path TEXT');
      }
    } catch (_) {}
  }

  Future<void> _loadClientes() async {
    final rows = await _db.rawQuery('''
      SELECT c.cod_cliente,
             (p.nombre || ' ' || p.apellidos) AS nombre,
             COUNT(v.cod_vehiculo) AS vehs
      FROM cliente c
      JOIN persona p ON p.cod_persona = c.cod_persona
      LEFT JOIN vehiculo v ON v.cod_cliente = c.cod_cliente
      GROUP BY c.cod_cliente, p.nombre, p.apellidos
      ORDER BY nombre
    ''');
    _clientes = rows.map(ClienteLite.fromRow).toList();
  }

  Future<void> loadVehiculosDeCliente(int codCliente) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _selCliente = codCliente;
      _selVehiculo = null;
      final rows = await _db.rawQuery('''
        SELECT v.cod_vehiculo, v.placas,
               m.descripcion AS marca,
               md.descripcion_modelo AS modelo,
               md.anio_modelo AS anio
        FROM vehiculo v
        JOIN marca_vehiculo m ON m.cod_marca_veh = v.cod_marca_veh
        JOIN modelo_vehiculo md ON md.cod_modelo_veh = v.cod_modelo_veh
        WHERE v.cod_cliente = ?
        ORDER BY v.cod_vehiculo DESC
      ''', [codCliente]);

      _vehiculos = rows.map((r) {
        final placas = (r['placas'] ?? '') as String;
        final marca = (r['marca'] ?? '') as String;
        final modelo = (r['modelo'] ?? '') as String;
        final anio = r['anio']?.toString() ?? '';
        final label = '$placas • $marca $modelo${anio.isNotEmpty ? " ($anio)" : ""}';
        return VehiculoLite(codVehiculo: r['cod_vehiculo'] as int, label: label);
      }).toList();

      _inventario = [];
    } catch (e) {
      _error = 'ERROR AL CARGAR VEHÍCULOS: $e';
      _vehiculos = [];
      _inventario = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadInventarioVehiculo(int codVehiculo) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _selVehiculo = codVehiculo;
      final rows = await _db.rawQuery('''
        SELECT riv.cod_reg_inv_veh,
               iv.cod_inv_veh,
               iv.descripcion_inv,
               iv.descripcion,
               riv.cantidad,
               riv.estado,
               riv.cod_empleado,
               riv.foto_path
        FROM reg_inventario_vehiculo riv
        JOIN inventario_vehiculo iv ON iv.cod_inv_veh = riv.cod_inv_veh
        WHERE riv.cod_vehiculo = ?
        ORDER BY riv.cod_reg_inv_veh DESC
      ''', [codVehiculo]);
      _inventario = rows.map(InvItemVM.fromRow).toList();
    } catch (e) {
      _error = 'ERROR AL CARGAR INVENTARIO: $e';
      _inventario = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setBuscarCliente(String v) {
    _buscarCliente = v;
    notifyListeners();
  }

  void setBuscarInventario(String v) {
    _buscarInventario = v;
    notifyListeners();
  }

  void setFiltroEstado(String v) {
    _filtroEstado = v;
    notifyListeners();
  }

  void toggleVistaCards() {
    _vistaCards = !_vistaCards;
    notifyListeners();
  }

  List<ClienteLite> _filteredClientes() {
    final q = _buscarCliente.trim().toUpperCase();
    if (q.isEmpty) return _clientes;
    return _clientes.where((c) => c.nombre.toUpperCase().contains(q)).toList();
  }

  List<InvItemVM> _filteredInventario() {
    Iterable<InvItemVM> it = _inventario;
    final q = _buscarInventario.trim().toUpperCase();
    if (q.isNotEmpty) {
      it = it.where((x) =>
          x.nombreItem.toUpperCase().contains(q) ||
          x.descripcion.toUpperCase().contains(q));
    }
    if (_filtroEstado != 'TODOS') {
      it = it.where((x) => (x.estado ?? '').toUpperCase() == _filtroEstado.toUpperCase());
    }
    return it.toList();
  }

  Future<String?> takePhoto() async {
    try {
      final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      return img?.path;
    } catch (e) {
      _error = 'NO SE PUDO ABRIR LA CÁMARA: $e';
      notifyListeners();
      return null;
    }
  }

  Future<String?> pickFromGallery() async {
    try {
      final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      return img?.path;
    } catch (e) {
      _error = 'NO SE PUDO ABRIR LA GALERÍA: $e';
      notifyListeners();
      return null;
    }
  }

  // ---------- CREAR (SIN CATÁLOGO EXPLÍCITO) ----------
  Future<bool> crearInventario({
    required String nombreObjeto,
    String? descripcionObjeto,
    required int cantidad,
    String? estado,
    String? fotoPath,
    int codEmpleado = 1,
  }) async {
    if (_selVehiculo == null) {
      _error = 'SELECCIONA UN VEHÍCULO';
      notifyListeners();
      return false;
    }
    try {
      // 1) Crear registro del objeto (inventario_vehiculo)
      final codInvVeh = await _db.rawInsert(
        'INSERT INTO inventario_vehiculo(descripcion_inv, descripcion) VALUES (?,?)',
        [nombreObjeto.trim(), (descripcionObjeto ?? '').trim()],
      );

      // 2) Asociar al vehículo con foto/estado/cantidad (reg_inventario_vehiculo)
      await _db.rawInsert('''
        INSERT INTO reg_inventario_vehiculo(cod_inv_veh, cod_vehiculo, cod_empleado, cantidad, estado, foto_path)
        VALUES (?,?,?,?,?,?)
      ''', [codInvVeh, _selVehiculo, codEmpleado, cantidad, (estado ?? 'REGULAR').toUpperCase(), fotoPath]);

      await loadInventarioVehiculo(_selVehiculo!);
      return true;
    } catch (e) {
      _error = 'NO SE PUDO CREAR: $e';
      notifyListeners();
      return false;
    }
  }

  // ---------- EDITAR (PERMITE CAMBIAR NOMBRE/DESC) ----------
  Future<bool> editarInventario({
    required int codRegInvVeh,
    required int codInvVeh,
    required String nombreObjeto,
    String? descripcionObjeto,
    required int cantidad,
    String? estado,
    String? fotoPath,
  }) async {
    if (_selVehiculo == null) {
      _error = 'SELECCIONA UN VEHÍCULO';
      notifyListeners();
      return false;
    }
    try {
      // Actualiza datos del objeto (nombre/descripcion)
      await _db.rawUpdate('''
        UPDATE inventario_vehiculo
        SET descripcion_inv=?, descripcion=?
        WHERE cod_inv_veh=?
      ''', [nombreObjeto.trim(), (descripcionObjeto ?? '').trim(), codInvVeh]);

      // Actualiza la relación con el vehículo
      if (fotoPath == null) {
        await _db.rawUpdate('''
          UPDATE reg_inventario_vehiculo
          SET cantidad=?, estado=?
          WHERE cod_reg_inv_veh=? AND cod_vehiculo=?
        ''', [cantidad, (estado ?? 'REGULAR').toUpperCase(), codRegInvVeh, _selVehiculo]);
      } else {
        await _db.rawUpdate('''
          UPDATE reg_inventario_vehiculo
          SET cantidad=?, estado=?, foto_path=?
          WHERE cod_reg_inv_veh=? AND cod_vehiculo=?
        ''', [cantidad, (estado ?? 'REGULAR').toUpperCase(), fotoPath, codRegInvVeh, _selVehiculo]);
      }

      await loadInventarioVehiculo(_selVehiculo!);
      return true;
    } catch (e) {
      _error = 'NO SE PUDO EDITAR: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarInventario(int codRegInvVeh) async {
    if (_selVehiculo == null) return false;
    try {
      final n = await _db.rawDelete(
        'DELETE FROM reg_inventario_vehiculo WHERE cod_reg_inv_veh=? AND cod_vehiculo=?',
        [codRegInvVeh, _selVehiculo],
      );
      await loadInventarioVehiculo(_selVehiculo!);
      return n > 0;
    } catch (e) {
      _error = 'NO SE PUDO ELIMINAR: $e';
      notifyListeners();
      return false;
    }
  }

  List<String> fotosDelVehiculo() {
    return _inventario
        .map((i) => i.fotoPath)
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty && File(p).existsSync())
        .toList();
  }
}
