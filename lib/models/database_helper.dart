// lib/data/local/database_helper.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_live/sqflite_live.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  static const String _dbName = 'taller_mecanico.db';

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB(_dbName);
    return _db!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onOpen: (db) async {
        await _ensureTables(db);
      },
    );

    if (!kReleaseMode) {
      try {
        await db.live(port: 8888);
        print('✅ SQFLITE LIVE → http://localhost:8888');
        print('💡 adb reverse tcp:8888 tcp:8888 (si usas dispositivo físico)');
      } catch (e) {
        print('⚠️ No se pudo iniciar sqflite_live: $e');
      }
    }

    return db;
  }

  // CREACIÓN INICIAL
  Future<void> _createDB(Database db, int version) async {
    await _runDDL(db);
    await _seed(db);
  }

  // REFORZAR AL ABRIR
  Future<void> _ensureTables(Database db) async {
    await _runDDL(db);
    await _seed(db);
  }

  // ==========================================
  // 🧱 ESTRUCTURA DE TABLAS (DDL)
  // ==========================================
  Future<void> _runDDL(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cargo_empleado(
        cod_cargo_emp INTEGER PRIMARY KEY AUTOINCREMENT,
        descripcion   TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS persona(
        cod_persona INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre      TEXT NOT NULL,
        apellidos   TEXT NOT NULL,
        telefono    TEXT,
        email       TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cliente(
        cod_cliente INTEGER PRIMARY KEY AUTOINCREMENT,
        cod_persona INTEGER NOT NULL,
        FOREIGN KEY(cod_persona) REFERENCES persona(cod_persona)
          ON UPDATE CASCADE ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS empleado(
        cod_empleado  INTEGER PRIMARY KEY AUTOINCREMENT,
        cod_persona   INTEGER NOT NULL,
        cod_cargo_emp INTEGER NOT NULL,
        FOREIGN KEY(cod_persona)   REFERENCES persona(cod_persona)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY(cod_cargo_emp) REFERENCES cargo_empleado(cod_cargo_emp)
          ON UPDATE CASCADE ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS estado_recibo(
        cod_est_rec   INTEGER PRIMARY KEY AUTOINCREMENT,
        estado_recibo TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventario_vehiculo(
        cod_inv_veh     INTEGER PRIMARY KEY AUTOINCREMENT,
        descripcion_inv TEXT,
        descripcion     TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS marca_vehiculo(
        cod_marca_veh INTEGER PRIMARY KEY AUTOINCREMENT,
        descripcion   TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS modelo_vehiculo(
        cod_modelo_veh     INTEGER PRIMARY KEY AUTOINCREMENT,
        anio_modelo        INTEGER,
        descripcion_modelo TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS vehiculo(
        cod_vehiculo   INTEGER PRIMARY KEY AUTOINCREMENT,
        cod_cliente    INTEGER NOT NULL,
        cod_marca_veh  INTEGER NOT NULL,
        cod_modelo_veh INTEGER NOT NULL,
        kilometraje    INTEGER,
        placas         TEXT NOT NULL UNIQUE,
        numero_serie   TEXT,
        color          TEXT,
        FOREIGN KEY(cod_cliente)    REFERENCES cliente(cod_cliente)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY(cod_marca_veh)  REFERENCES marca_vehiculo(cod_marca_veh)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY(cod_modelo_veh) REFERENCES modelo_vehiculo(cod_modelo_veh)
          ON UPDATE CASCADE ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recibo_pago(
        cod_recibo_pago    INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha              TEXT NOT NULL,
        total              REAL,
        a_cuenta           REAL,
        saldo              REAL,
        transferencia_pago TEXT,
        cod_cliente        INTEGER NOT NULL,
        cod_empleado       INTEGER NOT NULL,
        cod_est_rec        INTEGER NOT NULL,
        FOREIGN KEY(cod_cliente)  REFERENCES cliente(cod_cliente)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY(cod_empleado) REFERENCES empleado(cod_empleado)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY(cod_est_rec)  REFERENCES estado_recibo(cod_est_rec)
          ON UPDATE CASCADE ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS registro_auxilio_mecanico(
        cod_reg_auxilio   INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha             TEXT NOT NULL,
        ubicacion_cliente TEXT,
        cod_cliente       INTEGER NOT NULL,
        FOREIGN KEY(cod_cliente) REFERENCES cliente(cod_cliente)
          ON UPDATE CASCADE ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS registro_servicio_taller(
        cod_ser_taller  INTEGER PRIMARY KEY AUTOINCREMENT,
        cod_recibo_pago INTEGER NOT NULL,
        cod_vehiculo    INTEGER NOT NULL,
        cod_empleado    INTEGER NOT NULL,
        fecha_ingreso   TEXT,
        fecha_salida    TEXT,
        ingreso_en_grua INTEGER,
        observaciones   TEXT,
        FOREIGN KEY(cod_recibo_pago) REFERENCES recibo_pago(cod_recibo_pago)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY(cod_vehiculo)    REFERENCES vehiculo(cod_vehiculo)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY(cod_empleado)    REFERENCES empleado(cod_empleado)
          ON UPDATE CASCADE ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tipo_trabajo(
        cod_tipo_trabajo INTEGER PRIMARY KEY AUTOINCREMENT,
        descripcion      TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reg_aux_mec_tipo_trabajo(
        cod_reg_auxilio_tipo INTEGER PRIMARY KEY AUTOINCREMENT,
        cod_reg_auxilio      INTEGER NOT NULL,
        cod_tipo_trabajo     INTEGER NOT NULL,
        detalles             TEXT,
        costo                REAL,
        FOREIGN KEY(cod_reg_auxilio)  REFERENCES registro_auxilio_mecanico(cod_reg_auxilio)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY(cod_tipo_trabajo) REFERENCES tipo_trabajo(cod_tipo_trabajo)
          ON UPDATE CASCADE ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reg_inventario_vehiculo(
        cod_reg_inv_veh INTEGER PRIMARY KEY AUTOINCREMENT,
        cod_inv_veh     INTEGER NOT NULL,
        cod_vehiculo    INTEGER NOT NULL,
        cod_empleado    INTEGER NOT NULL,
        cantidad        INTEGER,
        estado          TEXT,
        FOREIGN KEY(cod_inv_veh)  REFERENCES inventario_vehiculo(cod_inv_veh)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY(cod_vehiculo) REFERENCES vehiculo(cod_vehiculo)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY(cod_empleado) REFERENCES empleado(cod_empleado)
          ON UPDATE CASCADE ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reg_serv_taller_tipo_trabajo(
        cod_reg_ser_taller_tipo INTEGER PRIMARY KEY AUTOINCREMENT,
        cod_ser_taller          INTEGER NOT NULL,
        cod_tipo_trabajo        INTEGER NOT NULL,
        costo                   REAL,
        detalles                TEXT,
        FOREIGN KEY(cod_ser_taller)   REFERENCES registro_servicio_taller(cod_ser_taller)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY(cod_tipo_trabajo) REFERENCES tipo_trabajo(cod_tipo_trabajo)
          ON UPDATE CASCADE ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuario(
        cod_usuario    INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre_usu     TEXT NOT NULL,
        contrasena_usu TEXT NOT NULL,
        correo         TEXT NOT NULL UNIQUE,
        nivel_acceso   TEXT NOT NULL,
        estado         TEXT,
        cod_empleado   INTEGER,
        FOREIGN KEY(cod_empleado) REFERENCES empleado(cod_empleado)
          ON UPDATE CASCADE ON DELETE CASCADE
      );
    ''');
  }

  // ======================================================
  // 🌱 SEED BÁSICO Y DEMO CONTROLADO
  // ======================================================
  Future<void> _seed(Database db) async {
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM estado_recibo');
    final c = (r.isNotEmpty ? (r.first['c'] as int?) : 0) ?? 0;
    if (c == 0) {
      await db.insert('estado_recibo', {'estado_recibo': 'PENDIENTE'});
      await db.insert('estado_recibo', {'estado_recibo': 'PAGADO'});
      await db.insert('estado_recibo', {'estado_recibo': 'ANULADO'});
    }
  }

  // ✅ NUEVO MÉTODO: SOLO CARGA DEMO SI LA BD ESTÁ VACÍA
  Future<bool> _isEmptyForDemo(Database db) async {
    final r1 = await db.rawQuery('SELECT COUNT(*) AS c FROM cliente');
    final r2 = await db.rawQuery('SELECT COUNT(*) AS c FROM registro_servicio_taller');
    final c1 = (r1.isNotEmpty ? (r1.first['c'] as int?) : 0) ?? 0;
    final c2 = (r2.isNotEmpty ? (r2.first['c'] as int?) : 0) ?? 0;
    return (c1 == 0 || c2 == 0);
  }

  Future<void> seedIfEmpty() async {
    final db = await database;
    if (await _isEmptyForDemo(db)) {
      await seedDemo();
    } else {
      print('ℹ️ La base de datos ya contiene datos, no se aplica seedDemo().');
    }
  }

  // ======================================================
  // 🔹 SEED DEMO COMPLETO
  // ======================================================
  Future<void> seedDemo() async {
    final db = await database;
    print('🚀 INICIANDO SEED DEMO...');

    final idCargoMec = await db.insert('cargo_empleado', {'descripcion': 'MECÁNICO'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idCargoAdm = await db.insert('cargo_empleado', {'descripcion': 'ADMINISTRADOR'}, conflictAlgorithm: ConflictAlgorithm.ignore);

    final idPersCli = await db.insert('persona', {'nombre': 'Juan', 'apellidos': 'Pérez López', 'telefono': '77788899', 'email': 'juan@example.com'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idPersEmp = await db.insert('persona', {'nombre': 'Ramiro', 'apellidos': 'Arcani Condori', 'telefono': '76543210', 'email': 'ramiro@example.com'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idPersAdm = await db.insert('persona', {'nombre': 'Alex', 'apellidos': 'Arcani Gutiérrez', 'telefono': '60123456', 'email': 'alex@example.com'}, conflictAlgorithm: ConflictAlgorithm.ignore);

    final idCliente = await db.insert('cliente', {'cod_persona': idPersCli}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idEmp = await db.insert('empleado', {'cod_persona': idPersEmp, 'cod_cargo_emp': idCargoMec}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idEmpAdm = await db.insert('empleado', {'cod_persona': idPersAdm, 'cod_cargo_emp': idCargoAdm}, conflictAlgorithm: ConflictAlgorithm.ignore);

    final idMarca = await db.insert('marca_vehiculo', {'descripcion': 'TOYOTA'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idModelo = await db.insert('modelo_vehiculo', {'anio_modelo': 2020, 'descripcion_modelo': 'HILUX'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idVeh = await db.insert('vehiculo', {
      'cod_cliente': idCliente,
      'cod_marca_veh': idMarca,
      'cod_modelo_veh': idModelo,
      'kilometraje': 125000,
      'placas': 'ABC-123',
      'numero_serie': 'XYZ987654',
      'color': 'GRIS'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final idTipoDiag = await db.insert('tipo_trabajo', {'descripcion': 'DIAGNÓSTICO'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idTipoMant = await db.insert('tipo_trabajo', {'descripcion': 'MANTENIMIENTO'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idTipoRep = await db.insert('tipo_trabajo', {'descripcion': 'REPARACIONES EN GENERAL'}, conflictAlgorithm: ConflictAlgorithm.ignore);

    final idRecibo = await db.insert('recibo_pago', {
      'fecha': DateTime.now().toIso8601String(),
      'total': 250.0,
      'a_cuenta': 100.0,
      'saldo': 150.0,
      'transferencia_pago': 'EFECTIVO',
      'cod_cliente': idCliente,
      'cod_empleado': idEmp,
      'cod_est_rec': 1
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final idServ = await db.insert('registro_servicio_taller', {
      'cod_recibo_pago': idRecibo,
      'cod_vehiculo': idVeh,
      'cod_empleado': idEmp,
      'fecha_ingreso': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'fecha_salida': DateTime.now().toIso8601String(),
      'ingreso_en_grua': 0,
      'observaciones': 'Cambio de batería y revisión del alternador'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('reg_serv_taller_tipo_trabajo', {
      'cod_ser_taller': idServ,
      'cod_tipo_trabajo': idTipoDiag,
      'costo': 100.0,
      'detalles': 'Prueba de carga eléctrica'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('registro_auxilio_mecanico', {
      'fecha': DateTime.now().toIso8601String(),
      'ubicacion_cliente': 'Av. 6 de Marzo, El Alto',
      'cod_cliente': idCliente
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('usuario', {
      'nombre_usu': 'admin',
      'contrasena_usu': '12345',
      'correo': 'admin@electronica.com',
      'nivel_acceso': 'ADMIN',
      'estado': 'ACTIVO',
      'cod_empleado': idEmpAdm
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    print('✅ SEED DEMO COMPLETADO');
  }

  // CRUD DE BAJO NIVEL
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? args]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }

  Future<int> rawInsert(String sql, [List<Object?>? args]) async {
    final db = await database;
    return db.rawInsert(sql, args);
  }

  Future<int> rawUpdate(String sql, [List<Object?>? args]) async {
    final db = await database;
    return db.rawUpdate(sql, args);
  }

  Future<int> rawDelete(String sql, [List<Object?>? args]) async {
    final db = await database;
    return db.rawDelete(sql, args);
  }

  // 🔄 RESET BD
  static Future<void> resetDevDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    await deleteDatabase(path);
    _db = null;
    await instance.database;
  }
}
