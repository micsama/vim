-- ===========================================================================
-- 最近打开的 Git 仓库：记录 / 别名 / frecency 排序 / Telescope picker
-- ===========================================================================

local M = {}

local json_store = require("utils.json_store")

local data_path = vim.fn.stdpath("data") .. "/recent_repos.json"
-- 每个仓库每天计一次有效访问；近期权重最多 1 分，不压过常用项目。
local half_life_days = 30
local recorded_today = {}
local alias_hl = "RecentRepoAlias"
local function ensure_alias_hl()
	local palette = require("catppuccin.palettes").get_palette("mocha")
	vim.api.nvim_set_hl(0, alias_hl, { fg = palette.mauve, bold = true, underline = true })
end

local function load()
	local result = {}
	for _, e in ipairs(json_store.read(data_path, {})) do
		if
			type(e) == "table"
			and type(e.path) == "string"
			and e.path ~= ""
			and type(e.days) == "number"
			and e.days >= 1
			and e.days < math.huge
			and e.days % 1 == 0
			and type(e.last) == "number"
			and e.last >= 0
			and e.last <= os.time()
			and (e.alias == nil or type(e.alias) == "string")
		then
			result[#result + 1] = e
		end
	end
	return result
end

local function save(data)
	if not json_store.write(data_path, data) then
		vim.notify("无法保存最近仓库记录", vim.log.levels.WARN)
	end
end

local function score(entry, now)
	local age = math.max(0, now - entry.last) / 86400
	return math.log(1 + entry.days) / math.log(2) + 0.5 ^ (age / half_life_days)
end

function M.record(path)
	if not path or path == "" then
		return
	end
	local today = os.date("%Y-%m-%d")
	if recorded_today[path] == today then
		return
	end
	recorded_today[path] = today
	local data = load()
	for _, e in ipairs(data) do
		if e.path == path then
			if os.date("%Y-%m-%d", e.last) ~= today then
				e.days = e.days + 1
			end
			e.last = os.time()
			save(data)
			return
		end
	end
	data[#data + 1] = { path = path, days = 1, last = os.time() }
	save(data)
end

function M.set_alias(path, alias)
	local data = load()
	for _, e in ipairs(data) do
		if e.path == path then
			alias = vim.trim(alias)
			e.alias = alias ~= "" and alias or nil
			break
		end
	end
	save(data)
end

local function sorted_entries()
	local data, now = load(), os.time()
	table.sort(data, function(a, b)
		local sa, sb = score(a, now), score(b, now)
		if sa ~= sb then
			return sa > sb
		end
		if a.last ~= b.last then
			return a.last > b.last
		end
		return a.path < b.path
	end)
	return data
end

function M.open(path)
	if vim.fn.isdirectory(path) ~= 1 then
		vim.notify("仓库目录不存在：" .. path, vim.log.levels.WARN)
		return
	end
	local files = require("mini.files")
	vim.cmd.tabnew()
	vim.cmd.tcd(path)
	M.record(path)
	files.open(path, false)
end

-- 目录预览：优先用 eza（图标 + 颜色），否则退回 ls；只看一层，不递归子目录
local function preview_cmd(path)
	if vim.fn.executable("eza") == 1 then
		return {
			"eza",
			"-l", -- 长格式：每项独立一行，附带时间/大小
			"--git", -- 每项后面标注 git 状态（M/N/D…）
			"--icons=always",
			"--group-directories-first",
			"--color=always",
			"--no-permissions", -- 自己的仓库不需要看权限位
			"--no-user",
			"--time-style=relative", -- "3 hours ago" 这种相对时间
			"--header",
			path,
		}
	elseif vim.fn.executable("ls") == 1 then
		return { "ls", "-1p", path }
	end
end

-- "[Process exited N]" 其实是 nvim 内置的 nested TermClose 自动命令用 extmark（虚拟文本）
-- 叠加上去的（namespace: nvim.terminal.exitmsg），不是真实 buffer 内容，直接清掉这个 namespace 即可
local exitmsg_ns = vim.api.nvim_create_namespace("nvim.terminal.exitmsg")
vim.api.nvim_create_autocmd("TermClose", {
	nested = true, -- 必须晚于内置的那个自动命令执行，等它把 extmark 打上去之后再清
	callback = function(args)
		if not vim.b[args.buf].recent_repos_preview then
			return
		end
		vim.schedule(function()
			if vim.api.nvim_buf_is_valid(args.buf) then
				vim.api.nvim_buf_clear_namespace(args.buf, exitmsg_ns, 0, -1)
			end
		end)
	end,
})

function M.picker(opts)
	opts = opts or {}
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local entry_display = require("telescope.pickers.entry_display")
	local previewers = require("telescope.previewers")

	ensure_alias_hl()
	local displayer = entry_display.create({
		separator = " ",
		items = { { width = 22 }, { remaining = true } },
	})

	local function make_finder()
		return finders.new_table({
			results = sorted_entries(),
			entry_maker = function(e)
				local tag = e.alias and { "[" .. e.alias .. "]", alias_hl } or { "[]" }
				return {
					value = e,
					path = e.path,
					ordinal = (e.alias or "") .. " " .. e.path,
					display = function()
						return displayer({ tag, vim.fn.fnamemodify(e.path, ":~") })
					end,
				}
			end,
		})
	end

	local tree_previewer = previewers.new_termopen_previewer({
		title = "目录预览",
		get_command = function(entry, status)
			-- 标记这个 buffer 是本 picker 的预览，退出后好清掉 "[Process exited]" 提示行
			local bufnr = vim.api.nvim_win_get_buf(status.layout.preview.winid)
			vim.b[bufnr].recent_repos_preview = true
			return preview_cmd(entry.value.path)
		end,
	})

	pickers
		.new(opts, {
			prompt_title = "🕒 最近 Git 仓库",
			finder = make_finder(),
			previewer = tree_previewer,
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if not selection then
						return
					end
					M.open(selection.value.path)
				end)

				-- 仅移除历史记录，不操作磁盘目录。
				map({ "n", "i" }, "<C-d>", function()
					local selected = action_state.get_selected_entry()
					if not selected then
						return
					end
					local data = vim.tbl_filter(function(e)
						return e.path ~= selected.value.path
					end, load())
					save(data)
					recorded_today[selected.value.path] = nil
					action_state.get_current_picker(prompt_bufnr):refresh(make_finder(), { reset_prompt = false })
				end)

				map({ "n", "i" }, "<C-r>", function()
					local selection = action_state.get_selected_entry()
					if not selection then
						return
					end
					local current_picker = action_state.get_current_picker(prompt_bufnr)
					vim.ui.input({ prompt = "别名: ", default = selection.value.alias or "" }, function(input)
						if input == nil then
							return
						end
						M.set_alias(selection.value.path, input)
						current_picker:refresh(make_finder(), { reset_prompt = false })
					end)
				end)

				return true
			end,
		})
		:find()
end

return M
