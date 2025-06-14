import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:url_launcher/url_launcher.dart";

class CiyueError extends StatelessWidget {
  final Object error;

  const CiyueError({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Error"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error.toString()),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                launchUrl(
                    Uri.parse("https://github.com/mumu-lhl/ciyue/issues"));
              },
              child: const Text("Report Issue"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: error.toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Error copied to clipboard")),
                );
              },
              child: const Text("Copy Error"),
            ),
          ],
        ),
      ),
    );
  }
}
