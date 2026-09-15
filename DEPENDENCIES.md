# 外部依赖清单

本文件梳理该 Neovim 配置依赖的**系统级外部命令行工具**（不含 Neovim 插件本身，插件由 `init.lua` 的 `vim.pack.add` 管理）。按「基础必需 → 推荐 → 可选」的优先级排列，方便换机器/换平台时对照安装。

> 本配置主力在 macOS 上开发，部分设置（如 shell 路径、`ps` 参数）写死为 macOS 行为，迁移到 Linux/WSL 时需要留意，见文末「跨平台注意事项」。

## 🔴 第一档：核心必需

缺了会直接报错，或日常最基础的功能（搜索/文件浏览/git）不可用。

| 工具 | 用途 |
|---|---|
| **git** | mini.git / mini.diff、`autocmds.lua` 里项目根目录自动切换 |
| **nu (nushell)** | 默认 shell，`lua/config/base.lua` 写死绝对路径 `/opt/homebrew/bin/nu` |
| **make** + **cc/clang/gcc** | 安装期编译 `telescope-fzf-native.nvim`、Treesitter parser |
| **rg (ripgrep)** | Telescope 全局搜索的核心引擎 |
| **fd** | Telescope find_files 的推荐后端，缺失会退化为 vim 自带的慢查找 |

## 🟡 第二档：LSP / 开发环境相关

### Mason 可自动装（需手动 `:MasonInstall`，`lsp.lua` 未配置 `ensure_installed`）

lua-language-server、stylua、ty、ruff、basedpyright、taplo、vtsls、biome、bash-language-server、markdown-oxide、docker-language-server

### Mason 管不了，需系统预装

| 工具 | 用途 |
|---|---|
| **node** | vtsls / biome / bash-language-server 等 JS 生态 LSP 的运行时 |
| **python3 / uv** | Python 开发环境、Runner 模式（`<D-r>`）运行 `.py` |
| **cargo**（rustup） | `rust_analyzer.lua` 里的 `cargo metadata`/`cargo run`、Rust Runner |
| **nu** | `nu --lsp` 是 nushell 自带子命令，Mason 装不了 |

## 🟢 第三档：Floatty / AI 相关

只有用到对应功能时才需要。

| 工具 | 用途 |
|---|---|
| **claude**（Claude Code CLI） | `<D-e>` AI 菜单主力，`lua/apps/floatty.lua` / `lua/utils/floatty_claude.lua` |
| **uuidgen** | claude 会话 session-id 生成；缺失会 fail-fast 直接报错，务必安装 |
| **lazygit** | `<D-i>` 浮窗 |
| **codex** | AI 菜单里的 Codex 选项 |
| **zsh** | AI 菜单唤起 shell 用 |

## ⚪ 第四档：锦上添花（有优雅降级）

| 工具 | 用途 | 降级行为 |
|---|---|---|
| **eza** | `recent_repos.lua` 目录预览（长格式/图标/git 状态） | 检测不到自动退回 `ls` |

## ⚫ 无需关心

- **DAP 全家桶**（nvim-dap / dap-ui / dap-virtual-text / mason-nvim-dap / dap-python / telescope-dap）及 **debugpy**：相关插件声明和旧配置文件已移除，不属于当前配置依赖。

---

## 跨平台注意事项（macOS → WSL/Linux）

- **Shell 路径写死**：`lua/config/base.lua` 里 `vim.opt.shell` 硬编码为 macOS 的 nu 路径，迁移到 Linux 需要按实际安装路径调整（或做平台判断）。
- **`ps` 命令格式**：`lua/apps/proctop.lua` 按 macOS BSD `ps -o pid=,ppid=,rss=,time=,comm=` 格式解析，Linux 的 `ps` 是 GNU 实现，字段/格式不同，可能解析异常或显示错误数据。
- **文件名大小写**：macOS 文件系统默认大小写不敏感，Linux 大小写敏感 —— 新增文件时注意与 `require(...)` 里的路径大小写完全一致（此前 `plugins/Ui.lua` 与 `require("plugins.ui")` 大小写不一致就在 WSL 下导致启动报错）。

## 快速安装参考（Debian/Ubuntu，如 WSL）

```bash
sudo apt install ripgrep fd-find make gcc git nodejs npm zsh uuid-runtime
# fd-find 装出来的命令叫 fdfind，需要建软链或在配置里改成 fdfind
curl -LsSf https://astral.sh/uv/install.sh | sh   # uv
# cargo 通过 rustup 安装：https://rustup.rs
```

`claude`、`lazygit`、`codex`、`eza`、`nu` 按需单独安装（各自有独立的官方安装方式，此处不展开）。
