
import 'package:flutter/material.dart';
import '../models/database_helper.dart';

class PagosViewModel extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  bool _loading = false;
  List<Map<String, Object?>> _rows = [];

  bool get loading => _loading;
  List<Map<String, Object?>> get rows => _rows;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    const sql = '''
      SELECT r.cod_recibo_pago,
             r.fecha,
             r.total,
             r.a_cuenta,
             r.saldo,
             e.estado_recibo,
             p.nombre || ' ' || p.apellidos AS cliente
        FROM recibo_pago r
        JOIN estado_recibo e ON e.cod_est_rec = r.cod_est_rec
        JOIN cliente c ON c.cod_clinte = r.cod_cliente
        JOIN persona p ON p.cod_persona = c.cod_persona
       ORDER BY r.cod_recibo_pago DESC
    ''';
    _rows = await _db.rawQuery(sql);
    _loading = false;
    notifyListeners();
  }
}
