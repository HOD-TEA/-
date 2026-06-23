import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mi_thermo_reader/services/bluetooth_commands.dart';
import 'package:mi_thermo_reader/services/bluetooth_constants.dart';
import 'package:mi_thermo_reader/services/command_processor.dart';
import 'package:mi_thermo_reader/services/config_command_processor.dart';
import 'package:mi_thermo_reader/services/memo_command_processor.dart';
import 'package:mi_thermo_reader/services/time_command_processor.dart';
import 'package:mi_thermo_reader/utils/sensor_entry.dart';

class BluetoothManager {
  final BluetoothDevice device;
  BluetoothCharacteristic? _characteristic;

  BluetoothManager({required this.device});

  // Two types of firmwares behave identically, but use different service and characteristic UUIDs.
  // https://github.com/pvvx/ATC_MiThermometer?tab=readme-ov-file#bluetooth-connection-mode
  // https://pvvx.github.io/THB2/web/GraphMemo.html
  // This method returns whatever is available in the given services list.
  BluetoothCharacteristic findCharacteristic(List<BluetoothService> services) {
    final compatibleServiceUuids = [
      BluetoothConstants.memoServiceGuid,
      BluetoothConstants.memoServiceTHB2Guid,
    ];
    final memoService = services.firstWhereOrNull(
      (service) =>
          service.isPrimary &&
          compatibleServiceUuids.contains(service.serviceUuid),
    );
    if (memoService == null) {
      throw Exception(
        '未能找到兼容的蓝牙服务。所需服务 UUID 之一：$compatibleServiceUuids', // 汉化修改
      );
    }
    final compatibleCharacteristicUuids = [
      BluetoothConstants.memoCharacteristicGuid,
      BluetoothConstants.memoCharacteristicTHB2Guid,
    ];
    final characteristic = memoService.characteristics.firstWhereOrNull(
      (c) => compatibleCharacteristicUuids.contains(c.characteristicUuid),
    );
    if (characteristic == null) {
      throw Exception(
        '未能找到兼容的数据特征通道。所需特征 UUID 之一：$compatibleCharacteristicUuids.', // 汉化修改
      );
    }
    return characteristic;
  }

  Future<void> init(Function(String) statusUpdate) async {
    if (_characteristic != null) {
      statusUpdate("蓝牙连接已完成初始化。"); // 汉化修改
      return;
    }
    await device.connect(license: License.free);
    statusUpdate("连接状态: 成功"); // 汉化修改

    final services = await device.discoverServices(
      subscribeToServicesChanged: false,
    );
    statusUpdate("发现蓝牙服务: 成功"); // 汉化修改

    _characteristic = findCharacteristic(services);
    statusUpdate('已找到温湿度数据特征通道。'); // 汉化修改

    await _characteristic!.setNotifyValue(true);
    statusUpdate('已开启数据通知订阅'); // 汉化修改
  }

  Future<T> _execute<T>(List<int> command, CommandProcessor processor) async {
    if (_characteristic == null) {
      throw "蓝牙未连接，数据特征通道缺失。"; // 汉化修改
    }
    final valueSubscription = _characteristic!.onValueReceived.listen(
      processor.onData,
      onError: processor.onError,
    );
    device.cancelWhenDisconnected(valueSubscription);

    await _characteristic!.write(command, withoutResponse: true);

    try {
      final result = await processor.waitForResults();
      return result;
    } finally {
      valueSubscription.cancel();
    }
  }

  Future getConfig() async {
    return _execute(
      BluetoothCommands.getConfigCommand(),
      ConfigCommandProcessor(),
    );
  }

  Future<List<SensorEntry>> getMemoryData(
    int numEntries,
    Function(String) statusUpdate,
  ) async {
    final processor = MemoCommandProcessor(statusUpdate: statusUpdate);
    statusUpdate('正在向设备请求 $numEntries 条历史温湿度记录...'); // 汉化修改
    return _execute(BluetoothCommands.getMemoCommand(numEntries), processor);
  }

  Future<Duration> getDeviceTimeAndDrift() async {
    final processor = TimeCommandProcessor();
    return _execute(BluetoothCommands.getDeviceTime(), processor);
  }

  // Because of time drifts on the device, calling this occasionally is necessary.
  Future<void> setDeviceTimeToNow() {
    if (_characteristic == null) {
      throw "蓝牙尚未初始化完成"; // 汉化修改
    }
    final now = DateTime.now();
    return _characteristic!.write(
      BluetoothCommands.setDeviceTime(now),
      withoutResponse: true,
    );
  }

  void dispose() {
    if (device.isConnected) {
      device.disconnect();
    }
  }
}
