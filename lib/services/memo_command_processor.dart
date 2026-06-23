import 'dart:typed_data';

import 'package:mi_thermo_reader/services/bluetooth_constants.dart';
import 'package:mi_thermo_reader/services/command_processor.dart';
import 'package:mi_thermo_reader/utils/sensor_entry.dart';

class MemoCommandProcessor extends CommandProcessor<List<SensorEntry>> {
  final Function(String) statusUpdate;
  final _sensorEntries = <SensorEntry>[];

  MemoCommandProcessor({required this.statusUpdate})
    : super(timeout: const Duration(seconds: 60));

  @override
  void onData(List<int> values) {
    if (values.isEmpty) {
      return;
    }
    final data = ByteData.view(Uint8List.fromList(values).buffer);
    final blkid = data.getInt8(0);
    if (blkid != BluetoothConstants.commandMemoBlk) {
      statusUpdate("接收到意外 blkid ($blkid) 的数据: $values"); // 汉化修改
      return;
    }
    if (data.lengthInBytes >= 13) {
      // Got an entry from memory. Convert it to a SensorEntry.
      _sensorEntries.add(SensorEntry.parse(data));
      return;
    }
    if (data.lengthInBytes >= 3) {
      statusUpdate('数据读取完成。共获取到 ${_sensorEntries.length} 条记录'); // 汉化修改
      done.complete(_sensorEntries);
      return;
    }
    if (data.lengthInBytes == 2) {
      // TODO(panmari): This message seems pointless. Seems to be mostly 0 if received.
      final numSamples = data.getUint16(1, Endian.little);
      statusUpdate('设备内存中的记录总数: $numSamples'); // 汉化修改
      return;
    }
    statusUpdate("接收到异常大小的数据（字节数: ${data.lengthInBytes}）: $data"); // 汉化修改
  }
}
