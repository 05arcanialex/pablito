// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // ⬅️ AGREGAR ESTA LÍNEA

// 🧠 ESTADOS
import 'viewmodels/dashboard_viewmodel.dart';
import 'viewmodels/clientes_viewmodel.dart';
import 'viewmodels/pagos_viewmodel.dart';
import 'viewmodels/ubicaciones_viewmodel.dart';
import 'viewmodels/login_viewmodel.dart';

// 🎨 CONSTANTES
import 'utils/constants.dart';

// 🗄 BASE DE DATOS
import 'models/database_helper.dart';

// 🖥 PANTALLAS
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/pagos/pagos_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 INICIALIZAR FIREBASE - SOLO ESTA LÍNEA NUEVA
  await Firebase.initializeApp();

  // ❌ EVITA BORRAR DATOS EN CADA EJECUCIÓN
  // await DatabaseHelper.resetDevDB();

  try {
    // 📂 ABRE O CREA LA BASE DE DATOS
    await DatabaseHelper.instance.database;

    // 🌱 CARGA AUTOMÁTICAMENTE LOS SEEDERS SI LA BD ESTÁ VACÍA
    await DatabaseHelper.instance.seedIfEmpty();

    debugPrint('✅ BASE DE DATOS LISTA');
  } catch (e) {
    debugPrint('❌ ERROR AL CREAR/ABRIR LA BD: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardViewModel()),
        ChangeNotifierProvider(
            create: (_) => ClientesViewModel()..loadClientes()),
        ChangeNotifierProvider(create: (_) => PagosViewModel()..init()),
        ChangeNotifierProvider(create: (_) => UbicacionesViewModel()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppStrings.appName,
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
        ),
        home: const Root(),
        routes: {
          '/pagos': (_) => const PagosScreen(),
        },
      ),
    );
  }
}

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool _loggedIn = false;

  void _handleLoggedIn() {
    setState(() => _loggedIn = true);
  }

  void _handleSOS() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(Messages.sosEnviado)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _loggedIn
        ? DashboardScreen(
            // 👤 POR AHORA DATOS DEMO (PUEDES CAMBIARLOS LUEGO POR LOS REALES DEL LOGIN)
            userName: 'ADMIN DEMO',
            userEmail: LoginViewModel.demoEmail,
            onLogout: () {
              setState(() {
                _loggedIn = false; // 🔚 VUELVE AL LOGIN
              });
            },
          )
        : LoginScreen(
            onLoggedIn: _handleLoggedIn,
            onPressSOS: _handleSOS,
          );
  }
}