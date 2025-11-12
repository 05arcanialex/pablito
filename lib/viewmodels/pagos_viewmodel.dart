import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/database_helper.dart';

/// MEDIOS DE PAGO HABILITADOS
const kMediosPago = <String>['EFECTIVO', 'QR'];

final _money = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs ', decimalDigits: 2);

/// ===== DTOs =====
class ReciboResumen {
  final int codRecibo;
  final String fecha;
  final int codCliente;
  final String cliente;
  final int codEmpleado;
  final String medioInicial;
  final double total;
  final double abonado;
  final double saldo;
  final String estadoCalc;

  ReciboResumen({
    required this.codRecibo,
    required this.fecha,
    required this.codCliente,
    required this.cliente,
    required this.codEmpleado,
    required this.medioInicial,
    required this.total,
    required this.abonado,
    required this.saldo,
    required this.estadoCalc,
  });

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory ReciboResumen.fromRow(Map<String, Object?> r) => ReciboResumen(
        codRecibo: r['cod_recibo_pago'] as int,
        fecha: (r['fecha'] ?? '') as String,
        codCliente: r['cod_cliente'] as int,
        cliente: (r['cliente'] ?? '') as String,
        codEmpleado: (r['cod_empleado'] ?? 0) as int,
        medioInicial: (r['medio_inicial'] ?? '') as String,
        total: _toDouble(r['total_detalles']),
        abonado: _toDouble(r['abonado']),
        saldo: _toDouble(r['saldo']),
        estadoCalc: (r['estado_calc'] ?? 'PENDIENTE') as String,
      );
}

class PagoMovimiento {
  final int codPagoMov;
  final String fecha;
  final double monto; // +abono / -devolución
  final String medio;
  final String? referencia;
  final String? observacion;

  PagoMovimiento({
    required this.codPagoMov,
    required this.fecha,
    required this.monto,
    required this.medio,
    this.referencia,
    this.observacion,
  });

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory PagoMovimiento.fromRow(Map<String, Object?> r) => PagoMovimiento(
        codPagoMov: r['cod_pago_mov'] as int,
        fecha: (r['fecha'] ?? '') as String,
        monto: _toDouble(r['monto']),
        medio: (r['medio'] ?? '') as String,
        referencia: r['referencia'] as String?,
        observacion: r['observacion'] as String?,
      );
}

/// ===== ViewModel =====
class PagosViewModel extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  bool _loading = false;
  String? _error;

  // filtros/UI
  String _query = '';
  String _filtroEstado = 'TODOS'; // TODOS | PENDIENTE | PAGADO

  // data
  List<ReciboResumen> _recibos = [];
  List<PagoMovimiento> _movimientos = [];

  bool get loading => _loading;
  String? get error => _error;
  String get filtroEstado => _filtroEstado;
  String get query => _query;

  List<ReciboResumen> get recibos => _filteredRecibos();
  List<PagoMovimiento> get movimientos => _movimientos;

  /// ===== INIT =====
  Future<void> init() async {
    await _ddlPagos();
    await _ensureViewResumen();
    await loadRecibos();
  }

  /// Crea tabla pago_movimiento (si no existe)
  Future<void> _ddlPagos() async {
    await _db.rawQuery('''
      CREATE TABLE IF NOT EXISTS pago_movimiento(
        cod_pago_mov    INTEGER PRIMARY KEY AUTOINCREMENT,
        cod_recibo_pago INTEGER NOT NULL,
        fecha           TEXT NOT NULL,
        monto           REAL NOT NULL,
        medio           TEXT NOT NULL,
        referencia      TEXT,
        observacion     TEXT,
        cod_empleado    INTEGER,
        FOREIGN KEY(cod_recibo_pago) REFERENCES recibo_pago(cod_recibo_pago)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY(cod_empleado) REFERENCES empleado(cod_empleado)
          ON UPDATE CASCADE ON DELETE SET NULL
      );
    ''');
    await _db.rawQuery('CREATE INDEX IF NOT EXISTS idx_pago_mov_recibo ON pago_movimiento(cod_recibo_pago);');
    await _db.rawQuery('CREATE INDEX IF NOT EXISTS idx_pago_mov_fecha  ON pago_movimiento(fecha);');
  }

  /// Crea/Refresca vista resumen
  Future<void> _ensureViewResumen() async {
    await _db.rawQuery('DROP VIEW IF EXISTS vw_recibo_resumen;');
    await _db.rawQuery('''
      CREATE VIEW vw_recibo_resumen AS
      SELECT
        r.cod_recibo_pago,
        r.fecha,
        c.cod_cliente,
        (p.nombre || ' ' || p.apellidos) AS cliente,
        r.cod_empleado,
        r.transferencia_pago AS medio_inicial,
        COALESCE((
          SELECT SUM(rtt.costo)
          FROM reg_serv_taller_tipo_trabajo rtt
          JOIN registro_servicio_taller rst ON rst.cod_ser_taller = rtt.cod_ser_taller
          WHERE rst.cod_recibo_pago = r.cod_recibo_pago
        ), 0) AS total_detalles,
        COALESCE((
          SELECT SUM(m.monto)
          FROM pago_movimiento m
          WHERE m.cod_recibo_pago = r.cod_recibo_pago
        ), 0) AS abonado,
        (
          COALESCE((
            SELECT SUM(rtt.costo)
            FROM reg_serv_taller_tipo_trabajo rtt
            JOIN registro_servicio_taller rst ON rst.cod_ser_taller = rtt.cod_ser_taller
            WHERE rst.cod_recibo_pago = r.cod_recibo_pago
          ), 0)
          -
          COALESCE((
            SELECT SUM(m.monto)
            FROM pago_movimiento m
            WHERE m.cod_recibo_pago = r.cod_recibo_pago
          ), 0)
        ) AS saldo,
        CASE
          WHEN COALESCE((
            SELECT SUM(rtt.costo)
            FROM reg_serv_taller_tipo_trabajo rtt
            JOIN registro_servicio_taller rst ON rst.cod_ser_taller = rtt.cod_ser_taller
            WHERE rst.cod_recibo_pago = r.cod_recibo_pago
          ), 0)
          <= COALESCE((
            SELECT SUM(m.monto)
            FROM pago_movimiento m
            WHERE m.cod_recibo_pago = r.cod_recibo_pago
          ), 0)
          THEN 'PAGADO'
          ELSE 'PENDIENTE'
        END AS estado_calc
      FROM recibo_pago r
      JOIN cliente c ON c.cod_cliente = r.cod_cliente
      JOIN persona p ON p.cod_persona = c.cod_persona;
    ''');
  }

  /// ===== LOAD =====
  Future<void> loadRecibos() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _db.rawQuery('SELECT * FROM vw_recibo_resumen ORDER BY date(fecha) DESC, cod_recibo_pago DESC;');
      _recibos = rows.map(ReciboResumen.fromRow).toList();
    } catch (e) {
      _error = 'ERROR AL CARGAR RECIBOS: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMovimientos(int codRecibo) async {
    try {
      final rs = await _db.rawQuery(
        'SELECT * FROM pago_movimiento WHERE cod_recibo_pago=? ORDER BY date(fecha) ASC, cod_pago_mov ASC;',
        [codRecibo],
      );
      _movimientos = rs.map(PagoMovimiento.fromRow).toList();
      notifyListeners();
    } catch (e) {
      _error = 'ERROR AL CARGAR PAGOS: $e';
      notifyListeners();
    }
  }

  /// ===== ACTIONS =====
  Future<bool> registrarPago({
    required int codRecibo,
    required double monto,
    required String medio,
    String? referencia,
    String? observacion,
    int? codEmpleado,
  }) async {
    if (monto == 0) return false;
    try {
      final fecha = DateTime.now().toIso8601String();
      await _db.rawInsert(
        '''INSERT INTO pago_movimiento(cod_recibo_pago,fecha,monto,medio,referencia,observacion,cod_empleado)
           VALUES(?,?,?,?,?,?,?)''',
        [codRecibo, fecha, monto, medio, referencia, observacion, codEmpleado],
      );
      await _autoMarcarSegunSaldo(codRecibo);
      await loadMovimientos(codRecibo);
      await loadRecibos();
      return true;
    } catch (e) {
      _error = 'NO SE PUDO REGISTRAR EL PAGO: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarPago(int codPagoMov, int codRecibo) async {
    try {
      await _db.rawDelete('DELETE FROM pago_movimiento WHERE cod_pago_mov=?', [codPagoMov]);
      await _autoMarcarSegunSaldo(codRecibo);
      await loadMovimientos(codRecibo);
      await loadRecibos();
      return true;
    } catch (e) {
      _error = 'NO SE PUDO ELIMINAR EL PAGO: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> _autoMarcarSegunSaldo(int codRecibo) async {
    final rs = await _db.rawQuery(
      'SELECT saldo FROM vw_recibo_resumen WHERE cod_recibo_pago=? LIMIT 1;',
      [codRecibo],
    );
    final saldo = (rs.isNotEmpty ? (rs.first['saldo'] as num?)?.toDouble() : 0.0) ?? 0.0;
    final nuevoEstado = (saldo <= 0.0001) ? 2 : 1; // 2=PAGADO, 1=PENDIENTE
    await _db.rawUpdate('UPDATE recibo_pago SET cod_est_rec=? WHERE cod_recibo_pago=?', [nuevoEstado, codRecibo]);
  }

  Future<bool> marcarReciboPagado(int codRecibo) async {
    try {
      // Ajusta saldo a 0 insertando un ajuste si hace falta
      final r = await _db.rawQuery('SELECT saldo FROM vw_recibo_resumen WHERE cod_recibo_pago=?', [codRecibo]);
      final saldo = (r.isNotEmpty ? (r.first['saldo'] as num?)?.toDouble() : 0.0) ?? 0.0;
      if (saldo > 0) {
        await registrarPago(
          codRecibo: codRecibo,
          monto: saldo,
          medio: 'EFECTIVO',
          observacion: 'AJUSTE AUTOMÁTICO PARA CERRAR RECIBO',
        );
      }
      await _db.rawUpdate('UPDATE recibo_pago SET cod_est_rec=? WHERE cod_recibo_pago=?', [2, codRecibo]);
      await loadRecibos();
      await loadMovimientos(codRecibo);
      return true;
    } catch (e) {
      _error = 'NO SE PUEDE MARCAR COMO PAGADO: $e';
      notifyListeners();
      return false;
    }
  }

  /// ===== FILTROS =====
  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  void setFiltroEstado(String estado) {
    _filtroEstado = estado;
    notifyListeners();
  }

  List<ReciboResumen> _filteredRecibos() {
    Iterable<ReciboResumen> list = _recibos;
    if (_filtroEstado != 'TODOS') {
      list = list.where((e) => e.estadoCalc.toUpperCase() == _filtroEstado);
    }
    final q = _query.trim().toUpperCase();
    if (q.isNotEmpty) {
      list = list.where((e) =>
          e.cliente.toUpperCase().contains(q) ||
          e.codRecibo.toString().contains(q));
    }
    return list.toList();
  }

  /// ===== IMPRESIÓN / PDF =====
  Future<String?> imprimirBoleta(BuildContext context, int codRecibo) async {
    try {
      final head = await _db.rawQuery('''
        SELECT r.cod_recibo_pago, r.fecha, v.placas,
               mv.descripcion AS marca, md.descripcion_modelo AS modelo,
               (pr.nombre || ' ' || pr.apellidos) AS cliente
        FROM recibo_pago r
        JOIN registro_servicio_taller rst ON rst.cod_recibo_pago = r.cod_recibo_pago
        JOIN vehiculo v ON v.cod_vehiculo = rst.cod_vehiculo
        JOIN marca_vehiculo mv ON mv.cod_marca_veh = v.cod_marca_veh
        JOIN modelo_vehiculo md ON md.cod_modelo_veh = v.cod_modelo_veh
        JOIN cliente c ON c.cod_cliente = r.cod_cliente
        JOIN persona pr ON pr.cod_persona = c.cod_persona
        WHERE r.cod_recibo_pago = ? LIMIT 1;
      ''', [codRecibo]);

      final det = await _db.rawQuery('''
        SELECT tt.descripcion, rtt.costo, rtt.detalles
        FROM reg_serv_taller_tipo_trabajo rtt
        JOIN registro_servicio_taller rst ON rst.cod_ser_taller = rtt.cod_ser_taller
        JOIN tipo_trabajo tt ON tt.cod_tipo_trabajo = rtt.cod_tipo_trabajo
        WHERE rst.cod_recibo_pago = ?;
      ''', [codRecibo]);

      final resumen = await _db.rawQuery(
        'SELECT * FROM vw_recibo_resumen WHERE cod_recibo_pago=?',
        [codRecibo],
      );

      if (head.isEmpty || resumen.isEmpty) return 'NO SE ENCONTRÓ INFORMACIÓN DEL RECIBO';

      final h = head.first;
      final r = resumen.first;
      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(28),
            textDirection: pw.TextDirection.ltr,
          ),
          build: (context) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ELECTRÓNICA AUTOMOTRIZ LA PAZ', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Auxilio mecánico y servicio técnico'),
                  ],
                ),
                pw.BarcodeWidget(
                  data: 'REC-${h['cod_recibo_pago']}',
                  barcode: pw.Barcode.qrCode(),
                  width: 70,
                  height: 70,
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),

            // Encabezado
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BOLETA / RECIBO #${h['cod_recibo_pago']}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Fecha: ${h['fecha']}'),
                      pw.SizedBox(height: 6),
                      pw.Text('Cliente: ${h['cliente']}'),
                      pw.Text('Vehículo: ${h['marca']} ${h['modelo']}  •  Placas: ${h['placas']}'),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // Detalle de trabajos
            pw.Table.fromTextArray(
              headers: const ['Trabajo', 'Detalle', 'Costo'],
              data: [
                for (final d in det)
                  [
                    (d['descripcion'] ?? '').toString(),
                    (d['detalles'] ?? '').toString(),
                    _money.format((d['costo'] as num?)?.toDouble() ?? 0.0),
                  ]
              ],
              cellAlignment: pw.Alignment.centerLeft,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFEFEF)),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1),
              },
            ),
            pw.SizedBox(height: 10),

            // Resumen
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 280,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _kv('Total', _money.format((r['total_detalles'] as num?)?.toDouble() ?? 0.0)),
                    _kv('Total abonado', _money.format((r['abonado'] as num?)?.toDouble() ?? 0.0)),
                    _kv('Saldo', _money.format((r['saldo'] as num?)?.toDouble() ?? 0.0)),
                    _kv('Estado', (r['estado_calc'] ?? 'PENDIENTE').toString()),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 16),

            pw.Text('Gracias por su preferencia.', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => await doc.save());
      return null; // null => OK
    } catch (e) {
      return 'ERROR AL GENERAR/IMPRIMIR PDF: $e';
    }
  }

  static pw.Widget _kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [pw.Text(k), pw.Text(v, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))],
        ),
      );
}
