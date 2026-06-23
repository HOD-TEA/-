import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MiThermoReaderAboutDialog extends StatelessWidget {
  const MiThermoReaderAboutDialog({super.key, required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return AboutDialog(
      applicationIcon: Image.asset('assets/icon/icon.png', height: 50),
      applicationName: "小米温湿度计读取器",
      applicationLegalese: '© 2025 panmari',
      applicationVersion: version,
      children: [
        Container(padding: const EdgeInsets.fromLTRB(0, 10, 0, 10)),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              const TextSpan(
                text: '在使用来自 ',
              ),
              TextSpan(
                text: 'https://github.com/pvvx/ATC_MiThermometer',
                style: const TextStyle(color: Colors.lightBlue),
                recognizer:
                    TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(
                          Uri.parse(
                            'https://github.com/pvvx/ATC_MiThermometer',
                          ),
                        );
                      },
              ),
              const TextSpan(text: ' 或 '),
              TextSpan(
                text: 'https://github.com/pvvx/THB2',
                style: const TextStyle(color: Colors.lightBlue),
                recognizer:
                    TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(Uri.parse('https://github.com/pvvx/THB2'));
                      },
              ),
              const TextSpan(
                text: ' 的第三方固件后，设备通常将历史记录以本地时间数值直接保存在其内部。本软件旨在方便快速读取并可视化这些历史记录。\n',
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed:
              () => launchUrl(
                Uri.parse('https://github.com/panmari/mi_thermo_reader'),
              ),
          child: const Text('GitHub 源码'),
        ),
      ],
    );
  }
}