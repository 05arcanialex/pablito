
import 'package:flutter/material.dart';
import '../models/database_helper.dart';

class ObjetosViewModel extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  bool _loading = false;
  List<Map<String, Object?>> _rows = [];

  bool get loading => _loading;
  List<Map<String, Object?>> get rows => _rows;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    const sql = '''
      SELECT iv.cod_inv_veh,
             iv.descripcion_inv,
             iv.descripcion
        FROM inventario_vehiculo iv
       ORDER BY iv.cod_inv_veh DESC
    ''';
    _rows = await _db.rawQuery(sql);
    _loading = false;
    notifyListeners();
  }
}
