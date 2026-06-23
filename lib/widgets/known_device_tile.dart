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
          title: Text('确认删除'), // 汉化修改
          content: Text('您确定要删除 "${_bestName()}" 吗？'), // 汉化修改
          actions: <Widget>[
            TextButton(
              child: Text('取消'), // 汉化修改
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              child: Text('删除'), // 汉化修改
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
            heigh
