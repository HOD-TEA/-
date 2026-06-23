import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mi_thermo_reader/scan_screen.dart';
import 'package:mi_thermo_reader/services/bluetooth_advertisement_parsers/thermometer_advertisement.dart';
import 'package:mi_thermo_reader/utils/known_device.dart';
import 'package:mi_thermo_reader/widgets/error_message.dart';
import 'package:mi_thermo_reader/widgets/known_device_tile.dart';
import 'package:mi_thermo_reader/widgets/popup_menu.dart';

class MiThermoReaderHomePage extends ConsumerStatefulWidget {
  const MiThermoReaderHomePage({super.key});

  @override
  ConsumerState<MiThermoReaderHomePage> createState() =>
      _MiThermoReaderHomePageState();
}

class _MiThermoReaderHomePageState
    extends ConsumerState<MiThermoReaderHomePage> {
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  final Map<String, ThermometerAdvertisement> _knownDeviceResults = {};
  bool _isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;
  late StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;

  @override
  void initState() {
    super.initState();
    _adapterStateStateSubscription = FlutterBluePlus.adapterState.listen((
      state,
    ) {
      if (mounted) {
        setState(() {
          _adapterState = state;
        });
      }
    });

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        final knownDevices = KnownDevice.getAll(ref);
        bool found = false;
        for (final result in results) {
          if (knownDevices.any(
            (d) => d.remoteId == result.device.remoteId.str,
          )) {
            try {
              final parsed = ThermometerAdvertisement.create(
                result.advertisementData,
              );
              // TODO(panmari): Handle this better with exception/null returns.
              if (parsed.temperature.isFinite && parsed.humidity.isFinite) {
                _knownDeviceResults[result.device.remoteId.str] = parsed;
                found = true;
              }
            } catch (e) {
              log('Failed to parse advertisement data: $e');
              continue;
            }
          }
        }
        if (found && mounted) {
          setState(() {});
        }
      },
      onError: (e, trace) {
        log('Subscription got an error: $e', stackTrace: trace);
      },
    );

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
      if (mounted) {
        setState(() {});
      }
    });
    onRefresh();
  }

  Future<void> onRefresh() async {
    FlutterBluePlus.stopScan();
    FlutterBluePlus.startScan(
      // withServices does not work on Android, the service is not advertised.
      // withServices: [BluetoothConstants.memoServiceGuid],
      // withServiceData works, but there's multiple formats for adve
