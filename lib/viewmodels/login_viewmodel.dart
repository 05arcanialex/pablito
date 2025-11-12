// lib/viewmodels/login_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/database_helper.dart';

class LoginViewModel extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool loading = false;
  String? error;

  // DEMO
  static const String demoEmail = "admin@electronicalapaz.com";
  static const String demoPass  = "12345";

  // ─────────────────────────────────────────────────────────────
  // ASEGURA USUARIO DEMO: CREA PERSONA (SI NO EXISTE) Y LUEGO USUARIO
  // ─────────────────────────────────────────────────────────────
  Future<void> _ensureDemoUser(Database db) async {
    // 1) BUSCAR/CREAR PERSONA DEMO
    int codPersona;
    final p = await db.query(
      'persona',
      columns: ['cod_persona'],
      where: 'LOWER(email)=LOWER(?)',
      whereArgs: [demoEmail],
      limit: 1,
    );
    if (p.isEmpty) {
      codPersona = await db.insert('persona', {
        'nombre'   : 'ADMIN',
        'apellidos': 'DEMO',
        'telefono' : '00000000',
        'email'    : demoEmail,
      });
    } else {
      codPersona = p.first['cod_persona'] as int;
    }

    // 2) INSERTAR USUARIO DEMO CON cod_persona (YA NO cod_empleado)
    await db.insert(
      'usuario',
      {
        'nombre_usu'    : 'ADMIN DEMO',
        'contrasena_usu': demoPass,     // SOLO PARA PRUEBAS LOCALES
        'correo'        : demoEmail,
        'nivel_acceso'  : 'ADMIN',
        'estado'        : 'ACTIVO',
        'cod_persona'   : codPersona,   // ← CLAVE CORRECTA
      },
      conflictAlgorithm: ConflictAlgorithm.ignore, // IGNORA SI YA EXISTE (UNIQUE correo)
    );
  }

  Future<bool> login(String email, String password) async {
    loading = true; error = null; notifyListeners();
    try {
      final db = await _dbHelper.database;

      // GARANTIZA USUARIO DEMO
      await _ensureDemoUser(db);

      // ACCESO DIRECTO A DEMO
      if (email.trim().toLowerCase() == demoEmail && password == demoPass) {
        return true;
      }

      // BÚSQUEDA CON ESTADO ≠ INACTIVO
      final rows = await db.rawQuery('''
        SELECT u.cod_usuario, u.nombre_usu, u.correo, u.nivel_acceso, u.estado
        FROM usuario u
        WHERE LOWER(u.correo)=LOWER(?)
          AND u.contrasena_usu=?
          AND (u.estado IS NULL OR UPPER(u.estado) <> 'INACTIVO')
        LIMIT 1
      ''', [email.trim(), password]);

      if (rows.isNotEmpty) {
        return true;
      } else {
        error = 'CREDENCIALES INVÁLIDAS';
        return false;
      }
    } catch (e) {
      error = 'ERROR DE LOGIN: $e';
      return false;
    } finally {
      loading = false; notifyListeners();
    }
  }

  Future<void> enviarSOS() async {
    try {
      final db = await _dbHelper.database;
      // OPCIONAL: GUARDAR LOG DE SOS
      // await db.insert('logs_sos', {'fecha': DateTime.now().toIso8601String()});
    } catch (_) {/* SILENCIOSO */}
  }
}
