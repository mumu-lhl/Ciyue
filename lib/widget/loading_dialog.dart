import "package:flutter/material.dart";

void showLoadingDialog(BuildContext context, {String? text}) {
  final alert = AlertDialog(
      backgroundColor: Colors.transparent,
      content: _LoadingDialogContent(text: text));

  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}

class _LoadingDialogContent extends StatefulWidget {
  final String? text;

  const _LoadingDialogContent({this.text});

  @override
  LoadingDialogContentState createState() => LoadingDialogContentState();
}

class LoadingDialogContentState extends State<_LoadingDialogContent> {
  static String? currentText;
  static late Function updateText;

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
      setState(() {
        currentText = text;
      });
    };
  }
}
