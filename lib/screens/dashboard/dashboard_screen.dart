// lib/screens/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/dashboard_viewmodel.dart';
import '../../utils/constants.dart';

import '../servicios/servicios_screen.dart';
import '../clientes/clientes_screen.dart';
import '../auxilio/mecanico_auxilios_screen.dart'; // Reemplazamos ubicaciones
import '../inicio/inicio_screen.dart';
import '../objetos/objetos_screen.dart';
import '../pagos/pagos_screen.dart';
import '../historial/historial_screen.dart';

class DashboardScreen extends StatelessWidget {
  // 👤 DATOS DEL USUARIO ACTUAL
  final String userName;  
  final String userEmail;

  // 🔚 CALLBACK PARA CERRAR SESIÓN
  final VoidCallback onLogout;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final dashboardVM = context.watch<DashboardViewModel>();

    final pages = <Widget>[
      const ServiciosScreen(),       // 0
      const ClientesScreen(),        // 1
      const MecanicoAuxiliosScreen(), // 2 - AHORA ES AUXILIO MECÁNICO
      InicioScreen(                  // 3
        onQuickAccess: (i) => context.read<DashboardViewModel>().changeIndex(i),
      ),
      const ObjetosScreen(),         // 4
      const PagosScreen(),           // 5
      const HistorialScreen(),       // 6
    ];

    return Scaffold(
      appBar: AppBar(
        elevation: 3,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        toolbarHeight: 72,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              AppStrings.appName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _titleForIndex(dashboardVM.selectedIndex),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      drawer: _buildDrawer(context, dashboardVM),
      body: IndexedStack(
        index: dashboardVM.selectedIndex,
        children: pages,
      ),
      bottomNavigationBar:
          _buildResponsiveBottomNavigationBar(dashboardVM, context),
    );
  }

  String _titleForIndex(int i) {
    switch (i) {
      case 0:
        return "SERVICIOS";
      case 1:
        return "CLIENTES";
      case 2:
        return "AUXILIO MECÁNICO"; // CAMBIADO
      case 3:
        return AppStrings.dashboard;
      case 4:
        return "OBJETOS";
      case 5:
        return "PAGOS";
      case 6:
        return "HISTORIAL";
      default:
        return AppStrings.dashboard;
    }
  }

  Drawer _buildDrawer(BuildContext context, DashboardViewModel dashboardVM) {
    final displayName =
        userName.isEmpty ? "USUARIO" : userName;
    final displayEmail = userEmail.isEmpty
        ? "usuario@correo.com"
        : userEmail;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: Text(
              displayName,
              style: AppTextStyles.body.copyWith(color: Colors.white),
            ),
            accountEmail: Text(
              displayEmail,
              style: AppTextStyles.body.copyWith(color: Colors.white70),
            ),
            currentAccountPicture: const CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.accent,
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
          ),
          _buildDrawerItem(context, Icons.home, "INICIO", 3, dashboardVM),
          _buildDrawerItem(context, Icons.build, "SERVICIOS", 0, dashboardVM),
          _buildDrawerItem(context, Icons.people, "CLIENTES", 1, dashboardVM),
          _buildDrawerItem(
              context, Icons.build_circle, "AUXILIO MECÁNICO", 2, dashboardVM), // CAMBIADO
          _buildDrawerItem(
              context, Icons.inventory_2, "OBJETOS", 4, dashboardVM),
          _buildDrawerItem(context, Icons.payments, "PAGOS", 5, dashboardVM),
          _buildDrawerItem(
              context, Icons.history, "HISTORIAL", 6, dashboardVM),
          const Spacer(),
          const Divider(height: 1, color: AppColors.textSecondary),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: Text(
              AppStrings.logout,
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
          ),
        ],
      ),
    );
  }

  ListTile _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
    DashboardViewModel dashboardVM,
  ) {
    final isSelected = dashboardVM.selectedIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      title: Text(
        label,
        style: AppTextStyles.body.copyWith(
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppColors.primary.withOpacity(0.08),
      onTap: () {
        dashboardVM.changeIndex(index);
        Navigator.pop(context);
      },
    );
  }

  // ───────────────────────────────────────────────────
  // NAV BOTTOM RESPONSIVO
  // ───────────────────────────────────────────────────
  Widget _buildResponsiveBottomNavigationBar(
    DashboardViewModel dashboardVM,
    BuildContext context,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return _buildMobileBottomNavigationBar(dashboardVM, context);
    } else if (screenWidth < 1200) {
      return _buildTabletBottomNavigationBar(dashboardVM, context);
    } else {
      return _buildDesktopBottomNavigationBar(dashboardVM, context);
    }
  }

  Widget _buildMobileBottomNavigationBar(
    DashboardViewModel dashboardVM,
    BuildContext context,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildNavItem(Icons.build, "SERVICIOS", 0, dashboardVM,
                  isMobile: true),
              _buildNavItem(Icons.people, "CLIENTES", 1, dashboardVM,
                  isMobile: true),
              _buildNavItem(Icons.build_circle, "AUXILIO", 2, dashboardVM, // CAMBIADO
                  isMobile: true),
              _buildNavItemInicio(dashboardVM, isMobile: true),
              _buildNavItem(Icons.inventory_2, "OBJETOS", 4, dashboardVM,
                  isMobile: true),
              _buildNavItem(Icons.payments, "PAGOS", 5, dashboardVM,
                  isMobile: true),
              _buildNavItem(Icons.history, "HISTORIAL", 6, dashboardVM,
                  isMobile: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletBottomNavigationBar(
    DashboardViewModel dashboardVM,
    BuildContext context,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(Icons.build, "SERVICIOS", 0, dashboardVM,
                        isTablet: true),
                    _buildNavItem(Icons.people, "CLIENTES", 1, dashboardVM,
                        isTablet: true),
                    _buildNavItem(Icons.build_circle, "AUXILIO", 2, // CAMBIADO
                        dashboardVM,
                        isTablet: true),
                  ],
                ),
              ),
              _buildNavItemInicio(dashboardVM, isTablet: true),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(Icons.inventory_2, "OBJETOS", 4, dashboardVM,
                        isTablet: true),
                    _buildNavItem(Icons.payments, "PAGOS", 5, dashboardVM,
                        isTablet: true),
                    _buildNavItem(Icons.history, "HISTORIAL", 6, dashboardVM,
                        isTablet: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopBottomNavigationBar(
    DashboardViewModel dashboardVM,
    BuildContext context,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
          height: 90,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(Icons.build, "SERVICIOS", 0, dashboardVM,
                        isDesktop: true),
                    _buildNavItem(Icons.people, "CLIENTES", 1, dashboardVM,
                        isDesktop: true),
                    _buildNavItem(Icons.build_circle, "AUXILIO", 2, // CAMBIADO
                        dashboardVM,
                        isDesktop: true),
                  ],
                ),
              ),
              _buildNavItemInicio(dashboardVM, isDesktop: true),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(Icons.inventory_2, "OBJETOS", 4, dashboardVM,
                        isDesktop: true),
                    _buildNavItem(Icons.payments, "PAGOS", 5, dashboardVM,
                        isDesktop: true),
                    _buildNavItem(Icons.history, "HISTORIAL", 6, dashboardVM,
                        isDesktop: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    DashboardViewModel dashboardVM, {
    bool isMobile = false,
    bool isTablet = false,
    bool isDesktop = false,
  }) {
    final isSelected = dashboardVM.selectedIndex == index;

    return MaterialButton(
      minWidth: isMobile ? 40 : (isTablet ? 60 : 80),
      onPressed: () => dashboardVM.changeIndex(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color:
                isSelected ? AppColors.primary : AppColors.textSecondary,
            size: isMobile ? 20 : (isTablet ? 24 : 28),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontSize: isMobile ? 10 : (isTablet ? 12 : 14),
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: isTablet ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItemInicio(
    DashboardViewModel dashboardVM, {
    bool isMobile = false,
    bool isTablet = false,
    bool isDesktop = false,
  }) {
    final isSelected = dashboardVM.selectedIndex == 3;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSpacing.medium : AppSpacing.large,
      ),
      child: GestureDetector(
        onTap: () => dashboardVM.changeIndex(3),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.success,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          width: isMobile ? 56 : (isTablet ? 64 : 72),
          height: isMobile ? 56 : (isTablet ? 64 : 72),
          child: const Icon(Icons.home, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}