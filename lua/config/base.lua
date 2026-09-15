-- ===========================================================================
-- 基础配置：选项 / 环境 / 终端配色
-- ===========================================================================

-- =============================================================================
-- 1) 基础选项
-- =============================================================================
vim.opt.langmenu = "zh_CN.UTF-8"

vim.opt.signcolumn = "yes" -- 始终显示标记列（用于LSP诊断、Git Gutter等）。
vim.opt.cursorline = true -- 始终高亮光标所在行，便于定位。
vim.opt.colorcolumn = "100" -- 在第100列显示辅助标尺线，帮助控制代码宽度。
vim.opt.scrolloff = 5 -- 光标距离窗口顶部/底部保留5行缓冲。
vim.opt.showmode = false -- 隐藏模式提示（如INSERT/NORMAL等），通常由状态栏插件处理。
vim.opt.virtualedit = "block" -- 允许在块选择模式下移动到空位置。
vim.opt.splitright = true -- 垂直分割时新窗口出现在右侧。
vim.opt.splitbelow = true -- 水平分割时新窗口出现在下方。
vim.cmd([[hi NonText ctermfg=gray guifg=grey10]]) -- 设置非文本元素（如文件末尾的~）的颜色。
vim.opt.number = true -- 显示文件的绝对行号。
vim.opt.relativenumber = true -- 显示相对于光标的相对行号，启用混合行号。
vim.opt.foldlevel = 99 -- 默认展开所有折叠（99是最高级别，即不折叠）。
vim.opt.foldmethod = "expr" -- 使用表达式计算折叠（通常由LSP或插件接管）。
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.viewoptions = "cursor,folds,slash,unix" -- 保存/恢复视图时记住光标位置、折叠状态等。
vim.opt.tabstop = 2 -- 设置一个Tab键的宽度为2个空格。
vim.opt.shiftwidth = 2 -- 自动缩进时使用的空格数。
vim.opt.softtabstop = 2 -- 退格键删除缩进时一次删除2个空格。
vim.opt.autoindent = true -- 启用新行自动保持与前一行相同的缩进。
vim.opt.smartindent = false -- 禁用智能缩进（通常由LSP或插件提供更精确的缩进）。
vim.opt.ignorecase = true -- 搜索时忽略大小写。
vim.opt.smartcase = true -- 如果搜索包含大写字母，则启用大小写敏感。
vim.opt.completeopt = "menuone,noselect" -- 补全菜单：总是显示菜单，但不自动选择/插入。
vim.opt.sessionoptions = { "curdir", "tabpages", "winsize", "help", "globals", "terminal" }
vim.opt.updatetime = 100 -- 触发LSP和CursorHold事件的时间间隔（毫秒）。
vim.opt.inccommand = "split" -- 实时预览命令效果（如替换命令）到分割窗口。
vim.opt.shortmess:append("c") -- 缩短某些消息显示（如补全菜单）。
vim.opt.formatoptions:remove({ "t", "c" }) -- 禁用自动换行(t)和文本注释自动换行(c)。
vim.o.showtabline = 2
vim.o.background = "dark"
vim.o.title = true -- 允许 Neovim 设置窗口/终端标题。
-- 标题的"文件部分"：终端 buffer 直接复用浮窗自己的窗口标题（floatty 设的那个），
-- 普通终端回退到 term_title，其余显示相对路径。
function _G.titlestring_file()
	if vim.bo.buftype == "terminal" then
		local t = vim.api.nvim_win_get_config(0).title -- floatty 浮窗标题；普通窗口为 nil
		if type(t) == "table" then
			local parts = {}
			for _, chunk in ipairs(t) do
				parts[#parts + 1] = chunk[1]
			end
			return table.concat(parts)
		end
		return t or vim.b.term_title or "Terminal"
	end
	local path = vim.fn.expand("%:~:.")
	return path ~= "" and path or "[No Name]"
end
-- 标题格式：[项目名] 文件路径 / 终端进程名（:cd、切 buffer 后实时更新）。
vim.o.titlestring = "[%{fnamemodify(getcwd(), ':t')}] %{%v:lua.titlestring_file()%}"
vim.opt.list = true -- 显示不可见字符（如Tab/空格等）。
vim.opt.listchars = { tab = "|\\ ", trail = "▫" } -- 设置不可见字符的显示样式: Tab为|和空格，行尾空格为▫。
-- vim.opt.exrc = true -- 允许加载项目本地.nvimrc配置文件（请确保信任项目）。
vim.opt.wildignore:append({ "*/__pycache__/*", "*/.git/*", "*/venv/*" }) -- 默认过滤掉一些冗余
vim.opt.autoread = true -- 文件在外部被修改后自动重新加载（0.13 起基于文件系统 watcher 实时检测）。
vim.opt.scrolloffpad = 1 -- 配合 scrolloff，让光标在文件末尾也能保持居中。

-- =============================================================================
-- 2) 文件与备份
-- =============================================================================
local config_dir = vim.fn.stdpath("config") .. "/tmp" -- 获取配置目录下的tmp子目录
vim.o.backupdir = config_dir .. "/backup,." -- 备份文件保存位置
vim.o.directory = config_dir .. "/backup,." -- 交换文件保存位置
vim.o.undofile = true -- 启用撤销历史持久化
vim.o.undodir = config_dir .. "/undo,." -- 撤销历史文件保存位置

-- =============================================================================
-- 3) 运行环境
-- =============================================================================
vim.g.python3_host_prog = (os.getenv("VIRTUAL_ENV") or "/Users/dzmfg/.venvs/base") .. "/bin/python" -- 优先使用虚拟环境中的 Python。

-- 禁用不必要的提供程序，减少启动开销。
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- 根据系统设置默认终端 Shell。
local uname = vim.uv.os_uname()
if uname.sysname == "Darwin" then
	vim.opt.shell = "/opt/homebrew/bin/nu" -- 优先使用 nu shell。
	vim.env.PATH = "/opt/homebrew/bin:" .. vim.env.PATH -- 将 Homebrew 的 bin 目录添加到 PATH。
else
	vim.opt.shell = "/usr/bin/bash"
end



-- 本机专属配置（如代理地址），因机器而异且不便公开，不纳入版本库。
-- Neovide 拿不到外部 shell 导出的环境变量，所以在这里用 vim.env 直接设置。
-- 参考模板：lua/config/local.lua.example
pcall(require, "config.local")
