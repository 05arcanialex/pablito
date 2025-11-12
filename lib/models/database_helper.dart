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
      version: 5, // ⬅️ V5 CON TODOS LOS CAMBIOS
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: (db, oldV, newV) async {
        // V1 -> V2: add foto_path a reg_inventario_vehiculo
        if (oldV < 2) {
          try { await db.execute('ALTER TABLE reg_inventario_vehiculo ADD COLUMN foto_path TEXT'); } catch (_) {}
        }
        // V2 -> V3: add foto_path a inventario_vehiculo
        if (oldV < 3) {
          try { await db.execute('ALTER TABLE inventario_vehiculo ADD COLUMN foto_path TEXT'); } catch (_) {}
        }
        // V3 -> V4: usuario usa cod_persona (migración segura con copia)
        if (oldV < 4) {
          await _migrateUsuarioToCodPersona(db);
        }
        // V4 -> V5: asegurar reg_serv_taller_tipo_trabajo (por si faltó)
        if (oldV < 5) {
          try {
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
          } catch (_) {}
        }
      },
      onOpen: (db) async {
        await _ensureTables(db); // BLINDA TABLAS
        await _ensureViews(db);  // BLINDA VISTAS
      },
    );

    if (!kReleaseMode) {
      try {
        await db.live(port: 8888);
        // ignore: avoid_print
        print('✅ SQFLITE LIVE → http://localhost:8888');
        // ignore: avoid_print
        print('💡 adb reverse tcp:8888 tcp:8888 (dispositivo físico)');
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ No se pudo iniciar sqflite_live: $e');
      }
    }

    return db;
  }

  // CREACIÓN INICIAL
  Future<void> _createDB(Database db, int version) async {
    await _runDDL(db);
    await _seed(db);
    await _ensureViews(db);
  }

  // REFORZAR AL ABRIR
  Future<void> _ensureTables(Database db) async {
    await _runDDL(db);
    await _seed(db);
  }

  Future<void> _ensureViews(Database db) async {
    await db.execute('DROP VIEW IF EXISTS vw_servicios');
    await db.execute('''
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
        NULL AS estado
      FROM registro_servicio_taller rst
      JOIN vehiculo v ON v.cod_vehiculo = rst.cod_vehiculo
      JOIN cliente  c ON c.cod_cliente  = v.cod_cliente
      JOIN persona  p ON p.cod_persona  = c.cod_persona;
    ''');
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
        descripcion     TEXT,
        foto_path       TEXT
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
        foto_path       TEXT,
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

    // ⬇️ USUARIO CON cod_persona (FK a persona)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuario(
        cod_usuario    INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre_usu     TEXT NOT NULL,
        contrasena_usu TEXT NOT NULL,
        correo         TEXT NOT NULL UNIQUE,
        nivel_acceso   TEXT NOT NULL,
        estado         TEXT,
        cod_persona    INTEGER,
        FOREIGN KEY(cod_persona) REFERENCES persona(cod_persona)
          ON UPDATE CASCADE ON DELETE CASCADE
      );
    ''');
  }

  // =============== MIGRACIÓN V4: usuario -> cod_persona ===============
  Future<void> _migrateUsuarioToCodPersona(Database db) async {
    // 1) crear tabla temporal con el nuevo esquema
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuario_tmp(
        cod_usuario    INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre_usu     TEXT NOT NULL,
        contrasena_usu TEXT NOT NULL,
        correo         TEXT NOT NULL UNIQUE,
        nivel_acceso   TEXT NOT NULL,
        estado         TEXT,
        cod_persona    INTEGER,
        FOREIGN KEY(cod_persona) REFERENCES persona(cod_persona)
          ON UPDATE CASCADE ON DELETE CASCADE
      );
    ''');

    // 2) copiar datos: derivar cod_persona desde empleado.cod_persona
    await db.execute('''
      INSERT OR IGNORE INTO usuario_tmp
      (cod_usuario, nombre_usu, contrasena_usu, correo, nivel_acceso, estado, cod_persona)
      SELECT u.cod_usuario, u.nombre_usu, u.contrasena_usu, u.correo, u.nivel_acceso, u.estado,
             e.cod_persona
      FROM usuario u
      LEFT JOIN empleado e ON e.cod_empleado = u.cod_empleado
    ''');

    // 3) eliminar tabla antigua y renombrar
    await db.execute('DROP TABLE IF EXISTS usuario;');
    await db.execute('ALTER TABLE usuario_tmp RENAME TO usuario;');
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

  // ✅ SOLO CARGA DEMO SI ESTÁ VACÍA
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
      // ignore: avoid_print
      print('ℹ️ La base de datos ya contiene datos, no se aplica seedDemo().');
    }
  }

  // 🔹 SEED DEMO COMPLETO (USA cod_persona EN USUARIO)
  Future<void> seedDemo() async {
    final db = await database;
    // ignore: avoid_print
    print('🚀 INICIANDO SEED DEMO COMPLETO...');

    // 1) CARGOS
    final idCargoMec = await db.insert('cargo_empleado', {'descripcion': 'MECÁNICO'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idCargoAdm = await db.insert('cargo_empleado', {'descripcion': 'ADMINISTRADOR'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idCargoTec = await db.insert('cargo_empleado', {'descripcion': 'TÉCNICO DIAGNOSTICADOR'}, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 2) PERSONAS
    final idPers1 = await db.insert('persona', {'nombre': 'Juan', 'apellidos': 'Pérez López', 'telefono': '77788899', 'email': 'juan@example.com'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idPers2 = await db.insert('persona', {'nombre': 'Ramiro', 'apellidos': 'Arcani Condori', 'telefono': '76543210', 'email': 'ramiro@example.com'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idPers3 = await db.insert('persona', {'nombre': 'Alex', 'apellidos': 'Arcani Gutiérrez', 'telefono': '60123456', 'email': 'alex@example.com'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idPers4 = await db.insert('persona', {'nombre': 'Carla', 'apellidos': 'Mendoza Vargas', 'telefono': '70654321', 'email': 'carla@example.com'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idPers5 = await db.insert('persona', {'nombre': 'Luis', 'apellidos': 'Torrez Nina', 'telefono': '78945612', 'email': 'luis@example.com'}, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 3) CLIENTES Y EMPLEADOS
    final idCliente1 = await db.insert('cliente', {'cod_persona': idPers1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idCliente2 = await db.insert('cliente', {'cod_persona': idPers4}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idCliente3 = await db.insert('cliente', {'cod_persona': idPers5}, conflictAlgorithm: ConflictAlgorithm.ignore);

    final idEmpMec = await db.insert('empleado', {'cod_persona': idPers2, 'cod_cargo_emp': idCargoMec}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idEmpAdm = await db.insert('empleado', {'cod_persona': idPers3, 'cod_cargo_emp': idCargoAdm}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idEmpTec = await db.insert('empleado', {'cod_persona': idPers4, 'cod_cargo_emp': idCargoTec}, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 4) MARCAS Y MODELOS
    final idToyota = await db.insert('marca_vehiculo', {'descripcion': 'TOYOTA'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idNissan = await db.insert('marca_vehiculo', {'descripcion': 'NISSAN'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idHyundai = await db.insert('marca_vehiculo', {'descripcion': 'HYUNDAI'}, conflictAlgorithm: ConflictAlgorithm.ignore);

    final idHilux  = await db.insert('modelo_vehiculo', {'anio_modelo': 2020, 'descripcion_modelo': 'HILUX'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idSentra = await db.insert('modelo_vehiculo', {'anio_modelo': 2018, 'descripcion_modelo': 'SENTRA'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idTucson = await db.insert('modelo_vehiculo', {'anio_modelo': 2021, 'descripcion_modelo': 'TUCSON'}, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 5) VEHÍCULOS
    final idVeh1 = await db.insert('vehiculo', {
      'cod_cliente': idCliente1,
      'cod_marca_veh': idToyota,
      'cod_modelo_veh': idHilux,
      'kilometraje': 125000,
      'placas': 'ABC-123',
      'numero_serie': 'XYZ987654',
      'color': 'GRIS'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final idVeh2 = await db.insert('vehiculo', {
      'cod_cliente': idCliente2,
      'cod_marca_veh': idNissan,
      'cod_modelo_veh': idSentra,
      'kilometraje': 80000,
      'placas': 'XYZ-987',
      'numero_serie': 'AA112233',
      'color': 'NEGRO'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final idVeh3 = await db.insert('vehiculo', {
      'cod_cliente': idCliente3,
      'cod_marca_veh': idHyundai,
      'cod_modelo_veh': idTucson,
      'kilometraje': 45000,
      'placas': 'MNO-456',
      'numero_serie': 'BB445566',
      'color': 'AZUL'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 6) TIPOS DE TRABAJO
    final idDiag         = await db.insert('tipo_trabajo', {'descripcion': 'DIAGNÓSTICO'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idMant         = await db.insert('tipo_trabajo', {'descripcion': 'MANTENIMIENTO'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idRep          = await db.insert('tipo_trabajo', {'descripcion': 'REPARACIÓN MECÁNICA'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idProg         = await db.insert('tipo_trabajo', {'descripcion': 'PROGRAMACIÓN ECU'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idCambioAceite = await db.insert('tipo_trabajo', {'descripcion': 'CAMBIO DE ACEITE'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final idAlineacion   = await db.insert('tipo_trabajo', {'descripcion': 'ALINEACIÓN Y BALANCEO'}, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 7) INVENTARIO
    final idAceite = await db.insert('inventario_vehiculo', {
      'descripcion_inv': 'Lubricante 10W-40',
      'descripcion': 'Aceite sintético de motor',
      'foto_path': 'assets/img/aceite.png'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final idFiltro = await db.insert('inventario_vehiculo', {
      'descripcion_inv': 'Filtro de aire',
      'descripcion': 'Filtro de aire de motor Toyota',
      'foto_path': 'assets/img/filtro.png'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final idBujia = await db.insert('inventario_vehiculo', {
      'descripcion_inv': 'Bujías NGK',
      'descripcion': 'Juego de bujías estándar',
      'foto_path': 'assets/img/bujia.png'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('reg_inventario_vehiculo', {
      'cod_inv_veh': idAceite,
      'cod_vehiculo': idVeh1,
      'cod_empleado': idEmpMec,
      'cantidad': 2,
      'estado': 'NUEVO',
      'foto_path': 'assets/img/aceite.png'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('reg_inventario_vehiculo', {
      'cod_inv_veh': idFiltro,
      'cod_vehiculo': idVeh2,
      'cod_empleado': idEmpTec,
      'cantidad': 1,
      'estado': 'USADO',
      'foto_path': 'assets/img/filtro.png'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 8) SERVICIOS + RECIBOS
    Future<void> _crearServicio(
      int codCliente,
      int codVeh,
      int codEmpleado,
      List<Map<String, dynamic>> trabajos,
      double total,
    ) async {
      final idRecibo = await db.insert('recibo_pago', {
        'fecha': DateTime.now().toIso8601String(),
        'total': total,
        'a_cuenta': total * 0.5,
        'saldo': total * 0.5,
        'transferencia_pago': 'EFECTIVO',
        'cod_cliente': codCliente,
        'cod_empleado': codEmpleado,
        'cod_est_rec': 1
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      final idServ = await db.insert('registro_servicio_taller', {
        'cod_recibo_pago': idRecibo,
        'cod_vehiculo': codVeh,
        'cod_empleado': codEmpleado,
        'fecha_ingreso': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'fecha_salida': DateTime.now().toIso8601String(),
        'ingreso_en_grua': 0,
        'observaciones': 'Servicio general con diagnóstico y mantenimiento preventivo.'
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      for (var t in trabajos) {
        await db.insert('reg_serv_taller_tipo_trabajo', {
          'cod_ser_taller': idServ,
          'cod_tipo_trabajo': t['id'],
          'costo': t['costo'],
          'detalles': t['detalle']
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    await _crearServicio(idCliente1, idVeh1, idEmpMec, [
      {'id': idDiag, 'costo': 80.0, 'detalle': 'Escaneo completo del sistema ECU'},
      {'id': idCambioAceite, 'costo': 50.0, 'detalle': 'Cambio de aceite sintético 10W-40'},
    ], 130.0);

    await _crearServicio(idCliente2, idVeh2, idEmpTec, [
      {'id': idRep, 'costo': 250.0, 'detalle': 'Cambio de bomba de combustible'},
      {'id': idAlineacion, 'costo': 80.0, 'detalle': 'Alineación y balanceo de ruedas'},
    ], 330.0);

    await _crearServicio(idCliente3, idVeh3, idEmpMec, [
      {'id': idProg, 'costo': 200.0, 'detalle': 'Reprogramación de ECU y actualización de firmware'},
      {'id': idMant, 'costo': 150.0, 'detalle': 'Revisión de frenos y líquido refrigerante'},
    ], 350.0);

    // 9) AUXILIOS MECÁNICOS
    await db.insert('registro_auxilio_mecanico', {
      'fecha': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      'ubicacion_cliente': 'Av. 6 de Marzo, El Alto',
      'cod_cliente': idCliente1
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('registro_auxilio_mecanico', {
      'fecha': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'ubicacion_cliente': 'Plaza del Estudiante, La Paz',
      'cod_cliente': idCliente2
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 10) USUARIOS
    await db.insert('usuario', {
      'nombre_usu': 'admin',
      'contrasena_usu': '12345',
      'correo': 'admin@electronica.com',
      'nivel_acceso': 'ADMIN',
      'estado': 'ACTIVO',
      'cod_persona': idPers3,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('usuario', {
      'nombre_usu': 'mecanico',
      'contrasena_usu': '12345',
      'correo': 'mecanico@electronica.com',
      'nivel_acceso': 'MECANICO',
      'estado': 'ACTIVO',
      'cod_persona': idPers2,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('usuario', {
      'nombre_usu': 'cliente',
      'contrasena_usu': '12345',
      'correo': 'cliente@electronica.com',
      'nivel_acceso': 'CLIENTE',
      'estado': 'ACTIVO',
      'cod_persona': idPers1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // ignore: avoid_print
    print('✅ SEED DEMO COMPLETO CREADO CON ÉXITO.');
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

  // 🔄 RESET BD (SOLO DEV)
  static Future<void> resetDevDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    await deleteDatabase(path);
    _db = null;
    await instance.database;
  }
}
