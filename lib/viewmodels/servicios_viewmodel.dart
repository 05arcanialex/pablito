import 'package:flutter/foundation.dart';
import '../models/database_helper.dart';

/// ITEM PARA LA TABLA DE UI
class ServicioItem {
  final int codSerTaller;
  final String fechaIngreso;
  final String? fechaSalida;
  final String? observaciones;
  final String vehiculo;
  final String cliente;
  final String tipos;
  final double totalAprox;
  final String? estado;

  ServicioItem({
    required this.codSerTaller,
    required this.fechaIngreso,
    required this.fechaSalida,
    required this.observaciones,
    required this.vehiculo,
    required this.cliente,
    required this.tipos,
    required this.totalAprox,
    required this.estado,
  });

  factory ServicioItem.fromRow(Map<String, Object?> r) {
    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return ServicioItem(
      codSerTaller: r['cod_ser_taller'] as int,
      fechaIngreso: (r['fecha_ingreso'] ?? '') as String,
      fechaSalida: r['fecha_salida'] as String?,
      observaciones: r['observaciones'] as String?,
      vehiculo: (r['vehiculo'] ?? '') as String,
      cliente: (r['cliente'] ?? '') as String,
      tipos: (r['tipos'] ?? '') as String,
      totalAprox: toDouble(r['total_aprox']),
      estado: r['estado'] as String?,
    );
  }
}

/// CLIENTE Y VEHÍCULO (para collapsables)
class ClienteVM {
  final int codCliente;
  final String nombre;
  ClienteVM(this.codCliente, this.nombre);
}

class VehiculoVM {
  final int codVehiculo;
  final String label;
  VehiculoVM(this.codVehiculo, this.label);
}

class ServiciosViewModel extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  bool _loading = false;
  String _filtroCategoria = 'TODOS';
  String? _error;
  List<ServicioItem> _items = [];

  List<ClienteVM> clientes = [];
  Map<int, List<VehiculoVM>> _cacheVehiculos = {};

  bool get loading => _loading;
  String get filtroCategoria => _filtroCategoria;
  String? get error => _error;
  List<ServicioItem> get items => _items;

  // ====== INIT ======
  Future<void> init() async {
    await _createOrEnsureView();
    await load();
  }

  // ====== CHEQUEAR COLUMNA ======
  Future<bool> _colExists(String table, String column) async {
    try {
      final info = await _db.rawQuery("PRAGMA table_info($table)");
      for (final r in info) {
        if ((r['name'] ?? '').toString() == column) return true;
      }
    } catch (_) {}
    return false;
  }

  // ====== VIEW SEGURA ======
  Future<void> _createOrEnsureView() async {
    final hasEstado = await _colExists('registro_servicio_taller', 'estado');
    try {
      await _db.rawQuery('DROP VIEW IF EXISTS vw_servicios');
    } catch (_) {}

    final selectEstado = hasEstado ? ' , rst.estado ' : ' , NULL AS estado ';
    final sql = '''
      CREATE VIEW IF NOT EXISTS vw_servicios AS
      SELECT
        rst.cod_ser_taller,
        rst.fecha_ingreso,
        rst.fecha_salida,
        rst.observaciones,
        v.placas                              AS vehiculo,
        (p.nombre || ' ' || p.apellidos)      AS cliente,
        (
          SELECT GROUP_CONCAT(tt.descripcion, ', ')
          FROM reg_serv_taller_tipo_trabajo rtt
          JOIN tipo_trabajo tt ON tt.cod_tipo_trabajo = rtt.cod_tipo_trabajo
          WHERE rtt.cod_ser_taller = rst.cod_ser_taller
        ) AS tipos,
        COALESCE((
          SELECT SUM(rtt.costo)
          FROM reg_serv_taller_tipo_trabajo rtt
          WHERE rtt.cod_ser_taller = rst.cod_ser_taller
        ), 0) AS total_aprox
        $selectEstado
      FROM registro_servicio_taller rst
      JOIN vehiculo v ON v.cod_vehiculo = rst.cod_vehiculo
      JOIN cliente  c ON c.cod_cliente  = v.cod_cliente
      JOIN persona  p ON p.cod_persona  = c.cod_persona;
    ''';
    await _db.rawQuery(sql);
  }

  // ====== LOAD ======
  Future<void> load({String? categoria}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final cat = categoria ?? _filtroCategoria;
      List<Map<String, Object?>> rows;
      if (cat == 'TODOS') {
        rows = await _db.rawQuery(
          'SELECT * FROM vw_servicios ORDER BY cod_ser_taller DESC',
        );
      } else {
        rows = await _db.rawQuery('''
          SELECT s.*
          FROM vw_servicios s
          WHERE EXISTS (
            SELECT 1
            FROM reg_serv_taller_tipo_trabajo rtt
            JOIN tipo_trabajo tt ON tt.cod_tipo_trabajo = rtt.cod_tipo_trabajo
            WHERE rtt.cod_ser_taller = s.cod_ser_taller
              AND UPPER(tt.descripcion) = UPPER(?)
          )
          ORDER BY s.cod_ser_taller DESC
        ''', [cat]);
      }

      _items = rows.map(ServicioItem.fromRow).toList();
    } catch (e) {
      _error = 'ERROR AL CARGAR SERVICIOS: $e';
      _items = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setFiltro(String value) {
    _filtroCategoria = value;
    load(categoria: value);
  }

  // ====== CLIENTES Y VEHÍCULOS ======
  Future<void> cargarClientes() async {
    try {
      final rs = await _db.rawQuery('''
        SELECT c.cod_cliente, p.nombre || ' ' || p.apellidos AS nom
        FROM cliente c
        JOIN persona p ON p.cod_persona = c.cod_persona
        ORDER BY nom
      ''');
      clientes = rs.map((e) => ClienteVM(e['cod_cliente'] as int, e['nom'] as String)).toList();
      notifyListeners();
    } catch (e) {
      _error = 'NO SE PUDO CARGAR CLIENTES: $e';
      notifyListeners();
    }
  }

  Future<List<VehiculoVM>> cargarVehiculosDeCliente(int codCliente) async {
    if (_cacheVehiculos.containsKey(codCliente)) return _cacheVehiculos[codCliente]!;
    final rs = await _db.rawQuery('''
      SELECT v.cod_vehiculo,
             mv.descripcion || ' ' || md.descripcion_modelo || ' - ' || v.placas AS label
      FROM vehiculo v
      LEFT JOIN marca_vehiculo mv ON mv.cod_marca_veh = v.cod_marca_veh
      LEFT JOIN modelo_vehiculo md ON md.cod_modelo_veh = v.cod_modelo_veh
      WHERE v.cod_cliente = ?
      ORDER BY label
    ''', [codCliente]);
    final list = rs.map((e) => VehiculoVM(e['cod_vehiculo'] as int, e['label'] as String)).toList();
    _cacheVehiculos[codCliente] = list;
    return list;
  }

  // ====== NEXT ID ======
  Future<int> getNextIdRegistroServicio() async {
    final rs = await _db.rawQuery("SELECT seq FROM sqlite_sequence WHERE name='registro_servicio_taller'");
    final seq = (rs.isNotEmpty ? (rs.first['seq'] as int?) : 0) ?? 0;
    return seq + 1;
  }

  // ====== CREAR SERVICIO COMPLETO ======
  Future<bool> crearServicioConSeleccion({
    required int codCliente,
    required int codVehiculo,
    String? observaciones,
    String? tipoDescripcion,
    double? costoTipo,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      final fecha = DateTime.now().toIso8601String();

      // EMPLEADO DEFAULT
      final emp = await _db.rawQuery('SELECT cod_empleado FROM empleado LIMIT 1');
      if (emp.isEmpty) throw Exception('No hay empleados registrados');
      final codEmpleado = emp.first['cod_empleado'] as int;

      // ESTADO RECIBO
      final est = await _db.rawQuery("SELECT cod_est_rec FROM estado_recibo WHERE estado_recibo='PENDIENTE' LIMIT 1");
      final codEst = est.isNotEmpty ? est.first['cod_est_rec'] as int : 1;

      // RECIBO
      final codRec = await _db.rawInsert('''
        INSERT INTO recibo_pago(fecha,total,a_cuenta,saldo,transferencia_pago,cod_cliente,cod_empleado,cod_est_rec)
        VALUES(?,?,?,?,?,?,?,?)
      ''', [fecha, 0, 0, 0, 'EFECTIVO', codCliente, codEmpleado, codEst]);

      // SERVICIO
      final codServ = await _db.rawInsert('''
        INSERT INTO registro_servicio_taller
        (cod_recibo_pago,cod_vehiculo,cod_empleado,fecha_ingreso,ingreso_en_grua,observaciones)
        VALUES(?,?,?,?,?,?)
      ''', [codRec, codVehiculo, codEmpleado, fecha, 0, (observaciones ?? '')]);

      // DETALLE
      if (tipoDescripcion != null && tipoDescripcion.trim().isNotEmpty) {
        final rsTipo = await _db.rawQuery(
            'SELECT cod_tipo_trabajo FROM tipo_trabajo WHERE descripcion=?', [tipoDescripcion]);
        int codTipo;
        if (rsTipo.isEmpty) {
          codTipo = await _db.rawInsert('INSERT INTO tipo_trabajo(descripcion) VALUES(?)', [tipoDescripcion]);
        } else {
          codTipo = rsTipo.first['cod_tipo_trabajo'] as int;
        }
        await _db.rawInsert(
            'INSERT INTO reg_serv_taller_tipo_trabajo(cod_ser_taller,cod_tipo_trabajo,costo,detalles) VALUES(?,?,?,?)',
            [codServ, codTipo, (costoTipo ?? 0), 'REGISTRO RÁPIDO']);
      }

      await load();
      _loading = false;
      return true;
    } catch (e) {
      _error = 'ERROR AL CREAR SERVICIO: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // ====== UPDATE OBSERVACIONES ======
  Future<bool> updateObservaciones({
    required int codSerTaller,
    required String observ,
  }) async {
    try {
      final n = await _db.rawUpdate(
        'UPDATE registro_servicio_taller SET observaciones=? WHERE cod_ser_taller=?',
        [observ, codSerTaller],
      );
      await load();
      return n > 0;
    } catch (_) {
      return false;
    }
  }

  // ====== UPDATE COSTO ======
  Future<bool> upsertCostoManual(int codSerTaller, double costo) async {
    try {
      final rsTipo = await _db.rawQuery(
          "SELECT cod_tipo_trabajo FROM tipo_trabajo WHERE descripcion='AJUSTE MANUAL'");
      int codTipo;
      if (rsTipo.isEmpty) {
        codTipo = await _db.rawInsert(
            "INSERT INTO tipo_trabajo(descripcion) VALUES('AJUSTE MANUAL')");
      } else {
        codTipo = rsTipo.first['cod_tipo_trabajo'] as int;
      }

      final rs = await _db.rawQuery('''
        SELECT cod_reg_ser_taller_tipo FROM reg_serv_taller_tipo_trabajo
        WHERE cod_ser_taller=? AND cod_tipo_trabajo=? AND detalles='AJUSTE MANUAL'
      ''', [codSerTaller, codTipo]);

      if (rs.isEmpty) {
        await _db.rawInsert(
            'INSERT INTO reg_serv_taller_tipo_trabajo(cod_ser_taller,cod_tipo_trabajo,costo,detalles) VALUES(?,?,?,?)',
            [codSerTaller, codTipo, costo, 'AJUSTE MANUAL']);
      } else {
        final id = rs.first['cod_reg_ser_taller_tipo'] as int;
        await _db.rawUpdate(
            'UPDATE reg_serv_taller_tipo_trabajo SET costo=? WHERE cod_reg_ser_taller_tipo=?',
            [costo, id]);
      }
      await load();
      return true;
    } catch (e) {
      _error = 'ERROR AL ACTUALIZAR COSTO: $e';
      return false;
    }
  }

  // ====== UPDATE ESTADO ======
  Future<bool> updateEstado({
    required int codSerTaller,
    required String estado,
  }) async {
    try {
      await _db.rawUpdate(
          'UPDATE registro_servicio_taller SET estado=? WHERE cod_ser_taller=?',
          [estado, codSerTaller]);
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ====== ELIMINAR ======
  Future<bool> deleteServicio(int codSerTaller) async {
    try {
      await _db.rawDelete(
          'DELETE FROM reg_serv_taller_tipo_trabajo WHERE cod_ser_taller=?',
          [codSerTaller]);
      final n = await _db.rawDelete(
          'DELETE FROM registro_servicio_taller WHERE cod_ser_taller=?',
          [codSerTaller]);
      await load();
      return n > 0;
    } catch (_) {
      return false;
    }
  }
}
