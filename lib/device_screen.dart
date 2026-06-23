import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_thermo_reader/services/bluetooth_manager.dart';
import 'package:mi_thermo_reader/utils/known_device.dart';
import 'package:mi_thermo_reader/utils/sensor_history.dart';
import 'package:mi_thermo_reader/widgets/error_message.dart';
import 'package:mi_thermo_reader/widgets/popup_menu.dart';
import 'package:region_settings/region_settings.dart';
import 'utils/sensor_entry.dart';
import 'widgets/sensor_chart.dart';

class DeviceScreen extends ConsumerStatefulWidget {
  final KnownDevice device;

  static const routeName = '/DeviceScreen';

  const DeviceScreen({super.key, required this.device});

  @override
  ConsumerState<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends ConsumerState<DeviceScreen> {
  bool _isUpdatingData = false;
  final List<String> _statusUpdates = [];
  String? _error;
  int lastNdaysFilter = -1;
  late final BluetoothManager _bluetoothManager;
  TemperatureUnit _temperatureUnit = TemperatureUnit.celsius;

  List<SensorEntry> _createFakeSensorData(int nElements) {
    double lastTemp = 21.0;
    double lastHum = 51.0;
    return List.generate(nElements, (i) {
      lastTemp += math.Random().nextDouble() * 0.1 - 0.05;
      lastHum += math.Random().nextDouble() - 0.5;
      return SensorEntry(
        index: i,
        timestamp: DateTime.now().subtract(
          Duration(minutes: (nElements - i) * 10),
        ),
        temperature: lastTemp,
        humidity: lastHum,
        voltageBattery: 0,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _bluetoothManager = BluetoothManager(device: widget.device.bluetoothDevice);
    if (!kIsWeb) {
      // Package only supports non-web platforms.
      RegionSettings.getSettings().then((settings) {
        _temperatureUnit = settings.temperatureUnits;
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _bluetoothManager.dispose();
  }

  void onUpdateDataPressed() {
    _error = null;
    _isUpdatingData = true;
    if (mounted) {
      setState(() {});
    }
    updateData().then((e) {
      _isUpdatingData = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future initBluetooth() async {
    await _bluetoothManager.init((update) {
      _statusUpdates.add(update);
      if (mounted) {
        setState(() {});
      }
    });
  }

  void getAndFixTime() async {
    _error = null;
    try {
      await initBluetooth();
      final drift = await _bluetoothManager.getDeviceTimeAndDrift();
      _statusUpdates.add("设备时间偏差: $drift"); // 汉化修改

      await _bluetoothManager.setDeviceTimeToNow();
      _statusUpdates.add("成功校准设备时间。"); // 汉化修改
    } catch (e, trace) {
      _error = "获取设备时间失败: $e"; // 汉化修改
      log('获取设备时间失败: $e', stackTrace: trace);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future updateData() async {
    final cachedSensorHistory =
        widget.device.getCachedSensorHistory(ref) ??
        SensorHistory(sensorEntries: []);

    try {
      final int numEntries = cachedSensorHistory.missingEntriesSince(
        DateTime.now(),
      );
      if (numEntries == 0) {
        _statusUpdates.add('无需同步新记录。'); // 汉化修改
        if (mounted) {
          setState(() {});
        }
        return;
      }
      try {
        await initBluetooth();
      } catch (e, trace) {
        _error = "蓝牙连接初始化失败: $e"; // 汉化修改
        log('蓝牙连接初始化失败: $e', stackTrace: trace);
        return;
      }
      // Get config first to wake up device. If this is not done, getMemoryData
      // occasionally only returns partial data.
      try {
        await _bluetoothManager.getConfig();
      } on TimeoutException {
        _statusUpdates.add('获取配置超时，正在忽略...'); // 汉化修改
      }
      List<SensorEntry> newEntries = [];
      try {
        newEntries = await _bluetoothManager.getMemoryData(numEntries, (
          update,
        ) {
          _statusUpdates.add(update);
          if (mounted) {
            setState(() {});
          }
        });
      } on TimeoutException {
        _error = "数据同步超时。请尝试离温湿度计更近一些。"; // 汉化修改
        return;
      }
      final updatedSensorHistory = SensorHistory.createUpdated(
        cachedSensorHistory,
        newEntries,
      );
      _statusUpdates.add('已更新传感器历史数据: $updatedSensorHistory'); // 汉化修改
      widget.device.setCachedSensorHistory(ref, updatedSensorHistory);
    } catch (e, trace) {
      _error = "更新数据失败: $e"; // 汉化修改
      log('更新数据失败: $e', stackTrace: trace);
    }
  }

  List<SensorEntry> _filter(SensorHistory? history) {
    if (history == null) {
      return [];
    }
    if (lastNdaysFilter == -1) {
      return history.sensorEntries;
    }
    return history.lastEntriesFrom(Duration(days: lastNdaysFilter));
  }

  Widget _buildDayFilterBar() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: DayFilterOption.values.length,
        itemBuilder: (context, index) {
          final option = DayFilterOption.values[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(option.label),
              selected: lastNdaysFilter == option.numDays,
              onSelected: (bool selected) {
                if (selected) {
                  setState(() {
                    lastNdaysFilter = option.numDays;
                  });
                }
              },
            ),
          );
        },
        padding: EdgeInsets.all(5),
      ),
    );
  }

  Widget _buildTitle() {
    final res = StringBuffer();
    if (widget.device.platformName.isNotEmpty) {
      res.write(widget.device.platformName);
    } else {
      res.write("无设备名称"); // 汉化修改
    }
    res.write(', (${widget.device.remoteId})');
    return Text(res.toString());
  }

  Widget _buildErrorMessage() {
    if (_error == null) {
      return SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ErrorMessage(message: _error!),
    );
  }

  Widget _buildBatteryBar(SensorHistory? sensorHistory) {
    final lastEntry = sensorHistory?.sensorEntries.lastOrNull;
    if (lastEntry == null || lastEntry.voltageBattery <= 0) {
      return const SizedBox();
    }
    return Text("剩余电量: ${lastEntry.batteryPercentage.toStringAsFixed(0)}%"); // 汉化修改
  }

  Future<void> _deleteSensorEntries() async {
    final history = widget.device.getCachedSensorHistory(ref);
    if (history == null || history.sensorEntries.isEmpty) {
      return;
    }

    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: history.sensorEntries.first.timestamp,
      lastDate: history.sensorEntries.last.timestamp,
      helpText: '选择要删除的日期范围', // 汉化修改
      saveText: '删除', // 汉化修改
    );

    if (dateRange != null) {
      // The picker returns dates with time 00:00:00, this makes sure all entries on that day are deleted.
      final endOfRange = DateTime(
        dateRange.end.year,
        dateRange.end.month,
        dateRange.end.day,
        23,
        59,
        59,
      );

      final updatedHistory = history.copyWithEntriesFiltered(
        dateRange.start,
        endOfRange,
      );
      await widget.device.setCachedSensorHistory(ref, updatedHistory);
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    SensorHistory? cachedSensorHistory = widget.device.getCachedSensorHistory(
      ref,
    );
    if (cachedSensorHistory == null && kDebugMode) {
      cachedSensorHistory = SensorHistory(
        sensorEntries: _createFakeSensorData(2000),
      );
    }
    final filteredSensorEntries = _filter(cachedSensorHistory);
    return ScaffoldMessenger(
      child: Scaffold(
        appBar: AppBar(
          title: _buildTitle(),
          actions: [
            PopupMenu(
              getAndFixTime: getAndFixTime,
              deleteSensorEntries: _deleteSensorEntries,
              sensorEntries: filteredSensorEntries,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.zero,
            child: _isUpdatingData ? LinearProgressIndicator() : SizedBox(),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _isUpdatingData ? null : onUpdateDataPressed,
          tooltip: "连接设备同步最新温湿度数据。", // 汉化修改
          child: Icon(Icons.update),
        ),
        body: SingleChildScrollView(
          child: Column(
            children:
                <Widget>[
                  _buildErrorMessage(),
                  _buildDayFilterBar(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child:
                        filteredSensorEntries.isEmpty
                            ? Text(
                              "暂无温湿度记录，请点击右下角按钮进行同步。", // 汉化修改
                            )
                            : SensorChart(
                              sensorEntries: filteredSensorEntries,
                              temperatureUnit: _temperatureUnit,
                            ),
                  ),
                  _buildBatteryBar(cachedSensorHistory),
                ] +
                _statusUpdates.map((e) => Text(e)).toList(),
          ),
        ),
      ),
    );
  }
}

enum DayFilterOption {
  all(numDays: -1, label: '全部'), // 汉化修改
  lastDay(numDays: 1, label: '24小时'), // 汉化修改
  oneWeek(numDays: 7, label: '最近7天'), // 汉化修改
  oneMonth(numDays: 30, label: '最近30天'); // 汉化修改

  final int numDays;
  final String label;

  const DayFilterOption({required this.numDays, required this.label});
}
