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
      version: 8, // ⬅️ V8 CON COLUMNAS FALTANTES
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: (db, oldV, newV) async {
        // V1 -> V2: add foto_path a reg_inventario_vehiculo
        if (oldV < 2) {
          try {
            await db.execute(
                'ALTER TABLE reg_inventario_vehiculo ADD COLUMN foto_path TEXT');
          } catch (_) {}
        }
        // V2 -> V3: add foto_path a inventario_vehiculo
        if (oldV < 3) {
          try {
            await db.execute(
                'ALTER TABLE inventario_vehiculo ADD COLUMN foto_path TEXT');
          } catch (_) {}
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
        // V5 -> V6: agregar tabla seguimiento_servicio
        if (oldV < 6) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS seguimiento_servicio(
                cod_seguimiento INTEGER PRIMARY KEY AUTOINCREMENT,
                cod_ser_taller INTEGER NOT NULL,
                paso_actual INTEGER NOT NULL DEFAULT 1,
                diagnostico TEXT,
                foto_diagnostico TEXT,
                fallas_identificadas TEXT,
                foto_fallas TEXT,
                observaciones_fallas TEXT,
                foto_observaciones TEXT,
                solucion_aplicada TEXT,
                foto_reparacion TEXT,
                resultado_pruebas TEXT,
                foto_pruebas TEXT,
                fecha_ultima_actualizacion TEXT,
                estado TEXT DEFAULT 'EN_PROCESO',
                FOREIGN KEY(cod_ser_taller) REFERENCES registro_servicio_taller(cod_ser_taller)
                  ON UPDATE CASCADE ON DELETE CASCADE
              );
            ''');
          } catch (_) {}
        }
        // ✅ V6 -> V7: AGREGAR COLUMNA firebase_rescue_id A registro_auxilio_mecanico
        if (oldV < 7) {
          try {
            await db.execute(
              'ALTER TABLE registro_auxilio_mecanico ADD COLUMN firebase_rescue_id TEXT'
            );
            print('✅ Columna firebase_rescue_id agregada a registro_auxilio_mecanico');
          } catch (e) {
            print('⚠️ Error agregando firebase_rescue_id: $e');
            // Si falla, recrear la tabla completa
            await _recreateRegistroAuxilioMecanicoV7(db);
          }
        }
        // ✅ V7 -> V8: AGREGAR COLUMNAS cod_empleado Y estado_auxilio
        if (oldV < 8) {
          try {
            await db.execute(
              'ALTER TABLE registro_auxilio_mecanico ADD COLUMN cod_empleado INTEGER'
            );
            await db.execute(
              'ALTER TABLE registro_auxilio_mecanico ADD COLUMN estado_auxilio TEXT DEFAULT "PENDIENTE"'
            );
            print('✅ Columnas cod_empleado y estado_auxilio agregadas a registro_auxilio_mecanico');
          } catch (e) {
            print('⚠️ Error agregando columnas faltantes: $e');
            // Si falla, recrear la tabla completa con todas las columnas
            await _recreateRegistroAuxilioMecanicoV8(db);
          }
        }
      },
      onOpen: (db) async {
        await _ensureTables(db); // BLINDA TABLAS
        await _ensureViews(db); // BLINDA VISTAS
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

  // ✅ MÉTODO PARA RECREAR TABLA EN V7
  Future<void> _recreateRegistroAuxilioMecanicoV7(Database db) async {
    print('🔄 Recreando tabla registro_auxilio_mecanico V7...');
    
    // 1. Crear tabla temporal con la nueva estructura
    await db.execute('''
      CREATE TABLE IF NOT EXISTS registro_auxilio_mecanico_temp(
        cod_reg_auxilio   INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_rescue_id TEXT,
        fecha             TEXT NOT NULL,
        ubicacion_cliente TEXT,
        cod_cliente       INTEGER NOT NULL,
        FOREIGN KEY(cod_cliente) REFERENCES cliente(cod_cliente)
          ON UPDATE CASCADE ON DELETE CASCADE
      );
    ''');

    // 2. Copiar datos existentes si los hay
    try {
      await db.execute('''
        INSERT INTO registro_auxilio_mecanico_temp 
        (cod_reg_auxilio, fecha, ubicacion_cliente, cod_cliente, firebase_rescue_id)
        SELECT cod_reg_auxilio, fecha, ubicacion_cliente, cod_cliente, NULL
        FROM registro_auxilio_mecanico
      ''');
    } catch (e) {
      print('ℹ️ No hay datos existentes para migrar: $e');
    }

    // 3. Eliminar tabla vieja
    await db.execute('DROP TABLE IF EXISTS registro_auxilio_mecanico');

    // 4. Renombrar tabla temporal
    await db.execute('ALTER TABLE registro_auxilio_mecanico_temp RENAME TO registro_auxilio_mecanico');
    
    print('✅ Tabla registro_auxilio_mecanico recreada con firebase_rescue_id');
  }

  // ✅ MÉTODO PARA RECREAR TABLA EN V8 CON TODAS LAS COLUMNAS
  Future<void> _recreateRegistroAuxilioMecanicoV8(Database db) async {
    print('🔄 Recreando tabla registro_auxilio_mecanico V8 con todas las columnas...');
    
    // 1. Crear tabla temporal con la estructura completa
    await db.execute('''
      CREATE TABLE IF NOT EXISTS registro_auxilio_mecanico_temp(
        cod_reg_auxilio   INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_rescue_id TEXT,
        fecha             TEXT NOT NULL,
        ubicacion_cliente TEXT,
        cod_cliente       INTEGER NOT NULL,
        cod_empleado      INTEGER,
        estado_auxilio    TEXT DEFAULT 'PENDIENTE',
        fecha_actualizacion TEXT,
        FOREIGN KEY(cod_cliente) REFERENCES cliente(cod_cliente)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY(cod_empleado) REFERENCES empleado(cod_empleado)
          ON UPDATE CASCADE ON DELETE SET NULL
      );
    ''');

    // 2. Copiar datos existentes si los hay
    try {
      await db.execute('''
        INSERT INTO registro_auxilio_mecanico_temp 
        (cod_reg_auxilio, firebase_rescue_id, fecha, ubicacion_cliente, cod_cliente, cod_empleado, estado_auxilio)
        SELECT 
          cod_reg_auxilio, 
          firebase_rescue_id, 
          fecha, 
          ubicacion_cliente, 
          cod_cliente,
          NULL as cod_empleado,
          'PENDIENTE' as estado_auxilio
        FROM registro_auxilio_mecanico
      ''');
    } catch (e) {
      print('ℹ️ No hay datos existentes para migrar: $e');
    }

    // 3. Eliminar tabla vieja
    await db.execute('DROP TABLE IF EXISTS registro_auxilio_mecanico');

    // 4. Renombrar tabla temporal
    await db.execute('ALTER TABLE registro_auxilio_mecanico_temp RENAME TO registro_auxilio_mecanico');
    
    print('✅ Tabla registro_auxilio_mecanico recreada con todas las columnas (V8)');
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
    // Limpieza previa
    await db.execute('DROP VIEW IF EXISTS vw_historial_all');
    await db.execute('DROP VIEW IF EXISTS vw_historial_pagos');
    await db.execute('DROP VIEW IF EXISTS vw_historial_auxilio');
    await db.execute('DROP VIEW IF EXISTS vw_historial_servicios');
    await db.execute('DROP VIEW IF EXISTS vw_historial_objetos');
    await db.execute('DROP VIEW IF EXISTS vw_historial_clientes');
    await db.execute('DROP VIEW IF EXISTS vw_servicios'); // tu vista antigua

    // ---------- SERVICIOS (TALLER) ----------
    await db.execute('''
      CREATE VIEW IF NOT EXISTS vw_historial_servicios AS
      SELECT
        'SERVICIOS'                            AS modulo,
        'TALLER'                               AS tipo,
        ('Serv. Taller #' || rst.cod_ser_taller || ' • ' || v.placas) AS titulo,
        ('Cliente: ' || (p.nombre || ' ' || p.apellidos) ||
          COALESCE(' • Trabajos: ' || (
            SELECT GROUP_CONCAT(tt.descripcion, ', ')
            FROM reg_serv_taller_tipo_trabajo rtt
            JOIN tipo_trabajo tt ON tt.cod_tipo_trabajo = rtt.cod_tipo_trabajo
            WHERE rtt.cod_ser_taller = rst.cod_ser_taller
          ), '')
        )                                     AS subtitulo,
        (SELECT COALESCE(SUM(rtt.costo), 0)
         FROM reg_serv_taller_tipo_trabajo rtt
         WHERE rtt.cod_ser_taller = rst.cod_ser_taller) AS monto,
        COALESCE(rst.fecha_salida, rst.fecha_ingreso)    AS fecha_iso,
        c.cod_cliente                                    AS cod_cliente,
        'registro_servicio_taller'                       AS ref_table,
        rst.cod_ser_taller                               AS ref_id
      FROM registro_servicio_taller rst
      JOIN vehiculo v ON v.cod_vehiculo = rst.cod_vehiculo
      JOIN cliente  c ON c.cod_cliente  = v.cod_cliente
      JOIN persona  p ON p.cod_persona  = c.cod_persona;
    ''');

    // ---------- PAGOS (RECIBOS) ----------
    await db.execute('''
      CREATE VIEW IF NOT EXISTS vw_historial_pagos AS
      SELECT
        'PAGOS'                                   AS modulo,
        'RECIBO'                                  AS tipo,
        ('Recibo #' || rp.cod_recibo_pago)        AS titulo,
        ('Cliente: ' || (p.nombre || ' ' || p.apellidos) ||
         ' • Estado: ' || er.estado_recibo)       AS subtitulo,
        rp.total                                   AS monto,
        rp.fecha                                   AS fecha_iso,
        rp.cod_cliente                             AS cod_cliente,
        'recibo_pago'                              AS ref_table,
        rp.cod_recibo_pago                         AS ref_id
      FROM recibo_pago rp
      JOIN cliente c   ON c.cod_cliente   = rp.cod_cliente
      JOIN persona p   ON p.cod_persona   = c.cod_persona
      JOIN estado_recibo er ON er.cod_est_rec = rp.cod_est_rec;
    ''');

    // ---------- AUXILIO MECÁNICO (ACTUALIZADA CON NUEVAS COLUMNAS) ----------
    await db.execute('''
      CREATE VIEW IF NOT EXISTS vw_historial_auxilio AS
      SELECT
        'AUXILIO'                                   AS modulo,
        'SOLICITUD'                                 AS tipo,
        ('Auxilio #' || ram.cod_reg_auxilio || 
         COALESCE(' (' || ram.firebase_rescue_id || ')', '')) AS titulo,
        ('Cliente: ' || (p.nombre || ' ' || p.apellidos) ||
         COALESCE(' • Ubicación: ' || ram.ubicacion_cliente, '') ||
         COALESCE(' • Estado: ' || ram.estado_auxilio, '') ||
         COALESCE(' • Mecánico: ' || (SELECT (pe.nombre || ' ' || pe.apellidos) 
                                     FROM empleado e 
                                     JOIN persona pe ON pe.cod_persona = e.cod_persona 
                                     WHERE e.cod_empleado = ram.cod_empleado), '')
        ) AS subtitulo,
        NULL                                        AS monto,
        ram.fecha                                   AS fecha_iso,
        ram.cod_cliente                             AS cod_cliente,
        'registro_auxilio_mecanico'                 AS ref_table,
        ram.cod_reg_auxilio                         AS ref_id,
        ram.firebase_rescue_id                      AS firebase_id,
        ram.estado_auxilio                          AS estado_auxilio,
        ram.cod_empleado                            AS cod_empleado
      FROM registro_auxilio_mecanico ram
      JOIN cliente c ON c.cod_cliente = ram.cod_cliente
      JOIN persona p ON p.cod_persona = c.cod_persona;
    ''');

    // ---------- OBJETOS / INVENTARIO ----------
    await db.execute('''
      CREATE VIEW IF NOT EXISTS vw_historial_objetos AS
      SELECT
        'OBJETOS'                                     AS modulo,
        'INVENTARIO'                                  AS tipo,
        ('Inventario: ' || iv.descripcion_inv || ' x' || COALESCE(riv.cantidad, 0)) AS titulo,
        ('Vehículo: ' || v.placas ||
          COALESCE(' • Estado: ' || riv.estado, '')
        )                                            AS subtitulo,
        NULL                                         AS monto,
        CURRENT_TIMESTAMP                            AS fecha_iso,
        c.cod_cliente                                AS cod_cliente,
        'reg_inventario_vehiculo'                    AS ref_table,
        riv.cod_reg_inv_veh                          AS ref_id
      FROM reg_inventario_vehiculo riv
      JOIN inventario_vehiculo iv ON iv.cod_inv_veh = riv.cod_inv_veh
      JOIN vehiculo v             ON v.cod_vehiculo = riv.cod_vehiculo
      JOIN cliente  c             ON c.cod_cliente  = v.cod_cliente;
    ''');

    // ---------- CLIENTES ----------
    await db.execute('''
      CREATE VIEW IF NOT EXISTS vw_historial_clientes AS
      SELECT
        'CLIENTES'                                   AS modulo,
        'REGISTRO'                                   AS tipo,
        ('Cliente: ' || (p.nombre || ' ' || p.apellidos)) AS titulo,
        ('Contacto: ' || COALESCE(p.telefono, '-') || ' • ' || COALESCE(p.email, '-')) AS subtitulo,
        NULL                                         AS monto,
        CURRENT_TIMESTAMP                            AS fecha_iso,
        c.cod_cliente                                AS cod_cliente,
        'cliente'                                    AS ref_table,
        c.cod_cliente                                AS ref_id
      FROM cliente c
      JOIN persona p ON p.cod_persona = c.cod_persona;
    ''');

    // ---------- VISTA UNIFICADA (ACTUALIZADA) ----------
    await db.execute('''
      CREATE VIEW IF NOT EXISTS vw_historial_all AS
      SELECT modulo, tipo, titulo, subtitulo, monto, fecha_iso, cod_cliente, ref_table, ref_id, NULL as firebase_id, NULL as estado_auxilio, NULL as cod_empleado
      FROM vw_historial_pagos
      UNION ALL
      SELECT modulo, tipo, titulo, subtitulo, monto, fecha_iso, cod_cliente, ref_table, ref_id, firebase_id, estado_auxilio, cod_empleado
      FROM vw_historial_auxilio
      UNION ALL
      SELECT modulo, tipo, titulo, subtitulo, monto, fecha_iso, cod_cliente, ref_table, ref_id, NULL as firebase_id, NULL as estado_auxilio, NULL as cod_empleado
      FROM vw_historial_servicios
      UNION ALL
      SELECT modulo, tipo, titulo, subtitulo, monto, fecha_iso, cod_cliente, ref_table, ref_id, NULL as firebase_id, NULL as estado_auxilio, NULL as cod_empleado
      FROM vw_historial_objetos
      UNION ALL
      SELECT modulo, tipo, titulo, subtitulo, monto, fecha_iso, cod_cliente, ref_table, ref_id, NULL as firebase_id, NULL as estado_auxilio, NULL as cod_empleado
      FROM vw_historial_clientes;
    ''');

    // Vista vw_servicios clásica
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

    // ✅ TABLA ACTUALIZADA CON TODAS LAS COLUMNAS NECESARIAS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS registro_auxilio_mecanico(
        cod_reg_auxilio   INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_rescue_id TEXT,
        fecha             TEXT NOT NULL,
        ubicacion_cliente TEXT,
        cod_cliente       INTEGER NOT NULL,
        cod_empleado      INTEGER,
        estado_auxilio    TEXT DEFAULT 'PENDIENTE',
        fecha_actualizacion TEXT,
        FOREIGN KEY(cod_cliente) REFERENCES cliente(cod_cliente)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY(cod_empleado) REFERENCES empleado(cod_empleado)
          ON UPDATE CASCADE ON DELETE SET NULL
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

    // ⬇️ TABLA SEGUIMIENTO SERVICIO (NUEVA)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS seguimiento_servicio(
        cod_seguimiento INTEGER PRIMARY KEY AUTOINCREMENT,
        cod_ser_taller INTEGER NOT NULL,
        paso_actual INTEGER NOT NULL DEFAULT 1,
        diagnostico TEXT,
        foto_diagnostico TEXT,
        fallas_identificadas TEXT,
        foto_fallas TEXT,
        observaciones_fallas TEXT,
        foto_observaciones TEXT,
        solucion_aplicada TEXT,
        foto_reparacion TEXT,
        resultado_pruebas TEXT,
        foto_pruebas TEXT,
        fecha_ultima_actualizacion TEXT,
        estado TEXT DEFAULT 'EN_PROCESO',
        FOREIGN KEY(cod_ser_taller) REFERENCES registro_servicio_taller(cod_ser_taller)
          ON UPDATE CASCADE ON DELETE CASCADE
      );
    ''');
  }

  // =============== MIGRACIÓN V4: usuario -> cod_persona ===============
  Future<void> _migrateUsuarioToCodPersona(Database db) async {
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

    await db.execute('''
      INSERT OR IGNORE INTO usuario_tmp
      (cod_usuario, nombre_usu, contrasena_usu, correo, nivel_acceso, estado, cod_persona)
      SELECT u.cod_usuario, u.nombre_usu, u.contrasena_usu, u.correo, u.nivel_acceso, u.estado,
             e.cod_persona
      FROM usuario u
      LEFT JOIN empleado e ON e.cod_empleado = u.cod_empleado
    ''');

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
    final r2 =
        await db.rawQuery('SELECT COUNT(*) AS c FROM registro_servicio_taller');
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

  // 🔹 SEED DEMO COMPLETO (ACTUALIZADO CON NUEVAS COLUMNAS)
  Future<void> seedDemo() async {
    final db = await database;
    // ignore: avoid_print
    print('🚀 INICIANDO SEED DEMO COMPLETO...');

    // 1) CARGOS
    final idCargoMec = await db.insert(
      'cargo_empleado',
      {'descripcion': 'MECÁNICO'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idCargoAdm = await db.insert(
      'cargo_empleado',
      {'descripcion': 'ADMINISTRADOR'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idCargoTec = await db.insert(
      'cargo_empleado',
      {'descripcion': 'TÉCNICO DIAGNOSTICADOR'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // 2) PERSONAS (EMPLEADOS + CLIENTES)
    final idPers1 = await db.insert(
      'persona',
      {
        'nombre': 'Juan',
        'apellidos': 'Pérez López',
        'telefono': '77788899',
        'email': 'juan@example.com',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idPers2 = await db.insert(
      'persona',
      {
        'nombre': 'Ramiro',
        'apellidos': 'Arcani Condori',
        'telefono': '76543210',
        'email': 'ramiro@example.com',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idPers3 = await db.insert(
      'persona',
      {
        'nombre': 'Alex',
        'apellidos': 'Arcani Gutiérrez',
        'telefono': '60123456',
        'email': 'alex@example.com',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idPers4 = await db.insert(
      'persona',
      {
        'nombre': 'Carla',
        'apellidos': 'Mendoza Vargas',
        'telefono': '70654321',
        'email': 'carla@example.com',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idPers5 = await db.insert(
      'persona',
      {
        'nombre': 'Luis',
        'apellidos': 'Torrez Nina',
        'telefono': '78945612',
        'email': 'luis@example.com',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idPers6 = await db.insert(
      'persona',
      {
        'nombre': 'María',
        'apellidos': 'Gómez Rojas',
        'telefono': '70111222',
        'email': 'maria@example.com',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idPers7 = await db.insert(
      'persona',
      {
        'nombre': 'José',
        'apellidos': 'Quispe Flores',
        'telefono': '70333444',
        'email': 'jose@example.com',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idPers8 = await db.insert(
      'persona',
      {
        'nombre': 'Patricia',
        'apellidos': 'Vargas Soto',
        'telefono': '70555666',
        'email': 'patricia@example.com',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idPers9 = await db.insert(
      'persona',
      {
        'nombre': 'Miguel',
        'apellidos': 'López Aguilar',
        'telefono': '70777888',
        'email': 'miguel@example.com',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // 3) CLIENTES
    final idCliente1 = await db.insert(
      'cliente',
      {'cod_persona': idPers1},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idCliente2 = await db.insert(
      'cliente',
      {'cod_persona': idPers4},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idCliente3 = await db.insert(
      'cliente',
      {'cod_persona': idPers5},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idCliente4 = await db.insert(
      'cliente',
      {'cod_persona': idPers6},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idCliente5 = await db.insert(
      'cliente',
      {'cod_persona': idPers7},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idCliente6 = await db.insert(
      'cliente',
      {'cod_persona': idPers8},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idCliente7 = await db.insert(
      'cliente',
      {'cod_persona': idPers9},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // 4) EMPLEADOS
    final idEmpMec = await db.insert(
      'empleado',
      {
        'cod_persona': idPers2,
        'cod_cargo_emp': idCargoMec,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idEmpAdm = await db.insert(
      'empleado',
      {
        'cod_persona': idPers3,
        'cod_cargo_emp': idCargoAdm,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idEmpTec = await db.insert(
      'empleado',
      {
        'cod_persona': idPers4,
        'cod_cargo_emp': idCargoTec,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // 5) MARCAS Y MODELOS
    final idToyota = await db.insert(
      'marca_vehiculo',
      {'descripcion': 'TOYOTA'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idNissan = await db.insert(
      'marca_vehiculo',
      {'descripcion': 'NISSAN'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idHyundai = await db.insert(
      'marca_vehiculo',
      {'descripcion': 'HYUNDAI'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idChevrolet = await db.insert(
      'marca_vehiculo',
      {'descripcion': 'CHEVROLET'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idKia = await db.insert(
      'marca_vehiculo',
      {'descripcion': 'KIA'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final idHilux = await db.insert(
      'modelo_vehiculo',
      {'anio_modelo': 2020, 'descripcion_modelo': 'HILUX'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idSentra = await db.insert(
      'modelo_vehiculo',
      {'anio_modelo': 2018, 'descripcion_modelo': 'SENTRA'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idTucson = await db.insert(
      'modelo_vehiculo',
      {'anio_modelo': 2021, 'descripcion_modelo': 'TUCSON'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idCorolla = await db.insert(
      'modelo_vehiculo',
      {'anio_modelo': 2019, 'descripcion_modelo': 'COROLLA'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idRio = await db.insert(
      'modelo_vehiculo',
      {'anio_modelo': 2017, 'descripcion_modelo': 'RIO'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idOnix = await db.insert(
      'modelo_vehiculo',
      {'anio_modelo': 2022, 'descripcion_modelo': 'ONIX'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idElantra = await db.insert(
      'modelo_vehiculo',
      {'anio_modelo': 2020, 'descripcion_modelo': 'ELANTRA'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // 6) VEHÍCULOS (2–3 POR CLIENTE)
    final vehIds = <int>[];

    // CLIENTE 1
    final idVeh1 = await db.insert(
      'vehiculo',
      {
        'cod_cliente': idCliente1,
        'cod_marca_veh': idToyota,
        'cod_modelo_veh': idHilux,
        'kilometraje': 125000,
        'placas': 'ABC-123',
        'numero_serie': 'XYZ987654',
        'color': 'GRIS',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    vehIds.add(idVeh1);

    final idVeh2 = await db.insert(
      'vehiculo',
      {
        'cod_cliente': idCliente1,
        'cod_marca_veh': idToyota,
        'cod_modelo_veh': idCorolla,
        'kilometraje': 90000,
        'placas': 'ABC-456',
        'numero_serie': 'XYZ111222',
        'color': 'BLANCO',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    vehIds.add(idVeh2);

    final idVeh3 = await db.insert(
      'vehiculo',
      {
        'cod_cliente': idCliente1,
        'cod_marca_veh': idNissan,
        'cod_modelo_veh': idSentra,
        'kilometraje': 70000,
        'placas': 'ABC-789',
        'numero_serie': 'XYZ333444',
        'color': 'NEGRO',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    vehIds.add(idVeh3);

    // CLIENTE 2
    final idVeh4 = await db.insert(
      'vehiculo',
      {
        'cod_cliente': idCliente2,
        'cod_marca_veh': idNissan,
        'cod_modelo_veh': idSentra,
        'kilometraje': 80000,
        'placas': 'XYZ-987',
        'numero_serie': 'AA112233',
        'color': 'NEGRO',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    vehIds.add(idVeh4);

    final idVeh5 = await db.insert(
      'vehiculo',
      {
        'cod_cliente': idCliente2,
        'cod_marca_veh': idHyundai,
        'cod_modelo_veh': idElantra,
        'kilometraje': 60000,
        'placas': 'XYZ-654',
        'numero_serie': 'AA445566',
        'color': 'PLATEADO',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    vehIds.add(idVeh5);

    // CLIENTE 3
    final idVeh6 = await db.insert(
      'vehiculo',
      {
        'cod_cliente': idCliente3,
        'cod_marca_veh': idHyundai,
        'cod_modelo_veh': idTucson,
        'kilometraje': 45000,
        'placas': 'MNO-456',
        'numero_serie': 'BB445566',
        'color': 'AZUL',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    vehIds.add(idVeh6);

    final idVeh7 = await db.insert(
      'vehiculo',
      {
        'cod_cliente': idCliente3,
        'cod_marca_veh': idKia,
        'cod_modelo_veh': idRio,
        'kilometraje': 30000,
        'placas': 'MNO-789',
        'numero_serie': 'BB778899',
        'color': 'ROJO',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    vehIds.add(idVeh7);

    // CLIENTE 4
    final idVeh8 = await db.insert(
      'vehiculo',
      {
        'cod_cliente': idCliente4,
        'cod_marca_veh': idChevrolet,
        'cod_modelo_veh': idOnix,
        'kilometraje': 20000,
        'placas': 'DEF-111',
        'numero_serie': 'CC111222',
        'color': 'BLANCO',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    vehIds.add(idVeh8);

    final idVeh9 = await db.insert(
      'vehiculo',
      {
        'cod_cliente': idCliente4,
        'cod_marca_veh': idToyota,
        'cod_modelo_veh': idCorolla,
        'kilometraje': 50000,
        'placas': 'DEF-222',
        'numero_serie': 'CC333444',
        'color': 'GRIS',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    vehIds.add(idVeh9);

    // CLIENTE 5
    final idVeh10 = await db.insert(
      'vehiculo',
      {
        'cod_cliente': idCliente5,
        'cod_marca_veh': idKia,
        'cod_modelo_veh': idRio,
        'kilometraje': 55000,
        'placas': 'GHI-333',
        'numero_serie': 'DD111222',
        'color': 'NEGRO',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    vehIds.add(idVeh10);

    final idVeh11 = await db.insert(
      'vehiculo',
      {
        'cod_cliente': idCliente5,
        'cod_marca_veh': idHyundai,
        'cod_modelo_veh': idTucson,
        'kilometraje': 40000,
        'placas': 'GHI-444',
        'numero_serie': 'DD333444',
        'color': 'AZUL OSCURO',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    vehIds.add(idVeh11);

    // CLIENTE 6
    final idVeh12 = await db.insert(
      'vehiculo',
      {
        'cod_cliente': idCliente6,
        'cod_marca_veh': idChevrolet,
        'cod_modelo_veh': idOnix,
        'kilometraje': 15000,
        'placas': 'JKL-555',
        'numero_serie': 'EE111222',
        'color': 'PLATEADO',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    vehIds.add(idVeh12);

    final idVeh13 = await db.insert(
      'vehiculo',
      {
        'cod_cliente': idCliente6,
        'cod_marca_veh': idToyota,
        'cod_modelo_veh': idHilux,
        'kilometraje': 90000,
        'placas': 'JKL-666',
        'numero_serie': 'EE333444',
        'color': 'BLANCO PERLA',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    vehIds.add(idVeh13);

    // CLIENTE 7
    final idVeh14 = await db.insert(
      'vehiculo',
      {
        'cod_cliente': idCliente7,
        'cod_marca_veh': idNissan,
        'cod_modelo_veh': idSentra,
        'kilometraje': 65000,
        'placas': 'PQR-777',
        'numero_serie': 'FF111222',
        'color': 'GRIS OSCURO',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    vehIds.add(idVeh14);

    final idVeh15 = await db.insert(
      'vehiculo',
      {
        'cod_cliente': idCliente7,
        'cod_marca_veh': idHyundai,
        'cod_modelo_veh': idElantra,
        'kilometraje': 35000,
        'placas': 'PQR-888',
        'numero_serie': 'FF333444',
        'color': 'ROJO VINO',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    vehIds.add(idVeh15);

    // 7) TIPOS DE TRABAJO (SOLO 4 CATEGORÍAS)
    final idDiag = await db.insert(
      'tipo_trabajo',
      {'descripcion': 'DIAGNÓSTICO'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idMant = await db.insert(
      'tipo_trabajo',
      {'descripcion': 'MANTENIMIENTO'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idRepGen = await db.insert(
      'tipo_trabajo',
      {'descripcion': 'REPARACIONES EN GENERAL'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final idProgMod = await db.insert(
      'tipo_trabajo',
      {'descripcion': 'PROGRAMACIÓN DE MÓDULOS'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // 8) SERVICIOS + RECIBOS (USANDO LAS 4 CATEGORÍAS)
    Future<void> crearServicio(
      int codCliente,
      int codVeh,
      int codEmpleado,
      List<Map<String, dynamic>> trabajos,
      double total,
    ) async {
      final idRecibo = await db.insert(
        'recibo_pago',
        {
          'fecha': DateTime.now().toIso8601String(),
          'total': total,
          'a_cuenta': total * 0.5,
          'saldo': total * 0.5,
          'transferencia_pago': 'EFECTIVO',
          'cod_cliente': codCliente,
          'cod_empleado': codEmpleado,
          'cod_est_rec': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      final idServ = await db.insert(
        'registro_servicio_taller',
        {
          'cod_recibo_pago': idRecibo,
          'cod_vehiculo': codVeh,
          'cod_empleado': codEmpleado,
          'fecha_ingreso':
              DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'fecha_salida': DateTime.now().toIso8601String(),
          'ingreso_en_grua': 0,
          'observaciones':
              'Servicio general con diagnóstico y mantenimiento preventivo.',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      for (var t in trabajos) {
        await db.insert(
          'reg_serv_taller_tipo_trabajo',
          {
            'cod_ser_taller': idServ,
            'cod_tipo_trabajo': t['id'],
            'costo': t['costo'],
            'detalles': t['detalle'],
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // 👉 CREAR SEGUIMIENTO DEMO PARA EL PRIMER SERVICIO
      if (idServ == 1) {
        await db.insert(
          'seguimiento_servicio',
          {
            'cod_ser_taller': idServ,
            'paso_actual': 3,
            'diagnostico': 'Diagnóstico demo: Sistema eléctrico con fallas en alternador y batería',
            'fallas_identificadas': 'Alternador no carga correctamente, batería descargada',
            'observaciones_fallas': 'El alternador presenta desgaste en escobillas, la batería tiene 3 años de uso',
            'fecha_ultima_actualizacion': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }

    await crearServicio(idCliente1, idVeh1, idEmpMec, [
      {
        'id': idDiag,
        'costo': 80.0,
        'detalle': 'DIAGNÓSTICO COMPLETO DEL SISTEMA ELÉCTRICO',
      },
      {
        'id': idMant,
        'costo': 50.0,
        'detalle': 'MANTENIMIENTO PREVENTIVO (CAMBIO ACEITE, FILTROS)',
      },
    ], 130.0);

    await crearServicio(idCliente2, idVeh4, idEmpTec, [
      {
        'id': idRepGen,
        'costo': 250.0,
        'detalle': 'REPARACIONES EN GENERAL DEL SISTEMA DE COMBUSTIBLE',
      },
      {
        'id': idMant,
        'costo': 80.0,
        'detalle': 'MANTENIMIENTO BÁSICO POST-REPARACIÓN',
      },
    ], 330.0);

    await crearServicio(idCliente3, idVeh6, idEmpMec, [
      {
        'id': idProgMod,
        'costo': 200.0,
        'detalle': 'PROGRAMACIÓN DE MÓDULOS Y REPROGRAMACIÓN DE ECU',
      },
      {
        'id': idMant,
        'costo': 150.0,
        'detalle': 'MANTENIMIENTO DE FRENOS Y SISTEMA DE REFRIGERACIÓN',
      },
    ], 350.0);

    // 9) AUXILIOS MECÁNICOS (ACTUALIZADOS CON TODAS LAS COLUMNAS)
    await db.insert(
      'registro_auxilio_mecanico',
      {
        'firebase_rescue_id': 'demo_rescue_001',
        'fecha': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'ubicacion_cliente': 'Av. 6 de Marzo, El Alto',
        'cod_cliente': idCliente1,
        'cod_empleado': idEmpMec, // ✅ NUEVA COLUMNA
        'estado_auxilio': 'ACEPTADO', // ✅ NUEVA COLUMNA
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert(
      'registro_auxilio_mecanico',
      {
        'firebase_rescue_id': 'demo_rescue_002',
        'fecha': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'ubicacion_cliente': 'Plaza del Estudiante, La Paz',
        'cod_cliente': idCliente2,
        'cod_empleado': idEmpTec, // ✅ NUEVA COLUMNA
        'estado_auxilio': 'EN_CAMINO', // ✅ NUEVA COLUMNA
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // 10) USUARIOS
    await db.insert(
      'usuario',
      {
        'nombre_usu': 'admin',
        'contrasena_usu': '12345',
        'correo': 'admin@electronica.com',
        'nivel_acceso': 'ADMIN',
        'estado': 'ACTIVO',
        'cod_persona': idPers3,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert(
      'usuario',
      {
        'nombre_usu': 'mecanico',
        'contrasena_usu': '12345',
        'correo': 'mecanico@electronica.com',
        'nivel_acceso': 'MECANICO',
        'estado': 'ACTIVO',
        'cod_persona': idPers2,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert(
      'usuario',
      {
        'nombre_usu': 'cliente',
        'contrasena_usu': '12345',
        'correo': 'cliente@electronica.com',
        'nivel_acceso': 'CLIENTE',
        'estado': 'ACTIVO',
        'cod_persona': idPers1,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // ignore: avoid_print
    print('✅ SEED DEMO COMPLETO CREADO CON ÉXITO.');
  }

  // CRUD DE BAJO NIVEL
  Future<List<Map<String, Object?>>> rawQuery(String sql,
      [List<Object?>? args]) async {
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