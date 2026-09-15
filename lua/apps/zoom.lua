-- 每个标签页一个放大窗口；同 buffer 返回时同步阅读位置。
local M = {}
local states = {}
local api = vim.api

local function get_opts(buf)
	local name = api.nvim_buf_get_name(buf)
	name = name ~= "" and vim.fn.fnamemodify(name, ":t") or "[No Name]"
	return {
		relative = "editor",
		row = 0,
		col = 0,
		width = math.max(vim.o.columns - 2, 1),
		height = math.max(vim.o.lines - vim.o.cmdheight - 2, 1),
		border = "rounded",
		title = (" %s "):format(name),
		title_pos = "center",
	}
end

function M.toggle()
	local tab = api.nvim_get_current_tabpage()
	local state = states[tab]
	if state and api.nvim_win_is_valid(state.win) then
		state.view = api.nvim_win_call(state.win, vim.fn.winsaveview)
		state.buf = api.nvim_win_get_buf(state.win)
		api.nvim_win_close(state.win, true)
		return
	end
	local source = api.nvim_get_current_win()
	local view = vim.fn.winsaveview()
	local win = api.nvim_open_win(0, true, get_opts(0))
	vim.fn.winrestview(view)
	states[tab] = { win = win, source = source, buf = api.nvim_win_get_buf(win), view = view }
end

local group = api.nvim_create_augroup("UserZoom", { clear = true })
local function resize()
	for _, state in pairs(states) do
		if api.nvim_win_is_valid(state.win) then
			api.nvim_win_set_config(state.win, get_opts(api.nvim_win_get_buf(state.win)))
		end
	end
end
api.nvim_create_autocmd("VimResized", { group = group, callback = resize })
api.nvim_create_autocmd("OptionSet", { group = group, pattern = "cmdheight", callback = resize })
-- WinClosed 时窗口可能已不可读，提前缓存视图，也覆盖手动 :close。
api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinLeave", "BufWinLeave" }, {
	group = group,
	callback = function()
		local state = states[api.nvim_get_current_tabpage()]
		if state and api.nvim_get_current_win() == state.win then
			state.view = vim.fn.winsaveview()
			state.buf = api.nvim_win_get_buf(state.win)
		end
	end,
})
api.nvim_create_autocmd("WinClosed", {
	group = group,
	callback = function(ev)
		for tab, state in pairs(states) do
			if state.win == tonumber(ev.match) then
				states[tab] = nil
				if api.nvim_win_is_valid(state.source) and api.nvim_win_get_buf(state.source) == state.buf then
					api.nvim_win_call(state.source, function()
						vim.fn.winrestview(state.view)
					end)
				end
				break
			end
		end
	end,
})
return M
