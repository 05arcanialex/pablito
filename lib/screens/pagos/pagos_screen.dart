import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../viewmodels/pagos_viewmodel.dart';

final _money = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs ', decimalDigits: 2);

class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Si no se inicializó en main, asegura init aquí:
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PagosViewModel>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PagosViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagos / Recibos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: vm.loadRecibos,
          ),
        ],
      ),
      body: Column(
        children: [
          // Búsqueda
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente o # de recibo...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: vm.setQuery,
            ),
          ),

          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _chip('TODOS', vm.filtroEstado == 'TODOS', () => vm.setFiltroEstado('TODOS')),
                const SizedBox(width: 8),
                _chip('PENDIENTE', vm.filtroEstado == 'PENDIENTE', () => vm.setFiltroEstado('PENDIENTE')),
                const SizedBox(width: 8),
                _chip('PAGADO', vm.filtroEstado == 'PAGADO', () => vm.setFiltroEstado('PAGADO')),
              ],
            ),
          ),

          if (vm.loading) const LinearProgressIndicator(minHeight: 2),

          // Lista
          Expanded(
            child: ListView.separated(
              itemCount: vm.recibos.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = vm.recibos[i];
                final estadoColor = r.estadoCalc == 'PAGADO' ? Colors.green : Colors.orange;

                return ListTile(
                  title: Text('${r.cliente}  •  ${r.fecha.split("T").first}'),
                  subtitle: Text('Total: ${_money.format(r.total)}   Abonado: ${_money.format(r.abonado)}   Saldo: ${_money.format(r.saldo)}'),
                  leading: CircleAvatar(
                    backgroundColor: estadoColor.withOpacity(0.15),
                    child: Icon(r.estadoCalc == 'PAGADO' ? Icons.verified : Icons.timelapse, color: estadoColor),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                    onPressed: () => _abrirDetallePagos(context, r.codRecibo),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  void _abrirDetallePagos(BuildContext context, int codRecibo) {
    final vm = context.read<PagosViewModel>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm, // MISMO SCOPE DEL PROVIDER
        child: _BSDetallePagos(codRecibo: codRecibo),
      ),
    );
  }
}

/// ===== BottomSheet de detalle/abonos =====
class _BSDetallePagos extends StatefulWidget {
  final int codRecibo;
  const _BSDetallePagos({required this.codRecibo});

  @override
  State<_BSDetallePagos> createState() => _BSDetallePagosState();
}

class _BSDetallePagosState extends State<_BSDetallePagos> {
  final _monto = TextEditingController();
  String _medio = kMediosPago.first;
  final _ref = TextEditingController();
  final _obs = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PagosViewModel>().loadMovimientos(widget.codRecibo);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PagosViewModel>();
    final rec = vm.recibos.firstWhere((e) => e.codRecibo == widget.codRecibo, orElse: () => vm.recibos.first);

    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(height: 4, width: 50, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Text('RECIBO #${widget.codRecibo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text('${rec.cliente}  •  Total ${_money.format(rec.total)}   Abonado ${_money.format(rec.abonado)}   Saldo ${_money.format(rec.saldo)}'),
              const SizedBox(height: 12),

              // Lista de pagos/abonos
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: vm.movimientos.length,
                  itemBuilder: (_, i) {
                    final m = vm.movimientos[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text('${m.medio}  •  ${_money.format(m.monto)}'),
                        subtitle: Text('${m.fecha}\n${m.referencia ?? ''} ${m.observacion ?? ''}'.trim()),
                        isThreeLine: (m.referencia?.isNotEmpty ?? false) || (m.observacion?.isNotEmpty ?? false),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => vm.eliminarPago(m.codPagoMov, widget.codRecibo),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
              // Form de nuevo abono
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _monto,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monto a abonar',
                        prefixIcon: Icon(Icons.payments),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _medio,
                    items: kMediosPago.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _medio = v ?? kMediosPago.first),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ref,
                decoration: const InputDecoration(
                  labelText: 'Referencia (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _obs,
                decoration: const InputDecoration(
                  labelText: 'Observación (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_card),
                      label: const Text('REGISTRAR ABONO'),
                      onPressed: () async {
                        final monto = double.tryParse(_monto.text.replaceAll(',', '.')) ?? 0.0;
                        final ok = await vm.registrarPago(
                          codRecibo: widget.codRecibo,
                          monto: monto,
                          medio: _medio,
                          referencia: _ref.text.trim().isEmpty ? null : _ref.text.trim(),
                          observacion: _obs.text.trim().isEmpty ? null : _obs.text.trim(),
                        );
                        if (ok) {
                          _monto.clear();
                          _ref.clear();
                          _obs.clear();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago registrado.')));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vm.error ?? 'Error')));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.verified),
                      label: const Text('MARCAR PAGADO'),
                      onPressed: () async {
                        final ok = await vm.marcarReciboPagado(widget.codRecibo);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? 'Recibo marcado PAGADO' : (vm.error ?? 'Error')),
                        ));
                        if (ok) Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('IMPRIMIR BOLETA'),
                  onPressed: () async {
                    final msg = await vm.imprimirBoleta(context, widget.codRecibo);
                    if (msg != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
