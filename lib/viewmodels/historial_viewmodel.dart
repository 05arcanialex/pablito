
import 'package:flutter/material.dart';
import '../models/database_helper.dart';

class HistorialViewModel extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  bool _loading = false;
  List<Map<String, Object?>> _rows = [];

  bool get loading => _loading;
  List<Map<String, Object?>> get rows => _rows;

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    const sql = '''
      SELECT 'TALLER' AS tipo, rst.cod_ser_taller AS id,
             rst.fecha_ingreso AS fecha, p.nombre || ' ' || p.apellidos AS persona,
             v.placas AS ref1, rst.observaciones AS ref2
        FROM registro_servicio_taller rst
        JOIN vehiculo v ON v.cod_vehiculo = rst.cod_vehiculo
        JOIN cliente c ON c.cod_clinte = v.cod_cliente
        JOIN persona p ON p.cod_persona = c.cod_persona
       UNION ALL
      SELECT 'AUXILIO' AS tipo, a.cod_reg_auxilio AS id,
             a.fecha, p.nombre || ' ' || p.apellidos AS persona,
             a.ubicacion_cliente AS ref1, NULL AS ref2
        FROM registro_auxilio_mecanico a
        JOIN cliente c ON c.cod_clinte = a.cod_cliente
        JOIN persona p ON p.cod_persona = c.cod_persona
       ORDER BY fecha DESC
       LIMIT 50
    ''';

    _rows = await _db.rawQuery(sql);
    _loading = false;
    notifyListeners();
  }
}
