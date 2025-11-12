import 'package:flutter/foundation.dart';
import '../models/database_helper.dart'; // <- ajusta si tu ruta es distinta

class MarcaVM {
  final int id;
  final String desc;
  MarcaVM({required this.id, required this.desc});
}

class ModeloVM {
  final int id;
  final String desc;
  final int? anio;
  ModeloVM({required this.id, required this.desc, this.anio});
}

class VehiculoVM {
  final int codVehiculo;
  final String placas;
  final String color;
  final int? kilometraje;
  final String marca;
  final String modelo;
  final int? anio;
  final String numeroSerie;

  VehiculoVM({
    required this.codVehiculo,
    required this.placas,
    required this.color,
    required this.kilometraje,
    required this.marca,
    required this.modelo,
    required this.anio,
    required this.numeroSerie,
  });

  factory VehiculoVM.fromRow(Map<String, Object?> r) {
    int? toInt(dynamic v) => (v == null) ? null : (v is int ? v : int.tryParse(v.toString()));
    return VehiculoVM(
      codVehiculo: r['cod_vehiculo'] as int,
      placas: (r['placas'] ?? '') as String,
      color: (r['color'] ?? '') as String,
      kilometraje: toInt(r['kilometraje']),
      marca: (r['marca'] ?? '') as String,
      modelo: (r['modelo'] ?? '') as String,
      anio: toInt(r['anio_modelo']),
      numeroSerie: (r['numero_serie'] ?? '') as String,
    );
  }
}

class VehiculosClienteViewModel extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  final int codCliente;
  VehiculosClienteViewModel({required this.codCliente});

  bool _loading = false;
  String? _error;
  List<VehiculoVM> _items = [];
  List<MarcaVM> _marcas = [];
  List<ModeloVM> _modelos = []; // modelos de la marca seleccionada (cuando aplique)

  bool get loading => _loading;
  String? get error => _error;
  List<VehiculoVM> get items => _items;
  List<MarcaVM> get marcas => _marcas;
  List<ModeloVM> get modelos => _modelos;

  // ---------------- INIT / LOAD ----------------
  Future<void> init() async {
    await _loadMarcas();
    await load();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _db.rawQuery('''
        SELECT
          v.cod_vehiculo,
          v.placas,
          v.color,
          v.kilometraje,
          v.numero_serie,
          m.descripcion AS marca,
          md.descripcion_modelo AS modelo,
          md.anio_modelo
        FROM vehiculo v
        JOIN marca_vehiculo m   ON m.cod_marca_veh  = v.cod_marca_veh
        JOIN modelo_vehiculo md ON md.cod_modelo_veh = v.cod_modelo_veh
        WHERE v.cod_cliente = ?
        ORDER BY v.cod_vehiculo DESC
      ''', [codCliente]);
      _items = rows.map(VehiculoVM.fromRow).toList();
    } catch (e) {
      _error = 'ERROR AL CARGAR VEHÍCULOS: $e';
      _items = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ---------------- MARCAS / MODELOS ----------------
  Future<void> _loadMarcas() async {
    final rows = await _db.rawQuery('SELECT cod_marca_veh, descripcion FROM marca_vehiculo ORDER BY descripcion');
    _marcas = rows
        .map((r) => MarcaVM(id: r['cod_marca_veh'] as int, desc: (r['descripcion'] ?? '') as String))
        .toList();
    notifyListeners();
  }

  Future<void> loadModelosByMarca(int codMarca) async {
    final rows = await _db.rawQuery('''
      SELECT cod_modelo_veh, descripcion_modelo, anio_modelo
      FROM modelo_vehiculo
      WHERE 1=1
      ORDER BY descripcion_modelo, anio_modelo DESC
    '''); // si quieres filtrar por marca, agrega relación marca-modelo en tu esquema
    _modelos = rows
        .map((r) => ModeloVM(
              id: r['cod_modelo_veh'] as int,
              desc: (r['descripcion_modelo'] ?? '') as String,
              anio: (r['anio_modelo'] is int) ? r['anio_modelo'] as int : int.tryParse('${r['anio_modelo'] ?? ''}'),
            ))
        .toList();
    notifyListeners();
  }

  Future<int> _ensureMarca(String descripcion) async {
    final d = descripcion.trim();
    if (d.isEmpty) throw 'MARCA VACÍA';
    final row = await _db.rawQuery('SELECT cod_marca_veh FROM marca_vehiculo WHERE UPPER(descripcion)=UPPER(?) LIMIT 1', [d]);
    if (row.isNotEmpty) return row.first['cod_marca_veh'] as int;
    return await _db.rawInsert('INSERT INTO marca_vehiculo(descripcion) VALUES (?)', [d]);
  }

  Future<int> _ensureModelo(String descripcion, {int? anio}) async {
    final d = descripcion.trim();
    if (d.isEmpty) throw 'MODELO VACÍO';
    final row = await _db.rawQuery(
      'SELECT cod_modelo_veh FROM modelo_vehiculo WHERE UPPER(descripcion_modelo)=UPPER(?) AND (anio_modelo IS ? OR anio_modelo = ?) LIMIT 1',
      [d, anio == null ? null : anio, anio],
    );
    if (row.isNotEmpty) return row.first['cod_modelo_veh'] as int;
    return await _db.rawInsert('INSERT INTO modelo_vehiculo(descripcion_modelo, anio_modelo) VALUES (?,?)', [d, anio]);
  }

  Future<bool> _placaDisponible(String placas, {int? exceptVehiculo}) async {
    final p = placas.trim().toUpperCase();
    final rows = await _db.rawQuery(
      exceptVehiculo == null
          ? 'SELECT 1 FROM vehiculo WHERE UPPER(placas)=? LIMIT 1'
          : 'SELECT 1 FROM vehiculo WHERE UPPER(placas)=? AND cod_vehiculo<>? LIMIT 1',
      exceptVehiculo == null ? [p] : [p, exceptVehiculo],
    );
    return rows.isEmpty;
  }

  // ---------------- CREATE ----------------
  Future<bool> crearVehiculo({
    required String placas,
    required String color,
    required int? kilometraje,
    required String numeroSerie,
    // selección por ID o alta rápida por texto:
    int? codMarca,
    int? codModelo,
    String? marcaNueva,
    String? modeloNuevo,
    int? anioModelo,
  }) async {
    try {
      // validaciones
      if (!await _placaDisponible(placas)) {
        _error = 'YA EXISTE UN VEHÍCULO CON ESAS PLACAS';
        notifyListeners();
        return false;
      }

      final marcaId = codMarca ?? await _ensureMarca(marcaNueva ?? '');
      final modeloId = codModelo ?? await _ensureModelo(modeloNuevo ?? '', anio: anioModelo);

      await _db.rawInsert('''
        INSERT INTO vehiculo(cod_cliente, cod_marca_veh, cod_modelo_veh, kilometraje, placas, numero_serie, color)
        VALUES (?,?,?,?,?,?,?)
      ''', [
        codCliente,
        marcaId,
        modeloId,
        kilometraje ?? 0,
        placas.trim().toUpperCase(),
        numeroSerie.trim(),
        color.trim(),
      ]);

      await load();
      return true;
    } catch (e) {
      _error = 'NO SE PUDO CREAR: $e';
      notifyListeners();
      return false;
    }
  }

  // ---------------- UPDATE ----------------
  Future<bool> editarVehiculo({
    required int codVehiculo,
    required String placas,
    required String color,
    required int? kilometraje,
    required String numeroSerie,
    int? codMarca,
    int? codModelo,
    String? marcaNueva,
    String? modeloNuevo,
    int? anioModelo,
  }) async {
    try {
      if (!await _placaDisponible(placas, exceptVehiculo: codVehiculo)) {
        _error = 'YA EXISTE OTRO VEHÍCULO CON ESAS PLACAS';
        notifyListeners();
        return false;
      }

      final marcaId = codMarca ?? await _ensureMarca(marcaNueva ?? '');
      final modeloId = codModelo ?? await _ensureModelo(modeloNuevo ?? '', anio: anioModelo);

      final n = await _db.rawUpdate('''
        UPDATE vehiculo
        SET cod_marca_veh=?, cod_modelo_veh=?, kilometraje=?, placas=?, numero_serie=?, color=?
        WHERE cod_vehiculo=? AND cod_cliente=?
      ''', [
        marcaId,
        modeloId,
        kilometraje ?? 0,
        placas.trim().toUpperCase(),
        numeroSerie.trim(),
        color.trim(),
        codVehiculo,
        codCliente
      ]);

      await load();
      return n > 0;
    } catch (e) {
      _error = 'NO SE PUDO EDITAR: $e';
      notifyListeners();
      return false;
    }
  }

  // ---------------- DELETE ----------------
  Future<int> contarServiciosAsociados(int codVehiculo) async {
    final r = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM registro_servicio_taller WHERE cod_vehiculo=?',
      [codVehiculo],
    );
    final c = r.isNotEmpty ? (r.first['c'] as int? ?? 0) : 0;
    return c;
  }

  Future<bool> eliminarVehiculo(int codVehiculo) async {
    try {
      final n = await _db.rawDelete(
        'DELETE FROM vehiculo WHERE cod_vehiculo=? AND cod_cliente=?',
        [codVehiculo, codCliente],
      );
      await load();
      return n > 0;
    } catch (e) {
      _error = 'NO SE PUDO ELIMINAR: $e';
      notifyListeners();
      return false;
    }
  }
}                                               
