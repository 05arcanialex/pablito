// screens/ubicaciones_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/constants.dart';
import '../../viewmodels/ubicaciones_viewmodel.dart';

/// WRAPPER QUE GARANTIZA UN PROVIDER DISPONIBLE (GLOBAL O LOCAL)
class UbicacionesScreen extends StatelessWidget {
  final int? codCliente;
  const UbicacionesScreen({super.key, this.codCliente});

  @override
  Widget build(BuildContext context) {
    bool providerExists = false;
    try {
      Provider.of<UbicacionesViewModel>(context, listen: false);
      providerExists = true;
    } catch (_) {
      providerExists = false;
    }

    if (providerExists) {
      return _UbicacionesScaffold(codCliente: codCliente);
    } else {
      return ChangeNotifierProvider(
        create: (_) => UbicacionesViewModel(),
        child: _UbicacionesScaffold(codCliente: codCliente),
      );
    }
  }
}

/// UI REAL CON FLUTTER MAP Y COURRIER
class _UbicacionesScaffold extends StatefulWidget {
  final int? codCliente;
  const _UbicacionesScaffold({super.key, required this.codCliente});

  @override
  State<_UbicacionesScaffold> createState() => _UbicacionesScaffoldState();
}

class _UbicacionesScaffoldState extends State<_UbicacionesScaffold> {
  MapController? _mapController;
  bool _inited = false;
  LatLng? _draggedPosition;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) {
      _inited = true;
      Future.microtask(() async {
        try {
          await context
              .read<UbicacionesViewModel>()
              .init(initialCodCliente: widget.codCliente);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ERROR AL INICIALIZAR GPS: $e')),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UbicacionesViewModel>();
    final pos = _draggedPosition ?? vm.pickedLatLng ?? vm.currentLatLng;

    if (vm.error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('UBICACIÓN DEL CLIENTE'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            vm.error!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Si hay un rescate activo, mostrar estado especial
    if (vm.currentRescueId != null) {
      return _buildRescueInProgressScreen(vm);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          vm.clienteNombreSel.isEmpty
              ? 'UBICACIÓN DEL CLIENTE'
              : 'UBICACIÓN • ${vm.clienteNombreSel}',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: vm.toggleSeguir,
            icon: Icon(
              vm.siguiendo ? Icons.my_location : Icons.location_disabled,
            ),
            tooltip: vm.siguiendo ? 'SEGUIR MI UBICACIÓN' : 'DEJAR DE SEGUIR',
          ),
          IconButton(
            onPressed: () {
              final currentPos = vm.currentLatLng;
              if (currentPos != null) {
                _mapController?.move(currentPos, 16.0);
                setState(() {
                  _draggedPosition = null;
                });
              }
            },
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'CENTRAR EN MI UBICACIÓN',
          ),
          IconButton(
            onPressed: vm.loading ? null : () => _showClientSelector(vm),
            icon: const Icon(Icons.person_search),
            tooltip: 'SELECCIONAR CLIENTE',
          ),
        ],
      ),
      body: (vm.loading && pos == null)
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                if (pos != null)
                  _buildFlutterMap(pos, vm)
                else
                  const Center(
                    child: Text(
                      'OBTENIENDO COORDENADAS...',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                _infoCard(vm),
                _actionButtons(vm),
              ],
            ),
    );
  }

  /// PANTALLA CUANDO HAY UN RESCATE ACTIVO
  Widget _buildRescueInProgressScreen(UbicacionesViewModel vm) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AUXILIO EN CURSO'),
        backgroundColor: AppColors.warning,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _showCancelRescueDialog(vm),
            tooltip: 'CANCELAR AUXILIO',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildFlutterMapWithRescue(vm),
          ),
          _rescueStatusCard(vm),
        ],
      ),
    );
  }

  /// MAPA CON INFORMACIÓN DEL RESCATE
  Widget _buildFlutterMapWithRescue(UbicacionesViewModel vm) {
    final pos = _draggedPosition ?? vm.pickedLatLng ?? vm.currentLatLng;
    if (pos == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: pos,
        zoom: 16.0,
        onTap: (tapPosition, point) {
          setState(() {
            _draggedPosition = point;
          });
          vm.onDragMarker(point);
        },
        interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.taller_mecanico',
        ),
        // RUTA DEL MECÁNICO
        if (vm.routePolyline != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: vm.routePolyline!,
                color: Colors.blue.withOpacity(0.7),
                strokeWidth: 4,
              ),
            ],
          ),
        MarkerLayer(
          markers: _buildRescueMarkers(vm),
        ),
      ],
    );
  }

  /// MAPA NORMAL (SIN RESCATE ACTIVO)
  Widget _buildFlutterMap(LatLng pos, UbicacionesViewModel vm) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: pos,
        zoom: 16.0,
        onTap: (tapPosition, point) {
          setState(() {
            _draggedPosition = point;
          });
          vm.onDragMarker(point);
        },
        interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.taller_mecanico',
        ),
        MarkerLayer(
          markers: _buildMarkers(vm),
        ),
        if (vm.siguiendo && vm.currentLatLng != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: vm.currentLatLng!,
                color: Colors.blue.withOpacity(0.3),
                borderColor: Colors.blue,
                borderStrokeWidth: 2,
                radius: 10,
              ),
            ],
          ),
      ],
    );
  }

  List<Marker> _buildRescueMarkers(UbicacionesViewModel vm) {
    final markers = <Marker>[];
    final clientPos = _draggedPosition ?? vm.pickedLatLng ?? vm.currentLatLng;

    // Marcador del cliente
    if (clientPos != null) {
      markers.add(
        Marker(
          point: clientPos,
          width: 50,
          height: 50,
          child: const Icon(
            Icons.location_pin,
            color: Colors.red,
            size: 50,
          ),
        ),
      );
    }

    // Marcador del mecánico (si está disponible)
    if (vm.mechanicLocation != null) {
      markers.add(
        Marker(
          point: vm.mechanicLocation!,
          width: 50,
          height: 50,
          child: const Icon(
            Icons.directions_car,
            color: Colors.blue,
            size: 50,
          ),
        ),
      );
    }

    return markers;
  }

  List<Marker> _buildMarkers(UbicacionesViewModel vm) {
    final pos = _draggedPosition ?? vm.pickedLatLng ?? vm.currentLatLng;
    if (pos == null) return [];

    return [
      Marker(
        point: pos,
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Ubicación seleccionada: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
                ),
              ),
            );
          },
          child: const Icon(
            Icons.location_pin,
            color: Colors.red,
            size: 50,
          ),
        ),
      ),
    ];
  }

  Widget _infoCard(UbicacionesViewModel vm) => Positioned(
        top: 15,
        left: 12,
        right: 12,
        child: Card(
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿ES ESTA SU UBICACIÓN?',
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.place, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vm.direccion.isEmpty
                            ? 'OBTENIENDO DIRECCIÓN...'
                            : vm.direccion,
                        style: AppTextStyles.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_draggedPosition != null)
                  Text(
                    'Ubicación seleccionada manualmente',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'CORREGIR DIRECCIÓN (OPCIONAL)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.all(12),
                  ),
                  onChanged: vm.setDireccionManual,
                ),
              ],
            ),
          ),
        ),
      );

  /// TARJETA DE ESTADO DEL RESCATE
  Widget _rescueStatusCard(UbicacionesViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'AUXILIO EN CURSO',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 8),
          if (vm.mechanicLocation != null)
            Text(
              'Mecánico en camino',
              style: AppTextStyles.body.copyWith(color: AppColors.success),
            )
          else
            Text(
              'Buscando mecánico disponible...',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _showCancelRescueDialog(vm),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('CANCELAR AUXILIO'),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons(UbicacionesViewModel vm) => Positioned(
        bottom: 15,
        left: 12,
        right: 12,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (vm.pickedLatLng == null && _draggedPosition == null)
                            ? null
                            : () => _goMaps(vm),
                    icon: const Icon(Icons.navigation),
                    label: const Text('ABRIR EN MAPS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: vm.loading
                        ? null
                        : () => _showRescueDialog(vm),
                    icon: const Icon(Icons.sos),
                    label: const Text('SOLICITAR AUXILIO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_draggedPosition != null || vm.pickedLatLng != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LAT: ${(_draggedPosition ?? vm.pickedLatLng)!.latitude.toStringAsFixed(6)}  |  LNG: ${(_draggedPosition ?? vm.pickedLatLng)!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );

  /// DIÁLOGO PARA SELECCIONAR CLIENTE
  Future<void> _showClientSelector(UbicacionesViewModel vm) async {
    if (vm.clientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NO HAY CLIENTES REGISTRADOS')),
      );
      return;
    }

    int? selectedId = vm.codClienteSel;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('SELECCIONAR CLIENTE'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: vm.clientes.length,
              itemBuilder: (context, index) {
                final c = vm.clientes[index];
                final isSelected = c.id == selectedId;
                return ListTile(
                  title: Text(c.nombre),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check,
                          color: AppColors.success,
                        )
                      : null,
                  onTap: () {
                    selectedId = c.id;
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
          ],
        );
      },
    );

    if (selectedId != null) {
      await vm.setClienteSeleccionado(selectedId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CLIENTE SELECCIONADO CORRECTAMENTE')),
      );
    }
  }

  /// DIÁLOGO PARA SOLICITAR AUXILIO COURRIER
  Future<void> _showRescueDialog(UbicacionesViewModel vm) async {
    if (vm.codClienteSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DEBES SELECCIONAR UN CLIENTE PRIMERO')),
      );
      return;
    }

    if (vm.userVehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('EL CLIENTE NO TIENE VEHÍCULOS REGISTRADOS')),
      );
      return;
    }

    int? selectedVehicleId;
    String problema = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('SOLICITAR AUXILIO MECÁNICO'),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Seleccione vehículo',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      value: selectedVehicleId,
                      items: vm.userVehicles.map((vehicle) {
                        return DropdownMenuItem(
                          value: vehicle.id,
                          child: Text(
                            vehicle.descripcionCompleta,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedVehicleId = value;
                        });
                      },
                      isExpanded: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Descripción del problema',
                        border: OutlineInputBorder(),
                        hintText:
                            'Ej: No enciende el motor, ponchadura de llanta, etc.',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        problema = value;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedVehicleId == null || problema.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Completa todos los campos')),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  await _solicitarAuxilioCourrier(
                      vm, selectedVehicleId!, problema);
                },
                child: const Text('SOLICITAR AUXILIO'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _solicitarAuxilioCourrier(
    UbicacionesViewModel vm,
    int vehicleId,
    String problema,
  ) async {
    try {
      final rescueId = await vm.solicitarAuxilioCourrier(
        vehicleId: vehicleId,
        problema: problema,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auxilio solicitado correctamente (#$rescueId)'),
          backgroundColor: Colors.green,
        ),
      );

      // El ViewModel automáticamente cambiará a la pantalla de rescate en curso
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al solicitar auxilio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCancelRescueDialog(UbicacionesViewModel vm) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Auxilio'),
        content: const Text(
            '¿Estás seguro de que quieres cancelar el auxilio en curso?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('NO'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await vm.cancelarRescateActual();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Auxilio cancelado'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('SÍ, CANCELAR'),
          ),
        ],
      ),
    );
  }

  Future<void> _goMaps(UbicacionesViewModel vm) async {
    final p = _draggedPosition ?? vm.pickedLatLng ?? vm.currentLatLng;
    if (p == null) return;

    final uri = Uri.parse(
      Platform.isIOS
          ? 'http://maps.apple.com/?daddr=${p.latitude},${p.longitude}'
          : 'https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('NO SE PUDO ABRIR LA APLICACIÓN DE MAPAS')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ERROR AL ABRIR MAPS: $e')),
      );
    }
  }
}
