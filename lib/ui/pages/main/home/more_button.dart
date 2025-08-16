import "package:flutter/material.dart";

import "dialogs.dart";

class MoreButton extends StatelessWidget {
  const MoreButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () async {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return const MoreOptionsDialog();
            },
          );
        },
      ),
    );
  }
}
