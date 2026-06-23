import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_thermo_reader/device_screen.dart';
import 'package:mi_thermo_reader/services/bluetooth_advertisement_parsers/thermometer_advertisement.dart';
import 'package:mi_thermo_reader/utils/known_device.dart';

class KnownDeviceTile extends ConsumerWidget {
  final KnownDevice device;
  final bool isScanning;
  final ThermometerAdvertisement? advertisement;

  const KnownDeviceTile({
    required this.device,
    required this.isScanning,
    this.advertisement,
    super.key,
  });

  String _bestName() {
    if (device.advName.isNotEmpty) {
      return device.advName;
    }
    if (device.platformName.isNotEmpty) {
      return device.platformName;
    }
    return device.remoteId;
  }

  Future<bool?> showDeleteConfirmationDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('您确定要删除 "${_bestName()}" 吗？'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              child: const Text('删除'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  Future _maybeRemoveKnownDevice(BuildContext context, WidgetRef ref) async {
    final shouldDelete = await showDeleteConfirmationDialog(context);
    if (shouldDelete == null || !shouldDelete) {
      return;
    }

    return KnownDevice.remove(ref, device);
  }

  Widget _advertisementDataRow() {
    final ad = advertisement;
    if (ad == null) {
      return isScanning
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(),
            )
          : const Text('暂无温湿度数据');
    }
    return Text('温度: ${ad.temperature}°C, 湿度: ${ad.humidity}%');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.device_thermostat, size: 50.0),
                  const SizedBox(height: 8.0),
                  Text(_bestName()),
                  const SizedBox(height: 8.0),
                  _advertisementDataRow(),
                  const SizedBox(height: 8.0),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pushNamed(
                      DeviceScreen.routeName,
                      arguments: device,
                    ),
                    child: const Text('打开'),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0.0,
            right: 0.0,
            child: IconButton(
              onPressed: () async {
                await _maybeRemoveKnownDevice(context, ref);
              },
              icon: const Icon(Icons.close, size: 20.0),
            ),
          ),
        ],
      ),
    );
  }
}