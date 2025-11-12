import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../viewmodels/clientes_viewmodel.dart';

/// WRAPPER A PRUEBA DE FALLOS:
/// - SI YA EXISTE Provider<ClientesViewModel> ARRIBA, LO USA.
/// - SI NO EXISTE, INYECTA UNO LOCAL Y CARGA DATOS.
class ClientesScreen extends StatelessWidget {
  const ClientesScreen({super.key});

  bool _hasProvider(BuildContext context) {
    try {
      Provider.of<ClientesViewModel>(context, listen: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasProvider(context)) return const _ClientesScreenBody();
    return ChangeNotifierProvider(
      create: (_) => ClientesViewModel()..loadClientes(),
      child: const _ClientesScreenBody(),
    );
  }
}

class _ClientesScreenBody extends StatefulWidget {
  const _ClientesScreenBody({super.key});
  @override
  State<_ClientesScreenBody> createState() => _ClientesScreenBodyState();
}

class _ClientesScreenBodyState extends State<_ClientesScreenBody> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClientesViewModel>();

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          _buildToolbarResponsive(vm),
          const SizedBox(height: AppSpacing.medium),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  child: _buildTable(vm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // TOOLBAR
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildToolbarResponsive(ClientesViewModel vm) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;

        final titleWidget = Text(
          'CLIENTES',
          style: AppTextStyles.heading2.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        );

        final searchBox = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isNarrow ? constraints.maxWidth : 420,
            minWidth: 180,
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: vm.setQuery,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'BUSCAR POR NOMBRE, TELÉFONO O EMAIL',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.backgroundVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.small),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        );

        final newBtn = ElevatedButton.icon(
          onPressed: () => _onCrearCliente(vm),
          icon: const Icon(Icons.person_add),
          label: const Text('NUEVO CLIENTE'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.small)),
          ),
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large, vertical: AppSpacing.medium),
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
                      children: [searchBox, newBtn],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: titleWidget),
                    searchBox,
                    const SizedBox(width: AppSpacing.medium),
                    newBtn,
                  ],
                ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // TABLA
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildTable(ClientesViewModel vm) {
    final rows = vm.clientes;

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 900),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(AppColors.primary.withOpacity(0.08)),
            dataRowHeight: 56,
            columns: const [
              DataColumn(label: _HeaderText('CÓDIGO')),
              DataColumn(label: _HeaderText('NOMBRE')),
              DataColumn(label: _HeaderText('TELÉFONO')),
              DataColumn(label: _HeaderText('EMAIL')),
              DataColumn(label: _HeaderText('VEHÍCULOS')),
              DataColumn(label: _HeaderText('ÚLTIMO SERVICIO')),
              DataColumn(label: _HeaderText('ACCIONES')),
            ],
            rows: rows.map((c) {
              final ultimo = c.ultimoServicio == null
                  ? '-'
                  : '${c.ultimoServicio!.year}-${c.ultimoServicio!.month.toString().padLeft(2, '0')}-${c.ultimoServicio!.day.toString().padLeft(2, '0')}';
              return DataRow(
                cells: [
                  DataCell(Text('${c.codCliente}')),
                  DataCell(Text(c.nombreCompleto)),
                  DataCell(Text(c.telefono ?? '-')),
                  DataCell(Text(c.email ?? '-')),
                  DataCell(_VehiculosChip(count: c.cantVehiculos, onTap: () => _onVerCliente(vm, c))),
                  DataCell(Text(ultimo)),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'VER',
                        icon: const Icon(Icons.visibility, color: AppColors.secondary),
                        onPressed: () => _onVerCliente(vm, c),
                      ),
                      IconButton(
                        tooltip: 'EDITAR',
                        icon: const Icon(Icons.edit, color: AppColors.primary),
                        onPressed: () => _onEditarCliente(vm, c),
                      ),
                      IconButton(
                        tooltip: 'ELIMINAR',
                        icon: const Icon(Icons.delete_forever, color: AppColors.accent),
                        onPressed: () => _onEliminarCliente(vm, c),
                      ),
                    ],
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CRUD CLIENTE
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _onCrearCliente(ClientesViewModel vm) async {
    final res = await showDialog<_ClienteFormResult>(
      context: context,
      builder: (_) => const _DlgCliente(title: 'REGISTRAR CLIENTE'),
    );
    if (res != null) {
      await vm.crearCliente(
        nombre: res.nombre,
        apellidos: res.apellidos,
        telefono: res.telefono,
        email: res.email,
      );
      _ok('CLIENTE REGISTRADO');
    }
  }

  Future<void> _onEditarCliente(ClientesViewModel vm, ClienteItem c) async {
    final res = await showDialog<_ClienteFormResult>(
      context: context,
      builder: (_) => _DlgCliente(
        title: 'EDITAR CLIENTE',
        initial: _ClienteFormResult(
          nombre: c.nombre,
          apellidos: c.apellidos,
          telefono: c.telefono,
          email: c.email,
        ),
      ),
    );
    if (res != null) {
      await vm.actualizarCliente(
        codCliente: c.codCliente,
        codPersona: c.codPersona,
        nombre: res.nombre,
        apellidos: res.apellidos,
        telefono: res.telefono,
        email: res.email,
      );
      _ok('CLIENTE ACTUALIZADO');
    }
  }

  Future<void> _onEliminarCliente(ClientesViewModel vm, ClienteItem c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ELIMINAR CLIENTE'),
        content: Text('¿DESEAS ELIMINAR A ${c.nombreCompleto}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await vm.eliminarCliente(codCliente: c.codCliente, codPersona: c.codPersona);
      _ok('CLIENTE ELIMINADO');
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // VER CLIENTE (BOTTOM SHEET) + CRUD VEHÍCULOS
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _onVerCliente(ClientesViewModel vm, ClienteItem c) async {
    final vehs = await vm.listarVehiculosDeCliente(c.codCliente);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BSClienteDetalle(
        cliente: c,
        vehiculos: vehs,
        onAddVehiculo: (v) async {
          await vm.crearVehiculo(
            codCliente: c.codCliente,
            marca: v.marca,
            modelo: v.modelo,
            anio: v.anio,
            placas: v.placas,
            color: v.color,
            kilometraje: v.kilometraje,
            numeroSerie: v.numeroSerie,
          );
          Navigator.pop(context);
          _onVerCliente(vm, c);
          _ok('VEHÍCULO AGREGADO');
        },
        onEditVehiculo: (v) async {
          assert(v.codVehiculo != null, 'codVehiculo NO PUEDE SER NULO AL EDITAR');
          await vm.actualizarVehiculo(
            codVehiculo: v.codVehiculo!,
            marca: v.marca,
            modelo: v.modelo,
            anio: v.anio,
            placas: v.placas,
            color: v.color,
            kilometraje: v.kilometraje,
            numeroSerie: v.numeroSerie,
          );
          Navigator.pop(context);
          _onVerCliente(vm, c);
          _ok('VEHÍCULO ACTUALIZADO');
        },
        onDeleteVehiculo: (codVehiculo) async {
          await vm.eliminarVehiculo(codVehiculo);
          Navigator.pop(context);
          _onVerCliente(vm, c);
          _ok('VEHÍCULO ELIMINADO');
        },
      ),
    );
  }

  void _ok(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

// ──────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ──────────────────────────────────────────────────────────────────────────────
class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.body.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _VehiculosChip extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _VehiculosChip({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET: DETALLE CLIENTE + CRUD VEHÍCULOS
// ──────────────────────────────────────────────────────────────────────────────
class BSClienteDetalle extends StatefulWidget {
  final ClienteItem cliente;
  final List<VehiculoItem> vehiculos;

  final Future<void> Function(_VehiculoFormResult nuevo) onAddVehiculo;
  final Future<void> Function(_VehiculoFormResult editado) onEditVehiculo;
  final Future<void> Function(int codVehiculo) onDeleteVehiculo;

  const BSClienteDetalle({
    super.key,
    required this.cliente,
    required this.vehiculos,
    required this.onAddVehiculo,
    required this.onEditVehiculo,
    required this.onDeleteVehiculo,
  });

  @override
  State<BSClienteDetalle> createState() => _BSClienteDetalleState();
}

class _BSClienteDetalleState extends State<BSClienteDetalle> {
  late List<VehiculoItem> _vehiculos;

  @override
  void initState() {
    super.initState();
    _vehiculos = widget.vehiculos;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.large,
        right: AppSpacing.large,
        top: AppSpacing.large,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.large,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 60, height: 6, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: AppSpacing.medium),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('DETALLE DEL CLIENTE', style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: AppSpacing.small),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.cliente.nombreCompleto, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('TEL: ${widget.cliente.telefono ?? '-'}  |  EMAIL: ${widget.cliente.email ?? '-'}', style: AppTextStyles.body),
          ),
          const SizedBox(height: AppSpacing.medium),

          Row(
            children: [
              Expanded(
                child: Text('VEHÍCULOS (${_vehiculos.length})',
                    style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.w600)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final res = await showDialog<_VehiculoFormResult>(
                    context: context,
                    builder: (_) => const _DlgVehiculo(title: 'AGREGAR VEHÍCULO'),
                  );
                  if (res != null) await widget.onAddVehiculo(res);
                },
                icon: const Icon(Icons.add),
                label: const Text('AGREGAR'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),

          Flexible(
            child: _vehiculos.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('SIN VEHÍCULOS REGISTRADOS'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemBuilder: (_, i) {
                      final v = _vehiculos[i];
                      return Card(
                        elevation: 1.5,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          leading: const Icon(Icons.directions_car, color: AppColors.primary),
                          title: Text('${v.marca} ${v.modelo}${v.anio != null ? ' (${v.anio})' : ''} - ${v.color}'),
                          subtitle: Text('PLACA: ${v.placas}${v.kilometraje != null ? ' | KM: ${v.kilometraje}' : ''}'),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'EDITAR',
                                icon: const Icon(Icons.edit, color: AppColors.primary),
                                onPressed: () async {
                                  final res = await showDialog<_VehiculoFormResult>(
                                    context: context,
                                    builder: (_) => _DlgVehiculo(
                                      title: 'EDITAR VEHÍCULO',
                                      initial: _VehiculoFormResult(
                                        codVehiculo: v.codVehiculo,
                                        marca: v.marca,
                                        modelo: v.modelo,
                                        anio: v.anio,
                                        placas: v.placas,
                                        color: v.color,
                                        kilometraje: v.kilometraje,
                                        numeroSerie: v.numeroSerie,
                                      ),
                                    ),
                                  );
                                  if (res != null) await widget.onEditVehiculo(res);
                                },
                              ),
                              IconButton(
                                tooltip: 'ELIMINAR',
                                icon: const Icon(Icons.delete_forever, color: AppColors.accent),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('ELIMINAR VEHÍCULO'),
                                      content: Text('¿Deseas eliminar el vehículo ${v.placas}?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                                          child: const Text('ELIMINAR'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) await widget.onDeleteVehiculo(v.codVehiculo);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemCount: _vehiculos.length,
                  ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// FORMULARIOS (CLIENTE Y VEHÍCULO)
// ──────────────────────────────────────────────────────────────────────────────
class _ClienteFormResult {
  final String nombre;
  final String apellidos;
  final String? telefono;
  final String? email;
  const _ClienteFormResult({required this.nombre, required this.apellidos, this.telefono, this.email});
}

class _DlgCliente extends StatefulWidget {
  final String title;
  final _ClienteFormResult? initial;
  const _DlgCliente({required this.title, this.initial});
  @override
  State<_DlgCliente> createState() => _DlgClienteState();
}

class _DlgClienteState extends State<_DlgCliente> {
  final _f = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _nombre.text = i.nombre;
      _apellidos.text = i.apellidos;
      _telefono.text = i.telefono ?? '';
      _email.text = i.email ?? '';
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _apellidos.dispose();
    _telefono.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _f,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'NOMBRE *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'REQUERIDO' : null,
              ),
              const SizedBox(height: AppSpacing.medium),
              TextFormField(
                controller: _apellidos,
                decoration: const InputDecoration(labelText: 'APELLIDOS *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'REQUERIDO' : null,
              ),
              const SizedBox(height: AppSpacing.medium),
              TextFormField(
                controller: _telefono,
                decoration: const InputDecoration(labelText: 'TELÉFONO', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.medium),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'EMAIL', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
        ElevatedButton(
          onPressed: () {
            if (!_f.currentState!.validate()) return;
            Navigator.pop(
              context,
              _ClienteFormResult(
                nombre: _nombre.text.trim().toUpperCase(),
                apellidos: _apellidos.text.trim().toUpperCase(),
                telefono: _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
                email: _email.text.trim().isEmpty ? null : _email.text.trim(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: const Text('GUARDAR'),
        ),
      ],
    );
  }
}

// RESULT PARA VEHÍCULO (CREAR = ID NULO, EDITAR = ID NO NULO)
class _VehiculoFormResult {
  final int? codVehiculo;
  final String marca;
  final String modelo;
  final int? anio;
  final String placas;
  final String color;
  final int? kilometraje;
  final String? numeroSerie;

  const _VehiculoFormResult({
    this.codVehiculo,
    required this.marca,
    required this.modelo,
    this.anio,
    required this.placas,
    required this.color,
    this.kilometraje,
    this.numeroSerie,
  });
}

class _DlgVehiculo extends StatefulWidget {
  final String title;
  final _VehiculoFormResult? initial;
  const _DlgVehiculo({required this.title, this.initial});

  @override
  State<_DlgVehiculo> createState() => _DlgVehiculoState();
}

class _DlgVehiculoState extends State<_DlgVehiculo> {
  final _f = GlobalKey<FormState>();
  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _anio = TextEditingController();
  final _placa = TextEditingController();
  final _color = TextEditingController();
  final _km = TextEditingController();
  final _serie = TextEditingController();

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _marca.text = i.marca;
      _modelo.text = i.modelo;
      _anio.text = i.anio?.toString() ?? '';
      _placa.text = i.placas;
      _color.text = i.color;
      _km.text = i.kilometraje?.toString() ?? '';
      _serie.text = i.numeroSerie ?? '';
    }
  }

  @override
  void dispose() {
    _marca.dispose();
    _modelo.dispose();
    _anio.dispose();
    _placa.dispose();
    _color.dispose();
    _km.dispose();
    _serie.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _f,
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _marca,
                    decoration: const InputDecoration(labelText: 'MARCA *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'REQUERIDO' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _modelo,
                    decoration: const InputDecoration(labelText: 'MODELO *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'REQUERIDO' : null,
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.medium),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _anio,
                    decoration: const InputDecoration(labelText: 'AÑO', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _placa,
                    decoration: const InputDecoration(labelText: 'PLACA *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'REQUERIDO' : null,
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.medium),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _color,
                    decoration: const InputDecoration(labelText: 'COLOR *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'REQUERIDO' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _km,
                    decoration: const InputDecoration(labelText: 'KILOMETRAJE', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.medium),
              TextFormField(
                controller: _serie,
                decoration: const InputDecoration(labelText: 'N° SERIE / VIN', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
        ElevatedButton(
          onPressed: () {
            if (!_f.currentState!.validate()) return;
            Navigator.pop(
              context,
              _VehiculoFormResult(
                codVehiculo: widget.initial?.codVehiculo,
                marca: _marca.text.trim().toUpperCase(),
                modelo: _modelo.text.trim().toUpperCase(),
                anio: _anio.text.trim().isEmpty ? null : int.tryParse(_anio.text.trim()),
                placas: _placa.text.trim().toUpperCase(),
                color: _color.text.trim().toUpperCase(),
                kilometraje: _km.text.trim().isEmpty ? null : int.tryParse(_km.text.trim()),
                numeroSerie: _serie.text.trim().isEmpty ? null : _serie.text.trim().toUpperCase(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: const Text('GUARDAR'),
        ),
      ],
    );
  }
}
