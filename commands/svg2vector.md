---
allowed-tools: Bash(svg2vector:*), Bash(command:*), Bash(which:*), Bash(curl:*), Bash(chmod:*), Bash(mkdir:*), Bash(uname:*), Bash(sed:*), Bash(test:*), Bash(ls:*)
description: Convert SVG to Android VectorDrawable XML (single file or whole directory)
---

Convert SVG file(s) to Android VectorDrawable XML using the `svg2vector` CLI.
This is a drop-in replacement for Android Studio's GUI-only Vector Asset Studio,
designed for agent invocation: batch-aware, structured exit codes, ~8ms cold start,
output byte-identical to Android Studio's GUI.

## Step 1 — Ensure svg2vector is installed

Run `command -v svg2vector`. If not found, propose this install command and ask the
user to confirm:

```bash
curl -fsSL https://raw.githubusercontent.com/HelloVass/svg2vector-skills/main/install.sh | sh
```

The installer auto-detects platform (macOS arm64 / x86_64 / Linux x86_64), downloads
the ~24 MB native binary from GitHub Releases, and installs to `~/.local/bin/svg2vector`.
After install, ensure `~/.local/bin` is in PATH.

## Step 2 — Decide single-file or batch from the user's intent

| Intent | Command |
|---|---|
| One SVG file | `svg2vector convert <input.svg> [-o <output.xml>]` |
| Whole directory of SVGs | `svg2vector batch <input-dir> <output-dir> [-r/--recursive]` |

If the user mentions "all icons in folder X" / "everything under design/svgs" / etc.,
prefer `batch -r`. If they reference a single file path, use `convert`.

## Step 3 — Run the command and interpret the exit code

The exit code IS the API. Capture both streams independently:

```bash
out=$(svg2vector convert input.svg -o output.xml 2>warnings.log); rc=$?
```

Map exit codes:

- **0** — clean success. Surface `wrote <path>` to user.
- **1** — fatal: cannot convert / I/O failure. Read `stderr` and surface the error.
- **2** — success **with warnings**: some SVG features dropped (text / filter / mask
  etc. are unsupported by Svg2Vector). The XML is written and is still usable.
  Surface the dropped features explicitly so the user knows what's missing.
- **3** — bad CLI arguments. Fix the invocation and retry.

## Step 4 — Streams contract (don't cross them)

- `stdout` carries success messages only: `wrote /path/to/output.xml` or batch
  summary (`done: N ok, M warned, K failed`).
- `stderr` carries errors and unsupported-feature warnings.

When reporting back to the user, separate "what succeeded" from "what was dropped".

## Known caveat — Figma dev mode SVGs

Figma's **dev mode** (URLs like `localhost:3845/assets/<hash>.svg`) emits SVGs with
`var(--token, fallback)` for colors. Svg2Vector does not resolve these — they pass
through verbatim and produce VectorDrawable XML that crashes Android at runtime.

If you see `var(--` in an SVG, preprocess before conversion:

```bash
sed -E 's/var\(--[^,]+,\s*([^)]+)\)/\1/g' input.svg > /tmp/clean.svg
svg2vector convert /tmp/clean.svg -o output.xml
```

Long-term fix: have the user export from Figma's **Export panel** instead of dev
mode — those SVGs use literal hex colors and need no preprocessing.

## Known caveat — Filter / text / mask / pattern are silently dropped

Svg2Vector does not support `<text>`, `<filter>`, `<mask>`, `<pattern>`, `<image>`,
external `<use>`, or CSS `@import`. These trigger exit code 2. The XML output loses
those parts. Tell the user explicitly when they get dropped — for `<filter>` shadows
the right Android-side fix is `android:elevation` on the View, not the drawable.

## Reference: full CLI surface

```
svg2vector --help
svg2vector --version
svg2vector convert <input.svg> [-o <output.xml>]
svg2vector batch <input-dir> <output-dir> [-r|--recursive]
```
