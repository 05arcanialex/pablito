// lib/viewmodels/inicio_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/database_helper.dart';

class PersonaItem {
  final int id;
  final String nombreCompleto;

  PersonaItem({
    required this.id,
    required this.nombreCompleto,
  });
}

class UsuarioItem {
  final int id;
  final String nombreUsu;
  final String correo;
  final String nivelAcceso;
  final String? nombrePersona;
  final int? codPersona;

  UsuarioItem({
    required this.id,
    required this.nombreUsu,
    required this.correo,
    required this.nivelAcceso,
    this.nombrePersona,
    this.codPersona,
  });
}

class InicioViewModel extends ChangeNotifier {
  final _dbHelper = DatabaseHelper.instance;

  bool isLoading = false;
  String? errorMessage;

  List<PersonaItem> personas = [];
  List<UsuarioItem> usuarios = [];

  Future<void> init() async {
    await _loadPersonas();
    await _loadUsuarios();
  }

  Future<void> _setLoading(bool value) async {
    isLoading = value;
    notifyListeners();
  }

  Future<void> _loadPersonas() async {
    await _setLoading(true);
    try {
      final db = await _dbHelper.database;
      final res = await db.rawQuery('''
        SELECT cod_persona, nombre, apellidos
        FROM persona
        ORDER BY nombre, apellidos;
      ''');

      personas = res
          .map(
            (e) => PersonaItem(
              id: e['cod_persona'] as int,
              nombreCompleto:
                  '${e['nombre'] ?? ''} ${e['apellidos'] ?? ''}'.trim(),
            ),
          )
          .toList();
      errorMessage = null;
    } catch (e) {
      errorMessage = 'ERROR AL CARGAR PERSONAS: $e';
    }
    await _setLoading(false);
  }

  Future<void> _loadUsuarios() async {
    await _setLoading(true);
    try {
      final db = await _dbHelper.database;
      final res = await db.rawQuery('''
        SELECT 
          u.cod_usuario,
          u.nombre_usu,
          u.correo,
          u.nivel_acceso,
          u.cod_persona,
          p.nombre,
          p.apellidos
        FROM usuario u
        LEFT JOIN persona p ON p.cod_persona = u.cod_persona
        ORDER BY u.cod_usuario DESC;
      ''');

      usuarios = res
          .map(
            (e) => UsuarioItem(
              id: e['cod_usuario'] as int,
              nombreUsu: (e['nombre_usu'] ?? '') as String,
              correo: (e['correo'] ?? '') as String,
              nivelAcceso: (e['nivel_acceso'] ?? '') as String,
              codPersona: e['cod_persona'] as int?,
              nombrePersona:
                  '${e['nombre'] ?? ''} ${e['apellidos'] ?? ''}'.trim(),
            ),
          )
          .toList();
      errorMessage = null;
    } catch (e) {
      errorMessage = 'ERROR AL CARGAR USUARIOS: $e';
    }
    await _setLoading(false);
  }

  /// CREA UN NUEVO USUARIO
  Future<String?> crearUsuario({
    required String nombreUsu,
    required String correo,
    required String password,
    required String confirmarPassword,
    required String nivelAcceso,
    required int? codPersona,
  }) async {
    if (nombreUsu.trim().isEmpty) {
      return 'EL NOMBRE DE USUARIO ES OBLIGATORIO';
    }
    if (correo.trim().isEmpty) {
      return 'EL CORREO ES OBLIGATORIO';
    }
    if (password.isEmpty || confirmarPassword.isEmpty) {
      return 'LA CONTRASEÑA Y SU CONFIRMACIÓN SON OBLIGATORIAS';
    }
    if (password != confirmarPassword) {
      return 'LAS CONTRASEÑAS NO COINCIDEN';
    }
    if (codPersona == null) {
      return 'DEBES SELECCIONAR UNA PERSONA';
    }

    try {
      final db = await _dbHelper.database;

      await db.insert(
        'usuario',
        {
          'nombre_usu': nombreUsu.trim(),
          'contrasena_usu': password, // ⛔ SIN HASH
          'correo': correo.trim(),
          'nivel_acceso': nivelAcceso,
          'estado': 'ACTIVO',
          'cod_persona': codPersona,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await _loadUsuarios();
      return null;
    } catch (e) {
      errorMessage = 'ERROR AL CREAR USUARIO: $e';
      notifyListeners();
      return 'NO SE PUDO CREAR EL USUARIO (CORREO REPETIDO?)';
    }
  }

  /// ACTUALIZA UN USUARIO
  Future<String?> actualizarUsuario({
    required int codUsuario,
    required String nombreUsu,
    required String correo,
    required String nivelAcceso,
    required int? codPersona,
    String? newPassword,
  }) async {
    if (nombreUsu.trim().isEmpty) {
      return 'EL NOMBRE DE USUARIO ES OBLIGATORIO';
    }
    if (correo.trim().isEmpty) {
      return 'EL CORREO ES OBLIGATORIO';
    }
    if (codPersona == null) {
      return 'DEBES SELECCIONAR UNA PERSONA';
    }

    try {
      final db = await _dbHelper.database;

      final data = <String, Object?>{
        'nombre_usu': nombreUsu.trim(),
        'correo': correo.trim(),
        'nivel_acceso': nivelAcceso,
        'cod_persona': codPersona,
      };

      // ⛔ SI SE CAMBIA CONTRASEÑA, GUARDAR TAL CUAL
      if (newPassword != null && newPassword.isNotEmpty) {
        data['contrasena_usu'] = newPassword;
      }

      await db.update(
        'usuario',
        data,
        where: 'cod_usuario = ?',
        whereArgs: [codUsuario],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await _loadUsuarios();
      return null;
    } catch (e) {
      errorMessage = 'ERROR AL ACTUALIZAR USUARIO: $e';
      notifyListeners();
      return 'NO SE PUDO ACTUALIZAR EL USUARIO';
    }
  }

  Future<void> eliminarUsuario(int codUsuario) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        'usuario',
        where: 'cod_usuario = ?',
        whereArgs: [codUsuario],
      );
      await _loadUsuarios();
    } catch (e) {
      errorMessage = 'ERROR AL ELIMINAR USUARIO: $e';
      notifyListeners();
    }
  }
}
