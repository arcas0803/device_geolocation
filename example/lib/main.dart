import 'dart:async';

import 'package:device_geolocation/device_geolocation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  LocationPermission? _permission;
  bool? _serviceEnabled;
  Position? _position;
  StreamSubscription<Position>? _positionSubscription;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    try {
      final perm = await DeviceGeolocation.checkPermission();
      final svc = await DeviceGeolocation.isLocationServiceEnabled();
      setState(() {
        _permission = perm;
        _serviceEnabled = svc;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _requestPermission() async {
    try {
      final perm = await DeviceGeolocation.requestPermission();
      setState(() {
        _permission = perm;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _getCurrentPosition() async {
    try {
      final pos = await DeviceGeolocation.getCurrentPosition();
      setState(() {
        _position = pos;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _toggleStream() {
    if (_positionSubscription != null) {
      _positionSubscription?.cancel();
      setState(() => _positionSubscription = null);
      return;
    }
    final sub =
        DeviceGeolocation.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          ),
        ).listen(
          (pos) => setState(() {
            _position = pos;
            _error = null;
          }),
          onError: (Object e) => setState(() => _error = e.toString()),
        );
    setState(() => _positionSubscription = sub);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('device_geolocation example')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text('Permission: ${_permission ?? "unknown"}'),
              Text('Service enabled: ${_serviceEnabled ?? "unknown"}'),
              const Divider(),
              if (_position != null) ...[
                Text('Latitude: ${_position!.latitude}'),
                Text('Longitude: ${_position!.longitude}'),
                Text('Accuracy: ${_position!.accuracy} m'),
                Text('Timestamp: ${_position!.timestamp.toIso8601String()}'),
              ] else
                const Text('No position yet'),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _refreshStatus,
                    child: const Text('Refresh status'),
                  ),
                  FilledButton(
                    onPressed: _requestPermission,
                    child: const Text('Request permission'),
                  ),
                  FilledButton(
                    onPressed: _getCurrentPosition,
                    child: const Text('Get current position'),
                  ),
                  FilledButton(
                    onPressed: _toggleStream,
                    child: Text(
                      _positionSubscription == null
                          ? 'Start stream'
                          : 'Stop stream',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => DeviceGeolocation.openAppSettings(),
                    child: const Text('App settings'),
                  ),
                  OutlinedButton(
                    onPressed: () => DeviceGeolocation.openLocationSettings(),
                    child: const Text('Location settings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
