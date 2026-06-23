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
          text: '从小米温湿度计读取器导出的传感器数据',
        ),
      );
    } catch (e, s) {
      debugPrint('Error while exporting and sharing: $e');
      debugPrintStack(stackTrace: s);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出数据出错: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _packageInfo,
      builder: (context, snapshot) {
        return PopupMenuButton<Selection>(
          onSelected: (Selection result) async {
            switch (result) {
              case Selection.about:
                showDialog(
                  context: context,
                  builder:
                      (context) => MiThermoReaderAboutDialog(
                        version: snapshot.data?.version ?? '未知版本',
                      ),
                );
                break;
              case Selection.rate:
                final InAppReview inAppReview = InAppReview.instance;
                if (await inAppReview.isAvailable()) {
                  inAppReview.requestReview();
                } else {
                  inAppReview.openStoreListing();
                }
                break;
              case Selection.fixTime:
                widget.getAndFixTime!();
                break;
              case Selection.export:
                _exportAndShare(context);
                break;
              case Selection.deleteRange:
                widget.deleteSensorEntries!();
                break;
              case Selection.changeTempUnit:
                int sdkInt = 0;
                if (!kIsWeb && Platform.isAndroid) {
                  final androidInfo = await DeviceInfoPlugin().androidInfo;
                  sdkInt = androidInfo.version.sdkInt;
                }
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder:
                        (context) =>
                            ChangeTemperatureUnitDialog(androidSdk: sdkInt),
                  );
                }
                break;
            }
          },
          itemBuilder: (BuildContext context) => _menuItemBuilder(context),
        );
      },
    );
  }

  List<PopupMenuEntry<Selection>> _menuItemBuilder(BuildContext context) {
    final hasSensorEntries =
        widget.sensorEntries != null && widget.sensorEntries!.isNotEmpty;
    return [
      if (widget.getAndFixTime != null)
        const PopupMenuItem<Selection>(
          value: Selection.fixTime,
          child: Text('校准时间'),
        ),
      if (hasSensorEntries)
        const PopupMenuItem<Selection>(
          value: Selection.export,
          child: Text('导出为 CSV'),
        ),
      if (hasSensorEntries)
        const PopupMenuItem<Selection>(
          value: Selection.deleteRange,
          child: Text('删除日期范围'),
        ),
      if (!kIsWeb)
        const PopupMenuItem<Selection>(
          value: Selection.changeTempUnit,
          child: Text('更改温度单位'),
        ),
      if (!kIsWeb)
        const PopupMenuItem<Selection>(
          value: Selection.rate,
          child: Text('评价此应用'),
        ),
      const PopupMenuItem<Selection>(
        value: Selection.about,
        child: Text('关于'),
      ),
    ];
  }
}