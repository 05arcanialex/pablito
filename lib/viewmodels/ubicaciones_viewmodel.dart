
import 'package:flutter/material.dart';
import '../models/database_helper.dart';

class UbicacionesViewModel extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  bool _loading = false;
  List<Map<String, Object?>> _rows = [];

  bool get loading => _loading;
  List<Map<String, Object?>> get rows => _rows;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    const sql = '''
      SELECT a.cod_reg_auxilio,
             a.fecha,
             a.ubicacion_cliente,
             p.nombre || ' ' || p.apellidos AS cliente
        FROM registro_auxilio_mecanico a
        JOIN cliente c ON c.cod_clinte = a.cod_cliente
        JOIN persona p ON p.cod_persona = c.cod_persona
       ORDER BY a.cod_reg_auxilio DESC
    ''';
    _rows = await _db.rawQuery(sql);
    _loading = false;
    notifyListeners();
  }
}
