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

  // ———————————————————————————————————————————
  // Asegura el usuario DEMO (idempotente / sin errores)
  // ———————————————————————————————————————————
  Future<void> _ensureDemoUser(Database db) async {
    // UNIQUE(correo) → usa INSERT OR IGNORE para evitar errores
    await db.insert(
      'usuario',
      {
        'nombre_usu'    : 'ADMIN DEMO',
        'contrasena_usu': demoPass,         // plano para pruebas locales
        'correo'        : demoEmail,
        'nivel_acceso'  : 'ADMIN',
        'estado'        : 'ACTIVO',
        'cod_empleado'  : null,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<bool> login(String email, String password) async {
    loading = true; error = null; notifyListeners();
    try {
      final db = await _dbHelper.database;

      // 1) Garantiza usuario DEMO
      await _ensureDemoUser(db);

      // 2) Si coincide con DEMO → acceso inmediato
      if (email.trim() == demoEmail && password == demoPass) {
        return true;
      }

      // 3) Consulta robusta (evita precedence raro)
      final rows = await db.query(
        'usuario',
        columns: ['cod_usuario', 'nombre_usu', 'correo', 'nivel_acceso', 'estado'],
        where: 'correo = ? AND contrasena_usu = ? AND (estado IS NULL OR estado <> ?)',
        whereArgs: [email.trim(), password, 'INACTIVO'],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        return true;
      } else {
        error = 'CREDENCIALES INVÁLIDAS';
        return false;
      }
    } catch (e) {
      // Mensaje claro y en mayúsculas
      error = 'ERROR DE LOGIN: $e';
      return false;
    } finally {
      loading = false; notifyListeners();
    }
  }

  // SOS opcional (no toca FKs para evitar ruidos en pruebas)
  Future<void> enviarSOS() async {
    try {
      final db = await _dbHelper.database;
      // Escribe un log simple en una tabla segura (si quieres crearla)
      // Por ahora no escribimos nada para no introducir efectos colaterales.
      // await db.insert('logs', {'tipo':'SOS','fecha':DateTime.now().toIso8601String()});
    } catch (_) {
      // Silencioso
    }
  }
}
