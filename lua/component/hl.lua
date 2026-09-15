-- ~/.config/nvim/lua/component/hl.lua
local M = {}
local api = vim.api
local mini_icons = require("mini.icons")

M.icons = {
	diag = {
		[vim.diagnostic.severity.ERROR] = { icon = " ✘", hl = "DiagnosticError" },
		[vim.diagnostic.severity.WARN] = { icon = " 󱓈", hl = "DiagnosticWarn" },
		[vim.diagnostic.severity.INFO] = { icon = " 󰋽", hl = "DiagnosticInfo" },
		[vim.diagnostic.severity.HINT] = { icon = " 󰛩", hl = "DiagnosticHint" },
	},
}

local hl_cache = {}

api.nvim_create_autocmd("ColorScheme", {
	group = api.nvim_create_augroup("ComponentHighlights", { clear = true }),
	callback = function()
		M.reset_hl_cache()
		require("component.util").redraw(true, true)
	end,
})

function M.hl(name)
	return api.nvim_get_hl(0, { name = name, link = false })
end

function M.reset_hl_cache()
	hl_cache = {}
end

function M.get_compound_hl(fg_name, bg_name, is_bold, is_italic)
	local key = string.format("%s_%s_%s_%s", fg_name, bg_name, tostring(is_bold), tostring(is_italic))
	if hl_cache[key] then
		return hl_cache[key]
	end

	local name = "CmpHL_" .. key:gsub("[^%w_]", "_")
	local fg_def = M.hl(fg_name)
	local bg_def = M.hl(bg_name)

	api.nvim_set_hl(0, name, {
		fg = fg_def.fg,
		bg = bg_def.bg,
		bold = is_bold,
		italic = is_italic,
	})

	hl_cache[key] = name
	return name
end

function M.get_file_icon_with_bg(buf, bg_name, is_bold)
	local path = api.nvim_buf_get_name(buf)
	local icon, icon_hl = mini_icons.get("file", path)

	if icon == "" then
		return "", bg_name
	end

	local final_hl = M.get_compound_hl(icon_hl, bg_name, is_bold, false)
	return icon, final_hl
end

return M
