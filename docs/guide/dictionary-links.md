# Dictionary Links

Ciyue follows the link conventions that MDict and GoldenDict dictionaries
already use. This page lists the accepted shapes and the one escape Ciyue adds
on top of them.

## Entry links

| Link | Where it goes |
| --- | --- |
| `entry://word` | The entry `word` |
| `bword://word` | Same as `entry://word` (Babylon spelling) |
| `entry://word#anchor` | The entry `word`, scrolled to `anchor` |
| `entry://#anchor` | The entry already on screen, scrolled to `anchor` |
| `entry://word##anchor` | The entry literally named `word#anchor` |

`bword://` behaves exactly like `entry://`, so every form above has a `bword://`
twin.

## Headwords that contain `#`

A single `#` always separates the headword from an anchor. A headword that
itself contains `#` therefore has to escape it by doubling:

| Headword | Write |
| --- | --- |
| `tag#sumeru` | `entry://tag##sumeru` |

Escaping and separation combine, so `entry://tag##sumeru#x` opens the entry
`tag#sumeru` and scrolls to `x`, while `entry://tag###sumeru` opens the entry
`tag#` and scrolls to `sumeru`.

This escaping is specific to Ciyue. GoldenDict-ng splits at a `#` as well, but
offers no way to reach a headword that contains one.

## Notes

- Anchors scroll, they are not part of the browsing history: going back never
  re-triggers a scroll.
- A link with no headword scrolls the entry on screen and does not look
  anything up.
- The anchor target is matched against both `id` and `name` attributes, so
  anchors written for either style work.
- An anchor belongs to the entry of the dictionary that contains the link. A
  sibling dictionary in the same group that happens to have the same headword
  does not get scrolled instead.

## Audio and video

Audio references keep the MDict spelling `<a href="sound://file.mp3">…</a>` and
are played from the dictionary's `.mdd`, or from a StarDict `res/` resource.
