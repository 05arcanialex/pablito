class ReciboPago {
  final int? codReciboPago;
  final DateTime fecha;
  final double? total;
  final double? aCuenta;
  final double? saldo;
  final String? transferenciaPago;
  final int codCliente;
  final int codEmpleado;
  final int codEstRec;

  ReciboPago({
    this.codReciboPago,
    required this.fecha,
    this.total,
    this.aCuenta,
    this.saldo,
    this.transferenciaPago,
    required this.codCliente,
    required this.codEmpleado,
    required this.codEstRec,
  });

  // 🔹 Conversión segura de fecha
  static DateTime _p(v) {
    if (v is DateTime) return v;
    return DateTime.parse('$v');
  }

  static String _f(DateTime d) => d.toIso8601String().split('T').first;

  // 🔹 Convertir desde mapa (por ejemplo, respuesta de API o base de datos)
  factory ReciboPago.fromMap(Map<String, dynamic> m) {
    double? d(v) => v == null
        ? null
        : (v is num ? v.toDouble() : double.tryParse('$v'));

    return ReciboPago(
      codReciboPago: m['cod_recibo_pago'] as int?,
      fecha: _p(m['fecha']),
      total: d(m['total']),
      aCuenta: d(m['a_cuenta']),
      saldo: d(m['saldo']),
      transferenciaPago: m['transferencia_pago'],
      codCliente: m['cod_cliente'],
      codEmpleado: m['cod_empleado'],
      codEstRec: m['cod_est_rec'],
    );
  }

  // 🔹 Convertir a mapa (por ejemplo, para enviar al backend)
  Map<String, dynamic> toMap() => {
        'cod_recibo_pago': codReciboPago,
        'fecha': _f(fecha),
        'total': total,
        'a_cuenta': aCuenta,
        'saldo': saldo,
        'transferencia_pago': transferenciaPago,
        'cod_cliente': codCliente,
        'cod_empleado': codEmpleado,
        'cod_est_rec': codEstRec,
      };
}
