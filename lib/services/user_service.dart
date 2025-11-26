// services/user_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/database_helper.dart';

class UserService {
  final DatabaseHelper _databaseHelper;

  UserService(this._databaseHelper);

  // Obtener usuario actual desde SQLite
  Future<LocalUser> getCurrentUser() async {
    final db = await _databaseHelper.database;
    
    // Obtener el usuario logeado desde SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('current_user_id') ?? 1; // Default para demo
    
    final userData = await db.query(
      'usuario',
      where: 'cod_usuario = ?',
      whereArgs: [userId],
    );

    if (userData.isEmpty) {
      throw Exception('Usuario no encontrado');
    }

    final user = userData.first;
    
    // Obtener datos de la persona
    final personData = await db.query(
      'persona',
      where: 'cod_persona = ?',
      whereArgs: [user['cod_persona']],
    );

    if (personData.isEmpty) {
      throw Exception('Datos de persona no encontrados para el usuario');
    }

    final person = personData.first;

    return LocalUser(
      id: user['cod_usuario'].toString(),
      name: '${person['nombre']} ${person['apellidos']}',
      phone: person['telefono']?.toString() ?? '',
      email: user['correo']?.toString() ?? '',
      nivelAcceso: user['nivel_acceso']?.toString() ?? 'CLIENTE',
      codPersona: user['cod_persona'] as int,
      codUsuario: user['cod_usuario'] as int,
    );
  }

  // Guardar ID de usuario en SharedPreferences al hacer login
  Future<void> setCurrentUser(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_user_id', userId);
  }

  // Cerrar sesión
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
  }

  // Verificar si hay un usuario logeado
  Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('current_user_id');
  }

  // Verificar si el usuario es mecánico
  Future<bool> isMechanic() async {
    try {
      final user = await getCurrentUser();
      final db = await _databaseHelper.database;
      
      final empleadoData = await db.query(
        'empleado',
        where: 'cod_persona = ?',
        whereArgs: [user.codPersona],
      );

      if (empleadoData.isNotEmpty) {
        final cargoId = empleadoData.first['cod_cargo_emp'] as int;
        final cargoData = await db.query(
          'cargo_empleado',
          where: 'cod_cargo_emp = ?',
          whereArgs: [cargoId],
        );
        
        if (cargoData.isNotEmpty) {
          final cargoDesc = cargoData.first['descripcion'] as String;
          return cargoDesc.contains('MECÁNICO') || 
                 cargoDesc.contains('TÉCNICO') ||
                 cargoDesc.contains('MECANICO');
        }
      }
      
      return false;
    } catch (e) {
      print('Error verificando si es mecánico: $e');
      return false;
    }
  }

  // Verificar si el usuario es administrador
  Future<bool> isAdmin() async {
    try {
      final user = await getCurrentUser();
      return user.nivelAcceso.toUpperCase().contains('ADMIN');
    } catch (e) {
      print('Error verificando si es admin: $e');
      return false;
    }
  }

  // Verificar si el usuario es cliente
  Future<bool> isClient() async {
    try {
      final user = await getCurrentUser();
      return user.nivelAcceso.toUpperCase().contains('CLIENTE');
    } catch (e) {
      print('Error verificando si es cliente: $e');
      return false;
    }
  }

  // Obtener vehículos del cliente actual (basado en el usuario logeado)
  Future<List<Vehicle>> getUserVehicles() async {
    try {
      final user = await getCurrentUser();
      final db = await _databaseHelper.database;
      
      final vehicles = await db.rawQuery('''
        SELECT 
          v.cod_vehiculo,
          v.placas,
          v.kilometraje,
          v.color,
          v.numero_serie,
          mv.descripcion as marca,
          modv.descripcion_modelo as modelo,
          modv.anio_modelo as anio
        FROM vehiculo v
        JOIN cliente c ON c.cod_cliente = v.cod_cliente
        JOIN persona p ON p.cod_persona = c.cod_persona
        JOIN marca_vehiculo mv ON mv.cod_marca_veh = v.cod_marca_veh
        JOIN modelo_vehiculo modv ON modv.cod_modelo_veh = v.cod_modelo_veh
        WHERE p.cod_persona = ?
        ORDER BY v.placas
      ''', [user.codPersona]);

      return vehicles.map((v) => Vehicle.fromMap(v)).toList();
    } catch (e) {
      print('Error obteniendo vehículos del usuario: $e');
      return [];
    }
  }

  // NUEVO MÉTODO: Obtener vehículos de un cliente específico (por cod_cliente)
  Future<List<Vehicle>> getClientVehicles(int codCliente) async {
    try {
      final db = await _databaseHelper.database;
      
      final vehicles = await db.rawQuery('''
        SELECT 
          v.cod_vehiculo,
          v.placas,
          v.kilometraje,
          v.color,
          v.numero_serie,
          mv.descripcion as marca,
          modv.descripcion_modelo as modelo,
          modv.anio_modelo as anio
        FROM vehiculo v
        JOIN cliente c ON c.cod_cliente = v.cod_cliente
        JOIN marca_vehiculo mv ON mv.cod_marca_veh = v.cod_marca_veh
        JOIN modelo_vehiculo modv ON modv.cod_modelo_veh = v.cod_modelo_veh
        WHERE c.cod_cliente = ?
        ORDER BY v.placas
      ''', [codCliente]);

      print('🚗 Vehículos encontrados para cliente $codCliente: ${vehicles.length}');
      
      return vehicles.map((v) => Vehicle.fromMap(v)).toList();
    } catch (e) {
      print('Error obteniendo vehículos del cliente $codCliente: $e');
      return [];
    }
  }

  // Obtener información específica de un vehículo
  Future<Vehicle> getVehicleById(int vehicleId) async {
    final db = await _databaseHelper.database;
    
    final vehicleData = await db.rawQuery('''
      SELECT 
        v.cod_vehiculo,
        v.placas,
        v.kilometraje,
        v.color,
        v.numero_serie,
        mv.descripcion as marca,
        modv.descripcion_modelo as modelo,
        modv.anio_modelo as anio
      FROM vehiculo v
      JOIN marca_vehiculo mv ON mv.cod_marca_veh = v.cod_marca_veh
      JOIN modelo_vehiculo modv ON modv.cod_modelo_veh = v.cod_modelo_veh
      WHERE v.cod_vehiculo = ?
    ''', [vehicleId]);

    if (vehicleData.isEmpty) {
      throw Exception('Vehículo no encontrado');
    }

    return Vehicle.fromMap(vehicleData.first);
  }

  // Obtener el código de cliente del usuario actual
  Future<int> getUserClientId() async {
    final user = await getCurrentUser();
    final db = await _databaseHelper.database;
    
    final clienteData = await db.query(
      'cliente',
      where: 'cod_persona = ?',
      whereArgs: [user.codPersona],
    );

    if (clienteData.isEmpty) {
      throw Exception('Cliente no encontrado para el usuario actual');
    }

    return clienteData.first['cod_cliente'] as int;
  }

  // Obtener el código de empleado del usuario actual (si es mecánico)
  Future<int?> getUserEmployeeId() async {
    try {
      final user = await getCurrentUser();
      final db = await _databaseHelper.database;
      
      final empleadoData = await db.query(
        'empleado',
        where: 'cod_persona = ?',
        whereArgs: [user.codPersona],
      );

      if (empleadoData.isNotEmpty) {
        return empleadoData.first['cod_empleado'] as int;
      }
      
      return null;
    } catch (e) {
      print('Error obteniendo ID de empleado: $e');
      return null;
    }
  }

  // Obtener información completa del perfil del usuario
  Future<UserProfile> getUserProfile() async {
    final user = await getCurrentUser();
    final db = await _databaseHelper.database;
    
    final personData = await db.query(
      'persona',
      where: 'cod_persona = ?',
      whereArgs: [user.codPersona],
    );

    if (personData.isEmpty) {
      throw Exception('Datos de persona no encontrados');
    }

    final person = personData.first;

    // Verificar si es empleado y obtener cargo
    String? cargo;
    final empleadoData = await db.query(
      'empleado',
      where: 'cod_persona = ?',
      whereArgs: [user.codPersona],
    );

    if (empleadoData.isNotEmpty) {
      final cargoId = empleadoData.first['cod_cargo_emp'] as int;
      final cargoData = await db.query(
        'cargo_empleado',
        where: 'cod_cargo_emp = ?',
        whereArgs: [cargoId],
      );
      
      if (cargoData.isNotEmpty) {
        cargo = cargoData.first['descripcion'] as String;
      }
    }

    return UserProfile(
      user: user,
      nombre: person['nombre'] as String,
      apellidos: person['apellidos'] as String,
      telefono: person['telefono'] as String?,
      email: user.email,
      cargo: cargo,
      nivelAcceso: user.nivelAcceso,
    );
  }

  // Método de login que verifica credenciales
  Future<LocalUser> login(String correo, String contrasena) async {
    final db = await _databaseHelper.database;
    
    final userData = await db.query(
      'usuario',
      where: 'correo = ? AND contrasena_usu = ?',
      whereArgs: [correo, contrasena],
    );

    if (userData.isEmpty) {
      throw Exception('Credenciales incorrectas');
    }

    final user = userData.first;
    
    // Guardar sesión
    await setCurrentUser(user['cod_usuario'] as int);
    
    return await getCurrentUser();
  }

  // Actualizar datos del perfil
  Future<void> updateProfile({
    String? nombre,
    String? apellidos,
    String? telefono,
    String? email,
  }) async {
    final user = await getCurrentUser();
    final db = await _databaseHelper.database;
    
    final updates = <String, dynamic>{};
    if (nombre != null) updates['nombre'] = nombre;
    if (apellidos != null) updates['apellidos'] = apellidos;
    if (telefono != null) updates['telefono'] = telefono;
    
    if (updates.isNotEmpty) {
      await db.update(
        'persona',
        updates,
        where: 'cod_persona = ?',
        whereArgs: [user.codPersona],
      );
    }
    
    if (email != null) {
      await db.update(
        'usuario',
        {'correo': email},
        where: 'cod_usuario = ?',
        whereArgs: [user.codUsuario],
      );
    }
  }
}

class LocalUser {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String nivelAcceso;
  final int codPersona;
  final int codUsuario;

  LocalUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.nivelAcceso,
    required this.codPersona,
    required this.codUsuario,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'nivelAcceso': nivelAcceso,
      'codPersona': codPersona,
      'codUsuario': codUsuario,
    };
  }

  @override
  String toString() {
    return 'LocalUser{id: $id, name: $name, email: $email, nivelAcceso: $nivelAcceso}';
  }
}

class Vehicle {
  final int id;
  final String placas;
  final String marca;
  final String modelo;
  final String color;
  final int kilometraje;
  final String? numeroSerie;
  final int? anio;

  Vehicle({
    required this.id,
    required this.placas,
    required this.marca,
    required this.modelo,
    required this.color,
    required this.kilometraje,
    this.numeroSerie,
    this.anio,
  });

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['cod_vehiculo'] as int,
      placas: map['placas'] as String,
      marca: map['marca'] as String,
      modelo: map['modelo'] as String,
      color: map['color'] as String? ?? 'N/A',
      kilometraje: map['kilometraje'] as int? ?? 0,
      numeroSerie: map['numero_serie'] as String?,
      anio: map['anio'] as int?,
    );
  }

  String get descripcionCompleta => '$marca $modelo - $placas';

  @override
  String toString() {
    return 'Vehicle{id: $id, placas: $placas, marca: $marca, modelo: $modelo}';
  }
}

class UserProfile {
  final LocalUser user;
  final String nombre;
  final String apellidos;
  final String? telefono;
  final String email;
  final String? cargo;
  final String nivelAcceso;

  UserProfile({
    required this.user,
    required this.nombre,
    required this.apellidos,
    required this.telefono,
    required this.email,
    required this.cargo,
    required this.nivelAcceso,
  });

  String get nombreCompleto => '$nombre $apellidos';

  bool get esMecanico => cargo?.toUpperCase().contains('MECÁNICO') == true ||
                         cargo?.toUpperCase().contains('TÉCNICO') == true;

  bool get esAdministrador => nivelAcceso.toUpperCase().contains('ADMIN');

  @override
  String toString() {
    return 'UserProfile{nombre: $nombreCompleto, email: $email, cargo: $cargo, nivelAcceso: $nivelAcceso}';
  }
}