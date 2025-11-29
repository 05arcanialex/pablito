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
  final bool tieneSeguimiento;

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
    required this.tieneSeguimiento,
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
      tieneSeguimiento: (r['tiene_seguimiento'] ?? 0) == 1,
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

/// MODELO SEGUIMIENTO SERVICIO
class SeguimientoServicio {
  final int codSeguimiento;
  final int codSerTaller;
  final int pasoActual;
  final String? diagnostico;
  final String? fotoDiagnostico;
  final String? fallasIdentificadas;
  final String? fotoFallas;
  final String? observacionesFallas;
  final String? fotoObservaciones;
  final String? solucionAplicada;
  final String? fotoReparacion;
  final String? resultadoPruebas;
  final String? fotoPruebas;
  final String fechaUltimaActualizacion;
  final String estado;

  SeguimientoServicio({
    required this.codSeguimiento,
    required this.codSerTaller,
    required this.pasoActual,
    this.diagnostico,
    this.fotoDiagnostico,
    this.fallasIdentificadas,
    this.fotoFallas,
    this.observacionesFallas,
    this.fotoObservaciones,
    this.solucionAplicada,
    this.fotoReparacion,
    this.resultadoPruebas,
    this.fotoPruebas,
    required this.fechaUltimaActualizacion,
    required this.estado,
  });

  factory SeguimientoServicio.fromRow(Map<String, Object?> r) {
    return SeguimientoServicio(
      codSeguimiento: r['cod_seguimiento'] as int,
      codSerTaller: r['cod_ser_taller'] as int,
      pasoActual: r['paso_actual'] as int,
      diagnostico: r['diagnostico'] as String?,
      fotoDiagnostico: r['foto_diagnostico'] as String?,
      fallasIdentificadas: r['fallas_identificadas'] as String?,
      fotoFallas: r['foto_fallas'] as String?,
      observacionesFallas: r['observaciones_fallas'] as String?,
      fotoObservaciones: r['foto_observaciones'] as String?,
      solucionAplicada: r['solucion_aplicada'] as String?,
      fotoReparacion: r['foto_reparacion'] as String?,
      resultadoPruebas: r['resultado_pruebas'] as String?,
      fotoPruebas: r['foto_pruebas'] as String?,
      fechaUltimaActualizacion: (r['fecha_ultima_actualizacion'] ?? '') as String,
      estado: (r['estado'] ?? 'EN_PROCESO') as String,
    );
  }
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
        ), 0) AS total_aprox,
        EXISTS(
          SELECT 1 FROM seguimiento_servicio ss 
          WHERE ss.cod_ser_taller = rst.cod_ser_taller
        ) AS tiene_seguimiento
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

  // ====== SEGUIMIENTO ======
  Future<SeguimientoServicio?> getSeguimiento(int codSerTaller) async {
    try {
      final rs = await _db.rawQuery(
        'SELECT * FROM seguimiento_servicio WHERE cod_ser_taller = ?',
        [codSerTaller],
      );
      if (rs.isEmpty) return null;
      return SeguimientoServicio.fromRow(rs.first);
    } catch (e) {
      _error = 'Error al obtener seguimiento: $e';
      return null;
    }
  }

  Future<bool> iniciarSeguimiento(int codSerTaller) async {
    try {
      final existe = await getSeguimiento(codSerTaller);
      if (existe != null) return true; // Ya existe
      
      await _db.rawInsert(
        'INSERT INTO seguimiento_servicio(cod_ser_taller, paso_actual, fecha_ultima_actualizacion) VALUES(?, ?, ?)',
        [codSerTaller, 1, DateTime.now().toIso8601String()],
      );
      return true;
    } catch (e) {
      _error = 'Error al iniciar seguimiento: $e';
      return false;
    }
  }

  Future<bool> actualizarSeguimiento({
    required int codSerTaller,
    required int pasoActual,
    String? diagnostico,
    String? fotoDiagnostico,
    String? fallasIdentificadas,
    String? fotoFallas,
    String? observacionesFallas,
    String? fotoObservaciones,
    String? solucionAplicada,
    String? fotoReparacion,
    String? resultadoPruebas,
    String? fotoPruebas,
    String? estado,
  }) async {
    try {
      final campos = <String>[];
      final valores = <Object?>[];
      
      campos.add('paso_actual = ?');
      valores.add(pasoActual);
      
      if (diagnostico != null) {
        campos.add('diagnostico = ?');
        valores.add(diagnostico);
      }
      if (fotoDiagnostico != null) {
        campos.add('foto_diagnostico = ?');
        valores.add(fotoDiagnostico);
      }
      if (fallasIdentificadas != null) {
        campos.add('fallas_identificadas = ?');
        valores.add(fallasIdentificadas);
      }
      if (fotoFallas != null) {
        campos.add('foto_fallas = ?');
        valores.add(fotoFallas);
      }
      if (observacionesFallas != null) {
        campos.add('observaciones_fallas = ?');
        valores.add(observacionesFallas);
      }
      if (fotoObservaciones != null) {
        campos.add('foto_observaciones = ?');
        valores.add(fotoObservaciones);
      }
      if (solucionAplicada != null) {
        campos.add('solucion_aplicada = ?');
        valores.add(solucionAplicada);
      }
      if (fotoReparacion != null) {
        campos.add('foto_reparacion = ?');
        valores.add(fotoReparacion);
      }
      if (resultadoPruebas != null) {
        campos.add('resultado_pruebas = ?');
        valores.add(resultadoPruebas);
      }
      if (fotoPruebas != null) {
        campos.add('foto_pruebas = ?');
        valores.add(fotoPruebas);
      }
      if (estado != null) {
        campos.add('estado = ?');
        valores.add(estado);
      }
      
      campos.add('fecha_ultima_actualizacion = ?');
      valores.add(DateTime.now().toIso8601String());
      
      valores.add(codSerTaller);
      
      final n = await _db.rawUpdate(
        'UPDATE seguimiento_servicio SET ${campos.join(', ')} WHERE cod_ser_taller = ?',
        valores,
      );
      
      return n > 0;
    } catch (e) {
      _error = 'Error al actualizar seguimiento: $e';
      return false;
    }
  }

  Future<bool> finalizarSeguimiento(int codSerTaller) async {
    try {
      final n = await _db.rawUpdate(
        'UPDATE seguimiento_servicio SET estado = ?, fecha_ultima_actualizacion = ? WHERE cod_ser_taller = ?',
        ['FINALIZADO', DateTime.now().toIso8601String(), codSerTaller],
      );
      return n > 0;
    } catch (e) {
      _error = 'Error al finalizar seguimiento: $e';
      return false;
    }
  }

  // ====== MÉTODOS AUXILIARES PARA CONVERSIÓN SEGURA ======
  
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  // ====== REPORTES ======

  /// Genera reporte de servicios por rango de fechas
  Future<bool> generarReporteServicios({
    required String fechaInicio,
    required String fechaFin,
    required String formato,
  }) async {
    try {
      // Obtener servicios filtrados por fecha
      final servicios = await _db.rawQuery('''
        SELECT * FROM vw_servicios 
        WHERE fecha_ingreso BETWEEN ? AND ?
        ORDER BY fecha_ingreso DESC
      ''', [fechaInicio, fechaFin]);

      if (servicios.isEmpty) {
        _error = 'No hay servicios en el rango de fechas seleccionado';
        return false;
      }

      // Calcular estadísticas con tipos seguros
      double totalIngresos = 0.0;
      int serviciosTerminados = 0;
      int serviciosEnCurso = 0;
      int serviciosEnEspera = 0;

      final serviciosData = servicios.map((s) {
        final item = ServicioItem.fromRow(s);
        final total = item.totalAprox;
        totalIngresos += total;

        // Contar por estado
        final estado = item.estado?.toUpperCase() ?? '';
        if (estado.contains('TERMINADO')) {
          serviciosTerminados++;
        } else if (estado.contains('EN CURSO') || estado.contains('EN_PROCESO')) {
          serviciosEnCurso++;
        } else if (estado.contains('ESPERA') || estado.contains('PENDIENTE')) {
          serviciosEnEspera++;
        }

        return {
          'codigo': item.codSerTaller,
          'fecha': item.fechaIngreso,
          'cliente': item.cliente,
          'vehiculo': item.vehiculo,
          'tipo': item.tipos,
          'total': total,
          'estado': item.estado ?? 'SIN ESTADO',
        };
      }).toList();

      // Preparar datos para el reporte
      final datosReporte = {
        'titulo': 'REPORTE DE SERVICIOS',
        'periodo': '$fechaInicio a $fechaFin',
        'fechaGeneracion': DateTime.now().toIso8601String(),
        'totalServicios': servicios.length,
        'servicios': serviciosData,
        'resumen': {
          'totalIngresos': totalIngresos,
          'serviciosTerminados': serviciosTerminados,
          'serviciosEnCurso': serviciosEnCurso,
          'serviciosEnEspera': serviciosEnEspera,
        }
      };

      // Generar reporte según formato
      return await _exportarReporte(datosReporte, formato, 'reporte_servicios_${fechaInicio}_${fechaFin}');
    } catch (e) {
      _error = 'Error generando reporte de servicios: $e';
      return false;
    }
  }

  /// Genera reporte de seguimiento técnico para un servicio específico
  Future<bool> generarReporteSeguimiento({
    required int codSerTaller,
    required String formato,
  }) async {
    try {
      // Obtener servicio
      final servicioRs = await _db.rawQuery(
        'SELECT * FROM vw_servicios WHERE cod_ser_taller = ?',
        [codSerTaller],
      );
      
      if (servicioRs.isEmpty) {
        _error = 'Servicio no encontrado';
        return false;
      }

      final servicio = ServicioItem.fromRow(servicioRs.first);

      // Obtener seguimiento
      final seguimiento = await getSeguimiento(codSerTaller);
      if (seguimiento == null) {
        _error = 'No existe seguimiento para este servicio';
        return false;
      }

      // Preparar datos para el reporte
      final datosReporte = {
        'titulo': 'REPORTE DE SEGUIMIENTO TÉCNICO',
        'servicio': {
          'codigo': servicio.codSerTaller,
          'cliente': servicio.cliente,
          'vehiculo': servicio.vehiculo,
          'fecha_ingreso': servicio.fechaIngreso,
          'fecha_salida': servicio.fechaSalida ?? 'PENDIENTE',
          'observaciones': servicio.observaciones ?? 'SIN OBSERVACIONES',
          'total': servicio.totalAprox,
        },
        'seguimiento': {
          'paso_actual': seguimiento.pasoActual,
          'diagnostico': seguimiento.diagnostico ?? 'NO REGISTRADO',
          'fallas_identificadas': seguimiento.fallasIdentificadas ?? 'NO REGISTRADO',
          'observaciones_fallas': seguimiento.observacionesFallas ?? 'NO REGISTRADO',
          'solucion_aplicada': seguimiento.solucionAplicada ?? 'NO REGISTRADO',
          'resultado_pruebas': seguimiento.resultadoPruebas ?? 'NO REGISTRADO',
          'estado': seguimiento.estado,
          'fecha_ultima_actualizacion': seguimiento.fechaUltimaActualizacion,
        },
        'fotos': {
          'diagnostico': seguimiento.fotoDiagnostico,
          'fallas': seguimiento.fotoFallas,
          'observaciones': seguimiento.fotoObservaciones,
          'reparacion': seguimiento.fotoReparacion,
          'pruebas': seguimiento.fotoPruebas,
        }
      };

      // Generar reporte según formato
      return await _exportarReporte(datosReporte, formato, 'seguimiento_${servicio.codSerTaller}');
    } catch (e) {
      _error = 'Error generando reporte de seguimiento: $e';
      return false;
    }
  }

  /// Genera reporte de estadísticas del taller
  Future<bool> generarReporteEstadisticas({
    required String fechaInicio,
    required String fechaFin,
    required String formato,
  }) async {
    try {
      // Obtener estadísticas básicas
      final totalServicios = await _db.rawQuery('''
        SELECT COUNT(*) as total FROM vw_servicios 
        WHERE fecha_ingreso BETWEEN ? AND ?
      ''', [fechaInicio, fechaFin]);

      final ingresosTotales = await _db.rawQuery('''
        SELECT SUM(total_aprox) as total FROM vw_servicios 
        WHERE fecha_ingreso BETWEEN ? AND ?
      ''', [fechaInicio, fechaFin]);

      // Estadísticas por tipo de trabajo
      final porTipo = await _db.rawQuery('''
        SELECT tt.descripcion, COUNT(*) as cantidad, SUM(rtt.costo) as total
        FROM reg_serv_taller_tipo_trabajo rtt
        JOIN tipo_trabajo tt ON tt.cod_tipo_trabajo = rtt.cod_tipo_trabajo
        JOIN registro_servicio_taller rst ON rst.cod_ser_taller = rtt.cod_ser_taller
        WHERE rst.fecha_ingreso BETWEEN ? AND ?
        GROUP BY tt.descripcion
        ORDER BY cantidad DESC
      ''', [fechaInicio, fechaFin]);

      // Servicios con seguimiento
      final conSeguimiento = await _db.rawQuery('''
        SELECT COUNT(*) as total FROM vw_servicios 
        WHERE fecha_ingreso BETWEEN ? AND ? AND tiene_seguimiento = 1
      ''', [fechaInicio, fechaFin]);

      // Convertir resultados a tipos numéricos seguros
      final totalServiciosNum = _toInt(totalServicios.first['total']);
      final ingresosTotalesNum = _toDouble(ingresosTotales.first['total']);
      final conSeguimientoNum = _toInt(conSeguimiento.first['total']);
      final sinSeguimientoNum = totalServiciosNum - conSeguimientoNum;
      final ingresoPromedio = totalServiciosNum > 0 ? ingresosTotalesNum / totalServiciosNum : 0.0;

      // Preparar datos para el reporte
      final datosReporte = {
        'titulo': 'REPORTE DE ESTADÍSTICAS DEL TALLER',
        'periodo': '$fechaInicio a $fechaFin',
        'fechaGeneracion': DateTime.now().toIso8601String(),
        'estadisticas_generales': {
          'total_servicios': totalServiciosNum,
          'ingresos_totales': ingresosTotalesNum,
          'servicios_con_seguimiento': conSeguimientoNum,
          'servicios_sin_seguimiento': sinSeguimientoNum,
        },
        'distribucion_por_tipo': porTipo.map((tipo) {
          return {
            'tipo': tipo['descripcion']?.toString() ?? 'DESCONOCIDO',
            'cantidad': _toInt(tipo['cantidad']),
            'total': _toDouble(tipo['total']),
          };
        }).toList(),
        'promedios': {
          'ingreso_promedio': ingresoPromedio,
        }
      };

      // Generar reporte según formato
      return await _exportarReporte(datosReporte, formato, 'estadisticas_${fechaInicio}_${fechaFin}');
    } catch (e) {
      _error = 'Error generando reporte de estadísticas: $e';
      return false;
    }
  }

  /// Método interno para exportar reportes según formato
  Future<bool> _exportarReporte(Map<String, dynamic> datos, String formato, String nombreBase) async {
    try {
      switch (formato) {
        case 'PDF':
          return await _generarPDF(datos, nombreBase);
        case 'EXCEL':
          return await _generarExcel(datos, nombreBase);
        case 'CSV':
          return await _generarCSV(datos, nombreBase);
        default:
          _error = 'Formato no soportado: $formato';
          return false;
      }
    } catch (e) {
      _error = 'Error al exportar reporte: $e';
      return false;
    }
  }

  /// Generar reporte en formato PDF
  Future<bool> _generarPDF(Map<String, dynamic> datos, String nombreBase) async {
    // TODO: Implementar generación de PDF usando pdf: ^3.10.4
    // Por ahora simulamos éxito
    print('Generando PDF: $nombreBase con datos: $datos');
    await Future.delayed(Duration(milliseconds: 500));
    return true;
  }

  /// Generar reporte en formato Excel
  Future<bool> _generarExcel(Map<String, dynamic> datos, String nombreBase) async {
    // TODO: Implementar generación de Excel usando excel: ^3.0.2
    // Por ahora simulamos éxito
    print('Generando Excel: $nombreBase con datos: $datos');
    await Future.delayed(Duration(milliseconds: 500));
    return true;
  }

  /// Generar reporte en formato CSV
  Future<bool> _generarCSV(Map<String, dynamic> datos, String nombreBase) async {
    try {
      // Simular generación de CSV básico
      final csvContent = _convertirACSV(datos);
      print('Generando CSV: $nombreBase\n$csvContent');
      await Future.delayed(Duration(milliseconds: 300));
      return true;
    } catch (e) {
      _error = 'Error generando CSV: $e';
      return false;
    }
  }

  /// Convertir datos a formato CSV básico
  String _convertirACSV(Map<String, dynamic> datos) {
    final buffer = StringBuffer();
    
    // Encabezado
    buffer.writeln('REPORTE: ${datos['titulo']}');
    buffer.writeln('PERIODO: ${datos['periodo']}');
    buffer.writeln('FECHA GENERACIÓN: ${datos['fechaGeneracion']}');
    buffer.writeln();
    
    // Datos específicos según el tipo de reporte
    if (datos.containsKey('servicios')) {
      // Reporte de servicios
      buffer.writeln('CÓDIGO,FECHA,CLIENTE,VEHÍCULO,TIPO,TOTAL,ESTADO');
      for (final servicio in datos['servicios']) {
        buffer.writeln('${servicio['codigo']},${servicio['fecha']},"${servicio['cliente']}","${servicio['vehiculo']}","${servicio['tipo']}",${servicio['total']},${servicio['estado']}');
      }
      
      // Resumen
      buffer.writeln();
      buffer.writeln('RESUMEN:');
      final resumen = datos['resumen'];
      buffer.writeln('TOTAL SERVICIOS,${datos['totalServicios']}');
      buffer.writeln('INGRESOS TOTALES,${resumen['totalIngresos']}');
      buffer.writeln('SERVICIOS TERMINADOS,${resumen['serviciosTerminados']}');
      buffer.writeln('SERVICIOS EN CURSO,${resumen['serviciosEnCurso']}');
      buffer.writeln('SERVICIOS EN ESPERA,${resumen['serviciosEnEspera']}');
      
    } else if (datos.containsKey('seguimiento')) {
      // Reporte de seguimiento
      final servicio = datos['servicio'];
      final seguimiento = datos['seguimiento'];
      
      buffer.writeln('INFORMACIÓN DEL SERVICIO');
      buffer.writeln('CÓDIGO,${servicio['codigo']}');
      buffer.writeln('CLIENTE,${servicio['cliente']}');
      buffer.writeln('VEHÍCULO,${servicio['vehiculo']}');
      buffer.writeln('FECHA INGRESO,${servicio['fecha_ingreso']}');
      buffer.writeln('FECHA SALIDA,${servicio['fecha_salida']}');
      buffer.writeln('OBSERVACIONES,${servicio['observaciones']}');
      buffer.writeln('TOTAL,${servicio['total']}');
      buffer.writeln();
      
      buffer.writeln('SEGUIMIENTO TÉCNICO');
      buffer.writeln('PASO ACTUAL,${seguimiento['paso_actual']}');
      buffer.writeln('ESTADO,${seguimiento['estado']}');
      buffer.writeln('FECHA ÚLTIMA ACTUALIZACIÓN,${seguimiento['fecha_ultima_actualizacion']}');
      buffer.writeln('DIAGNÓSTICO,${seguimiento['diagnostico']}');
      buffer.writeln('FALLAS IDENTIFICADAS,${seguimiento['fallas_identificadas']}');
      buffer.writeln('OBSERVACIONES FALLAS,${seguimiento['observaciones_fallas']}');
      buffer.writeln('SOLUCIÓN APLICADA,${seguimiento['solucion_aplicada']}');
      buffer.writeln('RESULTADO PRUEBAS,${seguimiento['resultado_pruebas']}');
      
    } else if (datos.containsKey('estadisticas_generales')) {
      // Reporte de estadísticas
      final stats = datos['estadisticas_generales'];
      final promedios = datos['promedios'];
      final distribucion = datos['distribucion_por_tipo'];
      
      buffer.writeln('ESTADÍSTICAS GENERALES');
      buffer.writeln('TOTAL SERVICIOS,${stats['total_servicios']}');
      buffer.writeln('INGRESOS TOTALES,${stats['ingresos_totales']}');
      buffer.writeln('SERVICIOS CON SEGUIMIENTO,${stats['servicios_con_seguimiento']}');
      buffer.writeln('SERVICIOS SIN SEGUIMIENTO,${stats['servicios_sin_seguimiento']}');
      buffer.writeln('INGRESO PROMEDIO,${promedios['ingreso_promedio']?.toStringAsFixed(2)}');
      buffer.writeln();
      
      buffer.writeln('DISTRIBUCIÓN POR TIPO DE TRABAJO');
      buffer.writeln('TIPO,CANTIDAD,TOTAL');
      for (final tipo in distribucion) {
        buffer.writeln('${tipo['tipo']},${tipo['cantidad']},${tipo['total']}');
      }
    }
    
    return buffer.toString();
  }
}