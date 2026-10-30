# Pronunciation and pronunciation packs

Ciyue can read a word out in two ways: **pronunciation packs** (recordings stored in `.mdd` or `.zip` / `.zips` files) and **TTS** (the system speech synthesiser).

## Three modes

| Mode | Behaviour |
|---|---|
| Packs first, TTS as fallback | Play a recording if the packs have one, otherwise read the word aloud |
| Packs only | Play recordings only; stay silent when none matches |
| TTS only | Ignore the packs and always read the word aloud |

Packs are added in Settings → Audio → Pronunciation Packs. You can add several and drag them to change their priority.

## Pack formats

A pack can be an `.mdd` file or a plain zip — with the `.zip` or `.zips` extension (the latter is GoldenDict's extension for pronunciation archives; the file itself is a plain zip).

| Format | To change one file inside |
|---|---|
| `.mdd` | MDict's private format: unpack and repack with MdxBuilder or mdict-utils |
| `.zip` / `.zips` | Plain zip: replace files with whatever archiver you already have |

When you need to swap one recording, the zip form is far less work — extract, replace, re-zip, no dedicated tools. Both forms can be mixed, and drag-to-reorder priority treats them the same.

## Which formats play

What decides this is the **system decoder** (Android uses MediaPlayer), not Ciyue.

| Format | Status |
|---|---|
| MP3 | The safest choice |
| WAV (PCM) | Fine; ADPCM, μ-law and A-law depend on the device |
| AAC / M4A | Supported natively, both raw ADTS (`.aac`) and MP4 |
| OGG Vorbis | Supported |
| Ogg Speex (`.spx`) | **Not supported** — Android has no Speex decoder |
| Opus | Depends on the system version and container; Ogg Opus is unreliable on older releases |

`.spx` is the format most likely to trip you up.

WAV is the same story: the extension says nothing about what is inside. The
`fmt` field can be PCM, ADPCM, μ-law, or **MP3 data in a WAV wrapper**
(`fmt=0x55`). The last one plays fine on the device we tested — the system hands
it to the MP3 decoder — so a `.wav` suffix is not a reason to suspect the
format. Check the log for `Playing sound` first, as described in the next
section.

## When a tap produces no sound

Two cases:

**A snackbar says this device cannot play the dictionary's audio format.**
The resource was found and handed to the decoder, which cannot handle it. Convert it, as described below.

**Nothing happens at all, not even a message.**
The `sound://` link does not point at an existing resource — the name in the entry does not match anything in the `.mdd` (for a StarDict dictionary, in its `res/` folder or resource archive), or the dictionary ships no audio. Confirm whether the tap reached playback with `adb logcat | grep -E "Playing sound|Failed to play audio bytes"`.

## Converting audio the device cannot play

The key rule: **if you are not going to edit the `.mdx`, do not rename anything inside the `.mdd`** (for a StarDict dictionary, anything in `res/` or its resource archive). Entries reference the files as `sound://ID1234.spx`, so changing an extension breaks the link and turns "silent" into "nothing happens at all".

Ogg Speex and Ogg Vorbis share the same container, so the contents of a `.spx` file can be replaced with Vorbis while the file keeps its `.spx` name. Container, extension and the MIME type Ciyue passes (`audio/ogg`) all stay consistent, and Android decodes it normally.

### 1. Unpack

With a GUI, use MdxExport (Windows) and export the `.mdd` to a folder. From a shell, use `mdict-utils`:

```bash
pip install mdict-utils
mdict-utils mddunpack dictionary.mdd    # split archives: dictionary.1.mdd, dictionary.2.mdd, …
```

> Some dictionaries keep images and audio in the same `.mdd`. Keep every file after unpacking; convert only the audio.

### 2. Convert in place, keeping file names

```bash
# Replace Ogg Speex with Ogg Vorbis, writing back to the same .spx name.
find . -type f -iname '*.spx' -print0 | while IFS= read -r -d '' f; do
  ffmpeg -nostdin -loglevel error -y -i "$f" \
    -c:a libvorbis -q:a 3 -ac 1 -ar 22050 \
    -f ogg "${f%.spx}.tmp" && mv "${f%.spx}.tmp" "$f"
done
```

Notes on the flags:

- `-f ogg` is required; without it ffmpeg refuses to pick a container for a `.spx` output name
- `-ac 1 -ar 22050` is plenty for a single word, and keeps the size roughly within twice the original
- `-q:a 3` is a comfortable Vorbis quality for speech

Spot-check one file afterwards:

```bash
file some-file.spx     # should report "Ogg data, Vorbis audio"
```

### 3. Repack

With a GUI, use MdxBuilder with type **MDD**, point the source at the unpacked folder and write the same `.mdd` name. From a shell:

```bash
mdict-utils mddpack ./unpacked dictionary.mdd
```

Repack split volumes separately (`.1.mdd`, `.2.mdd`, …). The number of volumes does not have to match the original, but keep the files of a volume together.

### 4. Put it back and re-add the pack

Replace the original `.mdd` (or place it anywhere), then remove the old pack in Settings → Audio → Pronunciation Packs, add the new one, and try a word.

## Common traps

- **Renamed extensions, untouched `.mdx`**: the `sound://…spx` links inside the `.mdx` do not follow. Keep the extension (the Vorbis trick above) or rebuild the `.mdx` too.
- **Converting only some files**: a dictionary may mix `.spx` and `.mp3`. Check first with `find . -type f | sed 's/.*\.//' | sort | uniq -c`.
- **Path separators**: resource paths inside an MDD can be `\img\a.spx` or `/img/a.spx`. Keep them exactly as they were when repacking.
- **Packs are not the same as entry audio**: recordings that ship inside a dictionary play through its `sound://` links with no setup — from the `.mdd` for an MDX dictionary, from `res/` or the resource archives (`res.zip`, `<name>.res.zip`, `res/res.zip`) for a StarDict one. Adding a pack is for the separate "read any looked-up word aloud" feature.
