# svg2vector

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Built on Svg2Vector](https://img.shields.io/badge/built%20on-Android%20Svg2Vector-3DDC84.svg)](https://android.googlesource.com/platform/tools/base/+/refs/heads/mirror-goog-studio-main/sdk-common/src/main/java/com/android/ide/common/vectordrawable/Svg2Vector.java)
[![Native binary](https://img.shields.io/badge/native%20binary-~24.6%20MB-blue.svg)](#install)
[![Cold start](https://img.shields.io/badge/cold%20start-~8ms-blue.svg)](#install)

> **English** | [中文](README_zh.md)

> ### The missing SVG → VectorDrawable CLI for Android.

Android Studio's **Vector Asset Studio** is GUI-only. Google's official
`android` CLI ships with `create`, `emulator`, `sdk`, `skills`... but
no SVG conversion. So in 2026 you still need to launch a 1 GB IDE and
click through dialogs just to turn an icon into a drawable.

**svg2vector** is the headless, agent-callable CLI that should have shipped:
same `Svg2Vector` algorithm Android Studio uses internally, packaged as a
~24 MB native binary with ~8 ms cold start. Wire it into Claude, agents,
scripts, or CI.

|                       | Vector Asset Studio (AS GUI) | **svg2vector**                            |
| --------------------- | ---------------------------- | ----------------------------------------- |
| Invocation            | Mouse clicks                 | CLI / Claude / agent / CI                 |
| Batch                 | ✗ one file at a time         | ✓ `batch -r` for an entire directory      |
| Exit codes            | ✗                            | ✓ structured `0` / `1` / `2` / `3`        |
| stdout / stderr split | ✗                            | ✓ stdout = success only, stderr = warnings|
| Cold start            | seconds (IDE startup)        | **~8 ms** (macOS arm64 native binary)     |
| Output                | Svg2Vector algorithm         | **same algorithm**, byte-identical        |

Under the hood it wraps Android's official `com.android.ide.common.vectordrawable.Svg2Vector`
(`com.android.tools:sdk-common`) — the exact class the Vector Asset Studio GUI runs.
Anything the GUI can convert, this CLI can convert, byte-for-byte the same.

---

## Install

### Option 1 — Claude Code plugin (recommended)

In Claude Code:

```
/plugin marketplace add HelloVass/svg2vector-skills
/plugin install svg2vector
```

Once installed:

- **Active**: `/svg2vector convert <input.svg>` slash command
- **Passive**: just say `convert all SVGs under ./design/svgs into vectordrawables
  and put them in app/src/main/res/drawable/` — the skill auto-activates.

On first use the slash command will offer to install the native binary (~24 MB):

```sh
curl -fsSL https://raw.githubusercontent.com/HelloVass/svg2vector-skills/main/install.sh | sh
```

### Option 2 — Plain CLI (no Claude required)

```sh
curl -fsSL https://raw.githubusercontent.com/HelloVass/svg2vector-skills/main/install.sh | sh
svg2vector --version
```

`install.sh` auto-detects OS and arch (`darwin-arm64` / `darwin-x86_64` /
`linux-x86_64`), pulls the matching native binary from GitHub Releases, and
drops it at `~/.local/bin/svg2vector`.

---

## Usage

### Convert a single file

```sh
svg2vector convert input.svg                  # writes input.xml beside it
svg2vector convert input.svg -o out/icon.xml  # explicit output path
```

### Convert a whole directory

```sh
svg2vector batch ./svgs ./drawable
svg2vector batch ./svgs ./drawable -r         # recurse into subdirectories
```

### Help / version

```sh
svg2vector --help
svg2vector --version
svg2vector convert --help
svg2vector batch --help
```

---

## Exit codes (this is the API)

| Code | Meaning                                                                   |
| ---- | ------------------------------------------------------------------------- |
| `0`  | Success, no warnings                                                      |
| `1`  | Fatal: cannot convert, or I/O error                                       |
| `2`  | Converted **with warnings** — XML still written, some SVG features dropped|
| `3`  | Bad CLI arguments                                                         |

In `batch` mode, the process exits with the **worst** per-file code (`max`).
A single warning anywhere in the batch surfaces as exit `2` overall.

`stdout` carries success messages only (`wrote ...`, batch summary like
`done: N ok, M warned, K failed`). `stderr` carries errors and "feature X is
not supported" warnings. The two streams are deliberately separated so
agents can capture them independently.

### Agent invocation pattern

```sh
out=$(svg2vector convert icon.svg -o icon.xml 2>err.log)
rc=$?
case $rc in
  0) echo "clean: $out" ;;
  2) echo "converted with dropped features (see err.log)" ;;
  *) echo "failed rc=$rc (see err.log)" ;;
esac
```

---

## Supported SVG features

Supported: `path` / `rect` / `circle` / `ellipse` / `line` / `polygon` /
`polyline` / `g` (transforms baked into paths) / basic `fill` / `stroke` /
`opacity` / `linearGradient` / `radialGradient` / `clipPath`.

Silently dropped (exit `2` + stderr warning): `text` / `filter` / `mask` /
`pattern` / `image` / external `<use>` / CSS `@import` / some advanced
gradient features.

### Figma users — read this

- ✅ SVGs from Figma's **Export panel** (literal hex colors): drop straight in.
- ⚠️ SVGs from Figma's **Dev Mode** (`localhost:3845/assets/...svg`) embed
  `var(--token, fallback)` CSS variables. Svg2Vector doesn't resolve those
  — output strokes / fills become unusable strings. Pre-process:

  ```sh
  sed -E 's/var\(--[^,]+,\s*([^)]+)\)/\1/g' input.svg > clean.svg
  ```

---

## Acknowledgements

- The conversion algorithm is Android tooling's
  [`Svg2Vector`](https://android.googlesource.com/platform/tools/base/+/refs/heads/mirror-goog-studio-main/sdk-common/src/main/java/com/android/ide/common/vectordrawable/Svg2Vector.java)
  (`com.android.tools:sdk-common`).
- Four of the regression test fixtures are taken from the
  [Ashung/svg2vectordrawable](https://github.com/Ashung/svg2vectordrawable) issue
  tracker — credit to the upstream community for reporting these bugs over the years.

---

## License

MIT
