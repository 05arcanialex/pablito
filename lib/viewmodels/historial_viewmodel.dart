import 'package:flutter/material.dart';
import '../models/database_helper.dart';

class HistorialItem {
  final String modulo;
  final String tipo;
  final String titulo;
  final String subtitulo;
  final double? monto;
  final String fechaIso;
  final int? codCliente;
  final String? refTable;
  final int? refId;

  HistorialItem({
    required this.modulo,
    required this.tipo,
    required this.titulo,
    required this.subtitulo,
    this.monto,
    required this.fechaIso,
    this.codCliente,
    this.refTable,
    this.refId,
  });
}

class HistorialViewModel extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  // Estado general
  bool _loading = false;
  String? _error;
  List<HistorialItem> _items = [];
  int _offset = 0;
  final int _limit = 25;
  bool _hasMore = true;

  // Filtros
  String _moduloFiltro = 'TODOS';
  String _query = '';
  DateTime? _desde;
  DateTime? _hasta;

  bool get loading => _loading;
  String? get error => _error;
  List<HistorialItem> get items => _items;
  bool get hasMore => _hasMore;

  String get moduloFiltro => _moduloFiltro;
  String get query => _query;
  DateTime? get desde => _desde;
  DateTime? get hasta => _hasta;

  // =================== INIT ===================
  Future<void> init() async {
    await refresh();
  }

  // =================== REFRESH ===================
  Future<void> refresh() async {
    _offset = 0;
    _items.clear();
    _hasMore = true;
    await _fetch();
  }

  // =================== LOAD MORE ===================
  Future<void> loadMore() async {
    if (!_hasMore || _loading) return;
    await _fetch();
  }

  // =================== SETTERS DE FILTROS ===================
  void setModulo(String mod) {
    _moduloFiltro = mod;
    refresh();
  }

  void setQuery(String q) {
    _query = q;
    refresh();
  }

  void setFecha(DateTime? d1, DateTime? d2) {
    _desde = d1;
    _hasta = d2;
    refresh();
  }

  // =================== CONSULTA PRINCIPAL ===================
  Future<void> _fetch() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final db = await _db.database;

      final desdeStr = _desde?.toIso8601String() ?? '1900-01-01T00:00:00';
      final hastaStr = _hasta?.toIso8601String() ?? '2100-12-31T23:59:59';

      final res = await db.rawQuery('''
        SELECT *
        FROM vw_historial_all
        WHERE (fecha_iso BETWEEN ? AND ?)
          AND (? = 'TODOS' OR modulo = ?)
          AND (titulo LIKE ? OR subtitulo LIKE ?)
        ORDER BY fecha_iso DESC
        LIMIT ? OFFSET ?;
      ''', [
        desdeStr,
        hastaStr,
        _moduloFiltro,
        _moduloFiltro,
        '%$_query%',
        '%$_query%',
        _limit,
        _offset,
      ]);

      final nuevos = res.map((r) {
        return HistorialItem(
          modulo: r['modulo']?.toString() ?? '',
          tipo: r['tipo']?.toString() ?? '',
          titulo: r['titulo']?.toString() ?? '',
          subtitulo: r['subtitulo']?.toString() ?? '',
          monto: r['monto'] != null
              ? double.tryParse(r['monto'].toString())
              : null,
          fechaIso: r['fecha_iso']?.toString() ?? '',
          codCliente: r['cod_cliente'] != null
              ? int.tryParse(r['cod_cliente'].toString())
              : null,
          refTable: r['ref_table']?.toString(),
          refId: r['ref_id'] != null
              ? int.tryParse(r['ref_id'].toString())
              : null,
        );
      }).toList();

      if (nuevos.length < _limit) _hasMore = false;
      _offset += nuevos.length;
      _items.addAll(nuevos);
    } catch (e) {
      _error = 'Error al obtener historial: $e';
    }

    _loading = false;
    notifyListeners();
  }

  // =================== KPIs / REPORTES ===================
  Future<Map<String, dynamic>> getKpis() async {
    final db = await _db.database;
    final desdeStr = _desde?.toIso8601String() ?? '1900-01-01T00:00:00';
    final hastaStr = _hasta?.toIso8601String() ?? '2100-12-31T23:59:59';

    final modCount = await db.rawQuery('''
      SELECT modulo, COUNT(*) AS cnt
      FROM vw_historial_all
      WHERE fecha_iso BETWEEN ? AND ?
      GROUP BY modulo;
    ''', [desdeStr, hastaStr]);

    final totalPagos = await db.rawQuery('''
      SELECT SUM(monto) AS total
      FROM vw_historial_all
      WHERE modulo='PAGOS' AND fecha_iso BETWEEN ? AND ?;
    ''', [desdeStr, hastaStr]);

    return {
      'porModulo': modCount,
      'totalPagos': totalPagos.first['total'] ?? 0.0,
    };
  }
}
