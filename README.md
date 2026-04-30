# svg2vector-skills

> Claude Code plugin to convert SVG → Android VectorDrawable. Drop-in
> agent-callable replacement for Android Studio's GUI-only Vector Asset Studio.

| | Vector Asset Studio (AS GUI) | **svg2vector** |
|---|---|---|
| 调用方式 | 鼠标点击 | CLI / Claude / agent / CI |
| 批量 | ✗ 一个一个拖 | ✓ `batch -r` 一键整个目录 |
| 退出码 | ✗ | ✓ 0 / 1 / 2 / 3 结构化契约 |
| stdout/stderr 分流 | ✗ | ✓ stdout 只发成功，stderr 只发错误/警告 |
| 冷启动 | 启动 IDE 几秒 | **~8ms**（macOS arm64 native 二进制） |
| 输出 | Svg2Vector 算法 | **同一份算法**，byte-identical |

底层封装的是 Android 官方 `com.android.ide.common.vectordrawable.Svg2Vector`
（`com.android.tools:sdk-common`）—— Vector Asset Studio GUI 走的也是这个类。
任何 GUI 能转的 SVG，svg2vector 也能转，输出字节相同。

---

## 安装

### 方式 1（推荐）：Claude Code plugin

在 Claude Code 主界面：

```text
/plugin marketplace add HelloVass/svg2vector-skills
/plugin install svg2vector
```

装好之后：

- **主动调用**：`/svg2vector convert <input.svg>` 之类的 slash command
- **隐式触发**：直接对 Claude 说"把 ./design/svgs 下所有图标转成 vectordrawable
  放到 app/src/main/res/drawable/"——skill 会自动激活

第一次使用时，slash command 会引导 Claude 装 native binary（~24 MB）：

```bash
curl -fsSL https://raw.githubusercontent.com/HelloVass/svg2vector-skills/main/install.sh | sh
```

### 方式 2：纯 CLI（不走 Claude，脚本 / CI 直接用）

```bash
curl -fsSL https://raw.githubusercontent.com/HelloVass/svg2vector-skills/main/install.sh | sh
svg2vector --version
```

`install.sh` 自动检测 OS / arch（macOS arm64 / x86_64 / Linux x86_64），下载对应
binary 到 `~/.local/bin/svg2vector`。

---

## 使用

### 转换单个文件

```bash
svg2vector convert input.svg                  # 旁边生成同名 .xml
svg2vector convert input.svg -o out/icon.xml  # 指定输出
```

### 批量转换整个目录

```bash
svg2vector batch ./svgs ./drawable
svg2vector batch ./svgs ./drawable -r         # 递归子目录
```

### 帮助 / 版本

```bash
svg2vector --help
svg2vector --version
svg2vector convert --help
svg2vector batch --help
```

---

## 退出码（这是这个工具的 API）

| Code | 含义 |
|------|------|
| `0` | 成功，无警告 |
| `1` | 致命错误：完全无法转换、I/O 失败 |
| `2` | 转换成功，但部分 SVG 特性不被支持已被跳过 — XML **仍然写出** |
| `3` | 命令行参数错误 |

`batch` 模式退出码 = 所有文件中**最差**那个（`max`）。

`stdout` 仅承载成功消息（`wrote <path>` / 批量摘要 `done: N ok, M warned, K failed`）。
`stderr` 承载错误和不支持特性的警告。两者刻意分流。

### Agent 调用示例

```bash
out=$(svg2vector convert icon.svg -o icon.xml 2>err.log)
rc=$?
case $rc in
  0) echo "干净转换: $out" ;;
  2) echo "转出来了但有特性被跳过 (见 err.log)" ;;
  *) echo "失败 rc=$rc (见 err.log)" ;;
esac
```

---

## 支持的 SVG 特性

`Svg2Vector` 支持：`path` / `rect` / `circle` / `ellipse` / `line` / `polygon` /
`polyline` / `g`（transform 烘焙进 path） / 基础 `fill` / `stroke` / `opacity` /
`linearGradient` / `radialGradient` / `clipPath`。

**静默跳过（exit 2 + stderr 警告）**：`text` / `filter` / `mask` / `pattern` /
`image` / 外部资源的 `<use>` / CSS `@import` / 部分高级 gradient 特性。

### Figma 用户特别注意

- ✅ Figma **Export 面板** 导出的 SVG（用字面量颜色）：直接喂，没问题
- ⚠️ Figma **dev mode** (`localhost:3845/assets/...svg`) 的 SVG 含
  `var(--token, fallback)` CSS 变量，Svg2Vector 不解析，输出会含不可用的字符串。
  预处理：

  ```bash
  sed -E 's/var\(--[^,]+,\s*([^)]+)\)/\1/g' input.svg > clean.svg
  ```

---

## 致谢

- 转换算法来自 Android tooling 团队的
  [`Svg2Vector`](https://android.googlesource.com/platform/tools/base/+/refs/heads/mirror-goog-studio-main/sdk-common/src/main/java/com/android/ide/common/vectordrawable/Svg2Vector.java)
  （`com.android.tools:sdk-common`）。
- 测试 fixture 借用了 [Ashung/svg2vectordrawable](https://github.com/Ashung/svg2vectordrawable)
  issue tracker 里的 4 个真实失败 SVG 作为回归保护——感谢上游用户多年踩坑。

---

## License

MIT
