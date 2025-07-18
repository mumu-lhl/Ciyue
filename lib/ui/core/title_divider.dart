import "package:flutter/material.dart";

class TitleDivider extends StatelessWidget {
  final String title;

  const TitleDivider({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(child: Divider(endIndent: 16)),
      ],
    );
  }
}
