// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 🧠 ESTADOS
import 'viewmodels/dashboard_viewmodel.dart';

// 🎨 CONSTANTES
import 'utils/constants.dart';

// 🗄 BASE DE DATOS
import 'models/database_helper.dart';

// 🖥 PANTALLAS
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ❌ EVITA BORRAR DATOS EN CADA EJECUCIÓN
  // await DatabaseHelper.resetDevDB();

  try {
    // 📂 ABRE O CREA LA BASE DE DATOS
    await DatabaseHelper.instance.database;

    // 🌱 CARGA AUTOMÁTICAMENTE LOS SEEDERS SI LA BD ESTÁ VACÍA
    await DatabaseHelper.instance.seedIfEmpty();

    print('✅ BASE DE DATOS LISTA');
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

  void _handleLoggedIn() => setState(() => _loggedIn = true);

  void _handleSOS() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(Messages.sosEnviado)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _loggedIn
        ? const DashboardScreen()
        : LoginScreen(onLoggedIn: _handleLoggedIn, onPressSOS: _handleSOS);
  }
}
