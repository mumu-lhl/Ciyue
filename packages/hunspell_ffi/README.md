# hunspell_ffi

Private Ciyue package for compiling Hunspell and exposing morphology operations
through `dart:ffi`.

The Hunspell source is kept as a pinned git submodule under
`third_party/hunspell`. Initialize it before building Ciyue:

```bash
git submodule update --init --recursive
```

The package currently exposes `stem` and `suggest`. The first Ciyue feature
uses `stem` for optional word-form lookup; the dictionary source is never used
as a standalone definition dictionary.
