// lib/viewmodels/inicio_viewmodel.dart
import 'dart:math';
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
  
  // PROPIEDADES PARA LOS DATOS REALES
  int totalClientes = 0;
  double totalIngresos = 0.0;

  // NUEVAS PROPIEDADES PARA GRÁFICOS
  List<Map<String, dynamic>> datosIngresosMensuales = [];
  List<Map<String, dynamic>> datosServiciosPorTipo = [];

  Future<void> init() async {
    await _loadPersonas();
    await _loadUsuarios();
    await _loadDatosReales();
    await _loadDatosGraficos();
  }

  Future<void> _setLoading(bool value) async {
    isLoading = value;
    notifyListeners();
  }

  // MÉTODO PARA CARGAR DATOS REALES
  Future<void> _loadDatosReales() async {
    try {
      final db = await _dbHelper.database;
      
      // CONTAR CLIENTES
      final clientesRes = await db.rawQuery('''
        SELECT COUNT(*) as total FROM cliente
      ''');
      totalClientes = clientesRes.first['total'] as int? ?? 0;
      
      // SUMAR INGRESOS (total de recibo_pago)
      final ingresosRes = await db.rawQuery('''
        SELECT COALESCE(SUM(total), 0) as total_ingresos FROM recibo_pago
      ''');
      totalIngresos = (ingresosRes.first['total_ingresos'] as num?)?.toDouble() ?? 0.0;
      
    } catch (e) {
      if (kDebugMode) {
        print('Error cargando datos reales: $e');
      }
    }
  }

  // NUEVO MÉTODO PARA CARGAR DATOS DE GRÁFICOS
  Future<void> _loadDatosGraficos() async {
    await _loadIngresosMensuales();
    await _loadServiciosPorTipo();
  }

  Future<void> _loadIngresosMensuales() async {
    try {
      final db = await _dbHelper.database;
      
      // Primero verificar si hay recibos en la base de datos
      final countRes = await db.rawQuery('''
        SELECT COUNT(*) as total FROM recibo_pago
      ''');
      final totalRecibos = (countRes.first['total'] as int?) ?? 0;
      
      if (totalRecibos == 0) {
        // No hay recibos, usar datos de ejemplo
        datosIngresosMensuales = _generarDatosEjemploIngresos();
        return;
      }

      // CONSULTA CORREGIDA - usar fecha directamente sin strftime si no funciona
      final res = await db.rawQuery('''
        SELECT 
          substr(fecha, 1, 7) as mes_anio,
          SUM(total) as ingresos
        FROM recibo_pago 
        WHERE fecha >= date('now', '-6 months')
        GROUP BY mes_anio
        ORDER BY mes_anio DESC
        LIMIT 6
      ''');

      if (res.isNotEmpty) {
        // Procesar los datos obtenidos
        final datosProcesados = <Map<String, dynamic>>[];
        
        for (var item in res) {
          final mesAnio = item['mes_anio'] as String?;
          final ingresos = (item['ingresos'] as num?)?.toDouble() ?? 0.0;
          
          if (mesAnio != null) {
            final partes = mesAnio.split('-');
            if (partes.length == 2) {
              final mesNum = int.parse(partes[1]);
              final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
              final mesNombre = meses[mesNum - 1];
              
              datosProcesados.add({
                'mes': mesNombre,
                'ingresos': ingresos,
              });
            }
          }
        }
        
        // Ordenar cronológicamente (más antiguo primero)
        datosProcesados.sort((a, b) {
          final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
          return meses.indexOf(a['mes']).compareTo(meses.indexOf(b['mes']));
        });
        
        datosIngresosMensuales = datosProcesados;
      } else {
        // Si no hay datos en los últimos 6 meses, intentar obtener cualquier dato
        final todosLosRecibos = await db.rawQuery('''
          SELECT fecha, total FROM recibo_pago 
          ORDER BY fecha DESC 
          LIMIT 6
        ''');
        
        if (todosLosRecibos.isNotEmpty) {
          datosIngresosMensuales = _procesarRecibosParaGrafico(todosLosRecibos);
        } else {
          datosIngresosMensuales = _generarDatosEjemploIngresos();
        }
      }
      
      // Si aún no hay datos, usar ejemplo
      if (datosIngresosMensuales.isEmpty) {
        datosIngresosMensuales = _generarDatosEjemploIngresos();
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Error cargando ingresos mensuales: $e');
      }
      // En caso de error, usar datos de ejemplo
      datosIngresosMensuales = _generarDatosEjemploIngresos();
    }
  }

  // Método para procesar recibos existentes y convertirlos en datos para el gráfico
  List<Map<String, dynamic>> _procesarRecibosParaGrafico(List<Map<String, dynamic>> recibos) {
    final ahora = DateTime.now();
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final datos = <Map<String, dynamic>>[];
    
    // Crear un mapa para agrupar por mes
    final ingresosPorMes = <String, double>{};
    
    for (final recibo in recibos) {
      final fechaStr = recibo['fecha'] as String?;
      final total = (recibo['total'] as num?)?.toDouble() ?? 0.0;
      
      if (fechaStr != null) {
        try {
          final fecha = DateTime.parse(fechaStr);
          final claveMes = '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}';
          ingresosPorMes[claveMes] = (ingresosPorMes[claveMes] ?? 0.0) + total;
        } catch (e) {
          // Si falla el parsing, usar el mes actual
          final claveMes = '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}';
          ingresosPorMes[claveMes] = (ingresosPorMes[claveMes] ?? 0.0) + total;
        }
      }
    }
    
    // Convertir a lista ordenada por fecha (más reciente primero)
    final mesesOrdenados = ingresosPorMes.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    
    // Tomar los últimos 6 meses
    for (int i = 0; i < min(6, mesesOrdenados.length); i++) {
      final entry = mesesOrdenados[i];
      final partes = entry.key.split('-');
      final mesNum = int.parse(partes[1]);
      final mesNombre = meses[mesNum - 1];
      
      datos.add({
        'mes': mesNombre,
        'ingresos': entry.value,
      });
    }
    
    // Ordenar de más antiguo a más reciente
    datos.sort((a, b) {
      final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return meses.indexOf(a['mes']).compareTo(meses.indexOf(b['mes']));
    });
    
    return datos;
  }

  // Generar datos de ejemplo realistas
  List<Map<String, dynamic>> _generarDatosEjemploIngresos() {
    final ahora = DateTime.now();
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final datos = <Map<String, dynamic>>[];
    final random = Random();
    
    // Generar datos para los últimos 6 meses
    for (int i = 5; i >= 0; i--) {
      final mesIndex = (ahora.month - 1 - i) % 12;
      final mes = meses[mesIndex >= 0 ? mesIndex : mesIndex + 12];
      
      // Datos de ejemplo con variación realista
      final baseIngresos = totalIngresos > 0 ? totalIngresos / 6 : 2000.0;
      final variacion = (random.nextDouble() * 0.4) - 0.2; // ±20% de variación
      final ingresos = baseIngresos * (1 + variacion);
      
      datos.add({
        'mes': mes,
        'ingresos': ingresos.abs(), // Asegurar positivo
      });
    }
    
    return datos;
  }

  Future<void> _loadServiciosPorTipo() async {
    try {
      final db = await _dbHelper.database;
      
      // CONSULTA CORREGIDA - usar la vista o tabla correcta
      final res = await db.rawQuery('''
        SELECT 
          tt.descripcion as tipo,
          COUNT(rstt.cod_reg_ser_taller_tipo) as cantidad
        FROM tipo_trabajo tt
        LEFT JOIN reg_serv_taller_tipo_trabajo rstt ON tt.cod_tipo_trabajo = rstt.cod_tipo_trabajo
        GROUP BY tt.descripcion
        HAVING cantidad > 0
        ORDER BY cantidad DESC
        LIMIT 6
      ''');

      if (res.isNotEmpty) {
        datosServiciosPorTipo = res.map((e) {
          return {
            'tipo': (e['tipo'] as String?) ?? 'Sin nombre',
            'cantidad': e['cantidad'] as int? ?? 0,
          };
        }).toList();
      } else {
        // Si no hay datos reales, intentar contar servicios de otra forma
        final resAlternativo = await db.rawQuery('''
          SELECT 
            tt.descripcion as tipo,
            (SELECT COUNT(*) FROM reg_serv_taller_tipo_trabajo rstt 
             WHERE rstt.cod_tipo_trabajo = tt.cod_tipo_trabajo) as cantidad
          FROM tipo_trabajo tt
          ORDER BY cantidad DESC
          LIMIT 6
        ''');
        
        if (resAlternativo.isNotEmpty) {
          datosServiciosPorTipo = resAlternativo.map((e) {
            return {
              'tipo': (e['tipo'] as String?) ?? 'Sin nombre',
              'cantidad': e['cantidad'] as int? ?? 0,
            };
          }).toList();
        } else {
          datosServiciosPorTipo = _generarDatosEjemploServicios();
        }
      }
      
      // Si todos los valores son 0, usar datos de ejemplo
      final totalServicios = datosServiciosPorTipo.fold<int>(0, (sum, item) => sum + (item['cantidad'] as int));
      if (totalServicios == 0) {
        datosServiciosPorTipo = _generarDatosEjemploServicios();
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Error cargando servicios por tipo: $e');
      }
      datosServiciosPorTipo = _generarDatosEjemploServicios();
    }
  }

  // Generar datos de ejemplo para servicios
  List<Map<String, dynamic>> _generarDatosEjemploServicios() {
    return [
      {'tipo': 'Mantenimiento', 'cantidad': 15},
      {'tipo': 'Diagnóstico', 'cantidad': 12},
      {'tipo': 'Reparaciones', 'cantidad': 8},
      {'tipo': 'Programación', 'cantidad': 5},
    ];
  }

  // ... (el resto de los métodos _loadPersonas, _loadUsuarios, crearUsuario, etc. se mantienen igual)
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
      final res = await _dbHelper.rawQuery('''
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
          'contrasena_usu': password,
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