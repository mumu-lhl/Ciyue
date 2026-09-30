import "dart:convert";

import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:material_ui/material_ui.dart";

class GoogleDriveFolderSelection {
  final String id;
  final String name;

  const GoogleDriveFolderSelection({required this.id, required this.name});
}

Future<GoogleDriveFolderSelection?> showGoogleDriveFolderPicker(
  BuildContext context, {
  required String accessToken,
  required String apiKey,
  required String projectNumber,
}) => showDialog<GoogleDriveFolderSelection>(
  context: context,
  builder: (context) => _GoogleDriveFolderPickerDialog(
    accessToken: accessToken,
    apiKey: apiKey,
    projectNumber: projectNumber,
  ),
);

class _GoogleDriveFolderPickerDialog extends StatefulWidget {
  final String accessToken;
  final String apiKey;
  final String projectNumber;

  const _GoogleDriveFolderPickerDialog({
    required this.accessToken,
    required this.apiKey,
    required this.projectNumber,
  });

  @override
  State<_GoogleDriveFolderPickerDialog> createState() =>
      _GoogleDriveFolderPickerDialogState();
}

class _GoogleDriveFolderPickerDialogState
    extends State<_GoogleDriveFolderPickerDialog> {
  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 760,
      height: 620,
      child: InAppWebView(
        initialData: InAppWebViewInitialData(
          data: _pickerHtml(
            accessToken: widget.accessToken,
            apiKey: widget.apiKey,
            projectNumber: widget.projectNumber,
          ),
          baseUrl: WebUri("http://localhost/"),
        ),
        initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
        onWebViewCreated: (controller) {
          controller.addJavaScriptHandler(
            handlerName: "googleDrivePickerResult",
            callback: (arguments) {
              if (arguments.isEmpty || arguments.single is! Map) return null;
              final result = Map<String, dynamic>.from(arguments.single as Map);
              if (result["action"] == "picked") {
                final id = result["id"];
                final name = result["name"];
                if (id is String && id.isNotEmpty && name is String) {
                  Navigator.of(context)
                      .pop(GoogleDriveFolderSelection(id: id, name: name));
                }
              } else if (result["action"] == "cancel") {
                Navigator.of(context).pop();
              } else if (result["action"] == "error") {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)!.cloudSyncDrivePickerFailed,
                    ),
                  ),
                );
              }
              return null;
            },
          );
        },
      ),
    ),
  );
}

String _pickerHtml({
  required String accessToken,
  required String apiKey,
  required String projectNumber,
}) =>
    '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>html,body{margin:0;width:100%;height:100%;overflow:hidden}</style>
  <script src="https://apis.google.com/js/api.js"></script>
</head>
<body>
<script>
const accessToken = ${jsonEncode(accessToken)};
const developerKey = ${jsonEncode(apiKey)};
const appId = ${jsonEncode(projectNumber)};
const sendResult = value => window.flutter_inappwebview.callHandler('googleDrivePickerResult', value);
function openPicker() {
  const folders = new google.picker.DocsView(google.picker.ViewId.FOLDERS)
    .setIncludeFolders(true)
    .setSelectFolderEnabled(true)
    .setMimeTypes('application/vnd.google-apps.folder');
  const picker = new google.picker.PickerBuilder()
    .addView(folders)
    .setOAuthToken(accessToken)
    .setDeveloperKey(developerKey)
    .setAppId(appId)
    .setOrigin(window.location.protocol + '//' + window.location.host)
    .setCallback(data => {
      if (data.action === google.picker.Action.PICKED && data.docs && data.docs.length) {
        sendResult({action:'picked', id:data.docs[0].id, name:data.docs[0].name});
      } else if (data.action === google.picker.Action.CANCEL) {
        sendResult({action:'cancel'});
      }
    })
    .build();
  picker.setVisible(true);
}
window.onerror = () => { sendResult({action:'error'}); };
gapi.load('picker', {callback: openPicker});
</script>
</body>
</html>
''';
