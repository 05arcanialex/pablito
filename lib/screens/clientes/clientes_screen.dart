import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _searchCtrl = TextEditingController();
  String _busqueda = '';

  // MOCK: Lista de clientes + vehículos (se reemplaza por API luego)
  final List<_ClienteRow> _clientes = [
    _ClienteRow(
      codCliente: 1,
      nombre: 'JUAN',
      apellidos: 'PÉREZ',
      telefono: '70123456',
      email: 'juan.perez@example.com',
      vehiculos: [
        _VehiculoRow(placa: '1234-ABC', marca: 'TOYOTA', modelo: 'COROLLA', color: 'BLANCO'),
        _VehiculoRow(placa: '5678-XYZ', marca: 'NISSAN', modelo: 'VERSA', color: 'NEGRO'),
      ],
    ),
    _ClienteRow(
      codCliente: 2,
      nombre: 'MARÍA',
      apellidos: 'LÓPEZ',
      telefono: '76543210',
      email: 'maria.lopez@example.com',
      vehiculos: [
        _VehiculoRow(placa: '7777-LLL', marca: 'KIA', modelo: 'RIO', color: 'GRIS'),
      ],
    ),
  ];

  List<_ClienteRow> get _filtrados {
    if (_busqueda.trim().isEmpty) return _clientes;
    final q = _busqueda.trim().toUpperCase();
    return _clientes.where((c) {
      final full = '${c.nombre} ${c.apellidos}'.toUpperCase();
      return full.contains(q) || (c.email?.toUpperCase().contains(q) ?? false) || (c.telefono?.contains(q) ?? false);
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          _buildToolbarResponsive(), // ✅ SIN OVERFLOW
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
                  child: _buildTable(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // TOOLBAR RESPONSIVE (BUSCADOR + NUEVO CLIENTE)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildToolbarResponsive() {
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
            // OCUPA EL ANCHO DISPONIBLE EN MÓVIL, Y HASTA 420PX EN PANTALLA ANCHA
            maxWidth: isNarrow ? constraints.maxWidth : 420,
            minWidth: 180,
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _busqueda = v),
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
          onPressed: _onCrearCliente,
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
                      children: [
                        searchBox,
                        newBtn,
                      ],
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
  Widget _buildTable() {
    final rows = _filtrados;

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          // ANCHO MÍNIMO PARA QUE LAS COLUMNAS TENGAN ESPACIO SIN CORTARSE
          constraints: const BoxConstraints(minWidth: 760),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(AppColors.primary.withOpacity(0.08)),
            dataRowHeight: 56,
            columns: const [
              DataColumn(label: _HeaderText('CÓDIGO')),
              DataColumn(label: _HeaderText('NOMBRE')),
              DataColumn(label: _HeaderText('TELÉFONO')),
              DataColumn(label: _HeaderText('EMAIL')),
              DataColumn(label: _HeaderText('VEHÍCULOS')),
              DataColumn(label: _HeaderText('ACCIONES')),
            ],
            rows: rows.map((c) => _buildRow(c)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(_ClienteRow c) {
    final nombre = '${c.nombre} ${c.apellidos}';
    return DataRow(
      cells: [
        DataCell(Text('${c.codCliente}')),
        DataCell(Text(nombre)),
        DataCell(Text(c.telefono ?? '-')),
        DataCell(Text(c.email ?? '-')),
        DataCell(_VehiculosChip(count: c.vehiculos.length, onTap: () => _onVerCliente(c))),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'VER',
              icon: const Icon(Icons.visibility, color: AppColors.secondary),
              onPressed: () => _onVerCliente(c),
            ),
            IconButton(
              tooltip: 'EDITAR',
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: () => _onEditarCliente(c),
            ),
            IconButton(
              tooltip: 'ELIMINAR',
              icon: const Icon(Icons.delete_forever, color: AppColors.accent),
              onPressed: () => _onEliminarCliente(c),
            ),
          ],
        )),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ACCIONES CLIENTE
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _onCrearCliente() async {
    final result = await showDialog<_ClienteRow>(
      context: context,
      builder: (_) => _DlgCliente(title: 'REGISTRAR CLIENTE'),
    );
    if (result != null) {
      setState(() => _clientes.add(result));
      _ok('CLIENTE REGISTRADO');
    }
  }

  Future<void> _onEditarCliente(_ClienteRow c) async {
    final result = await showDialog<_ClienteRow>(
      context: context,
      builder: (_) => _DlgCliente(title: 'EDITAR CLIENTE', initial: c),
    );
    if (result != null) {
      final idx = _clientes.indexWhere((e) => e.codCliente == c.codCliente);
      if (idx >= 0) setState(() => _clientes[idx] = result.copyWith(codCliente: c.codCliente));
      _ok('CLIENTE ACTUALIZADO');
    }
  }

  Future<void> _onEliminarCliente(_ClienteRow c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ELIMINAR CLIENTE'),
        content: Text('¿DESEAS ELIMINAR A ${c.nombre} ${c.apellidos}?'),
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
      setState(() => _clientes.removeWhere((e) => e.codCliente == c.codCliente));
      _ok('CLIENTE ELIMINADO');
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // VER CLIENTE (BOTTOM SHEET) + CRUD VEHÍCULOS
  // ────────────────────────────────────────────────────────────────────────────
  void _onVerCliente(_ClienteRow c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BSClienteDetalle(
        cliente: c,
        onAddVehiculo: (v) {
          setState(() => c.vehiculos.add(v));
          _ok('VEHÍCULO AGREGADO');
        },
        onEditVehiculo: (index, v) {
          setState(() => c.vehiculos[index] = v);
          _ok('VEHÍCULO ACTUALIZADO');
        },
        onDeleteVehiculo: (index) {
          setState(() => c.vehiculos.removeAt(index));
          _ok('VEHÍCULO ELIMINADO');
        },
      ),
    );
  }

  void _ok(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
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
// BOTTOM SHEET: DETALLE CLIENTE (DATOS + VEHÍCULOS)
// ──────────────────────────────────────────────────────────────────────────────
class _BSClienteDetalle extends StatelessWidget {
  final _ClienteRow cliente;
  final void Function(_VehiculoRow) onAddVehiculo;
  final void Function(int index, _VehiculoRow) onEditVehiculo;
  final void Function(int index) onDeleteVehiculo;

  const _BSClienteDetalle({
    required this.cliente,
    required this.onAddVehiculo,
    required this.onEditVehiculo,
    required this.onDeleteVehiculo,
  });

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
            child: Text('${cliente.nombre} ${cliente.apellidos}', style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('TEL: ${cliente.telefono ?? '-'}  |  EMAIL: ${cliente.email ?? '-'}', style: AppTextStyles.body),
          ),
          const SizedBox(height: AppSpacing.medium),
          Row(
            children: [
              Expanded(
                child: Text('VEHÍCULOS (${cliente.vehiculos.length})', style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.w600)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final res = await showDialog<_VehiculoRow>(
                    context: context,
                    builder: (_) => _DlgVehiculo(title: 'AGREGAR VEHÍCULO'),
                  );
                  if (res != null) onAddVehiculo(res);
                },
                icon: const Icon(Icons.add),
                label: const Text('AGREGAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemBuilder: (_, i) {
                final v = cliente.vehiculos[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: const Icon(Icons.directions_car, color: AppColors.primary),
                  title: Text('${v.marca} ${v.modelo} (${v.color})'),
                  subtitle: Text('PLACA: ${v.placa}'),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'EDITAR',
                        icon: const Icon(Icons.edit, color: AppColors.primary),
                        onPressed: () async {
                          final res = await showDialog<_VehiculoRow>(
                            context: context,
                            builder: (_) => _DlgVehiculo(title: 'EDITAR VEHÍCULO', initial: v),
                          );
                          if (res != null) onEditVehiculo(i, res);
                        },
                      ),
                      IconButton(
                        tooltip: 'ELIMINAR',
                        icon: const Icon(Icons.delete_forever, color: AppColors.accent),
                        onPressed: () => onDeleteVehiculo(i),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: cliente.vehiculos.length,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
class _DlgCliente extends StatefulWidget {
  final String title;
  final _ClienteRow? initial;
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
            final nuevo = _ClienteRow(
              codCliente: widget.initial?.codCliente ?? DateTime.now().millisecondsSinceEpoch,
              nombre: _nombre.text.trim().toUpperCase(),
              apellidos: _apellidos.text.trim().toUpperCase(),
              telefono: _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
              email: _email.text.trim().isEmpty ? null : _email.text.trim(),
              vehiculos: widget.initial?.vehiculos.toList() ?? [],
            );
            Navigator.pop(context, nuevo);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: const Text('GUARDAR'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
class _DlgVehiculo extends StatefulWidget {
  final String title;
  final _VehiculoRow? initial;
  const _DlgVehiculo({required this.title, this.initial});

  @override
  State<_DlgVehiculo> createState() => _DlgVehiculoState();
}

class _DlgVehiculoState extends State<_DlgVehiculo> {
  final _f = GlobalKey<FormState>();
  final _placa = TextEditingController();
  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _color = TextEditingController();

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _placa.text = i.placa;
      _marca.text = i.marca;
      _modelo.text = i.modelo;
      _color.text = i.color;
    }
  }

  @override
  void dispose() {
    _placa.dispose();
    _marca.dispose();
    _modelo.dispose();
    _color.dispose();
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
                controller: _placa,
                decoration: const InputDecoration(labelText: 'PLACA *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'REQUERIDO' : null,
              ),
              const SizedBox(height: AppSpacing.medium),
              TextFormField(
                controller: _marca,
                decoration: const InputDecoration(labelText: 'MARCA *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'REQUERIDO' : null,
              ),
              const SizedBox(height: AppSpacing.medium),
              TextFormField(
                controller: _modelo,
                decoration: const InputDecoration(labelText: 'MODELO *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'REQUERIDO' : null,
              ),
              const SizedBox(height: AppSpacing.medium),
              TextFormField(
                controller: _color,
                decoration: const InputDecoration(labelText: 'COLOR *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'REQUERIDO' : null,
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
            final v = _VehiculoRow(
              placa: _placa.text.trim().toUpperCase(),
              marca: _marca.text.trim().toUpperCase(),
              modelo: _modelo.text.trim().toUpperCase(),
              color: _color.text.trim().toUpperCase(),
            );
            Navigator.pop(context, v);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: const Text('GUARDAR'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// MODELOS UI (FRONTEND)
// ──────────────────────────────────────────────────────────────────────────────
class _ClienteRow {
  final int codCliente;
  final String nombre;
  final String apellidos;
  final String? telefono;
  final String? email;
  final List<_VehiculoRow> vehiculos;

  _ClienteRow({
    required this.codCliente,
    required this.nombre,
    required this.apellidos,
    this.telefono,
    this.email,
    required this.vehiculos,
  });

  _ClienteRow copyWith({
    int? codCliente,
    String? nombre,
    String? apellidos,
    String? telefono,
    String? email,
    List<_VehiculoRow>? vehiculos,
  }) {
    return _ClienteRow(
      codCliente: codCliente ?? this.codCliente,
      nombre: nombre ?? this.nombre,
      apellidos: apellidos ?? this.apellidos,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      vehiculos: vehiculos ?? this.vehiculos,
    );
  }
}

class _VehiculoRow {
  final String placa;
  final String marca;
  final String modelo;
  final String color;

  _VehiculoRow({
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.color,
  });
}
