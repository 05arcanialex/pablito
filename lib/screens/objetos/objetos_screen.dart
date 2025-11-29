import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/constants.dart';
import '../../viewmodels/objetos_viewmodel.dart';

class ObjetosScreen extends StatelessWidget {
  const ObjetosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ObjetosViewModel()..init(),
      child: const _ObjetosBody(),
    );
  }
}

class _ObjetosBody extends StatelessWidget {
  const _ObjetosBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ObjetosViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: (vm.loading || vm.vehiculoSeleccionado == null)
            ? null
            : () => _onAddInventario(context, vm),
        child: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: vm.loading && vm.clientes.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 3,
              ),
            )
          : _content(context, vm),
    );
  }

  Widget _content(BuildContext context, ObjetosViewModel vm) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8FBFF),
            Color(0xFFE6F2FF),
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.primary.withOpacity(0.9),
                  AppColors.primary.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'OBJETOS ENCONTRADOS EN EL VEHÍCULO',
                    style: AppTextStyles.heading2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: vm.vehiculoSeleccionado == null
                      ? null
                      : () => _verGaleriaCompleta(context, vm),
                  icon: const Icon(Icons.photo_library, size: 20),
                  label: const Text('VER GALERÍA'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.large),

          // CLIENTES
          _buildSectionCard(
            title: 'CLIENTES',
            subtitle: vm.clientes.isEmpty
                ? 'SIN CLIENTES'
                : '${vm.clientes.length} CLIENTE(S)',
            icon: Icons.people,
            initiallyExpanded: true,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueGrey.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.search,
                              color: AppColors.primary),
                          labelText: 'BUSCAR CLIENTE',
                          labelStyle:
                              const TextStyle(color: Colors.blueGrey),
                        ),
                        onChanged: vm.setBuscarCliente,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _clientesTable(context, vm),
            ],
          ),

          const SizedBox(height: AppSpacing.medium),

          // VEHÍCULOS
          _buildSectionCard(
            title: 'VEHÍCULOS DEL CLIENTE',
            subtitle: vm.clienteSeleccionado == null
                ? 'SELECCIONA UN CLIENTE'
                : (vm.vehiculos.isEmpty
                    ? 'SIN VEHÍCULOS'
                    : '${vm.vehiculos.length} VEHÍCULO(S)'),
            icon: Icons.directions_car,
            initiallyExpanded: vm.vehiculoSeleccionado != null,
            children: [
              if (vm.clienteSeleccionado == null)
                _buildEmptyState(
                  icon: Icons.person_search,
                  message:
                      'PRIMERO, SELECCIONA UN CLIENTE EN EL PANEL SUPERIOR.',
                )
              else
                _vehiculosChips(context, vm),
            ],
          ),

          const SizedBox(height: AppSpacing.medium),

          // INVENTARIO (OBJETOS)
          _buildSectionCard(
            title: 'OBJETOS REGISTRADOS EN EL VEHÍCULO',
            subtitle: vm.vehiculoSeleccionado == null
                ? 'SELECCIONA UN VEHÍCULO'
                : (vm.inventario.isEmpty
                    ? 'SIN OBJETOS'
                    : '${vm.inventario.length} OBJETO(S)'),
            icon: Icons.category,
            initiallyExpanded: vm.vehiculoSeleccionado != null,
            children: [
              if (vm.vehiculoSeleccionado == null)
                _buildEmptyState(
                  icon: Icons.car_repair,
                  message:
                      'SELECCIONA UN VEHÍCULO PARA VER/REGISTRAR SUS OBJETOS.',
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _inventarioFilters(context, vm),
                    const SizedBox(height: 16),
                    vm.vistaCards
                        ? _inventarioCards(context, vm)
                        : _inventarioTable(context, vm),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool initiallyExpanded,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              AppColors.primary.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, color: AppColors.primary),
          title: Text(
            title,
            style: AppTextStyles.heading3.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              color: Colors.blueGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: children,
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.primary.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.primary.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- CLIENTES ----------
  Widget _clientesTable(BuildContext context, ObjetosViewModel vm) {
    if (vm.clientes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        message: 'NO SE ENCONTRARON CLIENTES',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        ),
        child: DataTable(
          headingRowColor:
              MaterialStateProperty.all(AppColors.primary.withOpacity(0.08)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          columns: const [
            DataColumn(label: _Hdr('CÓDIGO')),
            DataColumn(label: _Hdr('CLIENTE')),
            DataColumn(label: _Hdr('VEHÍCULOS')),
            DataColumn(label: _Hdr('ACCIONES')),
          ],
          rows: vm.clientes
              .map(
                (c) => DataRow(
                  cells: [
                    DataCell(Text('${c.codCliente}',
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(c.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${c.vehiculos}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          )),
                    )),
                    DataCell(
                      FilledButton.icon(
                        icon: const Icon(Icons.garage, size: 16),
                        label: const Text('VER VEHÍCULOS'),
                        onPressed: vm.loading
                            ? null
                            : () => vm.loadVehiculosDeCliente(c.codCliente),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ---------- VEHÍCULOS ----------
  Widget _vehiculosChips(BuildContext context, ObjetosViewModel vm) {
    if (vm.vehiculos.isEmpty) {
      return _buildEmptyState(
        icon: Icons.directions_car_outlined,
        message: 'ESTE CLIENTE AÚN NO TIENE VEHÍCULOS.',
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: vm.vehiculos
          .map(
            (v) => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ChoiceChip(
                label: Text(
                  v.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                selected: vm.vehiculoSeleccionado == v.codVehiculo,
                onSelected: vm.loading
                    ? null
                    : (ok) => vm.loadInventarioVehiculo(v.codVehiculo),
                selectedColor: AppColors.primary,
                checkmarkColor: Colors.white,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                labelStyle: TextStyle(
                  color: vm.vehiculoSeleccionado == v.codVehiculo
                      ? Colors.white
                      : AppColors.primary,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ---------- FILTROS INVENTARIO ----------
  Widget _inventarioFilters(BuildContext context, ObjetosViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Helpers para no repetir código
          Widget buildSearchBox() {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueGrey.withOpacity(0.08),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.primary),
                  labelText: 'BUSCAR OBJETO (NOMBRE/DESCRIPCIÓN)',
                  labelStyle: const TextStyle(color: Colors.blueGrey),
                ),
                onChanged: vm.setBuscarInventario,
              ),
            );
          }

          Widget buildEstadoDropdown() {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueGrey.withOpacity(0.08),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: DropdownButtonFormField<String>(
                value: vm.filtroEstado,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'ESTADO',
                  labelStyle: const TextStyle(color: Colors.blueGrey),
                ),
                items: const [
                  DropdownMenuItem(value: 'TODOS', child: Text('TODOS')),
                  DropdownMenuItem(value: 'BUENO', child: Text('BUENO')),
                  DropdownMenuItem(value: 'REGULAR', child: Text('REGULAR')),
                  DropdownMenuItem(value: 'MALO', child: Text('MALO')),
                ],
                onChanged: (v) => vm.setFiltroEstado(v ?? 'TODOS'),
              ),
            );
          }

          Widget buildDeleteButton() {
            return FittedBox(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton.filled(
                  onPressed: vm.inventario.isEmpty
                      ? null
                      : () => _eliminarTodosObjetos(context, vm),
                  icon:
                      const Icon(Icons.delete_sweep, color: Colors.white, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  tooltip: 'ELIMINAR TODOS LOS OBJETOS',
                ),
              ),
            );
          }

          final isNarrow = constraints.maxWidth < 520;

          if (isNarrow) {
            // DISEÑO PARA PANTALLAS ESTRECHAS (EVITA OVERFLOW):
            // 1) BUSCADOR
            // 2) DROPDOWN ESTADO
            // 3) BOTÓN ELIMINAR ABAJO A LA DERECHA
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildSearchBox(),
                const SizedBox(height: 12),
                buildEstadoDropdown(),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: buildDeleteButton(),
                ),
              ],
            );
          }

          // DISEÑO HORIZONTAL PARA PANTALLAS AMPLIAS
          return Row(
            children: [
              Expanded(child: buildSearchBox()),
              const SizedBox(width: 16),
              SizedBox(width: 230, child: buildEstadoDropdown()),
              const SizedBox(width: 16),
              buildDeleteButton(),
            ],
          );
        },
      ),
    );
  }

  // ---------- TABLA ----------
  Widget _inventarioTable(BuildContext context, ObjetosViewModel vm) {
    final rows = vm.inventario;
    if (rows.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        message: 'NO SE ENCONTRARON OBJETOS',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.blueGrey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: DataTable(
          headingRowColor:
              MaterialStateProperty.all(AppColors.primary.withOpacity(0.08)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          columns: const [
            DataColumn(label: _Hdr('CÓDIGO')),
            DataColumn(label: _Hdr('FOTO')),
            DataColumn(label: _Hdr('OBJETO')),
            DataColumn(label: _Hdr('DESCRIPCIÓN')),
            DataColumn(label: _Hdr('CANT.')),
            DataColumn(label: _Hdr('ESTADO')),
            DataColumn(label: _Hdr('ACCIONES')),
          ],
          rows: rows
              .map(
                (e) => DataRow(
                  cells: [
                    DataCell(Text('${e.codRegInvVeh}',
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(_thumb(e.fotoPath)),
                    DataCell(Text(e.nombreItem,
                        style: const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Text(
                        e.descripcion.isEmpty ? '—' : e.descripcion)),
                    DataCell(Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${e.cantidad}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            )),
                      ),
                    )),
                    DataCell(_chipEstado(e.estado)),
                    DataCell(
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Botón Editar
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              maxWidth: 40,
                              minHeight: 36,
                              maxHeight: 40,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              tooltip: 'EDITAR OBJETO',
                              onPressed: () =>
                                  _onEditInventario(context, vm, e),
                              icon: Icon(Icons.edit,
                                  color: AppColors.primary, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Botón Eliminar
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              maxWidth: 40,
                              minHeight: 36,
                              maxHeight: 40,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              tooltip: 'ELIMINAR OBJETO',
                              onPressed: () =>
                                  _onDeleteInventario(context, vm, e),
                              icon: Icon(Icons.delete_forever,
                                  color: AppColors.accent, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ---------- CARDS ----------
  Widget _inventarioCards(BuildContext context, ObjetosViewModel vm) {
    final rows = vm.inventario;
    if (rows.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        message: 'NO SE ENCONTRARON OBJETOS',
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, i) {
        final e = rows[i];
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    AppColors.primary.withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _chipEstado(e.estado),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueGrey.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _thumb(e.fotoPath, radius: 12, size: 110),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.nombreItem,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading3.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.descripcion.isEmpty ? '—' : e.descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.format_list_numbered,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text('${e.cantidad}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  )),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Botón Editar
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                maxWidth: 36,
                                minHeight: 32,
                                maxHeight: 36,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                tooltip: 'EDITAR OBJETO',
                                onPressed: () =>
                                    _onEditInventario(context, vm, e),
                                icon: Icon(Icons.edit,
                                    color: AppColors.primary, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Botón Eliminar
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                maxWidth: 36,
                                minHeight: 32,
                                maxHeight: 36,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                tooltip: 'ELIMINAR OBJETO',
                                onPressed: () =>
                                    _onDeleteInventario(context, vm, e),
                                icon: Icon(Icons.delete_forever,
                                    color: AppColors.accent, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- GALERÍA COMPLETA DE IMÁGENES ----------
  Future<void> _verGaleriaCompleta(
      BuildContext context, ObjetosViewModel vm) async {
    final objetosConFotos = vm.inventario
        .where((objeto) =>
            objeto.fotoPath != null &&
            objeto.fotoPath!.trim().isNotEmpty &&
            File(objeto.fotoPath!).existsSync())
        .toList();

    if (objetosConFotos.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library,
                    size: 64, color: AppColors.primary.withOpacity(0.7)),
                const SizedBox(height: 16),
                Text(
                  'GALERÍA DE OBJETOS',
                  style: AppTextStyles.heading2.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No hay imágenes registradas para los objetos de este vehículo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('CERRAR'),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.95,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                AppColors.primary.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.primary.withOpacity(0.9),
                      AppColors.primary.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'GALERÍA DE OBJETOS (${objetosConFotos.length} IMÁGENES)',
                        style: AppTextStyles.heading2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close,
                            size: 24, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        MediaQuery.of(context).size.width > 600 ? 2 : 1,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: objetosConFotos.length,
                  itemBuilder: (context, index) {
                    final objeto = objetosConFotos[index];
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueGrey.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                AppColors.primary.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 3,
                                child: ClipRRect(
                                  borderRadius:
                                      const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                  child: Image.file(
                                    File(objeto.fotoPath!),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primary
                                          .withOpacity(0.08),
                                      AppColors.primary
                                          .withOpacity(0.03),
                                    ],
                                  ),
                                  borderRadius:
                                      const BorderRadius.only(
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      objeto.nombreItem,
                                      style: AppTextStyles.heading3
                                          .copyWith(
                                        fontWeight:
                                            FontWeight.w700,
                                        fontSize: 16,
                                        color: AppColors.primary,
                                      ),
                                      maxLines: 2,
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    if (objeto.descripcion
                                        .isNotEmpty)
                                      Text(
                                        objeto.descripcion,
                                        style:
                                            AppTextStyles.body
                                                .copyWith(
                                          fontSize: 14,
                                          color: Colors.blueGrey,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow
                                            .ellipsis,
                                      ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .spaceBetween,
                                      children: [
                                        _chipEstadoGrande(
                                            objeto.estado),
                                        Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 8,
                                              vertical: 4),
                                          decoration:
                                              BoxDecoration(
                                            color: AppColors
                                                .primary
                                                .withOpacity(
                                                    0.1),
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                                        6),
                                          ),
                                          child: Text(
                                            'Cantidad: ${objeto.cantidad}',
                                            style: AppTextStyles
                                                .body
                                                .copyWith(
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                              color: AppColors
                                                  .primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'CERRAR GALERÍA',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- DIALOGO: ELIMINAR TODOS LOS OBJETOS ----------
  Future<void> _eliminarTodosObjetos(
      BuildContext context, ObjetosViewModel vm) async {
    final cantidad = vm.inventario.length;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                AppColors.primary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning,
                    color: AppColors.accent, size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                'ELIMINAR TODOS LOS OBJETOS',
                style: AppTextStyles.heading2.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '¿Estás seguro de que deseas eliminar TODOS los objetos de este vehículo?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Se eliminarán $cantidad objeto(s) permanentemente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Esta acción no se puede deshacer.',
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.blueGrey),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                        side: BorderSide(color: AppColors.primary),
                      ),
                      child: Text(
                        'CANCELAR',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.delete_forever),
                      label: Text('ELIMINAR ($cantidad)'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                      ),
                      onPressed: () =>
                          Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmado == true) {
      final eliminados = await vm.eliminarTodosLosObjetos();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              eliminados
                  ? 'SE ELIMINARON TODOS LOS OBJETOS ($cantidad)'
                  : 'ERROR AL ELIMINAR LOS OBJETOS',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor:
                eliminados ? AppColors.success : AppColors.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ---------- DIALOGO: AGREGAR OBJETO ----------
  Future<void> _onAddInventario(
      BuildContext context, ObjetosViewModel vm) async {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int cantidad = 1;
    String estadoSel = 'REGULAR';
    String? fotoPath;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                AppColors.primary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: StatefulBuilder(
            builder: (context, setSB) {
              final media = MediaQuery.of(context);
              return AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: media.size.height * 0.9,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // CABECERA
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              AppColors.primary.withOpacity(0.9),
                              AppColors.primary.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add_circle,
                                color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'REGISTRAR OBJETO ENCONTRADO',
                                style: AppTextStyles.heading2.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // CUERPO SCROLLEABLE
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: formKey,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _fotoPreview(fotoPath),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.photo_camera,
                                            size: 18),
                                        label: const Text('CÁMARA'),
                                        onPressed: () async {
                                          final p = await vm.takePhoto();
                                          if (p != null) {
                                            setSB(() => fotoPath = p);
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.photo_library,
                                            size: 18),
                                        label: const Text('GALERÍA'),
                                        onPressed: () async {
                                          final p =
                                              await vm.pickFromGallery();
                                          if (p != null) {
                                            setSB(() => fotoPath = p);
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      ),
                                      if (fotoPath != null)
                                        TextButton.icon(
                                          icon: const Icon(Icons.clear,
                                              size: 18),
                                          label: const Text('QUITAR'),
                                          onPressed: () =>
                                              setSB(() => fotoPath = null),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                AppColors.accent,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: nombreCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'NOMBRE DEL OBJETO *',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    validator: (v) {
                                      if (v == null ||
                                          v.trim().isEmpty) {
                                        return 'OBLIGATORIO';
                                      }
                                      if (v.trim().length < 2) {
                                        return 'MÍNIMO 2 CARACTERES';
                                      }
                                      return null;
                                    },
                                    onChanged: (v) {
                                      if (v != v.toUpperCase()) {
                                        nombreCtrl.value =
                                            TextEditingValue(
                                          text: v.toUpperCase(),
                                          selection:
                                              TextSelection.collapsed(
                                                  offset: v.length),
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: descCtrl,
                                    maxLines: 2,
                                    decoration: InputDecoration(
                                      labelText:
                                          'DESCRIPCIÓN (OPCIONAL)',
                                   

                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    onChanged: (v) {
                                      if (v.isNotEmpty &&
                                          v[0] != v[0].toUpperCase()) {
                                        descCtrl.value =
                                            TextEditingValue(
                                          text: v[0].toUpperCase() +
                                              v.substring(1),
                                          selection:
                                              TextSelection.collapsed(
                                                  offset: v.length),
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'CANTIDAD *',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w600,
                                                color: Colors.blueGrey,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        12),
                                                border: Border.all(
                                                    color: Colors
                                                        .grey.shade300),
                                              ),
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.remove),
                                                    onPressed: () {
                                                      if (cantidad >
                                                          1) {
                                                        setSB(() =>
                                                            cantidad--);
                                                      }
                                                    },
                                                    style: IconButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          cantidad > 1
                                                              ? AppColors
                                                                  .primary
                                                                  .withOpacity(
                                                                      0.1)
                                                              : Colors.grey
                                                                  .shade200,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      cantidad
                                                          .toString(),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style:
                                                          const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight
                                                                .w600,
                                                        color: AppColors
                                                            .primary,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.add),
                                                    onPressed: () {
                                                      setSB(() =>
                                                          cantidad++);
                                                    },
                                                    style: IconButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          AppColors
                                                              .primary
                                                              .withOpacity(
                                                                  0.1),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child:
                                            DropdownButtonFormField<String>(
                                          value: estadoSel,
                                          decoration: InputDecoration(
                                            labelText: 'ESTADO *',
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                            12)),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                                value: 'BUENO',
                                                child: Text('BUENO')),
                                            DropdownMenuItem(
                                                value: 'REGULAR',
                                                child:
                                                    Text('REGULAR')),
                                            DropdownMenuItem(
                                                value: 'MALO',
                                                child: Text('MALO')),
                                          ],
                                          onChanged: (v) => setSB(
                                              () => estadoSel =
                                                  v ?? 'REGULAR'),
                                          validator: (v) => v == null
                                              ? 'SELECCIONA UN ESTADO'
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    '* Campos obligatorios',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // BOTONES INFERIORES
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.blueGrey.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  side: BorderSide(
                                      color: AppColors.primary),
                                ),
                                child: Text(
                                  'CANCELAR',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                icon: const Icon(Icons.save,
                                    size: 20),
                                label: const Text('GUARDAR'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                onPressed: () async {
                                  if (!formKey.currentState!
                                      .validate()) return;

                                  if (nombreCtrl.text
                                          .trim()
                                          .length <
                                      2) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'El nombre debe tener al menos 2 caracteres'),
                                        backgroundColor:
                                            AppColors.accent,
                                      ),
                                    );
                                    return;
                                  }

                                  final ok =
                                      await vm.crearInventario(
                                    nombreObjeto: nombreCtrl.text
                                        .trim(),
                                    descripcionObjeto:
                                        descCtrl.text.trim(),
                                    cantidad: cantidad,
                                    estado: estadoSel,
                                    fotoPath: fotoPath,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context, ok);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'OBJETO REGISTRADO CORRECTAMENTE'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else if (ok == false && context.mounted) {
      final msg = vm.error ?? 'NO SE PUDO REGISTRAR EL OBJETO';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ---------- DIALOGO: EDITAR OBJETO ----------
  Future<void> _onEditInventario(
      BuildContext context, ObjetosViewModel vm, InvItemVM e) async {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController(text: e.nombreItem);
    final descCtrl = TextEditingController(text: e.descripcion);
    int cantidad = e.cantidad;
    String estadoSel = (e.estado ?? 'REGULAR').toUpperCase();
    String? fotoPath = e.fotoPath;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                AppColors.primary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: StatefulBuilder(
            builder: (context, setSB) {
              final media = MediaQuery.of(context);
              return AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: media.size.height * 0.9,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // CABECERA
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              AppColors.primary.withOpacity(0.9),
                              AppColors.primary.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'EDITAR OBJETO #${e.codRegInvVeh}',
                                style: AppTextStyles.heading2.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // CUERPO SCROLLEABLE
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: formKey,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // SECCIÓN FOTO
                                  _fotoPreview(fotoPath),
                                  const SizedBox(height: 16),
                                  
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.photo_camera, size: 18),
                                        label: const Text('CÁMARA'),
                                        onPressed: () async {
                                          final p = await vm.takePhoto();
                                          if (p != null) {
                                            setSB(() => fotoPath = p);
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.photo_library, size: 18),
                                        label: const Text('GALERÍA'),
                                        onPressed: () async {
                                          final p = await vm.pickFromGallery();
                                          if (p != null) {
                                            setSB(() => fotoPath = p);
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                      if (fotoPath != null)
                                        TextButton.icon(
                                          icon: const Icon(Icons.clear, size: 18),
                                          label: const Text('QUITAR'),
                                          onPressed: () => setSB(() => fotoPath = null),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.accent,
                                          ),
                                        ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // SECCIÓN NOMBRE
                                  TextFormField(
                                    controller: nombreCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'NOMBRE DEL OBJETO *',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    textCapitalization: TextCapitalization.characters,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'OBLIGATORIO';
                                      }
                                      if (v.trim().length < 2) {
                                        return 'MÍNIMO 2 CARACTERES';
                                      }
                                      return null;
                                    },
                                    onChanged: (v) {
                                      if (v != v.toUpperCase()) {
                                        nombreCtrl.value = TextEditingValue(
                                          text: v.toUpperCase(),
                                          selection: TextSelection.collapsed(offset: v.length),
                                        );
                                      }
                                    },
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  // SECCIÓN DESCRIPCIÓN
                                  TextFormField(
                                    controller: descCtrl,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      labelText: 'DESCRIPCIÓN (OPCIONAL)',
                                      alignLabelWithHint: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    textCapitalization: TextCapitalization.sentences,
                                    onChanged: (v) {
                                      if (v.isNotEmpty && v[0] != v[0].toUpperCase()) {
                                        descCtrl.value = TextEditingValue(
                                          text: v[0].toUpperCase() + v.substring(1),
                                          selection: TextSelection.collapsed(offset: v.length),
                                        );
                                      }
                                    },
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // SECCIÓN CANTIDAD Y ESTADO
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'CANTIDAD *',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blueGrey,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.grey.shade300),
                                              ),
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.remove),
                                                    onPressed: () {
                                                      if (cantidad > 1) {
                                                        setSB(() => cantidad--);
                                                      }
                                                    },
                                                    style: IconButton.styleFrom(
                                                      backgroundColor: cantidad > 1
                                                          ? AppColors.primary.withOpacity(0.1)
                                                          : Colors.grey.shade200,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      cantidad.toString(),
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppColors.primary,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.add),
                                                    onPressed: () {
                                                      setSB(() => cantidad++);
                                                    },
                                                    style: IconButton.styleFrom(
                                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: estadoSel,
                                          decoration: InputDecoration(
                                            labelText: 'ESTADO *',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'BUENO',
                                              child: Text('BUENO'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'REGULAR',
                                              child: Text('REGULAR'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'MALO',
                                              child: Text('MALO'),
                                            ),
                                          ],
                                          onChanged: (v) => setSB(() => estadoSel = v ?? 'REGULAR'),
                                          validator: (v) => v == null ? 'SELECCIONA UN ESTADO' : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  // NOTA CAMPOS OBLIGATORIOS
                                  const Text(
                                    '* Campos obligatorios',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // BOTONES INFERIORES
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueGrey.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context, false),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(color: AppColors.primary),
                                ),
                                child: Text(
                                  'CANCELAR',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: FilledButton.icon(
                                icon: const Icon(Icons.save, size: 20),
                                label: const Text(
                                  'GUARDAR CAMBIOS',
                                  style: TextStyle(fontSize: 18),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) return;

                                  if (nombreCtrl.text.trim().length < 2) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('El nombre debe tener al menos 2 caracteres'),
                                        backgroundColor: AppColors.accent,
                                      ),
                                    );
                                    return;
                                  }

                                  final ok = await vm.editarInventario(
                                    codRegInvVeh: e.codRegInvVeh,
                                    codInvVeh: e.codInvVeh,
                                    nombreObjeto: nombreCtrl.text.trim(),
                                    descripcionObjeto: descCtrl.text.trim(),
                                    cantidad: cantidad,
                                    estado: estadoSel,
                                    fotoPath: fotoPath,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(context, ok);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('OBJETO ACTUALIZADO CORRECTAMENTE'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else if (ok == false && context.mounted) {
      final msg = vm.error ?? 'NO SE PUDO ACTUALIZAR EL OBJETO';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ---------- DIALOGO: ELIMINAR OBJETO ----------
  Future<void> _onDeleteInventario(
      BuildContext context, ObjetosViewModel vm, InvItemVM e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                AppColors.primary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_forever,
                    color: AppColors.accent, size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                'ELIMINAR OBJETO',
                style: AppTextStyles.heading2.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '¿Estás seguro de que deseas eliminar el objeto "${e.nombreItem}"?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Esta acción no se puede deshacer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.blueGrey),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                        side: BorderSide(color: AppColors.primary),
                      ),
                      child: Text(
                        'CANCELAR',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.delete, size: 20),
                      label: const Text('ELIMINAR'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                      ),
                      onPressed: () =>
                          Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true) {
      final deleted =
          await vm.eliminarInventario(e.codRegInvVeh);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(deleted
                ? 'OBJETO ELIMINADO CORRECTAMENTE'
                : 'NO SE PUDO ELIMINAR EL OBJETO'),
            backgroundColor:
                deleted ? AppColors.success : AppColors.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Widget _thumb(String? path,
      {double size = 56, double radius = 8}) {
    if (path == null ||
        path.trim().isEmpty ||
        !File(path).existsSync()) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
              color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Icon(Icons.image_not_supported,
            color: AppColors.primary.withOpacity(0.5),
            size: size * 0.4),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _fotoPreview(String? path) {
    return Container(
      width: 220,
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: (path != null && File(path).existsSync())
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
              ),
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo,
                      size: 36,
                      color: AppColors.primary
                          .withOpacity(0.5)),
                  const SizedBox(height: 8),
                  Text(
                    'SIN FOTO',
                    style: TextStyle(
                      color: AppColors.primary
                          .withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _chipEstado(String? estado) {
    final t = (estado ?? 'REGULAR').toUpperCase();
    Color bg;
    Color textColor;
    switch (t) {
      case 'BUENO':
        bg = AppColors.success.withOpacity(0.15);
        textColor = AppColors.success;
        break;
      case 'MALO':
        bg = AppColors.accent.withOpacity(0.15);
        textColor = AppColors.accent;
        break;
      default:
        bg = const Color(0xFFFFA726).withOpacity(0.15);
        textColor = const Color(0xFFF57C00);
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text(
        t,
        style: AppTextStyles.body.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 10,
          color: textColor,
        ),
      ),
    );
  }

  Widget _chipEstadoGrande(String? estado) {
    final t = (estado ?? 'REGULAR').toUpperCase();
    Color bg;
    Color textColor;
    switch (t) {
      case 'BUENO':
        bg = AppColors.success.withOpacity(0.15);
        textColor = AppColors.success;
        break;
      case 'MALO':
        bg = AppColors.accent.withOpacity(0.15);
        textColor = AppColors.accent;
        break;
      default:
        bg = const Color(0xFFFFA726).withOpacity(0.15);
        textColor = const Color(0xFFF57C00);
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text(
        t,
        style: AppTextStyles.body.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          color: textColor,
        ),
      ),
    );
  }
}

class _Hdr extends StatelessWidget {
  final String t;
  const _Hdr(this.t);

  @override
  Widget build(BuildContext context) {
    return Text(
      t,
      style: AppTextStyles.body.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
        letterSpacing: 0.2,
      ),
    );
  }
}