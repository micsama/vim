# nvim

个人 Neovim 配置，面向 **Neovim 0.12 Nightly**，追求轻量、可读、易维护。核心功能栈用 `mini.nvim` 拼起来，插件管理用 Neovim 原生的 `vim.pack.add`，不引入 lazy.nvim / packer 之类的外部管理器。

最初的组织方式受 [theniceboy/nvim](https://github.com/theniceboy/nvim/tree/lua-migration) 启发。

## 设计原则

- **声明式插件列表**：所有插件在 `init.lua` 里用 `vim.pack.add()` 一次性列出，版本靠 `nvim-pack-lock.json` 锁定。
- **模块化**：每个文件只负责一件事，按「核心配置 / 插件配置 / 自定义组件 / 独立小工具 / 横向工具」分层存放。
- **启动性能优先**：LSP 和重插件放进 `config/deferred.lua`，在 `VimEnter` / `FileType` 时才加载。
- **自己动手**：statusline、tabline、浮动终端（floatty）都是自研的，不依赖 lualine / toggleterm 等成熟插件。

## 目录结构

```
init.lua                  # 入口：加载顺序 + vim.pack.add 插件清单
lua/
├── config/                # 核心配置（与「用什么插件」无关的部分）
│   ├── base.lua           #   vim.opt 选项、shell、环境变量
│   ├── keymaps.lua        #   全局键位、mapleader 定义
│   ├── autocmds.lua       #   原生 autocmd
│   ├── lsp.lua            #   诊断 UI + vim.lsp.enable() 服务列表
│   ├── deferred.lua       #   VimEnter/FileType 触发的延迟加载
│   └── neovide.lua        #   仅 Neovide 客户端生效的设置
├── plugins/               # 插件的具体配置（插件已注册后加载）
│   ├── mini.lua           #   mini.nvim 各模块：补全/文件树/git/图标/代码片段…
│   ├── ui.lua             #   notify、which-key、原生 UI2
│   ├── telescope.lua      #   搜索快捷键与最近仓库入口
│   ├── editor.lua         #   treesitter、匹配、缩进高亮
│   └── llm/               #   AI 工具：codecompanion（deepseek 适配器）
├── component/             # 自定义 UI 组件
│   ├── statusline.lua     #   状态栏
│   ├── tabline.lua        #   标签页栏
│   ├── theme.lua          #   配色方案
│   ├── stldata.lua        #   git/lsp/diagnostic → 状态栏用的纯数据
│   └── hl.lua             #   statusline/tabline 共用的高亮 & 文件图标辅助
├── apps/                  # 自成一体、自带 keymap 的独立功能
│   ├── floatty.lua        #   浮动终端/窗口管理器（终端/Lazygit/AI 聊天/Runner）
│   ├── proctop.lua        #   子进程 CPU/内存监视器 (<D-p> / :ProcTop)
│   ├── recent_repos.lua   #   最近 Git 仓库 frecency 排序 + Telescope picker
│   └── zoom.lua           #   窗口最大化/恢复
└── utils/                 # 被其他模块 require 的横向工具
    ├── map.lua            #   键位映射封装（macOS <D-key>、全角标点转换）
    ├── floatty_claude.lua #   floatty 的 Claude 会话元数据 watcher
    └── json_store.lua     #   小型 JSON 文件安全读写

lsp/          # 每个 LSP 一个文件，由 config/lsp.lua 统一 enable
ftplugin/     # 按文件类型加载的设置
snippets/     # mini.snippets 用的 JSON 代码片段
```

## 插件管理

在 `init.lua` 中用 `vim.pack.add()` 声明式列出：

```lua
vim.pack.add({
  { src = "https://github.com/...", tag = "v0.2.0" },  -- 锁定版本
  { src = "https://github.com/...", build = "make" },  -- 需要构建步骤
  "https://github.com/...",                            -- 无需构建，简单 URL
})
```

`nvim-pack-lock.json` 记录实际锁定的 commit，跨机器同步时以它为准；改动插件版本时记得同步更新。

### 当前启用的主要插件

| 分类 | 插件 |
|---|---|
| 基础库 | `mini.nvim`、plenary.nvim、sqlite.lua、nui.nvim |
| UI/外观 | catppuccin、which-key.nvim、nvim-notify |
| 搜索 | telescope.nvim + telescope-fzf-native.nvim |
| 语法 | nvim-treesitter、nvim-treesitter-context、nvim-ts-autotag |
| 编辑增强 | wildfire.nvim、hlchunk.nvim、undotree、nvim-neoclip.lua |
| AI | codecompanion.nvim |
| 语言工具安装 | mason.nvim |
| 性能 | faster.nvim（大文件优化） |

> DAP 遗留配置已移除；Mason 和 CodeCompanion 保留。

## mini.nvim 覆盖的功能

一个插件顶多个：`completion`（补全）、`pairs`/`surround`（括号/包裹）、`diff` + `git`（Git 集成）、`files`（文件树）、`icons`（图标）、`cursorword`（光标高亮同名词）、`hipatterns`（颜色高亮）、`snippets`（代码片段）。详细配置见 `lua/plugins/mini.lua`。

## LSP

`lua/config/lsp.lua` 统一配置诊断 UI 并 `vim.lsp.enable()` 以下服务，具体行为在 `lsp/<name>.lua` 中：

`lua_ls`、`stylua`、`ty`、`ruff`、`basedpyright`、`taplo`、`rust_analyzer`、`vtsls`、`biome`、`bashls`、`nushell`、`markdown_oxide`、`docker_language_server`

服务器本身通过 Mason 安装（`:MasonInstall`），配置未设置 `ensure_installed`，需要手动装一次。

## 常用键位

Leader 是 `<space>`（`vim.g.mapleader`），完整定义看 `lua/config/keymaps.lua`。macOS `<D-key>`（Command 键）由 `lua/utils/map.lua` 统一处理。

| 按键 | 功能 |
|---|---|
| `<D-g>` | Floatty：浮动终端 |
| `<D-i>` | Floatty：Lazygit |
| `<D-e>` | Floatty：AI 聊天 / Shell 菜单（Claude / Codex / Gemini） |
| `<D-r>` | Floatty：Runner，按文件类型自动执行（`RUNNERS` 表：python → `uv run`、rust → `cargo run`…） |
| `<D-b>` | 打开侧边文件树（mini.files） |
| `<D-o>` | CodeCompanion AI 聊天 |
| `<D-p>` | ProcTop 子进程监视器 |
| `<leader>h` / `<leader>rn` / `<leader>,` | LSP：悬浮提示 / 重命名 / 代码操作 |
| `<D-S-f>` | 格式化当前文件 |

## 依赖

- **Neovim 0.12 Nightly 及以上**（依赖原生 `vim.pack.add`）
- 主力在 macOS 上开发，默认 shell 为 nu (Nushell)
- 完整的外部命令行工具清单（按必需/推荐/可选分级，含跨平台迁移注意事项）见 **[DEPENDENCIES.md](./DEPENDENCIES.md)**

## 安装

```bash
# 1. 备份原有配置
mv ~/.config/nvim ~/.config/nvim.bak

# 2. 克隆本仓库
git clone <repo-url> ~/.config/nvim

# 3. 启动 Neovim，vim.pack.add 会自动拉取插件
nvim
```

首次启动后按 [DEPENDENCIES.md](./DEPENDENCIES.md) 补齐系统级工具，再用 `:MasonInstall` 装齐 LSP。

## 修改配置时去哪找

| 想改什么 | 去哪 |
|---|---|
| 键位 | `lua/config/keymaps.lua` |
| Vim 选项 / shell / 环境变量 | `lua/config/base.lua` |
| 新增插件 | `init.lua` 的 `vim.pack.add()` → 按需在 `lua/plugins/` 建配置文件 → `init.lua` 底部 `require()` |
| 新语言 LSP | 新建 `lsp/<name>.lua` → `config/lsp.lua` 里 `vim.lsp.enable()` 加进去 → 按需在 `ftplugin/` 补充 |
| 状态栏 / 标签栏 | `lua/component/statusline.lua` / `tabline.lua` |
| Floatty 应用 / 快捷键 / Runner / 窗口 / 动画 | `lua/config/floatty.lua` |
| Floatty 终端生命周期 | `lua/apps/floatty.lua` |
| Floatty 会话注册表和缓存 | `lua/apps/floatty_registry.lua` |

修改后 `:source $MYVIMRC` 或重启 Neovim 验证；插件相关改动建议完全重启。出问题看 `:messages` 或 `:checkhealth`。

## 参考

- [Neovim 官方文档](https://neovim.io/doc/)
- 更详细的架构说明见仓库内 [CLAUDE.md](./CLAUDE.md)

### 配置整理说明

- Floatty 的常改参数集中在 `lua/config/floatty.lua`，保持原有应用顺序与快捷键。`apps` 配置会复制后使用，运行状态不会写回配置表。
- 应用可设置 `key`、`pick_key`、`cmd`、`shell`、`w`、`h`、`idle_ttl_ms`；AI 菜单通过 `choices` 配置，Claude 配置目录使用 `claude.dir`。
- 全局窗口默认值在 `window`，呼吸边框在 `pulse`（`enabled`、`period_s`、`interval_ms`），成功退出关窗延迟为 `autoclose_ms`。
- 状态栏读取缓存；注册表在启动、会话操作、焦点恢复和目录变化时刷新。仍沿用共享 JSON 和最近会话恢复机制，多实例事务与精确会话恢复尚未改动。
- 修改配置后重启 Neovim，不再保存 `init.lua` / `base.lua` 时自动部分重载。临时 `⌘N` 状态栏调试键已移除；`:StlProf on`、`:StlProf`、`:StlProf off` 保留。
