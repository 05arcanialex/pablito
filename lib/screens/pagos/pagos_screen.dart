import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../viewmodels/pagos_viewmodel.dart';

final _money =
    NumberFormat.currency(locale: 'es_BO', symbol: 'Bs ', decimalDigits: 2);

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PagosViewModel>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PagosViewModel>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Pagos / Recibos',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        backgroundColor: const Color(0xFF2E7D32), // Verde oscuro
        elevation: 4,
        shadowColor: Colors.green[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: vm.loadRecibos,
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: Column(
        children: [
          // Búsqueda
          Container(
            margin: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green[100]!,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente o # de recibo...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              onChanged: vm.setQuery,
            ),
          ),

          // Filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('TODOS', vm.filtroEstado == 'TODOS',
                      () => vm.setFiltroEstado('TODOS')),
                  const SizedBox(width: 8),
                  _chip(
                      'PENDIENTE',
                      vm.filtroEstado == 'PENDIENTE',
                      () => vm.setFiltroEstado('PENDIENTE')),
                  const SizedBox(width: 8),
                  _chip('PAGADO', vm.filtroEstado == 'PAGADO',
                      () => vm.setFiltroEstado('PAGADO')),
                ],
              ),
            ),
          ),

          if (vm.loading)
            LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.green[50],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
            ),

          // Lista
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ListView.separated(
                  itemCount: vm.recibos.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (_, i) {
                    final r = vm.recibos[i];
                    final isPagado = r.estadoCalc == 'PAGADO';
                    final estadoColor = isPagado
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFF57C00);
                    final estadoGradient = isPagado
                        ? LinearGradient(
                            colors: [Colors.green[400]!, Colors.green[600]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [Colors.orange[400]!, Colors.orange[600]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          );

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: estadoGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: estadoColor.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isPagado ? Icons.verified : Icons.timelapse,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          r.cliente,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r.fecha.split("T").first}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // ENVUELTO EN WRAP PARA EVITAR OVERFLOW HORIZONTAL
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                _buildInfoChip(
                                  'Total',
                                  _money.format(r.total),
                                  Colors.blue[50]!,
                                  Colors.blue[700]!,
                                ),
                                _buildInfoChip(
                                  'Abonado',
                                  _money.format(r.abonado),
                                  Colors.green[50]!,
                                  Colors.green[700]!,
                                ),
                                _buildInfoChip(
                                  'Saldo',
                                  _money.format(r.saldo),
                                  Colors.orange[50]!,
                                  Colors.orange[700]!,
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Container(
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green[100]!),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.arrow_forward_ios_rounded,
                                size: 16, color: Colors.green[700]!),
                            onPressed: () =>
                                _abrirDetallePagos(context, r.codRecibo),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.green[300]!,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ChoiceChip(
        label: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w500)),
        selected: selected,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF2E7D32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? const Color(0xFF2E7D32) : Colors.grey[300]!,
            width: selected ? 0 : 1,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
      String label, String value, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _abrirDetallePagos(BuildContext context, int codRecibo) {
    final vm = context.read<PagosViewModel>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
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

  void _mostrarModalQR(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green[50]!, Colors.blue[50]!],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Escanea el QR para pagar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green[100]!,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/img/qr_cobro_electronica_lapaz.jpg',
                    width: 250,
                    height: 250,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.grey[500], size: 50),
                            const SizedBox(height: 8),
                            Text(
                              'QR no encontrado',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Usa tu app de billetera móvil\npara escanear el código QR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('CERRAR',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PagosViewModel>();
    final rec = vm.recibos.firstWhere((e) => e.codRecibo == widget.codRecibo,
        orElse: () => vm.recibos.first);

    final montoIngresado =
        double.tryParse(_monto.text.replaceAll(',', '.')) ?? 0.0;
    final montoExcedeSaldo = montoIngresado > rec.saldo;
    final saldoInsuficiente = rec.saldo <= 0;
    final montoValido =
        montoIngresado > 0 && !montoExcedeSaldo && !saldoInsuficiente;

    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      duration: const Duration(milliseconds: 100),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.green[50]!, Colors.blue[50]!],
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          // AHORA TODO EL CONTENIDO ES SCROLLABLE
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              controller: controller,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 60,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text('RECIBO #${widget.codRecibo}',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32))),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[100]!),
                      ),
                      child: Column(
                        children: [
                          Text(rec.cliente,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildDetailItem('Total',
                                  _money.format(rec.total), Colors.blue[700]!),
                              _buildDetailItem(
                                  'Abonado',
                                  _money.format(rec.abonado),
                                  Colors.green[700]!),
                              _buildDetailItem(
                                  'Saldo',
                                  _money.format(rec.saldo),
                                  Colors.orange[700]!),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (saldoInsuficiente) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified, color: Colors.orange[800]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Este recibo ya está completamente pagado',
                                style: TextStyle(
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Text('Historial de Pagos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700])),
                    const SizedBox(height: 8),

                    // Lista de pagos/abonos (SIN LISTVIEW, PARA EVITAR CONFLICTOS DE SCROLL)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: vm.movimientos.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Sin pagos registrados para este recibo.',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 13),
                              ),
                            )
                          : Column(
                              children: vm.movimientos.map((m) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.payment,
                                          color: Colors.green[700], size: 20),
                                    ),
                                    title: Text(
                                        '${m.medio} • ${_money.format(m.monto)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                        '${m.fecha}\n${m.referencia ?? ''} ${m.observacion ?? ''}'
                                            .trim(),
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12)),
                                    trailing: IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          color: Colors.red[400]),
                                      onPressed: () => vm.eliminarPago(
                                          m.codPagoMov, widget.codRecibo),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),

                    const SizedBox(height: 16),
                    Text('Nuevo Abono',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700])),
                    const SizedBox(height: 12),

                    // Form de nuevo abono
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _monto,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Monto a abonar',
                                labelStyle: TextStyle(color: Colors.grey[700]),
                                prefixIcon: Icon(Icons.payments,
                                    color: Colors.green[700]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey[400]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.green[700]!),
                                ),
                                errorText: montoExcedeSaldo
                                    ? 'Monto supera el saldo disponible'
                                    : null,
                                errorStyle: const TextStyle(
                                    color: Colors.red, fontSize: 12),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 16),
                              ),
                              onChanged: (value) {
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButton<String>(
                              value: _medio,
                              items: kMediosPago
                                  .map((e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e,
                                            style: TextStyle(
                                                color: Colors.grey[700])),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _medio = v ?? kMediosPago.first;
                                });
                                if (v == 'QR') {
                                  _mostrarModalQR(context);
                                }
                              },
                              underline: const SizedBox(),
                              icon: Icon(Icons.arrow_drop_down,
                                  color: Colors.green[700]),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (montoExcedeSaldo) const SizedBox(height: 8),

                    TextField(
                      controller: _ref,
                      decoration: InputDecoration(
                        labelText: 'Referencia (opcional)',
                        labelStyle: TextStyle(color: Colors.grey[700]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.green[700]!),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _obs,
                      decoration: InputDecoration(
                        labelText: 'Observación (opcional)',
                        labelStyle: TextStyle(color: Colors.grey[700]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.green[700]!),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add_card, size: 20),
                            label: const Text('REGISTRAR ABONO'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: montoValido
                                  ? const Color(0xFF2E7D32)
                                  : Colors.grey[400],
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              shadowColor: montoValido
                                  ? Colors.green[300]
                                  : Colors.grey,
                            ),
                            onPressed: montoValido
                                ? () async {
                                    final monto = double.tryParse(_monto.text
                                            .replaceAll(',', '.')) ??
                                        0.0;

                                    if (monto > rec.saldo) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'El monto ingresado (${_money.format(monto)}) supera el saldo disponible (${_money.format(rec.saldo)})'),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                        ),
                                      );
                                      return;
                                    }

                                    final ok = await vm.registrarPago(
                                      codRecibo: widget.codRecibo,
                                      monto: monto,
                                      medio: _medio,
                                      referencia: _ref.text.trim().isEmpty
                                          ? null
                                          : _ref.text.trim(),
                                      observacion: _obs.text.trim().isEmpty
                                          ? null
                                          : _obs.text.trim(),
                                    );
                                    if (ok) {
                                      _monto.clear();
                                      _ref.clear();
                                      _obs.clear();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                              'Pago registrado exitosamente.'),
                                          backgroundColor: Colors.green[600],
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(vm.error ??
                                              'Error al registrar el pago'),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.verified, size: 20),
                            label: const Text('MARCAR PAGADO'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: saldoInsuficiente
                                  ? Colors.grey
                                  : const Color(0xFF2E7D32),
                              side: BorderSide(
                                color: saldoInsuficiente
                                    ? Colors.grey[300]!
                                    : const Color(0xFF2E7D32),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: saldoInsuficiente
                                ? null
                                : () async {
                                    final ok = await vm.marcarReciboPagado(
                                        widget.codRecibo);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(ok
                                            ? 'Recibo marcado como PAGADO'
                                            : (vm.error ?? 'Error')),
                                        backgroundColor:
                                            ok ? Colors.green[600] : Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    );
                                    if (ok) Navigator.pop(context);
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.print, size: 20),
                        label: const Text('IMPRIMIR BOLETA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor: Colors.blue[300],
                        ),
                        onPressed: () async {
                          final msg = await vm.imprimirBoleta(
                              context, widget.codRecibo);
                          if (msg != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                backgroundColor: Colors.blue[600],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 14, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
