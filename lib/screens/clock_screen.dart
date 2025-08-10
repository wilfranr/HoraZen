import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ClockScreen extends StatefulWidget {
  const ClockScreen({Key? key}) : super(key: key);

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  late Timer _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    // Evita que la pantalla se apague
    WakelockPlus.enable();
    _currentTime = DateTime.now();
    // Actualiza la hora cada segundo
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  @override
  void dispose() {
    _timer.cancel();
    // Permite que la pantalla se apague de nuevo
    WakelockPlus.disable();
    super.dispose();
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;

    Widget digitalClock = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          DateFormat('HH:mm').format(_currentTime),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 120,
            fontWeight: FontWeight.bold,
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
    );

    Widget analogClock = _AnalogClock(time: _currentTime);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: orientation == Orientation.landscape
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  digitalClock,
                  const SizedBox(width: 20),
                  analogClock,
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  analogClock,
                  const SizedBox(height: 20),
                  digitalClock,
                ],
              ),
      ),
    );
  }
}

class _AnalogClock extends StatelessWidget {
  final DateTime time;

  const _AnalogClock({Key? key, required this.time}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(
        painter: _AnalogClockPainter(time),
      ),
    );
  }
}

class _AnalogClockPainter extends CustomPainter {
  final DateTime time;

  _AnalogClockPainter(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, outline);

    // Horas
    final hourAngle = (time.hour % 12 + time.minute / 60) * 30 * pi / 180;
    final hourHandLength = radius * 0.5;
    final hourPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      center + Offset(hourHandLength * sin(hourAngle), -hourHandLength * cos(hourAngle)),
      hourPaint,
    );

    // Minutos
    final minuteAngle = (time.minute + time.second / 60) * 6 * pi / 180;
    final minuteHandLength = radius * 0.7;
    final minutePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      center + Offset(minuteHandLength * sin(minuteAngle), -minuteHandLength * cos(minuteAngle)),
      minutePaint,
    );

    // Segundos
    final secondAngle = time.second * 6 * pi / 180;
    final secondHandLength = radius * 0.9;
    final secondPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      center + Offset(secondHandLength * sin(secondAngle), -secondHandLength * cos(secondAngle)),
      secondPaint,
    );

    final centerDot = Paint()..color = Colors.white;
    canvas.drawCircle(center, 3, centerDot);
  }

  @override
  bool shouldRepaint(covariant _AnalogClockPainter oldDelegate) {
    return oldDelegate.time.second != time.second ||
        oldDelegate.time.minute != time.minute ||
        oldDelegate.time.hour != time.hour;
  }
}
