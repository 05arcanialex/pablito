
import 'package:flutter/material.dart';
import '../models/database_helper.dart';

class InicioViewModel extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  bool _loading = false;
  Map<String, Object?> _kpis = {};

  bool get loading => _loading;
  Map<String, Object?> get kpis => _kpis;

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    final totalServicios = (await _db.rawQuery('SELECT COUNT(*) AS n FROM registro_servicio_taller')).first['n'] ?? 0;
    final totalAuxilios  = (await _db.rawQuery('SELECT COUNT(*) AS n FROM registro_auxilio_mecanico')).first['n'] ?? 0;
    final totalClientes  = (await _db.rawQuery('SELECT COUNT(*) AS n FROM cliente')).first['n'] ?? 0;
    final totalVehiculos = (await _db.rawQuery('SELECT COUNT(*) AS n FROM vehiculo')).first['n'] ?? 0;
    final totalRecaudo   = (await _db.rawQuery('SELECT IFNULL(SUM(total),0) AS s FROM recibo_pago')).first['s'] ?? 0;

    _kpis = {
      'servicios': totalServicios,
      'auxilios': totalAuxilios,
      'clientes': totalClientes,
      'vehiculos': totalVehiculos,
      'recaudo': totalRecaudo,
    };
    _loading = false;
    notifyListeners();
  }
}
