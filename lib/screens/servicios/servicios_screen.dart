// lib/screens/servicios/servicios_screen.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../viewmodels/servicios_viewmodel.dart';

class ServiciosScreen extends StatelessWidget {
  const ServiciosScreen({super.key});

  static const String catTodos = 'TODOS';
  static const String catDiag  = 'DIAGNÓSTICO';
  static const String catMant  = 'MANTENIMIENTO';
  static const String catRep   = 'REPARACIONES EN GENERAL';
  static const String catProg  = 'PROGRAMACIÓN DE MÓDULOS';

  static const List<String> categorias = [
    catTodos, catDiag, catMant, catRep, catProg,
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiciosViewModel()..init(),
      child: const _ServiciosBody(),
    );
  }
}

class _ServiciosBody extends StatefulWidget {
  const _ServiciosBody();

  @override
  State<_ServiciosBody> createState() => _ServiciosBodyState();
}

class _ServiciosBodyState extends State<_ServiciosBody> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ServiciosViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: vm.loading ? null : () => _onRegistrar(context, vm),
        icon: const Icon(Icons.add),
        label: const Text('REGISTRAR SERVICIO'),
        backgroundColor: Color.fromARGB(255, 26, 54, 93),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildToolbarResponsive(context, vm),
          const SizedBox(height: AppSpacing.medium),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  child: _buildBody(vm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ServiciosViewModel vm) {
    if (vm.loading && vm.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null && vm.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            vm.error!,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    if (vm.items.isEmpty) {
      return const Center(child: Text('SIN REGISTROS'));
    }
    return _buildTable(vm);
  }

  Widget _buildToolbarResponsive(BuildContext context, ServiciosViewModel vm) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;

        final titleWidget = Text(
          'SERVICIOS',
          style: AppTextStyles.heading2.copyWith(
            color: Color.fromARGB(255, 26, 54, 93),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        );

        final dropdown = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Color(0xFFe8eaf6),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: vm.filtroCategoria,
              isDense: true,
              items: ServiciosScreen.categorias
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          c,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: vm.loading ? null : (v) => v != null ? vm.setFiltro(v) : null,
            ),
          ),
        );

        // Botón de Reportes - CORREGIDO
        final reportesBtn = PopupMenuButton<String>(
          color: Colors.white,
          onSelected: (value) {
            switch (value) {
              case 'servicios':
                _generarReporteServicios(context, vm);
                break;
              case 'seguimientos':
                _generarReporteSeguimientos(context, vm);
                break;
              case 'estadisticas':
                _generarReporteEstadisticas(context, vm);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'servicios',
              child: Row(
                children: [
                  Icon(Icons.description, color: Color.fromARGB(255, 26, 54, 93)),
                  SizedBox(width: 8),
                  Text('Reporte de Servicios'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'seguimientos',
              child: Row(
                children: [
                  Icon(Icons.assignment, color: Color.fromARGB(255, 26, 54, 93)),
                  SizedBox(width: 8),
                  Text('Reporte de Seguimientos'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'estadisticas',
              child: Row(
                children: [
                  Icon(Icons.bar_chart, color: Color.fromARGB(255, 26, 54, 93)),
                  SizedBox(width: 8),
                  Text('Estadísticas'),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Color.fromARGB(255, 26, 54, 93),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: const Row(
              children: [
                Icon(Icons.analytics, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('REPORTES', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.medium,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: AppSpacing.small),
                    Wrap(
                      spacing: AppSpacing.medium,
                      runSpacing: AppSpacing.small,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth - 2 * AppSpacing.large,
                            minWidth: 180,
                          ),
                          child: dropdown,
                        ),
                        reportesBtn,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: titleWidget),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: dropdown),
                    const SizedBox(width: AppSpacing.medium),
                    reportesBtn,
                  ],
                ),
        );
      },
    );
  }

  // ========== MÉTODOS DE REPORTES ==========

  Future<void> _generarReporteServicios(BuildContext context, ServiciosViewModel vm) async {
    final fechaInicioCtrl = TextEditingController();
    final fechaFinCtrl = TextEditingController();
    String tipoReporte = 'PDF';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('GENERAR REPORTE DE SERVICIOS'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: fechaInicioCtrl,
                decoration: const InputDecoration(
                  labelText: 'FECHA INICIO (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: fechaFinCtrl,
                decoration: const InputDecoration(
                  labelText: 'FECHA FIN (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tipoReporte,
                items: ['PDF', 'EXCEL', 'CSV']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => tipoReporte = v!),
                decoration: const InputDecoration(
                  labelText: 'FORMATO',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () async {
                if (fechaInicioCtrl.text.isEmpty || fechaFinCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Complete las fechas')),
                  );
                  return;
                }
                
                final resultado = await vm.generarReporteServicios(
                  fechaInicio: fechaInicioCtrl.text,
                  fechaFin: fechaFinCtrl.text,
                  formato: tipoReporte,
                );
                
                if (context.mounted) {
                  Navigator.pop(context);
                  if (resultado) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte generado en $tipoReporte')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${vm.error}')),
                    );
                  }
                }
              },
              child: const Text('GENERAR'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generarReporteSeguimientos(BuildContext context, ServiciosViewModel vm) async {
    final serviciosConSeguimiento = vm.items.where((s) => s.tieneSeguimiento).toList();
    
    if (serviciosConSeguimiento.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay servicios con seguimiento')),
      );
      return;
    }

    int? selectedServicio;
    String formato = 'PDF';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('REPORTE DE SEGUIMIENTO'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedServicio,
                items: serviciosConSeguimiento
                    .map((s) => DropdownMenuItem(
                          value: s.codSerTaller,
                          child: Text('Servicio #${s.codSerTaller} - ${s.cliente}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => selectedServicio = v),
                decoration: const InputDecoration(
                  labelText: 'SELECCIONAR SERVICIO',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: formato,
                items: ['PDF', 'EXCEL']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => formato = v!),
                decoration: const InputDecoration(
                  labelText: 'FORMATO',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: selectedServicio == null ? null : () async {
                final resultado = await vm.generarReporteSeguimiento(
                  codSerTaller: selectedServicio!,
                  formato: formato,
                );
                
                if (context.mounted) {
                  Navigator.pop(context);
                  if (resultado) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reporte de seguimiento generado')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${vm.error}')),
                    );
                  }
                }
              },
              child: const Text('GENERAR'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generarReporteEstadisticas(BuildContext context, ServiciosViewModel vm) async {
    final fechaInicioCtrl = TextEditingController();
    final fechaFinCtrl = TextEditingController();
    String tipoReporte = 'PDF';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('REPORTE DE ESTADÍSTICAS'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: fechaInicioCtrl,
                decoration: const InputDecoration(
                  labelText: 'FECHA INICIO (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: fechaFinCtrl,
                decoration: const InputDecoration(
                  labelText: 'FECHA FIN (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tipoReporte,
                items: ['PDF', 'EXCEL']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => tipoReporte = v!),
                decoration: const InputDecoration(
                  labelText: 'FORMATO',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () async {
                if (fechaInicioCtrl.text.isEmpty || fechaFinCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Complete las fechas')),
                  );
                  return;
                }
                
                final resultado = await vm.generarReporteEstadisticas(
                  fechaInicio: fechaInicioCtrl.text,
                  fechaFin: fechaFinCtrl.text,
                  formato: tipoReporte,
                );
                
                if (context.mounted) {
                  Navigator.pop(context);
                  if (resultado) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reporte de estadísticas generado en $tipoReporte')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${vm.error}')),
                    );
                  }
                }
              },
              child: const Text('GENERAR'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(ServiciosViewModel vm) {
    final rows = vm.items;

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 980),
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(
                Color.fromARGB(255, 26, 54, 93).withOpacity(0.08),
              ),
              columns: const [
                DataColumn(label: _HeaderText('CÓDIGO')),
                DataColumn(label: _HeaderText('FECHA')),
                DataColumn(label: _HeaderText('CLIENTE')),
                DataColumn(label: _HeaderText('VEHÍCULO')),
                DataColumn(label: _HeaderText('TIPOS')),
                DataColumn(label: _HeaderText('TOTAL (BS)')),
                DataColumn(label: _HeaderText('ESTADO')),
                DataColumn(label: _HeaderText('ACCIONES')),
              ],
              rows: rows
                  .map(
                    (e) => DataRow(
                      cells: [
                        DataCell(Text('${e.codSerTaller}')),
                        DataCell(Text(_fmtDate(e.fechaIngreso))),
                        DataCell(Text(e.cliente)),
                        DataCell(Text(e.vehiculo)),
                        DataCell(_TipoBadge(texto: e.tipos.isEmpty ? '—' : e.tipos)),
                        DataCell(Text(e.totalAprox.toStringAsFixed(2))),
                        DataCell(Text(e.estado ?? '—')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // BOTÓN DE SEGUIMIENTO
                              IconButton(
                                tooltip: 'SEGUIMIENTO',
                                icon: const Icon(Icons.build, color: Colors.orange),
                                onPressed: vm.loading ? null : () => _onSeguimiento(context, vm, e),
                              ),
                              IconButton(
                                tooltip: 'VER',
                                icon: const Icon(Icons.visibility, color: AppColors.textSecondary),
                                onPressed: () => _onVer(context, e),
                              ),
                              IconButton(
                                tooltip: 'EDITAR',
                                icon: const Icon(Icons.edit, color: Color.fromARGB(255, 26, 54, 93)),
                                onPressed: vm.loading ? null : () => _onEditar(context, vm, e),
                              ),
                              IconButton(
                                tooltip: 'ELIMINAR',
                                icon: const Icon(Icons.delete_forever, color: AppColors.accent),
                                onPressed: vm.loading ? null : () => _onEliminar(context, vm, e),
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
        ),
      ),
    );
  }

  // ---------- SEGUIMIENTO ----------
  Future<void> _onSeguimiento(BuildContext context, ServiciosViewModel vm, ServicioItem e) async {
    // Iniciar o cargar seguimiento existente
    final seguimiento = await vm.getSeguimiento(e.codSerTaller);
    if (seguimiento == null) {
      final iniciado = await vm.iniciarSeguimiento(e.codSerTaller);
      if (!iniciado && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar el seguimiento')),
        );
        return;
      }
    }
    
    // Mostrar diálogo de seguimiento
    if (mounted) {
      await showDialog(
        context: context,
        builder: (context) => SeguimientoDialog(
          servicio: e,
          viewModel: vm,
        ),
      );
    }
  }

  // ---------- Registrar Servicio (con cliente y vehículo) ----------
  Future<void> _onRegistrar(BuildContext context, ServiciosViewModel vm) async {
    final formKey = GlobalKey<FormState>();
    await vm.cargarClientes();

    int? selectedCliente;
    int? selectedVehiculo;
    List<VehiculoVM> vehiculos = [];

    String? tipoSel;
    final costoCtrl = TextEditingController(text: '0');
    final obsCtrl = TextEditingController();

    final nextIdFuture = vm.getNextIdRegistroServicio();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSB) => AlertDialog(
          title: const Text('REGISTRAR SERVICIO'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<int>(
                    future: nextIdFuture,
                    builder: (c, snap) {
                      final code = snap.data ?? 0;
                      return TextFormField(
                        initialValue: code > 0 ? '$code' : '—',
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'CÓDIGO (AUTOMÁTICO)',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.medium),

                  // ---- CLIENTE ----
                  ExpansionTile(
                    initiallyExpanded: true,
                    title: const Text('SELECCIONAR CLIENTE'),
                    children: [
                      if (vm.clientes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('NO HAY CLIENTES (usa seedDemo).'),
                        )
                      else
                        ...vm.clientes.map((c) {
                          final isSel = selectedCliente == c.codCliente;
                          return ListTile(
                            dense: true,
                            selected: isSel,
                            title: Text(c.nombre),
                            trailing: isSel ? const Icon(Icons.check_circle, color: Color.fromARGB(255, 26, 54, 93)) : null,
                            onTap: () async {
                              setSB(() => selectedCliente = c.codCliente);
                              // cargar vehículos del cliente
                              vehiculos = await vm.cargarVehiculosDeCliente(c.codCliente);
                              setSB(() {
                                selectedVehiculo = null;
                              });
                            },
                          );
                        }),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.small),

                  // ---- VEHÍCULO ----
                  ExpansionTile(
                    title: const Text('SELECCIONAR VEHÍCULO DEL CLIENTE'),
                    children: [
                      if (selectedCliente == null)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('PRIMERO ELIGE UN CLIENTE.'),
                        )
                      else if (vehiculos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('EL CLIENTE NO TIENE VEHÍCULOS.'),
                        )
                      else
                        ...vehiculos.map((v) {
                          final isSel = selectedVehiculo == v.codVehiculo;
                          return ListTile(
                            dense: true,
                            selected: isSel,
                            title: Text(v.label),
                            trailing: isSel ? const Icon(Icons.check_circle, color: Color.fromARGB(255, 26, 54, 93)) : null,
                            onTap: () => setSB(() => selectedVehiculo = v.codVehiculo),
                          );
                        }),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.small),

                  // ---- TIPO / COSTO / OBS ----
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    child: DropdownButtonFormField<String>(
                      value: tipoSel,
                      items: const [
                        DropdownMenuItem(value: ServiciosScreen.catDiag, child: Text(ServiciosScreen.catDiag)),
                        DropdownMenuItem(value: ServiciosScreen.catMant, child: Text(ServiciosScreen.catMant)),
                        DropdownMenuItem(value: ServiciosScreen.catRep,  child: Text(ServiciosScreen.catRep)),
                        DropdownMenuItem(value: ServiciosScreen.catProg, child: Text(ServiciosScreen.catProg)),
                      ],
                      onChanged: (v) => setSB(() => tipoSel = v),
                      decoration: const InputDecoration(
                        labelText: 'TIPO DE TRABAJO',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  TextFormField(
                    controller: costoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'COSTO (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  TextFormField(
                    controller: obsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'OBSERVACIONES (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
            FilledButton.icon(
              icon: vm.loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: const Text('GUARDAR'),
              style: FilledButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 26, 54, 93),
                foregroundColor: Colors.white,
              ),
              onPressed: vm.loading
                  ? null
                  : () async {
                      if (selectedCliente == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SELECCIONA UN CLIENTE')));
                        return;
                      }
                      if (selectedVehiculo == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SELECCIONA UN VEHÍCULO')));
                        return;
                      }
                      final costo = double.tryParse(costoCtrl.text.trim().replaceAll(',', '.'));
                      final ok = await vm.crearServicioConSeleccion(
                        codCliente: selectedCliente!,
                        codVehiculo: selectedVehiculo!,
                        observaciones: obsCtrl.text.trim(),
                        tipoDescripcion: tipoSel,
                        costoTipo: (tipoSel == null) ? null : (costo ?? 0),
                      );
                      if (context.mounted) Navigator.pop(context, ok);
                    },
            ),
          ],
        ),
      ),
    );

    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SERVICIO REGISTRADO')),
      );
    } else if (ok == false && context.mounted) {
      final msg = context.read<ServiciosViewModel>().error ?? 'NO SE PUDO REGISTRAR';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ---------- Otras acciones ----------
  void _onVer(BuildContext context, ServicioItem e) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('DETALLE DEL SERVICIO #${e.codSerTaller}',
                style: AppTextStyles.heading2.copyWith(color: Color.fromARGB(255, 26, 54, 93), fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _detailRow('FECHA INGRESO', _fmtDate(e.fechaIngreso)),
            _detailRow('FECHA SALIDA', e.fechaSalida ?? '—'),
            _detailRow('CLIENTE', e.cliente),
            _detailRow('VEHÍCULO', e.vehiculo),
            _detailRow('TIPOS', e.tipos.isEmpty ? '—' : e.tipos),
            _detailRow('TOTAL (BS)', e.totalAprox.toStringAsFixed(2)),
            _detailRow('ESTADO', e.estado ?? '—'),
            _detailRow('OBSERVACIONES', e.observaciones ?? '—'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context), 
              icon: const Icon(Icons.check), 
              label: const Text('CERRAR'),
              style: FilledButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 26, 54, 93),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _onEditar(BuildContext context, ServiciosViewModel vm, ServicioItem e) async {
    final obsCtrl = TextEditingController(text: e.observaciones ?? '');
    final costoCtrl = TextEditingController(text: e.totalAprox.toStringAsFixed(2));
    String estadoTmp = e.estado ?? 'EN CURSO';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('EDITAR SERVICIO'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: '${e.codSerTaller}',
              enabled: false,
              decoration: const InputDecoration(labelText: 'CÓDIGO', border: OutlineInputBorder()),
            ),
            const SizedBox(height: AppSpacing.medium),
            TextFormField(
              controller: obsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'OBSERVACIONES', border: OutlineInputBorder()),
            ),
            const SizedBox(height: AppSpacing.medium),
            TextFormField(
              controller: costoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'COSTO TOTAL (EDITABLE)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: AppSpacing.medium),
            DropdownButtonFormField<String>(
              value: estadoTmp,
              items: const [
                DropdownMenuItem(value: 'EN CURSO', child: Text('EN CURSO')),
                DropdownMenuItem(value: 'EN ESPERA', child: Text('EN ESPERA')),
                DropdownMenuItem(value: 'TERMINADO', child: Text('TERMINADO')),
              ],
              onChanged: (v) => estadoTmp = v ?? estadoTmp,
              decoration: const InputDecoration(labelText: 'ESTADO (SI LA BD LO TIENE)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('GUARDAR'),
            style: FilledButton.styleFrom(
              backgroundColor: Color.fromARGB(255, 26, 54, 93),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (ok == true) {
      final okObs = await vm.updateObservaciones(codSerTaller: e.codSerTaller, observ: obsCtrl.text.trim());
      final costo = double.tryParse(costoCtrl.text.trim().replaceAll(',', '.')) ?? e.totalAprox;
      final okCosto = await vm.upsertCostoManual(e.codSerTaller, costo);
      final okEst = await vm.updateEstado(codSerTaller: e.codSerTaller, estado: estadoTmp);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((okObs || okCosto || okEst) ? 'SERVICIO #${e.codSerTaller} ACTUALIZADO' : 'NO SE PUDO ACTUALIZAR')),
        );
      }
    }
  }

  void _onEliminar(BuildContext context, ServiciosViewModel vm, ServicioItem e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ELIMINAR SERVICIO'),
        content: Text('¿DESEAS ELIMINAR EL SERVICIO #${e.codSerTaller}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.delete),
            label: const Text('ELIMINAR'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent, 
              foregroundColor: Colors.white
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      final deleted = await vm.deleteServicio(e.codSerTaller);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(deleted ? 'SERVICIO ELIMINADO' : 'NO SE PUDO ELIMINAR')),
        );
      }
    }
  }

  String _fmtDate(String iso) {
    if (iso.isEmpty) return '—';
    final y = iso.substring(0, 4);
    final m = iso.substring(5, 7);
    final d = iso.substring(8, 10);
    return '$y-$m-$d';
  }

  static Widget _detailRow(String k, String v) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Color(0xFFe8eaf6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(0xFFc5cae9), width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              k,
              style: AppTextStyles.body.copyWith(color: Color.fromARGB(255, 26, 54, 93), fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.body.copyWith(
        fontWeight: FontWeight.w800,
        color: Color.fromARGB(255, 26, 54, 93),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _TipoBadge extends StatelessWidget {
  final String texto;
  const _TipoBadge({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color(0xFFe8eaf6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.body.copyWith(color: Color.fromARGB(255, 26, 54, 93), fontWeight: FontWeight.w700),
      ),
    );
  }
}

// WIDGET PARA EL DIÁLOGO DE SEGUIMIENTO FUNCIONAL - SIN PARPADEO
class SeguimientoDialog extends StatefulWidget {
  final ServicioItem servicio;
  final ServiciosViewModel viewModel;

  const SeguimientoDialog({
    super.key,
    required this.servicio,
    required this.viewModel,
  });

  @override
  State<SeguimientoDialog> createState() => _SeguimientoDialogState();
}

class _SeguimientoDialogState extends State<SeguimientoDialog> {
  SeguimientoServicio? _seguimiento;
  final _diagnosticoCtrl = TextEditingController();
  final _fallasCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  final _solucionCtrl = TextEditingController();
  final _pruebasCtrl = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  // Timer para guardado automático
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _cargarSeguimiento();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _diagnosticoCtrl.dispose();
    _fallasCtrl.dispose();
    _observacionesCtrl.dispose();
    _solucionCtrl.dispose();
    _pruebasCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarSeguimiento() async {
    final seguimiento = await widget.viewModel.getSeguimiento(widget.servicio.codSerTaller);
    if (seguimiento != null) {
      setState(() {
        _seguimiento = seguimiento;
      });
      
      // Inicializar controladores una sola vez
      _diagnosticoCtrl.text = seguimiento.diagnostico ?? '';
      _fallasCtrl.text = seguimiento.fallasIdentificadas ?? '';
      _observacionesCtrl.text = seguimiento.observacionesFallas ?? '';
      _solucionCtrl.text = seguimiento.solucionAplicada ?? '';
      _pruebasCtrl.text = seguimiento.resultadoPruebas ?? '';
    }
  }

  // ===== MÉTODOS DE PERMISOS =====
  Future<bool> _solicitarPermisosCamara() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> _solicitarPermisosAlmacenamiento() async {
    if (await Permission.storage.isGranted) {
      return true;
    }
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<bool> _verificarPermisos() async {
    final permisoCamara = await _solicitarPermisosCamara();
    final permisoAlmacenamiento = await _solicitarPermisosAlmacenamiento();
    
    if (!permisoCamara) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se necesita permiso de cámara para tomar fotos')),
        );
      }
      return false;
    }
    
    if (!permisoAlmacenamiento) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se necesita permiso de almacenamiento para guardar fotos')),
        );
      }
      return false;
    }
    
    return true;
  }

  // Método para guardar con debounce (evita múltiples llamadas rápidas)
  void _guardarConDebounce(int paso, String texto) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _guardarPaso(paso, texto: texto);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.build, color: Colors.orange),
          const SizedBox(width: 8),
          Text('SEGUIMIENTO #${widget.servicio.codSerTaller}'),
        ],
      ),
      content: _seguimiento == null 
          ? const Center(child: CircularProgressIndicator())
          : _buildPasos(_seguimiento!),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CERRAR'),
        ),
      ],
    );
  }

  Widget _buildPasos(SeguimientoServicio seguimiento) {
    final pasos = [
      _Paso(
        numero: 1,
        titulo: 'DIAGNÓSTICO',
        completado: seguimiento.pasoActual > 1,
        activo: seguimiento.pasoActual == 1,
        contenido: _buildPasoContenido(
          controller: _diagnosticoCtrl,
          hintText: 'Diagnóstico inicial del vehículo...',
          paso: 1,
          fotoActual: seguimiento.fotoDiagnostico,
          obligatorio: true,
        ),
      ),
      _Paso(
        numero: 2,
        titulo: 'IDENTIFICAR FALLAS',
        completado: seguimiento.pasoActual > 2,
        activo: seguimiento.pasoActual == 2,
        contenido: _buildPasoContenido(
          controller: _fallasCtrl,
          hintText: 'Fallas identificadas según diagnóstico...',
          paso: 2,
          fotoActual: seguimiento.fotoFallas,
          obligatorio: true,
        ),
      ),
      _Paso(
        numero: 3,
        titulo: 'OBSERVA FALLAS',
        completado: seguimiento.pasoActual > 3,
        activo: seguimiento.pasoActual == 3,
        contenido: _buildPasoContenido(
          controller: _observacionesCtrl,
          hintText: 'Observaciones detalladas de las fallas...',
          paso: 3,
          fotoActual: seguimiento.fotoObservaciones,
          obligatorio: false,
        ),
      ),
      _Paso(
        numero: 4,
        titulo: 'REPARAR/SOLUCIONAR',
        completado: seguimiento.pasoActual > 4,
        activo: seguimiento.pasoActual == 4,
        contenido: _buildPasoContenido(
          controller: _solucionCtrl,
          hintText: 'Reparación o solución aplicada...',
          paso: 4,
          fotoActual: seguimiento.fotoReparacion,
          obligatorio: true,
        ),
      ),
      _Paso(
        numero: 5,
        titulo: 'PRUEBAS POST-REPARACIÓN',
        completado: seguimiento.pasoActual > 5,
        activo: seguimiento.pasoActual == 5,
        contenido: _buildPasoPruebas(seguimiento),
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...pasos,
          if (seguimiento.estado == 'FINALIZADO')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'SEGUIMIENTO FINALIZADO',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPasoContenido({
    required TextEditingController controller,
    required String hintText,
    required int paso,
    required String? fotoActual,
    required bool obligatorio,
  }) {
    return Column(
      children: [
        TextFormField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
            labelText: obligatorio ? 'OBLIGATORIO' : 'OPCIONAL',
            labelStyle: TextStyle(
              color: obligatorio ? Colors.red : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          onChanged: (value) => _guardarConDebounce(paso, value),
        ),
        const SizedBox(height: 10),
        _buildBotonFoto(paso, fotoActual),
        if (obligatorio && controller.text.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Este campo es obligatorio para avanzar',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (paso < 5 && controller.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: FilledButton(
              onPressed: () => _avanzarPaso(paso),
              style: FilledButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 26, 54, 93),
                foregroundColor: Colors.white,
              ),
              child: const Text('AVANZAR AL SIGUIENTE PASO'),
            ),
          ),
      ],
    );
  }

  Widget _buildPasoPruebas(SeguimientoServicio seguimiento) {
    return Column(
      children: [
        TextFormField(
          controller: _pruebasCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Resultado de las pruebas realizadas...',
            border: OutlineInputBorder(),
            labelText: 'OBLIGATORIO',
            labelStyle: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          onChanged: (value) => _guardarConDebounce(5, value),
        ),
        const SizedBox(height: 10),
        _buildBotonFoto(5, seguimiento.fotoPruebas),
        const SizedBox(height: 10),
        if (_pruebasCtrl.text.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _finalizarSeguimiento(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('PRUEBA EXITOSA'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => _volverAIdentificarFallas(),
                  style: FilledButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 26, 54, 93),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('IDENTIFICAR FALLAS'),
                ),
              ),
            ],
          ),
        if (_pruebasCtrl.text.isEmpty)
          Text(
            'Debes registrar el resultado de las pruebas para finalizar',
            style: TextStyle(
              color: Colors.red[700],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildBotonFoto(int paso, String? fotoActual) {
    return Column(
      children: [
        if (fotoActual != null && fotoActual.isNotEmpty)
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: Image.file(
              File(fotoActual),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.photo, size: 50, color: Colors.grey),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text(''), // Solo ícono
                onPressed: () => _tomarFoto(paso, ImageSource.camera),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color.fromARGB(255, 26, 54, 93),
                  side: BorderSide(color: Color.fromARGB(255, 26, 54, 93)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text(''), // Solo ícono
                onPressed: () => _tomarFoto(paso, ImageSource.gallery),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color.fromARGB(255, 26, 54, 93),
                  side: BorderSide(color: Color.fromARGB(255, 26, 54, 93)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _tomarFoto(int paso, ImageSource source) async {
    try {
      // Verificar permisos antes de tomar la foto
      final permisosOtorgados = await _verificarPermisos();
      if (!permisosOtorgados) {
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (image != null) {
        await _guardarPaso(paso, foto: image.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto agregada correctamente')),
          );
          // Recargar para mostrar la nueva foto
          _cargarSeguimiento();
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al tomar foto: $e')),
        );
      }
    }
  }

  void _avanzarPaso(int pasoActual) {
    if (_validarPaso(pasoActual)) {
      _guardarPaso(pasoActual + 1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa los campos obligatorios para avanzar')),
      );
    }
  }

  bool _validarPaso(int paso) {
    switch (paso) {
      case 1:
        return _diagnosticoCtrl.text.isNotEmpty;
      case 2:
        return _fallasCtrl.text.isNotEmpty;
      case 3:
        return true; // Opcional
      case 4:
        return _solucionCtrl.text.isNotEmpty;
      case 5:
        return _pruebasCtrl.text.isNotEmpty;
      default:
        return false;
    }
  }

  Future<void> _guardarPaso(int paso, {String? texto, String? foto}) async {
    final textoAGuardar = texto ?? _obtenerTextoDelControlador(paso);
    
    final campos = <String, String?>{};
    
    switch (paso) {
      case 1:
        campos['diagnostico'] = textoAGuardar;
        if (foto != null) campos['fotoDiagnostico'] = foto;
        break;
      case 2:
        campos['fallasIdentificadas'] = textoAGuardar;
        if (foto != null) campos['fotoFallas'] = foto;
        break;
      case 3:
        campos['observacionesFallas'] = textoAGuardar;
        if (foto != null) campos['fotoObservaciones'] = foto;
        break;
      case 4:
        campos['solucionAplicada'] = textoAGuardar;
        if (foto != null) campos['fotoReparacion'] = foto;
        break;
      case 5:
        campos['resultadoPruebas'] = textoAGuardar;
        if (foto != null) campos['fotoPruebas'] = foto;
        break;
    }
    
    await widget.viewModel.actualizarSeguimiento(
      codSerTaller: widget.servicio.codSerTaller,
      pasoActual: paso,
      diagnostico: campos['diagnostico'],
      fotoDiagnostico: campos['fotoDiagnostico'],
      fallasIdentificadas: campos['fallasIdentificadas'],
      fotoFallas: campos['fotoFallas'],
      observacionesFallas: campos['observacionesFallas'],
      fotoObservaciones: campos['fotoObservaciones'],
      solucionAplicada: campos['solucionAplicada'],
      fotoReparacion: campos['fotoReparacion'],
      resultadoPruebas: campos['resultadoPruebas'],
      fotoPruebas: campos['fotoPruebas'],
    );
    
    // Recargar los datos actualizados
    _cargarSeguimiento();
  }

  String _obtenerTextoDelControlador(int paso) {
    switch (paso) {
      case 1:
        return _diagnosticoCtrl.text;
      case 2:
        return _fallasCtrl.text;
      case 3:
        return _observacionesCtrl.text;
      case 4:
        return _solucionCtrl.text;
      case 5:
        return _pruebasCtrl.text;
      default:
        return '';
    }
  }

  void _finalizarSeguimiento(bool exito) async {
    if (!_validarPaso(5)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes registrar el resultado de las pruebas para finalizar')),
      );
      return;
    }

    await widget.viewModel.finalizarSeguimiento(widget.servicio.codSerTaller);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seguimiento finalizado exitosamente')),
      );
    }
  }

  void _volverAIdentificarFallas() async {
    await widget.viewModel.actualizarSeguimiento(
      codSerTaller: widget.servicio.codSerTaller,
      pasoActual: 2, // Volver al paso 2
    );
    _cargarSeguimiento();
  }
}

class _Paso extends StatelessWidget {
  final int numero;
  final String titulo;
  final bool completado;
  final bool activo;
  final Widget contenido;

  const _Paso({
    required this.numero,
    required this.titulo,
    required this.completado,
    required this.activo,
    required this.contenido,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: activo ? Color.fromARGB(255, 26, 54, 93).withOpacity(0.1) :
               completado ? Colors.green.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: activo ? Color.fromARGB(255, 26, 54, 93) :
                 completado ? Colors.green : Colors.grey,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: completado ? Colors.green : 
                               activo ? Color.fromARGB(255, 26, 54, 93) : Colors.grey,
                child: Text(
                  '$numero',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: activo ? Color.fromARGB(255, 26, 54, 93) :
                         completado ? Colors.green : Colors.grey,
                ),
              ),
              if (completado) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
              ],
            ],
          ),
          if (activo || completado) ...[
            const SizedBox(height: 12),
            contenido,
          ],
        ],
      ),
    );
  }
}