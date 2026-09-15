-- ~/.config/nvim/lua/component/statusline.lua
local M = {}
local api = vim.api
local utils = require("component.hl")
local diag_icons = utils.icons.diag
local data = require("component.stldata")
local util = require("component.util")
local esc_stl = util.escape
local fl = require("apps.floatty")
local fclaude = require("utils.floatty_claude")

local R_ROUND = ""
local L_ROUND = ""
local GIT_BRANCH = ""
local GIT_ADD = "+"
local GIT_CHANGE = "~"
local GIT_DELETE = "-"

local capsule_hl_cache = {}

local mode_group_map = {
	i = "StatusLineInsert",
	c = "StatusLineCmd",
	R = "StatusLineReplace",
	v = "StatusLineVisual",
	V = "StatusLineVisual",
	["\22"] = "StatusLineVisual",
}

local function current_mode_group()
	local mode = api.nvim_get_mode().mode
	return mode_group_map[mode] or mode_group_map[mode:sub(1, 1)] or "StatusLineNormal"
end

-- Comment 默认斜体，孤儿角标只想要灰色不想要斜体，单独开一个不带 italic 的组
local function build_orphan_hl()
	local comment = utils.hl("Comment")
	api.nvim_set_hl(0, "StlOrphan", { fg = comment.fg, italic = false })
end

local function build_inactive_capsule_hl()
	local stl_nc = utils.hl("StatusLineNC")
	local info = utils.hl("DiagnosticInfo")
	local tab_project = utils.hl("TabProject")
	local body_name = "StlCapsule_fixed"
	local tail_name = "StlCapsuleTail_fixed"

	api.nvim_set_hl(0, body_name, { fg = tab_project.fg, bg = info.fg, bold = true })
	api.nvim_set_hl(0, tail_name, { fg = info.fg, bg = stl_nc.bg })

	capsule_hl_cache.fixed = { body = body_name, tail = tail_name }
end

local function get_capsule_hl(mode_hl, is_active)
	if not is_active then
		return capsule_hl_cache.fixed
	end

	local key = mode_hl
	if capsule_hl_cache[key] then
		return capsule_hl_cache[key]
	end

	local stl_bg = utils.hl("StatusLine").bg
	local body_name = "StlCapsule_" .. key
	local tail_name = "StlCapsuleTail_" .. key
	local tone
	if mode_hl == "StatusLineNormal" then
		tone = utils.hl("TabProject").bg
	else
		tone = utils.hl(mode_hl).fg
	end
	api.nvim_set_hl(0, body_name, { fg = stl_bg, bg = tone, bold = true })
	api.nvim_set_hl(0, tail_name, { fg = tone, bg = stl_bg })

	capsule_hl_cache[key] = { body = body_name, tail = tail_name }
	return capsule_hl_cache[key]
end

local C = {}

local function fold_path(path, max_width)
	if vim.fn.strdisplaywidth(path) <= max_width then
		return path
	end

	local parts = vim.split(path, "/", { plain = true, trimempty = true })
	local first, last = parts[1], parts[#parts]
	if first and last and #parts > 1 then
		local folded = string.format("%s/…/%s", first, last)
		if vim.fn.strdisplaywidth(folded) <= max_width then
			return folded
		end
		folded = string.format("…/%s", last)
		if vim.fn.strdisplaywidth(folded) <= max_width then
			return folded
		end
		return util.truncate(folded, max_width)
	end

	return util.truncate(path, max_width)
end

local function format_file_path(buf, win)
	local path = api.nvim_buf_get_name(buf)
	if path == "" then
		return "[No Name]", ""
	end

	local tab = api.nvim_win_get_tabpage(win)
	local tab_cwd = vim.fn.getcwd(-1, api.nvim_tabpage_get_number(tab))
	local rel = vim.fs.relpath(tab_cwd, path)
	local display
	if rel then
		display = "./" .. rel
	else
		display = vim.fn.fnamemodify(path, ":~")
	end
	local file = vim.fn.fnamemodify(display, ":t")
	local dir = vim.fn.fnamemodify(display, ":h")

	if dir == "." then
		dir = ""
	elseif dir ~= "" then
		local max_dir_width = math.max(16, math.min(60, math.floor(api.nvim_win_get_width(win) * 0.28)))
		dir = fold_path(dir, max_dir_width)
	end

	return esc_stl(file), esc_stl(dir)
end

function C.file_capsule(buf, win, mode_hl, is_active)
	local file, dir = format_file_path(buf, win)
	local hls = get_capsule_hl(mode_hl, is_active)
	local readonly = api.nvim_get_option_value("readonly", { buf = buf }) and " " or ""
	local path_part = string.format("%%#%s#%s", hls.body, file)

	if dir ~= "" then
		path_part = string.format("%s %%#%s#│ %s", path_part, hls.body, dir)
	end

	return string.format("%%#%s# %s%s %%#%s#%s", hls.body, path_part, readonly, hls.tail, R_ROUND)
end

function C.git(buf)
	local info = data.git_info(buf)
	if not info then
		return ""
	end

	local user_hl = (info.user == "micsama") and "Function" or "DiagnosticWarn"
	local user_str = info.user and string.format(" %%#%s#(%s)", user_hl, esc_stl(info.user)) or ""
	local diff_str = ""
	if info.added > 0 then
		diff_str = diff_str .. " %#MiniDiffSignAdd#" .. GIT_ADD .. info.added
	end
	if info.changed > 0 then
		diff_str = diff_str .. " %#MiniDiffSignChange#" .. GIT_CHANGE .. info.changed
	end
	if info.deleted > 0 then
		diff_str = diff_str .. " %#MiniDiffSignDelete#" .. GIT_DELETE .. info.deleted
	end

	return string.format(" %%#String#%s %s%%#Comment#%s%s", GIT_BRANCH, esc_stl(info.branch), user_str, diff_str)
end

function C.lsp(buf)
	local counts = data.diagnostics(buf)
	local err, warn = counts[1] or 0, counts[2] or 0
	if err == 0 and warn == 0 then
		return ""
	end
	local res = ""
	if err > 0 then
		res = res .. " %#DiagnosticError#" .. diag_icons[1].icon .. err
	end
	if warn > 0 then
		res = res .. " %#DiagnosticWarn#" .. diag_icons[2].icon .. warn
	end
	return res .. " "
end

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

function C.lsp_progress(buf)
	local info = data.lsp_progress()
	if not info then
		return vim.bo[buf].busy > 0 and " %#Comment#◐" or ""
	end

	local spinner_idx = math.floor(vim.uv.hrtime() / 1e8) % #spinner_frames + 1

	-- 显示 title + message，让用户区分不同阶段
	local msg = info.title
	if info.message ~= "" then
		msg = msg .. ": " .. info.message
	end
	msg = util.truncate(msg, 24)

	-- 进度条（10 格宽，箭头指示位置）
	local bar
	local width = 10
	if info.percentage then
		local percentage = math.max(0, math.min(100, info.percentage))
		local pos = math.min(width - 1, math.floor(width * percentage / 100))
		bar = string.rep("─", pos) .. ">" .. string.rep("─", math.max(0, width - pos - 1))
	else
		-- 无百分比：按时间计算位置，无额外动画定时器。
		local pos = (spinner_idx - 1) % width
		bar = string.rep("─", pos) .. ">" .. string.rep("─", width - pos - 1)
	end

	return string.format(" %%#Comment#%s %%#Function#%s %s", esc_stl(msg), spinner_frames[spinner_idx], bar)
end

function C.menu_alive()
	local items = fl.active_menu_indices()
	local orphan_idx = fl.orphan_menu_indices()
	if #items == 0 and #orphan_idx == 0 then
		return ""
	end
	local s = ""
	if #items > 0 then
		local parts = {}
		for _, it in ipairs(items) do
			if it.status then
				local g = fclaude.STATUS_GLYPHS[it.status] or fclaude.STATUS_GLYPHS.idle
				parts[#parts + 1] = string.format("%%#%s#%d%s", g.hl, it.idx, g.icon)
			else
				parts[#parts + 1] = string.format("%%#Function#%d", it.idx)
			end
		end
		s = s .. string.format(" %%#Function#󰚩 [%s%%#Function#]", table.concat(parts, "%#Comment#,"))
	end
	if #orphan_idx > 0 then
		s = s .. string.format(" %%#StlOrphan#󰊠 [%s]", table.concat(orphan_idx, ","))
	end
	return s
end

function C.ruler(buf, win, mode_hl)
	local ft = api.nvim_get_option_value("filetype", { buf = buf })
	local row = api.nvim_win_get_cursor(win)[1]
	local total = api.nvim_buf_line_count(buf)
	local progress = (row <= 1) and "󰘣"
		or (row >= total and "󰘡" or string.format("%d%%%%", math.floor((row / total) * 100)))

	local icon, icon_hl = utils.get_file_icon_with_bg(buf, "StatusLine")
	local icon_str = (icon ~= "") and string.format("%%#%s#%s ", icon_hl, icon) or ""

	local hls = get_capsule_hl(mode_hl, true)
	local progress_str = string.format("%%#%s# %s ", hls.body, progress)
	local cursor_str = string.format("%%#%s# %%l:%%c", hls.tail)
	local sep_str = string.format("%%#%s#%s", hls.tail, L_ROUND)

	return string.format("%%#StatusLine# %s%s %s %s%s", icon_str, esc_stl(ft), cursor_str, sep_str, progress_str)
end

function M.render()
	local win = vim.g.statusline_winid or api.nvim_get_current_win()
	local buf = api.nvim_win_get_buf(win)

	if win ~= api.nvim_get_current_win() then
		return C.file_capsule(buf, win, "StatusLineNormal", false)
	end

	local mode_hl = current_mode_group()
	return table.concat({
		C.file_capsule(buf, win, mode_hl, true),
		C.git(buf),
		C.lsp(buf),
		"%=",
		C.menu_alive(),
		C.lsp_progress(buf),
		C.ruler(buf, win, mode_hl),
	})
end

M.render = require("component.profiler").wrap("statusline", M.render)

-- 两条栏渲染耗时采样开关：:StlProf on|off|reset，:StlProf 打印统计。
-- 默认关闭，仅在调优 statusline 时临时开启（详见 component/profiler.lua）。
local function setup_profiler_cmd()
	api.nvim_create_user_command("StlProf", function(a)
		local prof = require("component.profiler")
		if a.args == "on" then
			prof.enabled = true
			vim.notify("StlProf: 采样已开启", vim.log.levels.INFO)
		elseif a.args == "off" then
			prof.enabled = false
			vim.notify("StlProf: 采样已关闭", vim.log.levels.INFO)
		elseif a.args == "reset" then
			prof.reset()
		elseif a.args == "" then
			prof.print_stats()
		else
			vim.notify("StlProf: 使用 on / off / reset", vim.log.levels.WARN)
		end
	end, {
		nargs = "?",
		complete = function()
			return { "on", "off", "reset" }
		end,
	})
end

function M.setup()
	build_inactive_capsule_hl()
	build_orphan_hl()
	setup_profiler_cmd()
	vim.o.laststatus = 2
	vim.o.statusline = "%!v:lua.require('component.statusline').render()"

	local grp = api.nvim_create_augroup("StlCore", { clear = true })

	api.nvim_create_autocmd("ColorScheme", {
		group = grp,
		callback = function()
			capsule_hl_cache = {}
			build_inactive_capsule_hl()
			build_orphan_hl()
		end,
	})

	-- 光标移动、窗口切换由 Neovim 自身刷新；只补充自定义内容的变化。
	api.nvim_create_autocmd("ModeChanged", {
		group = grp,
		callback = function()
			util.redraw(true, false)
		end,
	})
	api.nvim_create_autocmd("OptionSet", {
		group = grp,
		pattern = "busy",
		callback = function()
			util.redraw(true, false)
		end,
	})
end

return M
