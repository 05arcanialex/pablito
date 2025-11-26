// lib/screens/inicio/inicio_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/constants.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/inicio_viewmodel.dart';

class InicioScreen extends StatelessWidget {
  /// CALLBACK OPCIONAL QUE PERMITE CAMBIAR EL ÍNDICE DEL DASHBOARD
  final void Function(int index)? onQuickAccess;

  const InicioScreen({super.key, this.onQuickAccess});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InicioViewModel()..init(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: AppSpacing.large),
                _cardsResumen(context),
                const SizedBox(height: AppSpacing.large),
                _accesosRapidos(context),
                const SizedBox(height: AppSpacing.large),
                const _UsuariosSection(), // 🔹 CARD DISCRETO
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'INICIO',
        style: AppTextStyles.heading1.copyWith(color: Colors.white),
      ),
    );
  }

  Widget _cardsResumen(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _StatCard(
            icon: Icons.build,
            label: 'SERVICIOS HOY',
            value: '6',
            color: AppColors.primary,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.people,
            label: 'CLIENTES',
            value: '124',
            color: Color(0xFF0EA5E9),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.payments,
            label: 'INGRESOS (BS)',
            value: '1,240',
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _accesosRapidos(BuildContext context) {
    final items = <_QuickItem>[
      _QuickItem(icon: Icons.build, label: 'SERVICIOS', index: 0),
      _QuickItem(icon: Icons.people, label: 'CLIENTES', index: 1),
      _QuickItem(icon: Icons.location_on, label: 'UBICACIONES', index: 2),
      _QuickItem(icon: Icons.inventory_2, label: 'OBJETOS', index: 4),
      _QuickItem(icon: Icons.payments, label: 'PAGOS', index: 5),
      _QuickItem(icon: Icons.history, label: 'HISTORIAL', index: 6),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: Colors.blue.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.0,
        ),
        itemBuilder: (_, i) {
          final it = items[i];
          return _QuickButton(
            icon: it.icon,
            label: it.label,
            onTap: () {
              if (onQuickAccess != null) {
                onQuickAccess!(it.index);
              } else {
                final vm = context.read<DashboardViewModel>();
                vm.changeIndex(it.index);
              }
            },
          );
        },
      ),
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String label;
  final int index;
  _QuickItem({required this.icon, required this.label, required this.index});
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.blue.shade50,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.9), color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// ================================
/// CARD DISCRETO DE GESTIÓN USUARIOS
/// ================================
class _UsuariosSection extends StatelessWidget {
  const _UsuariosSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<InicioViewModel>(
      builder: (context, vm, _) {
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
          elevation: 3,
          child: ListTile(
            leading: const Icon(Icons.manage_accounts, color: AppColors.primary),
            title: const Text(
              'GESTIONAR USUARIOS',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Personas registradas: ${vm.personas.length} • Usuarios: ${vm.usuarios.length}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.keyboard_arrow_up),
            onTap: () {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (dialogCtx) {
                  final sharedVm = Provider.of<InicioViewModel>(
                    context,
                    listen: false,
                  );
                  return ChangeNotifierProvider.value(
                    value: sharedVm,
                    child: const _UsuariosDialogContent(),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// ================================
/// DIALOG EMERGENTE CON FORM + LISTA
/// ================================
class _UsuariosDialogContent extends StatefulWidget {
  const _UsuariosDialogContent();

  @override
  State<_UsuariosDialogContent> createState() => _UsuariosDialogContentState();
}

class _UsuariosDialogContentState extends State<_UsuariosDialogContent> {
  final _formKey = GlobalKey<FormState>();

  final _nombreUsuCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  int? _selectedPersonaId;
  String _nivelAcceso = 'ADMIN';

  @override
  void dispose() {
    _nombreUsuCtrl.dispose();
    _correoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: const [
          Icon(Icons.manage_accounts, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Gestión de usuarios'),
        ],
      ),
      content: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.7,
        child: Consumer<InicioViewModel>(
          builder: (context, vm, _) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (vm.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        vm.errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  /// ---------- FORM CREAR USUARIO ----------
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Persona',
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedPersonaId,
                          items: vm.personas
                              .map(
                                (p) => DropdownMenuItem<int>(
                                  value: p.id,
                                  child: Text(p.nombreCompleto),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() => _selectedPersonaId = v);
                          },
                          validator: (v) =>
                              v == null ? 'Selecciona una persona' : null,
                        ),
                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _nombreUsuCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de usuario',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Obligatorio'
                              : null,
                        ),
                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _correoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Correo',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Obligatorio'
                              : null,
                        ),
                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _passwordCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Obligatorio' : null,
                        ),
                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _confirmPasswordCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar contraseña',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Obligatorio';
                            }
                            if (v != _passwordCtrl.text) {
                              return 'No coincide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Nivel de acceso',
                            border: OutlineInputBorder(),
                          ),
                          value: _nivelAcceso,
                          items: const [
                            DropdownMenuItem(
                              value: 'ADMIN',
                              child: Text('ADMIN'),
                            ),
                            DropdownMenuItem(
                              value: 'MECANICO',
                              child: Text('MECÁNICO'),
                            ),
                            DropdownMenuItem(
                              value: 'CLIENTE',
                              child: Text('CLIENTE'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _nivelAcceso = v);
                            }
                          },
                        ),
                        const SizedBox(height: 8),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: vm.isLoading
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) {
                                      return;
                                    }

                                    final error = await vm.crearUsuario(
                                      nombreUsu: _nombreUsuCtrl.text,
                                      correo: _correoCtrl.text,
                                      password: _passwordCtrl.text,
                                      confirmarPassword:
                                          _confirmPasswordCtrl.text,
                                      nivelAcceso: _nivelAcceso,
                                      codPersona: _selectedPersonaId,
                                    );

                                    if (!mounted) return;

                                    if (error != null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(error),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'USUARIO CREADO CORRECTAMENTE'),
                                        ),
                                      );
                                      _passwordCtrl.clear();
                                      _confirmPasswordCtrl.clear();
                                      _nombreUsuCtrl.clear();
                                      _correoCtrl.clear();
                                      setState(() {
                                        _selectedPersonaId = null;
                                        _nivelAcceso = 'ADMIN';
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.save),
                            label: Text(
                              vm.isLoading
                                  ? 'Guardando...'
                                  : 'Guardar usuario',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  /// ---------- LISTA DE USUARIOS ----------
                  Text(
                    'Usuarios registrados',
                    style: AppTextStyles.heading3
                        .copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),

                  if (vm.isLoading && vm.usuarios.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (vm.usuarios.isEmpty)
                    const Text(
                      'No hay usuarios registrados.',
                      style: TextStyle(fontSize: 12),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: vm.usuarios.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final u = vm.usuarios[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(
                              u.nombreUsu,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${u.correo}\n${u.nombrePersona ?? ''} • ${u.nivelAcceso}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () {
                                    _showEditDialog(context, vm, u);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text(
                                                'Eliminar usuario'),
                                            content: Text(
                                                '¿Deseas eliminar a "${u.nombreUsu}"?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        ctx, false),
                                                child:
                                                    const Text('Cancelar'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        ctx, true),
                                                child:
                                                    const Text('Eliminar'),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                        false;

                                    if (ok) {
                                      await vm.eliminarUsuario(u.id);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('USUARIO ELIMINADO'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CERRAR'),
        ),
      ],
    );
  }

  void _showEditDialog(
      BuildContext context, InicioViewModel vm, UsuarioItem u) {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController(text: u.nombreUsu);
    final correoCtrl = TextEditingController(text: u.correo);
    final passCtrl = TextEditingController();
    int? selectedPersonaId = u.codPersona;
    String nivel = u.nivelAcceso;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Editar usuario'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Persona',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedPersonaId,
                    items: vm.personas
                        .map(
                          (p) => DropdownMenuItem<int>(
                            value: p.id,
                            child: Text(p.nombreCompleto),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      selectedPersonaId = v;
                    },
                    validator: (v) =>
                        v == null ? 'Selecciona una persona' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de usuario',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: correoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Obligatorio'
                            : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Nivel de acceso',
                      border: OutlineInputBorder(),
                    ),
                    value: nivel,
                    items: const [
                      DropdownMenuItem(
                        value: 'ADMIN',
                        child: Text('ADMIN'),
                      ),
                      DropdownMenuItem(
                        value: 'MECANICO',
                        child: Text('MECÁNICO'),
                      ),
                      DropdownMenuItem(
                        value: 'CLIENTE',
                        child: Text('CLIENTE'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) nivel = v;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: passCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nueva contraseña (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR'),
            ),
            TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final error = await vm.actualizarUsuario(
                  codUsuario: u.id,
                  nombreUsu: nombreCtrl.text,
                  correo: correoCtrl.text,
                  nivelAcceso: nivel,
                  codPersona: selectedPersonaId,
                  newPassword:
                      passCtrl.text.isEmpty ? null : passCtrl.text,
                );

                if (error != null) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('USUARIO ACTUALIZADO'),
                    ),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('GUARDAR'),
            ),
          ],
        );
      },
    );
  }
}
