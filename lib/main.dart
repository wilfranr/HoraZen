import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:weather/weather.dart';
import 'package:geolocator/geolocator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await initializeDateFormatting('es_ES', null);
  runApp(const ClockApp());
}

class ClockApp extends StatelessWidget {
  const ClockApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ClockScreen(),
    );
  }
}

class ClockScreen extends StatefulWidget {
  const ClockScreen({Key? key}) : super(key: key);

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  // --- ESTADO DEL RELOJ ---
  late Timer _timer;
  late DateTime _currentTime;

  // --- ESTADO DE LA BARRA DE INFORMACIÓN ---
  final Battery _battery = Battery();
  int _batteryLevel = 0;
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  // --- IMPORTANTE: REEMPLAZA CON TU CLAVE DE API ---
  final WeatherFactory _wf = WeatherFactory("3076b13538df91c4620c2a4886e59c21");
  String _weatherInfo = "Obteniendo clima...";

  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  int _calendarEventsCount = 0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
    _initPlatformState();
  }

  @override
  void dispose() {
    _timer.cancel();
    _batteryStateSubscription?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _updateTime() {
    if (mounted) setState(() => _currentTime = DateTime.now());
  }

  // --- MÉTODOS PARA OBTENER DATOS ---

  Future<void> _initPlatformState() async {
    _listenToBatteryState();
    await _fetchWeatherData();
    await _fetchCalendarEvents();
  }

  void _listenToBatteryState() async {
    final batteryLevel = await _battery.batteryLevel;
    if (mounted) setState(() => _batteryLevel = batteryLevel);
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen((_) async {
      final newLevel = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = newLevel);
    });
  }

  Future<void> _fetchWeatherData() async {
    try {
      Position position = await _getCurrentLocation();
      Weather w = await _wf.currentWeatherByLocation(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _weatherInfo = "${w.temperature?.celsius?.toStringAsFixed(0)}°C en ${w.areaName}");
      }
    } catch (e) {
      if (mounted) setState(() => _weatherInfo = "Clima no disponible");
    }
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Servicios de ubicación desactivados.');
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Permiso de ubicación denegado.');
    }
    if (permission == LocationPermission.deniedForever) return Future.error('Permiso de ubicación denegado permanentemente.');
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _fetchCalendarEvents() async {
    var status = await Permission.calendar.request();
    if (status.isGranted) {
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data!.isNotEmpty) {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        int eventCount = 0;
        for (var calendar in calendarsResult.data!) {
          if (calendar.isReadOnly == true) continue;
          final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
            calendar.id, RetrieveEventsParams(startDate: startOfDay, endDate: endOfDay));
          if (eventsResult.isSuccess && eventsResult.data != null) eventCount += eventsResult.data!.length;
        }
        if (mounted) setState(() => _calendarEventsCount = eventCount);
      }
    }
  }

  // --- CONSTRUCCIÓN DE LA INTERFAZ DE USUARIO ---

  // ESTE ES EL MÉTODO BUILD QUE FALTABA
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Llamamos a la función que construye la barra superior
          _buildTopInfoBar(),
          // El reloj ocupa el resto de la pantalla
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('HH:mm:ss', 'es_ES').format(_currentTime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(_currentTime),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Y AQUÍ ESTÁ LA FUNCIÓN PARA LA BARRA, DEFINIDA UNA SOLA VEZ
  Widget _buildTopInfoBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  const Icon(Icons.thermostat, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _weatherInfo,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('$_calendarEventsCount', style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(width: 20),
                Text('$_batteryLevel%', style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(width: 8),
                const Icon(Icons.battery_full, color: Colors.white, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
