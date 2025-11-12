// lib/screens/inicio/inicio_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/constants.dart';
import '../../viewmodels/dashboard_viewmodel.dart';

class InicioScreen extends StatelessWidget {
  /// CALLBACK OPCIONAL QUE PERMITE CAMBIAR EL ÍNDICE DEL DASHBOARD
  final void Function(int index)? onQuickAccess;

  const InicioScreen({super.key, this.onQuickAccess});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            ],
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
          BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
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
        Expanded(child: _StatCard(icon: Icons.build, label: 'SERVICIOS HOY', value: '6', color: AppColors.primary)),
        SizedBox(width: 10),
        Expanded(child: _StatCard(icon: Icons.people, label: 'CLIENTES', value: '124', color: Color(0xFF0EA5E9))),
        SizedBox(width: 10),
        Expanded(child: _StatCard(icon: Icons.payments, label: 'INGRESOS (BS)', value: '1,240', color: AppColors.success)),
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
              // SI EL PADRE PASÓ EL CALLBACK, USARLO
              if (onQuickAccess != null) {
                onQuickAccess!(it.index);
              } else {
                // SINO, CAMBIAR DESDE AQUÍ CON EL PROVIDER
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
  const _QuickButton({super.key, required this.icon, required this.label, required this.onTap});

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
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}
