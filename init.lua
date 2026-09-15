-- ===========================================================================
-- Neovim 主配置文件 (init.lua)
-- 负责加载 LuaJIT 模块、基础配置、快捷键以及所有插件
-- ===========================================================================
vim.loader.enable() -- 启用 LuaJIT 加载器，优化启动速度

-- 1. 加载核心配置
require("config.base") -- 加载基础 Vim/Neovim 选项配置
require("config.keymaps") -- 加载全局键盘快捷键映射
require("config.autocmds") -- 纯内置自动命令
require("apps.floatty") -- 浮窗控制
require("apps.proctop").setup() -- 进程监控 (<D-p> / :ProcTop)

-- 2. GUI 客户端特定配置
if vim.g.neovide then
	require("config.neovide") -- 仅在 Neovide 环境下加载 GUI 特有配置
end


-- stylua: ignore start

-- 3. 插件管理：使用 vim.pack.add 定义所有插件列表，方便统一管理，都放一起。
vim.g.pack_ft_markdown = {
	"https://github.com/kaymmm/bullets.nvim",                          -- Markdown 列表增强
	"https://github.com/MeanderingProgrammer/render-markdown.nvim",    -- Markdown 实时渲染/预览
}
vim.pack.add({

    -- Telescope FZF 性能优化(需要在安装的目录下手动运行 make)
    { src = "https://github.com/nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    { src = "https://github.com/nvim-telescope/telescope.nvim"},
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
    "https://github.com/nvim-mini/mini.nvim",                        -- mini.nvim(具体配置见mini.lua)

    -- A. 核心依赖 & 基础工具 (Core Dependencies & Utilities)
    "https://github.com/nvim-lua/plenary.nvim",                      -- Lua 基础工具库，许多插件依赖(6个月没更新)
    "https://github.com/kkharji/sqlite.lua",                         -- SQLite 数据库支持 (如 Neoclip 依赖)
    "https://github.com/MunifTanjim/nui.nvim",                       -- 强大的 Neovim UI 组件库

    -- B. UI / 外观 / 状态栏 (UI / Appearance / Statusline)
    "https://github.com/catppuccin/nvim",                            -- 主题色
    "https://github.com/folke/which-key.nvim",                       -- 快捷键提示系统

    "https://github.com/rcarriga/nvim-notify",                       -- 通知系统

    -- D. 编辑器增强与生产力 (Editing Enhancements & Productivity)
    "https://github.com/SUSTech-data/wildfire.nvim",                 -- 支持按回车键范围选择
    "https://github.com/nvim-treesitter/nvim-treesitter-context",    -- Treesitter 上下文显示
    "https://github.com/shellRaining/hlchunk.nvim",                  -- 高亮当前代码块/缩进块
    "https://github.com/mbbill/undotree",                            -- 可视化撤销树
    "https://github.com/AckslD/nvim-neoclip.lua",                    -- 剪贴板历史管理器
		"https://github.com/windwp/nvim-ts-autotag",

    -- E. 文件管理与工作区 (File Management & Workspaces)
    "https://github.com/pteroctopus/faster.nvim",                    -- 大型文件优化处理

    -- F. Git / 终端 / LLM 工具 (Git / Terminal / LLM Tools)
    "https://github.com/olimorris/codecompanion.nvim",               -- LLM/AI 代码伴侣工具

    -- 语言工具安装器
    "https://github.com/williamboman/mason.nvim",

})
-- stylua: ignore end
require("component.theme") -- 主题（须在 plugins.ui 之前加载，notify 等插件的高亮依赖当前 colorscheme）
require("plugins.editor") -- 编辑器增强功能
require("plugins.ui") -- 用户界面和外观
require("plugins.telescope") -- 搜索与项目导航
require("plugins.mini") -- 配置 mini家族的 核心插件
require("config.deferred") -- 依赖插件的延迟加载
require("component.stldata").setup()
require("component.statusline").setup()
require("component.tabline").setup()

