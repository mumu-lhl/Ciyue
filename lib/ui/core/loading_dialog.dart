import "package:material_ui/material_ui.dart";

bool _loadingDialogVisible = false;

void showLoadingDialog(BuildContext context, {String? text}) {
  _loadingDialogVisible = true;
  final alert = AlertDialog(
    backgroundColor: Colors.transparent,
    content: _LoadingDialogContent(text: text),
  );

  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  ).whenComplete(() {
    _loadingDialogVisible = false;
  });
}

void closeLoadingDialog(BuildContext context) {
  if (!_loadingDialogVisible) {
    return;
  }

  _loadingDialogVisible = false;
  Navigator.of(context, rootNavigator: true).pop();
}

class _LoadingDialogContent extends StatefulWidget {
  final String? text;

  const _LoadingDialogContent({this.text});

  @override
  LoadingDialogContentState createState() => LoadingDialogContentState();
}

class LoadingDialogContentState extends State<_LoadingDialogContent> {
  static String? currentText;

  /// Set while the dialog's state is alive; null when it is not on screen.
  /// Callers update progress from loops that outlive the dialog, so this must
  /// be nullable: a `late` field threw LateInitializationError whenever the
  /// dialog had never been built (or was already gone).
  static void Function(String text)? updateText;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.all(Radius.circular(24.0)),
          ),
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
        if (currentText != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              currentText!,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();

    currentText = widget.text;
    updateText = (String text) {
      if (!mounted) return;
      setState(() {
        currentText = text;
      });
    };
  }

  @override
  void dispose() {
    // The dialog can be closed while a long import is still running; drop the
    // reference so later calls do not touch a disposed State.
    updateText = null;
    super.dispose();
  }
}
