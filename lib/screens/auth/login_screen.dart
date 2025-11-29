// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/constants.dart';
import '../../viewmodels/login_viewmodel.dart';
import '../../screens/ubicaciones/ubicaciones_screen.dart'; // ← Importar la pantalla de ubicaciones

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoggedIn;
  final VoidCallback onPressSOS;

  const LoginScreen({
    super.key,
    required this.onLoggedIn,
    required this.onPressSOS,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _f = GlobalKey<FormState>();
  final _email = TextEditingController(text: LoginViewModel.demoEmail);
  final _password = TextEditingController(text: LoginViewModel.demoPass);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(),
      child: Consumer<LoginViewModel>(
        builder: (_, vm, __) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xlarge),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xlarge),
                      child: Form(
                        key: _f,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'ElectroMec SOS',
                              style: AppTextStyles.heading1.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.large),

                            // CORREO
                            TextFormField(
                              controller: _email,
                              decoration: const InputDecoration(
                                labelText: 'Correo',
                                prefixIcon: Icon(Icons.email),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Ingresa tu correo';
                                }
                                if (!v.contains('@')) return 'Correo inválido';
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.medium),

                            // CONTRASEÑA
                            TextFormField(
                              controller: _password,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: Icon(Icons.lock),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  (v == null || v.isEmpty)
                                      ? 'Ingresa tu contraseña'
                                      : null,
                            ),
                            const SizedBox(height: AppSpacing.large),

                            if (vm.error != null) ...[
                              Text(
                                vm.error!,
                                style: const TextStyle(color: AppColors.error),
                              ),
                              const SizedBox(height: AppSpacing.small),
                            ],

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: vm.loading ? null : () => _onLogin(vm),
                                    icon: const Icon(Icons.login),
                                    label: vm.loading
                                        ? const Text('Verificando...')
                                        : const Text('Iniciar sesión'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.medium),
                                IconButton.filled(
                                  onPressed: vm.loading ? null : () => _onSOS(vm),
                                  icon: const Icon(Icons.sos),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.all(16),
                                  ),
                                  tooltip: 'AUXILIO',
                                ),
                              ],
                            ),

                            const SizedBox(height: AppSpacing.large),
                            const Divider(),
                            Text(
                              "Usuario demo: ${LoginViewModel.demoEmail}\nContraseña: ${LoginViewModel.demoPass}",
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onLogin(LoginViewModel vm) async {
    if (!_f.currentState!.validate()) return;

    final ok = await vm.login(_email.text.trim(), _password.text);
    if (!mounted) return;

    if (ok) {
      widget.onLoggedIn();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error ?? 'No se pudo iniciar sesión')),
      );
    }
  }

  Future<void> _onSOS(LoginViewModel vm) async {
    await vm.enviarSOS();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS enviado')),
    );
    
    // Navegar directamente a UbicacionesScreen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UbicacionesScreen(),
      ),
    );
  }
}