import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
// 👇 CORRIGE LA RUTA SEGÚN TU ESTRUCTURA
import '../models/database_helper.dart';
/// DTO PARA LA FILA DE CLIENTE EN LISTA
class ClienteItem {
  final int codCliente;
  final int codPersona;
  final String nombre;
  final String apellidos;
  final String? telefono;
  final String? email;
  final int cantVehiculos;
  final DateTime? ultimoServicio;

  ClienteItem({
    required this.codCliente,
    required this.codPersona,
    required this.nombre,
    required this.apellidos,
    required this.telefono,
    required this.email,
    required this.cantVehiculos,
    required this.ultimoServicio,
  });

  String get nombreCompleto => '${nombre.toUpperCase()} ${apellidos.toUpperCase()}';
}

/// DTO PARA VEHÍCULO DETALLE
class VehiculoItem {
  final int codVehiculo;
  final String placas;
  final String color;
  final int? kilometraje;
  final String? numeroSerie;
  final String marca;
  final String modelo;
  final int? anio;

  VehiculoItem({
    required this.codVehiculo,
    required this.placas,
    required this.color,
    required this.kilometraje,
    required this.numeroSerie,
    required this.marca,
    required this.modelo,
    required this.anio,
  });
}

/// VIEWMODEL DE CLIENTES
class ClientesViewModel extends ChangeNotifier {
  final _dbh = DatabaseHelper.instance;

  List<ClienteItem> _clientes = [];
  String _query = '';

  List<ClienteItem> get clientes {
    if (_query.trim().isEmpty) return _clientes;
    final q = _query.trim().toUpperCase();
    return _clientes.where((c) {
      final full = '${c.nombre} ${c.apellidos}'.toUpperCase();
      return full.contains(q) ||
          (c.email?.toUpperCase().contains(q) ?? false) ||
          (c.telefono?.contains(q) ?? false);
    }).toList();
  }

  String get query => _query;

  Future<void> refresh() async => loadClientes();

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  // CARGA DE CLIENTES
  Future<void> loadClientes() async {
    final db = await _dbh.database;
    final rows = await db.rawQuery(r'''
      SELECT 
        c.cod_cliente,
        p.cod_persona,
        p.nombre,
        p.apellidos,
        p.telefono,
        p.email,
        IFNULL((
          SELECT COUNT(*)
          FROM vehiculo v
          WHERE v.cod_cliente = c.cod_cliente
        ), 0) AS cant_vehiculos,
        (
          SELECT MAX(rst.fecha_salida)
          FROM vehiculo v
          LEFT JOIN registro_servicio_taller rst ON rst.cod_vehiculo = v.cod_vehiculo
          WHERE v.cod_cliente = c.cod_cliente
        ) AS ultimo_servicio
      FROM cliente c
      JOIN persona p ON p.cod_persona = c.cod_persona
      ORDER BY p.apellidos COLLATE NOCASE ASC, p.nombre COLLATE NOCASE ASC
    ''');

    _clientes = rows.map((r) {
      final us = r['ultimo_servicio'] as String?;
      return ClienteItem(
        codCliente: (r['cod_cliente'] as int),
        codPersona: (r['cod_persona'] as int),
        nombre: (r['nombre'] as String),
        apellidos: (r['apellidos'] as String),
        telefono: r['telefono'] as String?,
        email: r['email'] as String?,
        cantVehiculos: (r['cant_vehiculos'] as int?) ?? 0,
        ultimoServicio: (us == null || us.isEmpty) ? null : DateTime.tryParse(us),
      );
    }).toList();

    notifyListeners();
  }

  // CRUD CLIENTE (PERSONA + CLIENTE)
  Future<int> crearCliente({
    required String nombre,
    required String apellidos,
    String? telefono,
    String? email,
  }) async {
    final db = await _dbh.database;
    return await db.transaction<int>((txn) async {
      final codPersona = await txn.insert('persona', {
        'nombre': nombre.trim().toUpperCase(),
        'apellidos': apellidos.trim().toUpperCase(),
        'telefono': (telefono ?? '').trim().isEmpty ? null : telefono!.trim(),
        'email': (email ?? '').trim().isEmpty ? null : email!.trim(),
      });
      final codCliente = await txn.insert('cliente', {
        'cod_persona': codPersona,
      });
      return codCliente;
    }).whenComplete(loadClientes);
  }

  Future<void> actualizarCliente({
    required int codCliente,
    required int codPersona,
    required String nombre,
    required String apellidos,
    String? telefono,
    String? email,
  }) async {
    final db = await _dbh.database;
    await db.update(
      'persona',
      {
        'nombre': nombre.trim().toUpperCase(),
        'apellidos': apellidos.trim().toUpperCase(),
        'telefono': (telefono ?? '').trim().isEmpty ? null : telefono!.trim(),
        'email': (email ?? '').trim().isEmpty ? null : email!.trim(),
      },
      where: 'cod_persona = ?',
      whereArgs: [codPersona],
    );
    await loadClientes();
  }

  Future<void> eliminarCliente({
    required int codCliente,
    required int codPersona,
  }) async {
    final db = await _dbh.database;
    await db.transaction((txn) async {
      await txn.delete('cliente', where: 'cod_cliente = ?', whereArgs: [codCliente]);
      await txn.delete('persona', where: 'cod_persona = ?', whereArgs: [codPersona]);
    });
    await loadClientes();
  }

  // LISTAR VEHÍCULOS POR CLIENTE
  Future<List<VehiculoItem>> listarVehiculosDeCliente(int codCliente) async {
    final db = await _dbh.database;
    final rows = await db.rawQuery(r'''
      SELECT 
        v.cod_vehiculo,
        v.placas,
        IFNULL(v.color,'') AS color,
        v.kilometraje,
        v.numero_serie,
        m.descripcion AS marca,
        mo.descripcion_modelo AS modelo,
        mo.anio_modelo AS anio
      FROM vehiculo v
      JOIN marca_vehiculo m ON m.cod_marca_veh = v.cod_marca_veh
      JOIN modelo_vehiculo mo ON mo.cod_modelo_veh = v.cod_modelo_veh
      WHERE v.cod_cliente = ?
      ORDER BY v.cod_vehiculo DESC
    ''', [codCliente]);

    return rows.map((r) {
      return VehiculoItem(
        codVehiculo: r['cod_vehiculo'] as int,
        placas: (r['placas'] as String),
        color: (r['color'] as String),
        kilometraje: r['kilometraje'] as int?,
        numeroSerie: r['numero_serie'] as String?,
        marca: (r['marca'] as String),
        modelo: (r['modelo'] as String),
        anio: r['anio'] as int?,
      );
    }).toList();
  }

  // HELPERS MARCA/MODELO
  Future<int> _findOrCreateMarca(DatabaseExecutor db, String descripcion) async {
    final desc = descripcion.trim().toUpperCase();
    final hit = await db.query('marca_vehiculo', where: 'descripcion = ?', whereArgs: [desc], limit: 1);
    if (hit.isNotEmpty) return hit.first['cod_marca_veh'] as int;
    return await db.insert('marca_vehiculo', {'descripcion': desc});
  }

  Future<int> _findOrCreateModelo(DatabaseExecutor db, {required String descripcion, int? anio}) async {
    final desc = descripcion.trim().toUpperCase();
    final hit = await db.query(
      'modelo_vehiculo',
      where: 'descripcion_modelo = ? AND (anio_modelo IS ? OR anio_modelo = ?)',
      whereArgs: [desc, anio == null ? null : anio, anio ?? 0],
      limit: 1,
    );
    if (hit.isNotEmpty) return hit.first['cod_modelo_veh'] as int;
    return await db.insert('modelo_vehiculo', {
      'descripcion_modelo': desc,
      'anio_modelo': anio,
    });
  }

  // CRUD VEHÍCULO
  Future<int> crearVehiculo({
    required int codCliente,
    required String marca,
    required String modelo,
    int? anio,
    required String placas,
    required String color,
    int? kilometraje,
    String? numeroSerie,
  }) async {
    final db = await _dbh.database;
    final id = await db.transaction<int>((txn) async {
      final codMarca = await _findOrCreateMarca(txn, marca);
      final codModelo = await _findOrCreateModelo(txn, descripcion: modelo, anio: anio);
      final codVeh = await txn.insert('vehiculo', {
        'cod_cliente': codCliente,
        'cod_marca_veh': codMarca,
        'cod_modelo_veh': codModelo,
        'kilometraje': kilometraje,
        'placas': placas.trim().toUpperCase(),
        'numero_serie': (numeroSerie ?? '').trim().isEmpty ? null : numeroSerie!.trim().toUpperCase(),
        'color': color.trim().toUpperCase(),
      });
      return codVeh;
    });
    await loadClientes();
    return id;
  }

  Future<void> actualizarVehiculo({
    required int codVehiculo,
    required String marca,
    required String modelo,
    int? anio,
    required String placas,
    required String color,
    int? kilometraje,
    String? numeroSerie,
  }) async {
    final db = await _dbh.database;
    await db.transaction((txn) async {
      final codMarca = await _findOrCreateMarca(txn, marca);
      final codModelo = await _findOrCreateModelo(txn, descripcion: modelo, anio: anio);
      await txn.update(
        'vehiculo',
        {
          'cod_marca_veh': codMarca,
          'cod_modelo_veh': codModelo,
          'kilometraje': kilometraje,
          'placas': placas.trim().toUpperCase(),
          'numero_serie': (numeroSerie ?? '').trim().isEmpty ? null : numeroSerie!.trim().toUpperCase(),
          'color': color.trim().toUpperCase(),
        },
        where: 'cod_vehiculo = ?',
        whereArgs: [codVehiculo],
      );
    });
    await loadClientes();
  }

  Future<void> eliminarVehiculo(int codVehiculo) async {
    final db = await _dbh.database;
    await db.delete('vehiculo', where: 'cod_vehiculo = ?', whereArgs: [codVehiculo]);
    await loadClientes();
  }
}
