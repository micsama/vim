local M = {}
local api = vim.api
local hl = require("component.hl")
local util = require("component.util")
local data = require("component.stldata")
local tab_bufs = {}
local scroll_start = 1

local function seg(group, text)
	return ("%%#%s#%s"):format(group, util.escape(text))
end

local function editing_buffer(win)
	local config = api.nvim_win_get_config(win)
	local buf = api.nvim_win_get_buf(win)
	if config.relative == "" and not config.external and vim.bo[buf].buftype == "" then
		return buf
	end
end

local function representative(tab)
	local buf = tab_bufs[tab]
	if buf and api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
		return buf
	end
	buf = editing_buffer(api.nvim_tabpage_get_win(tab))
	if not buf then
		for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
			buf = editing_buffer(win)
			if buf then
				break
			end
		end
	end
	tab_bufs[tab] = buf
	return buf
end

local function make_item(idx, selected, entry, names, paths, max_width)
	local buf, path = entry.buf, entry.path
	local base = selected and "TabLineSel" or "TabLine"
	local filename = path == "" and "[No Name]" or vim.fs.basename(path)
	if path ~= "" and names[filename] > 1 and paths[path] == 1 then
		local parent = vim.fs.basename(vim.fs.dirname(path))
		if parent ~= "" and parent ~= "." then
			filename = parent .. "/" .. filename
		end
	end

	local diag
	for severity = 1, 4 do
		if (data.diagnostics(buf)[severity] or 0) > 0 then
			diag = hl.icons.diag[severity]
			break
		end
	end
	local icon, icon_hl = "", base
	if buf then
		icon, icon_hl = hl.get_file_icon_with_bg(buf, base, selected)
	end
	local prefix = (" %s%d "):format(selected and "󰄲 " or "󰄱 ", idx)
	local icon_text = icon ~= "" and icon .. " " or ""
	local diag_text = diag and diag.icon or ""
	local duplicate = path ~= "" and paths[path] > 1 and " 󰆏" or ""
	local modified = buf and vim.bo[buf].modified and " 󰷫▕" or " ▕"
	local fixed = api.nvim_strwidth(prefix .. icon_text .. diag_text .. duplicate .. modified)
	-- 单项超宽时优先留住序号和文件名，极窄窗口省掉装饰。
	if max_width and fixed + 1 > max_width then
		prefix, icon_text, diag_text, duplicate, modified = (" %d "):format(idx), "", "", "", ""
		fixed = api.nvim_strwidth(prefix)
	end
	filename = util.truncate(filename, math.min(20, max_width and math.max(0, max_width - fixed) or 20))
	local name_hl = not selected and diag and hl.get_compound_hl(diag.hl, base, false, false) or base
	local diag_hl = diag and hl.get_compound_hl(diag.hl, base, selected, false) or base
	local mod_hl = hl.get_compound_hl("DiagnosticOk", base, selected, false)
	return {
		width = fixed + api.nvim_strwidth(filename),
		text = table.concat({
			("%%%dT"):format(idx),
			seg(base, prefix),
			seg(icon_hl, icon_text),
			seg(name_hl, filename),
			seg(diag_hl, diag_text),
			seg(mod_hl, duplicate .. modified),
		}),
	}
end

function M.render()
	local tabs = api.nvim_list_tabpages()
	local current, current_idx = api.nvim_get_current_tabpage(), 1
	local entries, names, paths = {}, {}, {}
	for i, tab in ipairs(tabs) do
		if tab == current then
			current_idx = i
		end
		local buf = representative(tab)
		local path = buf and api.nvim_buf_get_name(buf) or ""
		entries[i] = { buf = buf, path = path }
		local name = path == "" and "[No Name]" or vim.fs.basename(path)
		names[name] = (names[name] or 0) + 1
		paths[path] = (paths[path] or 0) + 1
	end

	-- 项目目录取 tab-local cwd，不随浮窗中的 lcd 改变。
	local cwd = vim.fn.getcwd(-1, api.nvim_tabpage_get_number(current))
	local project = vim.fs.basename(cwd)
	project = project == "" and "/" or project
	local header = "▌ "
	local project_text = "  " .. util.truncate(project, 20) .. "▕ "
	local header_width = api.nvim_strwidth(header .. project_text)
	if header_width + 12 > vim.o.columns then
		header, project_text, header_width = "", "", 0
	end
	local available = math.max(1, vim.o.columns - header_width)
	local items = {}
	for i, entry in ipairs(entries) do
		items[i] = make_item(i, i == current_idx, entry, names, paths)
	end

	-- 先保证当前项可见，再向右填满；空间不足时从左侧移走旧项。
	local first = math.min(scroll_start, current_idx)
	local used = 0
	for i = first, current_idx do
		used = used + items[i].width
	end
	while used > available and first < current_idx do
		used = used - items[first].width
		first = first + 1
	end
	local last = current_idx
	if items[current_idx].width > available then
		items[current_idx] = make_item(current_idx, true, entries[current_idx], names, paths, available)
		used = items[current_idx].width
	end
	while last < #items and used + items[last + 1].width <= available do
		last = last + 1
		used = used + items[last].width
	end
	-- 放大窗口/关闭 tab 后回填左侧，避免保留无意义的滚动空白。
	while first > 1 and used + items[first - 1].width <= available do
		first = first - 1
		used = used + items[first].width
	end
	scroll_start = first
	local result = { seg("Special", header), seg("TabProject", project_text) }
	for i = first, last do
		result[#result + 1] = items[i].text
	end
	result[#result + 1] = "%#TabLineFill#%T"
	return table.concat(result)
end

M.render = require("component.profiler").wrap("tabline", M.render)

function M.setup()
	vim.o.tabline = "%!v:lua.require('component.tabline').render()"
	local group = api.nvim_create_augroup("TablineCore", { clear = true })
	local function remember_current()
		local buf = editing_buffer(api.nvim_get_current_win())
		if buf then
			tab_bufs[api.nvim_get_current_tabpage()] = buf
		end
		util.redraw(false, true)
	end
	remember_current()
	api.nvim_create_autocmd({ "BufEnter", "WinEnter", "TabEnter" }, { group = group, callback = remember_current })
	api.nvim_create_autocmd({ "BufFilePost", "DirChanged" }, {
		group = group,
		callback = function()
			util.redraw(true, true)
		end,
	})
	api.nvim_create_autocmd("OptionSet", {
		group = group,
		pattern = "modified",
		callback = function()
			util.redraw(false, true)
		end,
	})
	api.nvim_create_autocmd("TabClosed", {
		group = group,
		callback = function()
			for tab in pairs(tab_bufs) do
				if not api.nvim_tabpage_is_valid(tab) then
					tab_bufs[tab] = nil
				end
			end
			util.redraw(false, true)
		end,
	})
	api.nvim_create_autocmd("BufDelete", {
		group = group,
		callback = function(ev)
			for tab, buf in pairs(tab_bufs) do
				if buf == ev.buf then
					tab_bufs[tab] = nil
				end
			end
			util.redraw(false, true)
		end,
	})
	api.nvim_create_autocmd("SessionLoadPost", {
		group = group,
		callback = function()
			tab_bufs, scroll_start = {}, 1
			remember_current()
		end,
	})
end

return M
