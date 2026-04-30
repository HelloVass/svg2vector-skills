---
name: svg2vector
description: Convert SVG files to Android VectorDrawable XML using the svg2vector CLI. Auto-load when the user wants to convert SVG icons to Android, batch-process a folder of SVGs, integrate Figma exports into an Android project, or replace Android Studio's GUI-only Vector Asset Studio with an agent-callable workflow.
---

# svg2vector skill

When the user wants to turn SVG file(s) into Android `VectorDrawable` XML, use the
`svg2vector` CLI. It wraps Android Studio's official `Svg2Vector` algorithm
(`com.android.tools:sdk-common`) and produces output **byte-identical** to Vector
Asset Studio's GUI — but as a fast (~8ms cold start) headless CLI you can call
from a script or agent.

## Prerequisite check

Before the first invocation, run `command -v svg2vector`. If missing, ask the user
to confirm and run:

```
curl -fsSL https://raw.githubusercontent.com/HelloVass/svg2vector-skills/main/install.sh | sh
```

This installs `~/.local/bin/svg2vector` (auto-detects macOS arm64 / x86_64 / Linux
x86_64). User must have `~/.local/bin` in `PATH`.

## CLI surface

```
svg2vector convert <input.svg> [-o <output.xml>]
svg2vector batch <input-dir> <output-dir> [-r|--recursive]
```

`convert` writes one XML next to the input (or wherever `-o` points). `batch`
walks a directory; `-r` recurses subdirectories preserving structure.

## Exit code contract — this is the API

| Code | Meaning | What to do |
|---|---|---|
| `0` | clean success | surface `wrote ...` to user |
| `1` | fatal (cannot convert / I/O failure) | read stderr, surface error |
| `2` | success **with warnings** (XML still written, some SVG features dropped) | surface dropped features so user knows what's missing |
| `3` | bad CLI arguments | fix invocation, retry |

In `batch` mode, the process exits with the **worst** per-file code seen.

## Streams contract

- `stdout`: only success messages (`wrote ...`, batch summary)
- `stderr`: errors and "feature X is not supported" warnings

Capture them independently:

```
out=$(svg2vector convert input.svg -o output.xml 2>warnings.log); rc=$?
```

## Known input gotchas

- **Figma dev mode SVGs** (URLs like `localhost:3845/assets/<hash>.svg`) embed
  `var(--token, color)` CSS variables. Svg2Vector doesn't resolve them — output
  has unusable color attributes. Preprocess:
  `sed -E 's/var\(--[^,]+,\s*([^)]+)\)/\1/g' in.svg > clean.svg`. Or have the
  user export from Figma's **Export panel** (literal colors, no preprocessing).
- **`<text>` / `<filter>` / `<mask>` / `<pattern>` / `<image>` / external `<use>`
  / CSS `@import`** are silently dropped — exit code 2 with stderr warnings.
  For Figma drop-shadow filters specifically, the Android-side replacement is
  `android:elevation` on the View, not the drawable.
