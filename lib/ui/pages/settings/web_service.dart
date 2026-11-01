import "dart:io";

import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/services/web_server_service.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/badges.dart";
import "package:ciyue/ui/core/settings_group.dart";
import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";
import "package:path/path.dart" as p;
import "package:url_launcher/url_launcher.dart";

class WebServiceSettingsPage extends StatefulWidget {
  const WebServiceSettingsPage({super.key});

  @override
  State<WebServiceSettingsPage> createState() => _WebServiceSettingsPageState();
}

class _WebServiceSettingsPageState extends State<WebServiceSettingsPage> {
  final TextEditingController _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _portController.text = settings.webServerPort.toString();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Future<void> _toggleService(bool value) async {
    await settings.setEnableWebServer(value);
    if (value) {
      await webServerService.start();
    } else {
      await webServerService.stop();
    }
    setState(() {});
  }

  Future<void> _toggleAllowLan(bool value) async {
    await settings.setWebServerAllowLan(value);
    if (webServerService.isRunning) {
      await webServerService.restart();
    }
    setState(() {});
  }

  Future<void> _savePort(String value) async {
    final port = int.tryParse(value.trim());
    if (port != null && port > 1024 && port < 65535) {
      await settings.setWebServerPort(port);
      if (webServerService.isRunning) {
        await webServerService.restart();
      }
      setState(() {});
    }
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(webServerService.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: webServerService.url));
    if (context.mounted) {
      await ToastService.show(AppLocalizations.of(context)!.urlCopied, context);
    }
  }

  void _openExtensionFolder() {
    final extensionDir = p.join(Directory.current.path, "browser_extension");
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.browserExtension),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.browserExtensionDescription),
              const SizedBox(height: 16),
              const Text(
                "Chrome / Edge / Brave 安装步骤：\n"
                "1. 在浏览器打开 chrome://extensions/\n"
                "2. 开启右上角「开发者模式」\n"
                "3. 点击「加载已解压的扩展程序」\n"
                "4. 选择词悦目录下的 browser_extension 文件夹即可！",
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 12),
              SelectableText(
                "扩展目录路径：$extensionDir",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRunning = webServerService.isRunning;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.webService)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              SettingsGroupCard(
                children: [
                  SwitchListTile(
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.enableWebService),
                        const SizedBox(width: 8),
                        BaseBadge(
                          text: isRunning
                              ? l10n.webServiceRunning
                              : l10n.webServiceStopped,
                        ),
                      ],
                    ),
                    subtitle: isRunning
                        ? Text(
                            webServerService.url,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          )
                        : null,
                    secondary: const Icon(Icons.public),
                    value: settings.enableWebServer,
                    onChanged: _toggleService,
                  ),
                  if (isRunning) ...[
                    ListTile(
                      leading: const Icon(Icons.open_in_browser),
                      title: Text(l10n.webServiceOpenInBrowser),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _openInBrowser,
                    ),
                    ListTile(
                      leading: const Icon(Icons.copy),
                      title: Text(l10n.copyServerUrl),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _copyUrl(context),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              SettingsGroupCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.numbers),
                    title: Text(l10n.webServicePort),
                    trailing: SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.end,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: _savePort,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.lan),
                    title: Text(l10n.webServiceAllowLan),
                    subtitle: Text(l10n.webServiceAllowLanDescription),
                    value: settings.webServerAllowLan,
                    onChanged: _toggleAllowLan,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SettingsGroupCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.extension),
                    title: Text(l10n.browserExtension),
                    subtitle: Text(l10n.browserExtensionDescription),
                    trailing: const Icon(Icons.help_outline),
                    onTap: _openExtensionFolder,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
