// lib/screens/servicios/servicios_screen.dart
import 'package:flutter/material.dart';
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
        backgroundColor: AppColors.primary,
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
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        );

        final dropdown = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.backgroundVariant,
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

        final auxilioBtn = FilledButton.icon(
          onPressed: vm.loading ? null : () => _onAuxilio(context),
          icon: const Icon(Icons.sos),
          label: const Text('AUXILIO'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
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
                        auxilioBtn,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: titleWidget),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: dropdown),
                    const SizedBox(width: AppSpacing.medium),
                    auxilioBtn,
                  ],
                ),
        );
      },
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
                AppColors.primary.withOpacity(0.08),
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
                              IconButton(
                                tooltip: 'VER',
                                icon: const Icon(Icons.visibility, color: AppColors.textSecondary),
                                onPressed: () => _onVer(context, e),
                              ),
                              IconButton(
                                tooltip: 'EDITAR',
                                icon: const Icon(Icons.edit, color: AppColors.primary),
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
                            trailing: isSel ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
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
                            trailing: isSel ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                            onTap: () => setSB(() => selectedVehiculo = v.codVehiculo),
                          );
                        }),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.small),

                  // ---- TIPO / COSTO / OBS ----
                  DropdownButtonFormField<String>(
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
                style: AppTextStyles.heading2.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
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
            FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.check), label: const Text('CERRAR')),
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
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

  void _onAuxilio(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOLICITUD DE AUXILIO ENVIADA')),
    );
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
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.backgroundVariant, width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              k,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
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
        color: AppColors.textPrimary,
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
        color: AppColors.backgroundVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
