import "package:flutter/material.dart";

void showLoadingDialog(BuildContext context) {
  final alert = AlertDialog(
    backgroundColor: Colors.transparent,
    content: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.all(Radius.circular(24.0))),
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator())
      ],
    ),
  );
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}
