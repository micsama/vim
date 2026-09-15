-- ===========================================================================
-- 自动命令 (AuCommands)
-- ===========================================================================

-- 创建 AutoCommand Group 并清除之前的命令
vim.api.nvim_create_augroup("CustomSetupGroup", { clear = true })
local custom_group = "CustomSetupGroup"

-- 自动切换工作目录到项目根目录
-- 优先用 git rev-parse (正确处理 worktree)，回退到 vim.fs.root；结果按 buffer 缓存
vim.api.nvim_create_autocmd("BufEnter", {
	group = custom_group,
	callback = function(ctx)
		local name = vim.api.nvim_buf_get_name(ctx.buf)
		if vim.bo[ctx.buf].buftype ~= "" or name == "" then
			return
		end

		-- 缓存：每个 buffer 只计算一次
		local root = vim.b[ctx.buf].project_root
		if root == nil then
			local buf_dir = vim.fn.fnamemodify(name, ":p:h")
			local git_root = vim.fn.systemlist("git -C " .. vim.fn.shellescape(buf_dir) .. " rev-parse --show-toplevel")
			if vim.v.shell_error == 0 and git_root[1] then
				root = git_root[1]
				vim.b[ctx.buf].project_is_git = true
			else
				local root_markers =
					{ "pyproject.toml", ".luarc.json", "Makefile", "Cargo.toml", "package.json", "go.mod" }
				root = vim.fs.root(ctx.buf, root_markers) or false
			end
			vim.b[ctx.buf].project_root = root
		end

		if root and vim.b[ctx.buf].project_is_git then
			require("apps.recent_repos").record(root)
		end

		if root and root ~= "." and root ~= vim.fn.getcwd() then
			vim.cmd.tcd(root)
			vim.notify(root, nil, { title = "Workspace ->", icon = "󱉭" })
		end
	end,
	desc = "Auto change working directory to project root",
})

-- 恢复上次打开文件时的光标位置
vim.api.nvim_create_autocmd("BufReadPost", {
	group = custom_group,
	pattern = "*",
	callback = function()
		-- 检查上次光标位置是否有效（行号大于1且小于文件总行数）
		if vim.fn.line("'\"") > 1 and vim.fn.line("'\"") <= vim.fn.line("$") then
			-- 跳转到上次光标位置 (''')
			vim.cmd.normal({ 'g`"', bang = true })
		end
	end,
	desc = "Restore cursor position when reopening files",
})

-- 终端打开时自动进入插入模式
vim.api.nvim_create_autocmd("TermOpen", {
	group = custom_group,
	pattern = "term://*",
	command = "startinsert",
	desc = "Automatically enter insert mode when opening terminal",
})

-- 配置修改后重启 Neovim，避免 source 与 require 缓存造成部分重载。

vim.filetype.add({
	extension = {
		log = "log",
	},
})
