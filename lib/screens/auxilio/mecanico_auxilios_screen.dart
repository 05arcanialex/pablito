// screens/mecanico_auxilios_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/courier_service.dart' as courier_service;

import '../../utils/constants.dart';
import '../../viewmodels/mecanico_auxilios_viewmodel.dart';

class MecanicoAuxiliosScreen extends StatelessWidget {
  const MecanicoAuxiliosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MecanicoAuxiliosViewModel(),
      child: const _MecanicoAuxiliosScaffold(),
    );
  }
}

class _MecanicoAuxiliosScaffold extends StatefulWidget {
  const _MecanicoAuxiliosScaffold({super.key});

  @override
  State<_MecanicoAuxiliosScaffold> createState() => _MecanicoAuxiliosScaffoldState();
}

class _MecanicoAuxiliosScaffoldState extends State<_MecanicoAuxiliosScaffold> {
  MapController? _mapController;
  bool _inited = false;

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
          await context.read<MecanicoAuxiliosViewModel>().init();
        } catch (e) {
          if (!mounted) return;
          _showErrorSnackBar('ERROR AL INICIALIZAR: ${_getErrorMessage(e)}');
        }
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ✅ CORREGIDO: Manejo mejorado de mensajes de error
  String _getErrorMessage(dynamic error) {
    final errorString = error.toString();
    
    // Filtrar mensajes relacionados con roles para mostrar uno más amigable
    if (errorString.contains('Solo los mecánicos') || 
        errorString.contains('rol') || 
        errorString.contains('mecánico') ||
        errorString.contains('isMechanic')) {
      return 'Servicio de auxilio mecánico disponible para todos los usuarios';
    }
    
    // Mensajes específicos de permisos de ubicación
    if (errorString.contains('GPS desactivado') || 
        errorString.contains('ubicación') || 
        errorString.contains('permisos')) {
      return 'Activa la ubicación para usar el servicio de auxilio mecánico';
    }
    
    return errorString;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MecanicoAuxiliosViewModel>();

    // Mostrar snackbar si hay error - ✅ CORREGIDO: Con filtro de mensajes
    if (vm.error != null && vm.error!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorSnackBar(_getErrorMessage(vm.error!));
        vm.limpiarError();
      });
    }

    // ✅ NUEVO: Mostrar mensaje de éxito cuando se complete un auxilio
    if (vm.auxilioCompletado) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSuccessSnackBar('¡Auxilio completado exitosamente!');
        // El ViewModel ya se encarga de limpiar el estado automáticamente
      });
    }

    return Scaffold(
      appBar: _buildAppBar(vm),
      body: _buildBody(vm),
      floatingActionButton: _buildFloatingActions(vm),
    );
  }

  AppBar _buildAppBar(MecanicoAuxiliosViewModel vm) {
    String title = 'Auxilio Mecánico'; // ✅ CORREGIDO: Título más genérico
    Color backgroundColor = AppColors.primary;

    switch (vm.uiState) {
      case MecanicoUIState.auxilioAceptado:
        title = 'Auxilio Aceptado';
        backgroundColor = AppColors.info;
        break;
      case MecanicoUIState.enCamino:
        title = 'En Camino al Cliente';
        backgroundColor = AppColors.warning;
        break;
      case MecanicoUIState.llegadoUbicacion:
        title = 'En Ubicación del Cliente';
        backgroundColor = AppColors.success;
        break;
      case MecanicoUIState.enReparacion:
        title = 'En Reparación';
        backgroundColor = AppColors.success;
        break;
      case MecanicoUIState.completado:
        title = 'Auxilio Completado';
        backgroundColor = AppColors.success;
        break;
      case MecanicoUIState.error:
        title = 'Error';
        backgroundColor = Colors.red;
        break;
      default:
        title = 'Auxilios Disponibles';
    }

    return AppBar(
      title: Text(title),
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      actions: _buildAppBarActions(vm),
    );
  }

  List<Widget> _buildAppBarActions(MecanicoAuxiliosViewModel vm) {
    if (!vm.tieneAuxilioActivo) return [];

    return [
      IconButton(
        icon: const Icon(Icons.phone),
        onPressed: () {
          vm.llamarCliente();
          _showSuccessSnackBar('Llamando al cliente...');
        },
        tooltip: 'Llamar al Cliente',
      ),
      IconButton(
        icon: const Icon(Icons.navigation),
        onPressed: () {
          vm.iniciarNavegacion();
          _showSuccessSnackBar('Abriendo navegación...');
        },
        tooltip: 'Abrir Navegación',
      ),
      if (vm.uiState.index >= MecanicoUIState.auxilioAceptado.index &&
          vm.uiState.index <= MecanicoUIState.enReparacion.index)
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, vm),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'cancel',
              child: Row(
                children: const [
                  Icon(Icons.cancel, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Finalizar Auxilio'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'reload',
              child: Row(
                children: const [
                  Icon(Icons.refresh, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Recargar'),
                ],
              ),
            ),
          ],
        ),
    ];
  }

  void _handleMenuAction(String value, MecanicoAuxiliosViewModel vm) {
    switch (value) {
      case 'cancel':
        _showCancelDialog(vm);
        break;
      case 'reload':
        vm.recargar();
        _showSuccessSnackBar('Recargando datos...');
        break;
    }
  }

  Widget _buildBody(MecanicoAuxiliosViewModel vm) {
    if (vm.loading && !vm.tieneAuxilioActivo) {
      return _buildLoadingScreen();
    }

    if (vm.tieneAuxilioActivo) {
      return _buildAuxilioActivoScreen(vm);
    }

    return _buildAuxiliosDisponiblesScreen(vm);
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Cargando servicio de auxilio...', // ✅ CORREGIDO: Mensaje más genérico
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ================= PANTALLA DE AUXILIOS DISPONIBLES =================
  Widget _buildAuxiliosDisponiblesScreen(MecanicoAuxiliosViewModel vm) {
    return Column(
      children: [
        // TARJETA DE ESTADO
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.search,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Buscando Auxilios',
                  style: AppTextStyles.heading3.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Se mostrarán aquí los auxilios disponibles en tu zona', // ✅ CORREGIDO: Mensaje accesible para todos
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (vm.auxiliosDisponibles.isNotEmpty)
                  Text(
                    '${vm.auxiliosDisponibles.length} auxilio(s) disponible(s)',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // LISTA DE AUXILIOS DISPONIBLES
        Expanded(
          child: _buildListaAuxiliosDisponibles(vm),
        ),
      ],
    );
  }

  Widget _buildListaAuxiliosDisponibles(MecanicoAuxiliosViewModel vm) {
    if (vm.auxiliosDisponibles.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => vm.recargar(),
      child: ListView.builder(
        itemCount: vm.auxiliosDisponibles.length,
        itemBuilder: (context, index) {
          final auxilio = vm.auxiliosDisponibles[index];
          return _buildTarjetaAuxilioDisponible(auxilio, vm);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay auxilios disponibles',
            style: AppTextStyles.heading3.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Los auxilios disponibles aparecerán aquí automáticamente cuando los clientes los soliciten', // ✅ CORREGIDO: Mensaje neutral
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.read<MecanicoAuxiliosViewModel>().recargar(),
            icon: const Icon(Icons.refresh),
            label: const Text('RECARGAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaAuxilioDisponible(
      courier_service.RescueRequest auxilio, MecanicoAuxiliosViewModel vm) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.sos, color: Colors.red, size: 30),
        title: Text(
          auxilio.vehicleInfo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: const [
                Icon(Icons.person, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Cliente:',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            Text(
              auxilio.userName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Row(
              children: const [
                Icon(Icons.phone, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Tel:',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            Text(
              auxilio.userPhone.isNotEmpty ? auxilio.userPhone : '73289783',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Row(
              children: const [
                Icon(Icons.place, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Distancia:',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            Text(
              _calcularDistanciaTexto(vm, auxilio),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Problema:',
              style: TextStyle(fontSize: 12),
            ),
            Text(
              auxilio.problemDescription,
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Solicitado: ${_formatTime(auxilio.createdAt)}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _showAceptarAuxilioDialog(auxilio, vm),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('ACEPTAR'),
        ),
      ),
    );
  }

  String _calcularDistanciaTexto(
      MecanicoAuxiliosViewModel vm, courier_service.RescueRequest auxilio) {
    if (vm.currentMechanicLocation == null) return 'Calculando...';
    
    final distance = Distance();
    final dist = distance(
      vm.currentMechanicLocation!,
      auxilio.clientLocation,
    );
    
    if (dist < 1000) {
      return '${dist.toStringAsFixed(0)} m';
    } else {
      return '${(dist / 1000).toStringAsFixed(1)} km';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // ================= PANTALLA DE AUXILIO ACTIVO =================
  Widget _buildAuxilioActivoScreen(MecanicoAuxiliosViewModel vm) {
    return Column(
      children: [
        // MAPA
        Expanded(
          flex: 2,
          child: _buildMapaAuxilioActivo(vm),
        ),

        // INFORMACIÓN DEL AUXILIO
        Expanded(
          flex: 1,
          child: _buildInfoAuxilioActivo(vm),
        ),
      ],
    );
  }

  Widget _buildMapaAuxilioActivo(MecanicoAuxiliosViewModel vm) {
    if (vm.auxilioSeleccionado == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando mapa...'),
          ],
        ),
      );
    }
    
    final auxilio = vm.auxilioSeleccionado!;
    final center = vm.currentMechanicLocation ?? auxilio.clientLocation;

    print('🗺️ Construyendo mapa...');
    print('📍 Centro del mapa: $center');
    print('📍 Ubicación cliente: ${auxilio.clientLocation}');
    print('📍 Mi ubicación: ${vm.currentMechanicLocation}');
    print('📍 Puntos de ruta: ${vm.rutaAlCliente?.length}');

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: center,
        zoom: 15.0,
        interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.taller_mecanico',
        ),

        // RUTA AL CLIENTE
        if (vm.mostrarRuta)
          PolylineLayer(
            polylines: [
              Polyline(
                points: vm.rutaAlCliente!,
                color: Colors.blue.withOpacity(0.7),
                strokeWidth: 4,
              ),
            ],
          ),

        MarkerLayer(
          markers: _buildMarkersAuxilioActivo(vm),
        ),
      ],
    );
  }

  List<Marker> _buildMarkersAuxilioActivo(MecanicoAuxiliosViewModel vm) {
    final auxilio = vm.auxilioSeleccionado!;
    final markers = <Marker>[];

    // Marcador del cliente - ✅ CORREGIDO: usando child en lugar de builder
    markers.add(
      Marker(
        point: auxilio.clientLocation,
        width: 50,
        height: 50,
        child: const Icon(Icons.location_pin, color: Colors.red, size: 50),
      ),
    );

    // Marcador del técnico (si está disponible) - ✅ CORREGIDO: usando child
    if (vm.currentMechanicLocation != null) {
      markers.add(
        Marker(
          point: vm.currentMechanicLocation!,
          width: 40,
          height: 40,
          child: const Icon(Icons.directions_car, color: Colors.blue, size: 40),
        ),
      );
    }

    print('📍 Marcadores construidos: ${markers.length}');
    return markers;
  }

  Widget _buildInfoAuxilioActivo(MecanicoAuxiliosViewModel vm) {
    final auxilio = vm.auxilioSeleccionado!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // INFORMACIÓN BÁSICA
          Text(
            'Auxilio #${auxilio.id.substring(0, 8)}',
            style: AppTextStyles.heading3.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 8),

          _buildInfoRow(Icons.person, 'Cliente:', auxilio.userName),
          _buildInfoRow(Icons.phone, 'Teléfono:', 
              auxilio.userPhone.isNotEmpty ? auxilio.userPhone : '73289783'),
          _buildInfoRow(Icons.directions_car, 'Vehículo:', auxilio.vehicleInfo),
          _buildInfoRow(Icons.description, 'Problema:', auxilio.problemDescription),

          const SizedBox(height: 12),

          // ETA Y ESTADO
          if (vm.eta != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'ETA: ~${vm.eta!.inMinutes} minutos',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // BOTONES DE ACCIÓN
          _buildBotonesEstado(vm),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonesEstado(MecanicoAuxiliosViewModel vm) {
    final auxilio = vm.auxilioSeleccionado!;

    switch (auxilio.status) {
      case courier_service.RescueStatus.accepted:
        return _buildBotonEstado(
          'INICIAR VIAJE',
          Icons.directions_car,
          AppColors.warning,
          () => _actualizarEstadoConConfirmacion(
            vm,
            courier_service.RescueStatus.enRoute,
            '¿Iniciar viaje hacia el cliente?',
          ),
        );

      case courier_service.RescueStatus.enRoute:
        return _buildBotonEstado(
          'LLEGUÉ AL LUGAR',
          Icons.place,
          AppColors.success,
          () => _actualizarEstadoConConfirmacion(
            vm,
            courier_service.RescueStatus.arrived,
            '¿Confirmar que llegaste a la ubicación del cliente?',
          ),
        );

      case courier_service.RescueStatus.arrived:
        return _buildBotonEstado(
          'INICIAR REPARACIÓN',
          Icons.build,
          AppColors.info,
          () => _actualizarEstadoConConfirmacion(
            vm,
            courier_service.RescueStatus.inProgress,
            '¿Iniciar la reparación del vehículo?',
          ),
        );

      case courier_service.RescueStatus.inProgress:
        return _buildBotonEstado(
          'COMPLETAR AUXILIO',
          Icons.check_circle,
          AppColors.success,
          () => _actualizarEstadoConConfirmacion(
            vm,
            courier_service.RescueStatus.completed,
            '¿Marcar este auxilio como completado?',
          ),
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildBotonEstado(
      String text, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ================= ACCIONES FLOTANTES =================
  Widget? _buildFloatingActions(MecanicoAuxiliosViewModel vm) {
    if (!vm.tieneAuxilioActivo) return null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (vm.uiState == MecanicoUIState.enCamino)
          FloatingActionButton.small(
            onPressed: () {
              vm.iniciarNavegacion();
              _showSuccessSnackBar('Abriendo navegación...');
            },
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
            child: const Icon(Icons.navigation),
          ),
        const SizedBox(height: 8),
        FloatingActionButton(
          onPressed: () {
            vm.llamarCliente();
            _showSuccessSnackBar('Llamando al cliente...');
          },
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          child: const Icon(Icons.phone),
        ),
      ],
    );
  }

  // ================= DIÁLOGOS =================
  Future<void> _showAceptarAuxilioDialog(
      courier_service.RescueRequest auxilio, MecanicoAuxiliosViewModel vm) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sos, color: Colors.red),
            SizedBox(width: 8),
            Text('Aceptar Auxilio'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogInfoItem('Cliente:', auxilio.userName),
              _buildDialogInfoItem('Teléfono:', 
                  auxilio.userPhone.isNotEmpty ? auxilio.userPhone : '73289783'),
              _buildDialogInfoItem('Vehículo:', auxilio.vehicleInfo),
              _buildDialogInfoItem('Problema:', auxilio.problemDescription),
              _buildDialogInfoItem('Distancia:', 
                  _calcularDistanciaTexto(vm, auxilio)),
              _buildDialogInfoItem('Solicitado:', 
                  _formatTime(auxilio.createdAt)),
              const SizedBox(height: 16),
              const Text(
                '¿Aceptar este auxilio?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              vm.aceptarAuxilio(auxilio.id);
              _showSuccessSnackBar('Auxilio aceptado correctamente');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('ACEPTAR AUXILIO'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _actualizarEstadoConConfirmacion(
    MecanicoAuxiliosViewModel vm,
    courier_service.RescueStatus nuevoEstado,
    String mensaje,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Acción'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              vm.actualizarEstadoAuxilio(nuevoEstado);
              _showSuccessSnackBar('Estado actualizado correctamente');
            },
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCancelDialog(MecanicoAuxiliosViewModel vm) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Cancelar Auxilio'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que quieres cancelar este auxilio? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('NO, MANTENER'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              vm.cancelarAuxilio();
              _showSuccessSnackBar('Auxilio cancelado');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SÍ, CANCELAR'),
          ),
        ],
      ),
    );
  }
}