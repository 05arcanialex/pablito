import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

/// UI REAL
class _UbicacionesScaffold extends StatefulWidget {
  final int? codCliente;
  const _UbicacionesScaffold({super.key, this.codCliente});

  @override
  State<_UbicacionesScaffold> createState() => _UbicacionesScaffoldState();
}

class _UbicacionesScaffoldState extends State<_UbicacionesScaffold> {
  GoogleMapController? _controller;
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) {
      _inited = true;
      Future.microtask(() async {
        try {
          await context.read<UbicacionesViewModel>().init();
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
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UbicacionesViewModel>();
    final pos = vm.pickedLatLng ?? vm.currentLatLng;

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          vm.clienteNombreSel.isEmpty ? 'UBICACIÓN DEL CLIENTE' : 'UBICACIÓN • ${vm.clienteNombreSel}',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: vm.toggleSeguir,
            icon: Icon(vm.siguiendo ? Icons.my_location : Icons.location_disabled),
            tooltip: vm.siguiendo ? 'SEGUIR MI UBICACIÓN' : 'DEJAR DE SEGUIR',
          ),
        ],
      ),
      body: (vm.loading && pos == null)
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                if (pos != null)
                  _buildSafeMap(pos, vm)
                else
                  const Center(
                    child: Text(
                      'OBTENIENDO COORDENADAS...',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                _infoCard(vm),
                _actionButtons(vm),
              ],
            ),
    );
  }

  /// ENVUELVE GOOGLE MAPS EN TRY/CATCH PARA EVITAR CRASHES NATIVOS
  Widget _buildSafeMap(LatLng pos, UbicacionesViewModel vm) {
    try {
      return GoogleMap(
        initialCameraPosition: CameraPosition(target: pos, zoom: 16),
        onMapCreated: (c) => _controller = c,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        compassEnabled: true,
        trafficEnabled: false,
        buildingsEnabled: true,
        mapToolbarEnabled: false,
        markers: _marker(vm),
      );
    } catch (e) {
      return Center(
        child: Text(
          'NO SE PUDO MOSTRAR EL MAPA: $e',
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }
  }

  Set<Marker> _marker(UbicacionesViewModel vm) {
    final pos = vm.pickedLatLng ?? vm.currentLatLng;
    if (pos == null) return {};
    return {
      Marker(
        markerId: const MarkerId('ubicacion'),
        position: pos,
        draggable: true,
        onDragEnd: vm.onDragMarker,
        infoWindow: const InfoWindow(title: 'MI UBICACIÓN'),
      ),
    };
  }

  Widget _infoCard(UbicacionesViewModel vm) => Positioned(
        top: 15,
        left: 12,
        right: 12,
        child: Card(
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Text(
                  '¿ES ESTA SU UBICACIÓN?',
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.place, color: Colors.red),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        vm.direccion.isEmpty ? 'OBTENIENDO DIRECCIÓN...' : vm.direccion,
                        style: AppTextStyles.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'CORREGIR DIRECCIÓN (OPCIONAL)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: vm.setDireccionManual,
                ),
              ],
            ),
          ),
        ),
      );

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
                    onPressed: vm.pickedLatLng == null ? null : () => _goMaps(vm),
                    icon: const Icon(Icons.navigation),
                    label: const Text('NAVEGAR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: vm.loading
                        ? null
                        : () async {
                            final ok = await vm.confirmarSolicitud(
                              codCliente: widget.codCliente,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'AUXILIO REGISTRADO (#${vm.codRegistro})'
                                      : (vm.error ?? 'ERROR AL GUARDAR'),
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.sos),
                    label: const Text('SOLICITAR AUXILIO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (vm.pickedLatLng != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'LAT: ${vm.pickedLatLng!.latitude.toStringAsFixed(6)}  |  LNG: ${vm.pickedLatLng!.longitude.toStringAsFixed(6)}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      );

  Future<void> _goMaps(UbicacionesViewModel vm) async {
    final p = vm.pickedLatLng ?? vm.currentLatLng;
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
          const SnackBar(content: Text('NO SE PUDO ABRIR MAPS')),
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
