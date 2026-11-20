import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorDemoPage extends StatefulWidget {
  const SensorDemoPage({super.key});

  @override
  State<SensorDemoPage> createState() => _SensorDemoPageState();
}

class _SensorDemoPageState extends State<SensorDemoPage> {
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  String _reading = 'Gerakkan ponsel secara perlahan.';
  double _x = 0, _y = 0, _z = 0;

  @override
  void initState() {
    super.initState();
    _subscription = userAccelerometerEventStream().listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _x = event.x;
          _y = event.y;
          _z = event.z;
          _reading = 'x: ${event.x.toStringAsFixed(2)} | '
              'y: ${event.y.toStringAsFixed(2)} | '
              'z: ${event.z.toStringAsFixed(2)} m/s²';
        });
      },
      onError: (Object error) {
        if (mounted) setState(() => _reading = 'Sensor tidak tersedia: $error');
      },
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Demo Accelerometer')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sensors, size: 60, color: Colors.teal),
              const SizedBox(height: 20),
              Text(
                _reading,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              // ── Bar visual ─────────────────────────────────
              _AxisBar(label: 'X', value: _x, color: Colors.red),
              const SizedBox(height: 10),
              _AxisBar(label: 'Y', value: _y, color: Colors.green),
              const SizedBox(height: 10),
              _AxisBar(label: 'Z', value: _z, color: Colors.blue),
              const SizedBox(height: 32),
              const Text(
                'Gerakkan ponsel ke berbagai arah dan amati perubahan nilai sumbu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
}

class _AxisBar extends StatelessWidget {
  const _AxisBar({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(-10.0, 10.0);
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(label,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LinearProgressIndicator(
            value: (clamped + 10) / 20,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 16,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(value.toStringAsFixed(2),
              style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
