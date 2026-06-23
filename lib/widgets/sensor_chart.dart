import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:mi_thermo_reader/utils/sensor_entry.dart';
import 'dart:math';
import 'package:region_settings/region_settings.dart';

class SensorChart extends StatelessWidget {
  final List<SensorEntry> sensorEntries;
  final TemperatureUnit temperatureUnit;

  final Color tempColor = Colors.orange;
  final Color humidityColor = Colors.blue;

  const SensorChart({
    super.key,
    required this.sensorEntries,
    required this.temperatureUnit,
  });

  // 格式化 X 轴上的日期。如果是较长的时间跨度，使用中文的 “M月d日” 格式。
  String _formatDate(Duration timeRange, double value) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (timeRange.inDays > 2) {
      return DateFormat('M月d日').format(dateTime); // 汉化修改：例如 "4月9日"
    }
    return DateFormat('HH:mm').format(dateTime); // 例如 "11:41"
  }

  // 计算垂直网格线（时间轴）的合理间隔
  Duration _calculateTimeGridIntervalDuration(Duration timeRange) {
    if (timeRange.inDays > 30) {
      return Duration(days: 7);
    }
    if (timeRange.inDays > 6) {
      return Duration(days: 2);
    }
    if (timeRange.inDays > 1) {
      return Duration(days: 1);
    }
    return Duration(hours: 5);
  }

  // 计算水平网格线（温度轴）的合理间隔
  double _calculateTempGridInterval(double tempRange) {
    if (tempRange <= 0) return 1;
    if (tempRange > 10) return 2;
    if (tempRange > 3) return 1;
    return 0.5;
  }

  @override
  Widget build(BuildContext context) {
    // 处理无数据情况
    if (sensorEntries.isEmpty) {
      return const AspectRatio(
        aspectRatio: 2,
        child: Center(child: Text('无可用传感器数据。')), // 汉化修改
      );
    }

    Size size = MediaQuery.of(context).size;
    if (size.width > size.height) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width,
          maxHeight: size.height * 0.6,
        ),
        child: _buildChart(context),
      );
    }
    return AspectRatio(
      aspectRatio: 2,
      child: _buildChart(context),
    );
  }

  Widget _buildChart(BuildContext context) {
    // --- 计算范围 ---
    final minTimestamp =
        sensorEntries.first.timestamp.millisecondsSinceEpoch.toDouble();
    final minX =
        sensorEntries.first.timestamp
            .copyWith(minute: 0, second: 0, millisecond: 0, microsecond: 0)
            .millisecondsSinceEpoch
            .toDouble();
    final maxTimestamp =
        sensorEntries.last.timestamp.millisecondsSinceEpoch.toDouble();
    final maxX =
        sensorEntries.last.timestamp
            .add(const Duration(minutes: 59, seconds: 59))
            .copyWith(minute: 0, second: 0, millisecond: 0, microsecond: 0)
            .millisecondsSinceEpoch
            .toDouble();
    final timeRange = Duration(
      milliseconds: (maxTimestamp - minTimestamp).toInt(),
    );

    // 温度范围 (Y 轴左侧 - 主轴)
    final minTemp = sensorEntries
        .map((e) => e.temperatureIn(temperatureUnit))
        .reduce(min);
    final maxTemp = sensorEntries
        .map((e) => e.temperatureIn(temperatureUnit))
        .reduce(max);
    final double tempPadding = (maxTemp - minTemp) * 0.15;
    final double finalMinY =
        (minTemp - tempPadding)
            .floorToDouble();
    final double finalMaxY = (maxTemp + tempPadding).ceilToDouble();
    final double primaryYRange = max(
      1,
      finalMaxY - finalMinY,
    );

    // 湿度范围 (Y 轴右侧 - 副轴)
    final minHumidity = sensorEntries.map((e) => e.humidity).reduce(min);
    final maxHumidity = sensorEntries.map((e) => e.humidity).reduce(max);
    final double humidityPadding = (maxHumidity - minHumidity) * 0.15;
    final double finalMinHumidity = max(
      0,
      minHumidity - humidityPadding,
    );
    final double finalMaxHumidity = min(
      100,
      maxHumidity + humidityPadding,
    );
    final double secondaryYRange = max(
      1,
      finalMaxHumidity - finalMinHumidity,
    );

    // --- 归一化湿度数据 ---
    final List<FlSpot> normalizedHumiditySpots =
        sensorEntries.map((s) {
          final double originalY = s.humidity;
          final double normalizedY =
              finalMinY +
              ((originalY - finalMinHumidity) / secondaryYRange) *
                  primaryYRange;
          return FlSpot(
            s.timestamp.millisecondsSinceEpoch.toDouble(),
            normalizedY,
          );
        }).toList();

    // --- 准备温度数据点 ---
    final List<FlSpot> temperatureSpots =
        sensorEntries
            .map(
              (s) => FlSpot(
                s.timestamp.millisecondsSinceEpoch.toDouble(),
                s.temperatureIn(temperatureUnit),
              ),
            )
            .toList();

    final int numHorizontalLabels = 5;
    final double bottomTitleInterval = (maxX - minX) / numHorizontalLabels;

    return LineChart(
      LineChartData(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1.5,
            ),
            left: BorderSide(color: Theme.of(context).dividerColor, width: 1.5),
            right: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1.5,
            ),
            top: BorderSide.none,
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          verticalInterval:
              _calculateTimeGridIntervalDuration(
                timeRange,
              ).inMilliseconds.toDouble(),
          drawHorizontalLine: true,
          horizontalInterval: _calculateTempGridInterval(
            maxTemp - minTemp,
          ),
          getDrawingHorizontalLine:
              (value) => FlLine(
                color: Theme.of(context).dividerColor.withAlpha(50),
                strokeWidth: 1,
              ),
          getDrawingVerticalLine:
              (value) => FlLine(
                color: Theme.of(context).dividerColor.withAlpha(50),
                strokeWidth: 1,
              ),
        ),

        minX: minX,
        maxX: maxX,
        minY: finalMinY,
        maxY: finalMaxY,
        lineBarsData: [
          // 温度折线 (左轴)
          LineChartBarData(
            spots: temperatureSpots,
            color: tempColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
          // 湿度折线 (右轴)
          LineChartBarData(
            spots: normalizedHumiditySpots,
            color: humidityColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
        ],

        titlesData: FlTitlesData(
          show: true,

          // X 轴时间
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              minIncluded: false,
              maxIncluded: false,
              showTitles: true,
              reservedSize: 35,
              interval: bottomTitleInterval,
              getTitlesWidget: (value, TitleMeta meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _formatDate(timeRange, value),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              },
            ),
          ),

          // Y 轴左侧：温度
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              '温度 (°${temperatureUnit.value})', // 汉化修改
              style: TextStyle(color: tempColor),
            ),
            axisNameSize: 24,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: max(1, (primaryYRange / 5).roundToDouble()),
              getTitlesWidget: (value, meta) {
                if (value < finalMinY || value > finalMaxY) {
                  return Container();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    meta.formattedValue,
                    style: TextStyle(color: tempColor),
                  ),
                );
              },
            ),
          ),

          // Y 轴右侧：湿度
          rightTitles: AxisTitles(
            axisNameWidget: Text(
              '湿度 (%)', // 汉化修改
              style: TextStyle(color: humidityColor),
            ),
            axisNameSize: 24,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: max(1, (primaryYRange / 5).roundToDouble()),
              getTitlesWidget: (value, meta) {
                if (value < finalMinY || value > finalMaxY) {
                  return Container();
                }

                final double originalHumidity =
                    finalMinHumidity +
                    ((value - finalMinY) / primaryYRange) * secondaryYRange;

                if (originalHumidity < finalMinHumidity ||
                    originalHumidity > finalMaxHumidity) {
                  if (originalHumidity < finalMinHumidity) {
                    return Container();
                  }
                  if (originalHumidity > finalMaxHumidity) {
                    return Container();
                  }
                }

                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    originalHumidity.toStringAsFixed(0),
                    style: TextStyle(color: humidityColor),
                  ),
                );
              },
            ),
          ),

          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),

        // --- 触摸提示框 ---
        lineTouchData: LineTouchData(
          enabled: true,
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: Theme.of(context).colorScheme.inverseSurface,
                  strokeWidth: 2,
                ),
                FlDotData(
                  getDotPainter:
                      (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 6,
                        color: barData.color ?? Colors.black,
                        strokeWidth: 2,
                        strokeColor: Theme.of(context).colorScheme.surface,
                      ),
                ),
              );
            }).toList();
          },
          touchTooltipData: LineTouchTooltipData(
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            tooltipBorder: BorderSide(color: Theme.of(context).dividerColor),
            getTooltipItems: (touchedSpots) {
              final textStyle = TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              );
              final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
                touchedSpots.first.x.toInt(),
              );
              final String formattedDate = DateFormat(
                'yyyy-MM-dd HH:mm:ss',
              ).format(dateTime);
              touchedSpots.sort((a, b) => a.barIndex.compareTo(b.barIndex));
              final items = touchedSpots.map((LineBarSpot touchedSpot) {
                if (touchedSpot.barIndex == 0) {
                  // 汉化修改，并修复了原作者在华氏度(°F)下依然显示 °C 的 Bug
                  return '温度: ${touchedSpot.y.toStringAsFixed(1)}°${temperatureUnit.value}\n';
                } else {
                  final double originalHumidity =
                      finalMinHumidity +
                      ((touchedSpot.y - finalMinY) / primaryYRange) *
                          secondaryYRange;
                  // 汉化修改
                  return '湿度: ${originalHumidity.toStringAsFixed(1)}%';
                }
              });
              return [
                LineTooltipItem(
                  '$formattedDate\n',
                  textStyle.copyWith(
                    fontWeight: FontWeight.normal,
                    fontSize: 10,
                  ),
                  children:
                      items
                          .map((t) => TextSpan(text: t, style: textStyle))
                          .toList(),
                  textAlign: TextAlign.left,
                ),
                null,
              ];
            },
          ),
        ),
      ),
    );
  }
}
