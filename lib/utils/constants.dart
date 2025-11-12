import 'package:flutter/material.dart';

/// ===========================
/// 🎨 COLORES DE LA APP
/// ===========================
class AppColors {
  static const primary = Color(0xFF1A365D);       // Azul marino profesional
  static const secondary = Color(0xFF2D3748);     // Gris azulado oscuro
  static const accent = Color(0xFFE53E3E);        // Rojo acento
  static const background = Color(0xFFF7FAFC);    // Fondo claro
  static const backgroundVariant = Color(0xFFEDF2F7);
  static const success = Color(0xFF38A169);       // Verde éxito
  static const error = Color(0xFFE53E3E);         // Rojo error
  static const warning = Color(0xFFD69E2E);       // Amarillo advertencia
  static const textPrimary = Color(0xFF2D3748);   // Texto principal
  static const textSecondary = Color(0xFF718096); // Texto secundario
}

/// ===========================
/// ✍️ ESTILOS DE TEXTO
/// ===========================
class AppTextStyles {
  static const heading1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static const heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  static const heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 16,
    color: AppColors.textSecondary,
  );

  static const bodyBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const caption = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static const button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
}

/// ===========================
/// 📏 ESPACIADOS Y RADIOS
/// ===========================
class AppSpacing {
  static const double xsmall = 4.0;
  static const double small = 8.0;
  static const double medium = 16.0;
  static const double large = 24.0;
  static const double xlarge = 32.0;
  static const double xxlarge = 48.0;
}

class AppRadius {
  static const double small = 8.0;
  static const double medium = 16.0;
  static const double large = 24.0;
  static const double xlarge = 32.0;
}

/// ===========================
/// 🖼️ ASSETS / ICONOS
/// ===========================
class AppAssets {
  static const logo = "assets/logo.png";
  static const userPlaceholder = "assets/images/user.png";
  static const mechanicIcon = "assets/icons/mechanic.png";
  static const carIcon = "assets/icons/car.png";
  static const mapIcon = "assets/icons/map.png";
}

/// ===========================
/// 🔑 STRINGS COMUNES
/// ===========================
class AppStrings {
  static const appName = "ElectroMec SOS";
  static const login = "Iniciar Sesión";
  static const logout = "Cerrar Sesión";
  static const dashboard = "Panel Principal";
  static const servicios = "Servicios";
  static const clientes = "Clientes";
  static const pagos = "Pagos";
  static const inventario = "Inventario";
  static const ubicaciones = "Ubicaciones";
  static const error = "Ocurrió un error, inténtalo nuevamente";
}

/// ===========================
/// 👤 ROLES DE USUARIO
/// ===========================
class UserRoles {
  static const administrador = 'Administrador';
  static const empleado = 'Empleado';
  static const cliente = 'Cliente';
}

/// ===========================
/// 📌 ESTADOS GENERALES
/// ===========================
class Estados {
  static const activo = 'Activo';
  static const inactivo = 'Inactivo';
  static const pendiente = 'Pendiente';
  static const enCurso = 'En curso';
  static const finalizado = 'Finalizado';
  static const cancelado = 'Cancelado';
}

/// ===========================
/// 💬 MENSAJES COMUNES
/// ===========================
class Messages {
  static const loginError = 'Usuario o contraseña incorrectos';
  static const campoRequerido = 'Este campo es obligatorio';
  static const correoInvalido = 'Correo electrónico inválido';
  static const passwordCorta = 'La contraseña debe tener al menos 6 caracteres';
  static const exitoLogin = 'Inicio de sesión exitoso';
  static const sosEnviado = 'Solicitud de auxilio enviada correctamente';
  static const sosError = 'No se pudo enviar el SOS';
  static const registroExitoso = 'Registro completado correctamente';
  static const eliminado = 'Eliminado con éxito';
  static const actualizado = 'Actualizado correctamente';
  static const sinResultados = 'No hay datos disponibles';
}

/// ===========================
/// 🧭 ICONOS COMUNES
/// ===========================
class AppIcons {
  static const IconData servicios = Icons.build_circle_outlined;
  static const IconData clientes = Icons.people_outline;
  static const IconData pagos = Icons.attach_money_outlined;
  static const IconData historial = Icons.history_outlined;
  static const IconData ubicaciones = Icons.location_on_outlined;
  static const IconData inventario = Icons.inventory_2_outlined;
  static const IconData salir = Icons.logout;
}
