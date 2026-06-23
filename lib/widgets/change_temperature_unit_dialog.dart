import 'package:flutter/material.dart';
import 'package:open_settings_plus/open_settings_plus.dart';

class ChangeTemperatureUnitDialog extends StatelessWidget {
  final int androidSdk;

  const ChangeTemperatureUnitDialog({super.key, required this.androidSdk});

  @override
  Widget build(BuildContext context) {
    const firstAndroidVersionWithTemperatureUnitSetting = 14;
    if (Theme.of(context).platform == TargetPlatform.android &&
        androidSdk < firstAndroidVersionWithTemperatureUnitSetting) {
      return AlertDialog(
        title: const Text('更改温度单位'), // 汉化修改
        content: const Text(
          '目前仅支持在 Android 14 及以上版本的系统上更改温度单位。对此我们深表歉意。如需要，您可以提交功能请求。', // 汉化修改
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('好的'), // 汉化修改
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    }
    return AlertDialog(
      title: const Text('更改温度单位'), // 汉化修改
      content: const Text(
        '要更改温度单位，请在系统设置菜单中向下滚动至“区域偏好”（Regional Preferences），并在那里设置您需要的温度单位。', // 汉化修改
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('取消'), // 汉化修改
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('打开系统设置'), // 汉化修改
          onPressed: () {
            Navigator.of(context).pop();
            final _ = switch (OpenSettingsPlus.shared) {
              // Directly linking to https://developer.android.com/reference/android/provider/Settings#ACTION_REGIONAL_PREFERENCES_SETTINGS didn't work on my tester phone.
              OpenSettingsPlusAndroid settings => settings.locale(),
              OpenSettingsPlusIOS settings => settings.languageAndRegion(),
              _ => throw Exception('Platform not supported'),
            };
          },
        ),
      ],
    );
  }
}