import "package:ciyue/database/app.dart";
import "package:flutter/material.dart";

class TagsList extends StatefulWidget {
  final List<WordbookTag> tags;
  final List<int> tagsOfWord;
  final List<int> toAdd;
  final List<int> toDel;

  const TagsList(
      {super.key,
      required this.tags,
      required this.tagsOfWord,
      required this.toAdd,
      required this.toDel});

  @override
  State<StatefulWidget> createState() => _TagsListState();
}

class _TagsListState extends State<TagsList> {
  List<int>? oldTagsOfWord;

  @override
  Widget build(BuildContext context) {
    final checkboxListTile = <Widget>[];

    oldTagsOfWord ??= List<int>.from(widget.tagsOfWord);

    for (final tag in widget.tags) {
      checkboxListTile.add(CheckboxListTile(
        title: Text(tag.tag),
        value: widget.tagsOfWord.contains(tag.id),
        onChanged: (value) {
          setState(() {
            if (value == true) {
              if (!oldTagsOfWord!.contains(tag.id)) {
                widget.toAdd.add(tag.id);
              }

              widget.toDel.remove(tag.id);

              widget.tagsOfWord.add(tag.id);
            } else {
              if (oldTagsOfWord!.contains(tag.id)) {
                widget.toDel.add(tag.id);
              }

              widget.toAdd.remove(tag.id);

              widget.tagsOfWord.remove(tag.id);
            }
          });
        },
      ));
    }

    return Column(children: checkboxListTile);
  }
}
