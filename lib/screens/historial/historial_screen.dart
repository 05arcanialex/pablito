import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/historial_viewmodel.dart';
import '../../utils/constants.dart';

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HistorialViewModel()..init(),
      child: const _HistorialScaffold(),
    );
  }
}

class _HistorialScaffold extends StatefulWidget {
  const _HistorialScaffold();

  @override
  State<_HistorialScaffold> createState() => _HistorialScaffoldState();
}

class _HistorialScaffoldState extends State<_HistorialScaffold> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final vm = context.read<HistorialViewModel>();
      if (_scroll.position.pixels >=
          _scroll.position.maxScrollExtent - 200) {
        vm.loadMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistorialViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('HISTORIAL GENERAL'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: vm.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          _Filtros(vm),
          Expanded(
            child: vm.loading && vm.items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _HistorialList(vm: vm, scroll: _scroll),
          ),
        ],
      ),
    );
  }
}

class _Filtros extends StatelessWidget {
  final HistorialViewModel vm;
  const _Filtros(this.vm);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<String>(
              value: vm.moduloFiltro,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'TODOS', child: Text('TODOS')),
                DropdownMenuItem(value: 'PAGOS', child: Text('PAGOS')),
                DropdownMenuItem(value: 'AUXILIO', child: Text('AUXILIO')),
                DropdownMenuItem(value: 'SERVICIOS', child: Text('SERVICIOS')),
                DropdownMenuItem(value: 'OBJETOS', child: Text('OBJETOS')),
                DropdownMenuItem(value: 'CLIENTES', child: Text('CLIENTES')),
              ],
              onChanged: (v) => vm.setModulo(v ?? 'TODOS'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: vm.setQuery,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorialList extends StatelessWidget {
  final HistorialViewModel vm;
  final ScrollController scroll;
  const _HistorialList({required this.vm, required this.scroll});

  Color _modColor(String mod) {
    switch (mod) {
      case 'PAGOS':
        return Colors.green.shade400;
      case 'AUXILIO':
        return Colors.red.shade400;
      case 'SERVICIOS':
        return Colors.blue.shade400;
      case 'OBJETOS':
        return Colors.deepPurple.shade400;
      case 'CLIENTES':
        return Colors.orange.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (vm.error != null) {
      return Center(child: Text(vm.error!, style: const TextStyle(color: Colors.red)));
    }
    if (vm.items.isEmpty) {
      return const Center(child: Text('SIN REGISTROS'));
    }

    return ListView.builder(
      controller: scroll,
      itemCount: vm.items.length + (vm.hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= vm.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = vm.items[i];
        final color = _modColor(item.modulo);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          elevation: 3,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color,
              child: Text(item.modulo[0],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text(item.titulo,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(item.subtitulo),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (item.monto != null)
                  Text('Bs ${item.monto!.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold)),
                Text(
                  item.fechaIso.split('T').first,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
