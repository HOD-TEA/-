import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mi_thermo_reader/utils/sensor_entry.dart';
import 'package:mi_thermo_reader/widgets/about_dialog.dart';
import 'package:mi_thermo_reader/widgets/change_temperature_unit_dialog.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum Selection { about, rate, fixTime, export, deleteRange, changeTempUnit }

/// For retrieving PackageInfo async, the actual PopupMenu is wrapped
/// in this stateful widget.
class PopupMenu extends StatefulWidget {
  final Function? getAndFixTime;
  final Function? deleteSensorEntries;
  final List<SensorEntry>? sensorEntries;

  const PopupMenu({
    super.key,
    this.getAndFixTime,
    this.deleteSensorEntries,
    this.sensorEntries,
  });

  @override
  State<PopupMenu> createState() => _PopupMenuState();
}

class _PopupMenuState extends State<PopupMenu> {
  Future<PackageInfo>? _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  String _sensorEntriesToCsv(List<SensorEntry> entries) {
    final buffer = StringBuffer();
    buffer.writeln('timestamp,temperature,humidity,voltageBattery');
    for (final entry in entries) {
      buffer.writeln(
        '${entry.timestamp.toIso8601String()},${entry.temperature.toStringAsFixed(2)},${entry.humidity.toStringAsFixed(2)},${entry.voltageBattery}',
      );
    }
    return buffer.toString();
  }

  Future<void> _exportAndShare(BuildContext context) async {
    if (widget.sensorEntries == null) {
      return;
    }
    try {
      final csvData = _sensorEntriesToCsv(widget.sensorEntries!);
      final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final filename = 'mi_thermo_reader_export_$formattedDate.csv';
      final tempDir = await getTemporaryDirectory();
      final file = await File(
        '${tempDir.path}/$filename',
      ).writeAsBytes(utf8.encode(csvData));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          text: '从小米温湿度计读取器导出的传感器数据', // 汉化修改
        ),
      );
    } catch (e, s) {
      debugPrint('Error while exporting and sharing: $e');
      debugPrintStack(stackTrace: s);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出数据出错: $e'))); // 汉化修改
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _packageInfo,
      builder: (context, snapshot) {
        ret
