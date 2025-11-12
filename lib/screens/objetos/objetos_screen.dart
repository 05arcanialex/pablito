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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (vm.loading || vm.vehiculoSeleccionado == null)
            ? null
            : () => _onAddInventario(context, vm),
        icon: const Icon(Icons.add),
        label: const Text('AGREGAR OBJETO'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: vm.loading && vm.clientes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _content(context, vm),
    );
  }

  Widget _content(BuildContext context, ObjetosViewModel vm) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.large),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'OBJETOS ENCONTRADOS EN EL VEHÍCULO',
                style: AppTextStyles.heading2.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: vm.vehiculoSeleccionado == null ? null : () => _verGaleria(context, vm),
              icon: const Icon(Icons.photo_library),
              label: const Text('VER GALERÍA'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.medium),

        // CLIENTES
        Card(
          elevation: 2,
          child: ExpansionTile(
            initiallyExpanded: true,
            title: const Text('CLIENTES'),
            subtitle: Text(vm.clientes.isEmpty ? 'SIN CLIENTES' : '${vm.clientes.length} CLIENTE(S)'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        labelText: 'BUSCAR CLIENTE',
                      ),
                      onChanged: vm.setBuscarCliente,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _clientesTable(context, vm),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.medium),

        // VEHÍCULOS
        Card(
          elevation: 2,
          child: ExpansionTile(
            initiallyExpanded: vm.vehiculoSeleccionado != null,
            title: const Text('VEHÍCULOS DEL CLIENTE'),
            subtitle: Text(
              vm.clienteSeleccionado == null
                  ? 'SELECCIONA UN CLIENTE'
                  : (vm.vehiculos.isEmpty ? 'SIN VEHÍCULOS' : '${vm.vehiculos.length} VEHÍCULO(S)'),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (vm.clienteSeleccionado == null)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('PRIMERO, SELECCIONA UN CLIENTE EN EL PANEL SUPERIOR.'),
                )
              else
                _vehiculosChips(context, vm),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.medium),

        // INVENTARIO (OBJETOS)
        Card(
          elevation: 2,
          child: ExpansionTile(
            initiallyExpanded: vm.vehiculoSeleccionado != null,
            title: const Text('OBJETOS REGISTRADOS EN EL VEHÍCULO'),
            subtitle: Text(
              vm.vehiculoSeleccionado == null
                  ? 'SELECCIONA UN VEHÍCULO'
                  : (vm.inventario.isEmpty ? 'SIN OBJETOS' : '${vm.inventario.length} OBJETO(S)'),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (vm.vehiculoSeleccionado == null)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('SELECCIONA UN VEHÍCULO PARA VER/REGISTRAR SUS OBJETOS.'),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _inventarioFilters(vm),
                    const SizedBox(height: 12),
                    vm.vistaCards ? _inventarioCards(vm) : _inventarioTable(vm),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- CLIENTES ----------
  Widget _clientesTable(BuildContext context, ObjetosViewModel vm) {
    if (vm.clientes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('SIN REGISTROS'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(AppColors.primary.withOpacity(0.08)),
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
                  DataCell(Text('${c.codCliente}')),
                  DataCell(Text(c.nombre)),
                  DataCell(Text('${c.vehiculos}')),
                  DataCell(
                    FilledButton.icon(
                      icon: const Icon(Icons.garage),
                      label: const Text('VER VEHÍCULOS'),
                      onPressed: vm.loading ? null : () => vm.loadVehiculosDeCliente(c.codCliente),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  // ---------- VEHÍCULOS ----------
  Widget _vehiculosChips(BuildContext context, ObjetosViewModel vm) {
    if (vm.vehiculos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('ESTE CLIENTE AÚN NO TIENE VEHÍCULOS.'),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: vm.vehiculos
          .map(
            (v) => ChoiceChip(
              label: Text(v.label, overflow: TextOverflow.ellipsis),
              selected: vm.vehiculoSeleccionado == v.codVehiculo,
              onSelected: vm.loading ? null : (ok) => vm.loadInventarioVehiculo(v.codVehiculo),
            ),
          )
          .toList(),
    );
  }

  // ---------- FILTROS INVENTARIO ----------
  Widget _inventarioFilters(ObjetosViewModel vm) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
              labelText: 'BUSCAR OBJETO (NOMBRE/DESCRIPCIÓN)',
            ),
            onChanged: vm.setBuscarInventario,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            value: vm.filtroEstado,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'ESTADO'),
            items: const [
              DropdownMenuItem(value: 'TODOS', child: Text('TODOS')),
              DropdownMenuItem(value: 'BUENO', child: Text('BUENO')),
              DropdownMenuItem(value: 'REGULAR', child: Text('REGULAR')),
              DropdownMenuItem(value: 'MALO', child: Text('MALO')),
            ],
            onChanged: (v) => vm.setFiltroEstado(v ?? 'TODOS'),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          onPressed: vm.toggleVistaCards,
          icon: Icon(vm.vistaCards ? Icons.table_rows : Icons.view_agenda),
          tooltip: vm.vistaCards ? 'VER EN TABLA' : 'VER EN CARDS',
        ),
      ],
    );
  }

  // ---------- TABLA ----------
  Widget _inventarioTable(ObjetosViewModel vm) {
    final rows = vm.inventario;
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('SIN OBJETOS'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(AppColors.primary.withOpacity(0.08)),
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
                  DataCell(Text('${e.codRegInvVeh}')),
                  DataCell(_thumb(e.fotoPath)),
                  DataCell(Text(e.nombreItem)),
                  DataCell(Text(e.descripcion.isEmpty ? '—' : e.descripcion)),
                  DataCell(Text('${e.cantidad}')),
                  DataCell(Text(e.estado ?? '—')),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'EDITAR',
                        onPressed: () => _onEditInventario(vm, e),
                        icon: const Icon(Icons.edit, color: AppColors.primary),
                      ),
                      IconButton(
                        tooltip: 'ELIMINAR',
                        onPressed: () => _onDeleteInventario(vm, e),
                        icon: const Icon(Icons.delete_forever, color: AppColors.accent),
                      ),
                    ],
                  )),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  // ---------- CARDS ----------
  Widget _inventarioCards(ObjetosViewModel vm) {
    final rows = vm.inventario;
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('SIN OBJETOS'),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.45,
      ),
      itemBuilder: (context, i) {
        final e = rows[i];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _chipEstado(e.estado),
                const SizedBox(height: 6),
                Expanded(child: Center(child: _thumb(e.fotoPath, radius: 10, size: 110))),
                const SizedBox(height: 6),
                Text(e.nombreItem, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(e.descripcion.isEmpty ? '—' : e.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.format_list_numbered, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text('${e.cantidad}', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800)),
                    ]),
                    Row(children: [
                      IconButton(
                        tooltip: 'EDITAR',
                        onPressed: () => _onEditInventario(vm, e),
                        icon: const Icon(Icons.edit, color: AppColors.primary),
                      ),
                      IconButton(
                        tooltip: 'ELIMINAR',
                        onPressed: () => _onDeleteInventario(vm, e),
                        icon: const Icon(Icons.delete_forever, color: AppColors.accent),
                      ),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- DIALOGO: AGREGAR (SIN CATÁLOGO) ----------
  Future<void> _onAddInventario(BuildContext context, ObjetosViewModel vm) async {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final cantCtrl = TextEditingController(text: '1');
    String estadoSel = 'REGULAR';
    String? fotoPath;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSB) => AlertDialog(
          title: const Text('REGISTRAR OBJETO ENCONTRADO'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _fotoPreview(fotoPath),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('CÁMARA'),
                    onPressed: () async {
                      final p = await vm.takePhoto();
                      if (p != null) setSB(() => fotoPath = p);
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('GALERÍA'),
                    onPressed: () async {
                      final p = await vm.pickFromGallery();
                      if (p != null) setSB(() => fotoPath = p);
                    },
                  ),
                  if (fotoPath != null)
                    TextButton.icon(
                      icon: const Icon(Icons.clear),
                      label: const Text('QUITAR'),
                      onPressed: () => setSB(() => fotoPath = null),
                    ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'NOMBRE DEL OBJETO', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'OBLIGATORIO' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'DESCRIPCIÓN (OPCIONAL)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: cantCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'CANTIDAD', border: OutlineInputBorder()),
                      validator: (v) => (int.tryParse((v ?? '').trim()) == null) ? 'CANTIDAD INVÁLIDA' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: estadoSel,
                      items: const [
                        DropdownMenuItem(value: 'BUENO', child: Text('BUENO')),
                        DropdownMenuItem(value: 'REGULAR', child: Text('REGULAR')),
                        DropdownMenuItem(value: 'MALO', child: Text('MALO')),
                      ],
                      onChanged: (v) => setSB(() => estadoSel = v ?? 'REGULAR'),
                      decoration: const InputDecoration(labelText: 'ESTADO', border: OutlineInputBorder()),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('GUARDAR'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final ok = await vm.crearInventario(
                  nombreObjeto: nombreCtrl.text,
                  descripcionObjeto: descCtrl.text,
                  cantidad: int.tryParse(cantCtrl.text.trim()) ?? 1,
                  estado: estadoSel,
                  fotoPath: fotoPath,
                );
                if (context.mounted) Navigator.pop(context, ok);
              },
            ),
          ],
        ),
      ),
    );

    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OBJETO REGISTRADO')));
    } else if (ok == false && context.mounted) {
      final msg = vm.error ?? 'NO SE PUDO REGISTRAR';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ---------- DIALOGO: EDITAR (SIN CATÁLOGO) ----------
  Future<void> _onEditInventario(ObjetosViewModel vm, InvItemVM e) async {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController(text: e.nombreItem);
    final descCtrl = TextEditingController(text: e.descripcion);
    final cantCtrl = TextEditingController(text: '${e.cantidad}');
    String estadoSel = (e.estado ?? 'REGULAR').toUpperCase();
    String? fotoPath = e.fotoPath;

    final ok = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (_) => StatefulBuilder(
        builder: (context, setSB) => AlertDialog(
          title: Text('EDITAR OBJETO #${e.codRegInvVeh}'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _fotoPreview(fotoPath),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('CÁMARA'),
                    onPressed: () async {
                      final p = await vm.takePhoto();
                      if (p != null) setSB(() => fotoPath = p);
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('GALERÍA'),
                    onPressed: () async {
                      final p = await vm.pickFromGallery();
                      if (p != null) setSB(() => fotoPath = p);
                    },
                  ),
                  if (fotoPath != null)
                    TextButton.icon(
                      icon: const Icon(Icons.clear),
                      label: const Text('QUITAR'),
                      onPressed: () => setSB(() => fotoPath = null),
                    ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'NOMBRE DEL OBJETO', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'OBLIGATORIO' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'DESCRIPCIÓN (OPCIONAL)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: cantCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'CANTIDAD', border: OutlineInputBorder()),
                      validator: (v) => (int.tryParse((v ?? '').trim()) == null) ? 'CANTIDAD INVÁLIDA' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: estadoSel,
                      items: const [
                        DropdownMenuItem(value: 'BUENO', child: Text('BUENO')),
                        DropdownMenuItem(value: 'REGULAR', child: Text('REGULAR')),
                        DropdownMenuItem(value: 'MALO', child: Text('MALO')),
                      ],
                      onChanged: (v) => setSB(() => estadoSel = v ?? 'REGULAR'),
                      decoration: const InputDecoration(labelText: 'ESTADO', border: OutlineInputBorder()),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('GUARDAR'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final ok = await vm.editarInventario(
                  codRegInvVeh: e.codRegInvVeh,
                  codInvVeh: e.codInvVeh,
                  nombreObjeto: nombreCtrl.text,
                  descripcionObjeto: descCtrl.text,
                  cantidad: int.tryParse(cantCtrl.text.trim()) ?? e.cantidad,
                  estado: estadoSel,
                  fotoPath: fotoPath,
                );
                if (context.mounted) Navigator.pop(context, ok);
              },
            ),
          ],
        ),
      ),
    );

    if (ok == true && navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(content: Text('OBJETO ACTUALIZADO')),
      );
    } else if (ok == false && navigatorKey.currentContext != null) {
      final msg = vm.error ?? 'NO SE PUDO ACTUALIZAR';
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _onDeleteInventario(ObjetosViewModel vm, InvItemVM e) async {
    final ok = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (_) => AlertDialog(
        title: const Text('ELIMINAR OBJETO'),
        content: Text('¿DESEAS ELIMINAR "${e.nombreItem}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(navigatorKey.currentContext!, false), child: const Text('CANCELAR')),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.delete),
            label: const Text('ELIMINAR'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(navigatorKey.currentContext!, true),
          ),
        ],
      ),
    );

    if (ok == true) {
      final deleted = await vm.eliminarInventario(e.codRegInvVeh);
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(content: Text(deleted ? 'OBJETO ELIMINADO' : 'NO SE PUDO ELIMINAR')),
        );
      }
    }
  }

  Future<void> _verGaleria(BuildContext context, ObjetosViewModel vm) async {
    final fotos = vm.fotosDelVehiculo();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('GALERÍA DE OBJETOS DEL VEHÍCULO'),
        content: fotos.isEmpty
            ? const Text('SIN FOTOS REGISTRADAS.')
            : SizedBox(
                width: 480,
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: fotos.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1,
                  ),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(fotos[i]), fit: BoxFit.cover),
                  ),
                ),
              ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CERRAR'))],
      ),
    );
  }

  Widget _thumb(String? path, {double size = 56, double radius = 6}) {
    if (path == null || path.trim().isEmpty || !File(path).existsSync()) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: const Icon(Icons.image_not_supported, color: AppColors.textSecondary),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(File(path), width: size, height: size, fit: BoxFit.cover),
    );
  }

  Widget _fotoPreview(String? path) {
    return Container(
      width: 220,
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: (path != null && File(path).existsSync())
          ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(path), fit: BoxFit.cover))
          : const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.photo, size: 36, color: AppColors.textSecondary),
              SizedBox(height: 6),
              Text('SIN FOTO', style: TextStyle(color: AppColors.textSecondary)),
            ])),
    );
  }

  Widget _chipEstado(String? estado) {
    final t = (estado ?? 'REGULAR').toUpperCase();
    Color bg;
    switch (t) {
      case 'BUENO':
        bg = AppColors.success.withOpacity(0.15);
        break;
      case 'MALO':
        bg = AppColors.accent.withOpacity(0.15);
        break;
      default:
        bg = AppColors.secondary.withOpacity(0.15);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(t, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800)),
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
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      ),
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
