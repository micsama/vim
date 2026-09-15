-- 事件更新数据，渲染阶段只读取；Git 配置由 Git 自己解析（支持 worktree/includeIf）。
local M = {}
local api = vim.api
local redraw = require("component.util").redraw
local users, pending_users, diagnostics, progress = {}, {}, {}, {}
local empty_counts = {}
local sequence = 0

local function refresh_user(root, force)
	if not root or root == "" or pending_users[root] or (not force and users[root] ~= nil) then
		return
	end
	pending_users[root] = true
	vim.system({ "git", "-C", root, "config", "--get", "user.name" }, { text = true }, function(result)
		vim.schedule(function()
			pending_users[root] = nil
			local name = result.code == 0 and vim.trim(result.stdout or "") or ""
			users[root] = name ~= "" and name or false
			redraw(true, false)
		end)
	end)
end

local function refresh_users(force)
	local roots = {}
	for _, buf in ipairs(api.nvim_list_bufs()) do
		local summary = vim.b[buf].minigit_summary
		if summary and summary.root then
			roots[summary.root] = true
		end
	end
	for root in pairs(roots) do
		refresh_user(root, force)
	end
end

function M.git_info(buf)
	local summary = vim.b[buf].minigit_summary
	if not summary or not summary.head_name then
		return nil
	end
	local diff = vim.b[buf].minidiff_summary
	return {
		branch = summary.head_name,
		user = users[summary.root],
		added = diff and diff.add or 0,
		changed = diff and diff.change or 0,
		deleted = diff and diff.delete or 0,
	}
end

function M.diagnostics(buf)
	return diagnostics[buf] or empty_counts
end

-- 显示最早开始的活跃任务，避免多个客户端的消息来回跳动。
function M.lsp_progress()
	local selected
	for client_id, tasks in pairs(progress) do
		local client = vim.lsp.get_client_by_id(client_id)
		if client and not client:is_stopped() then
			for _, task in pairs(tasks) do
				if not selected or task.sequence < selected.sequence then
					selected = task
				end
			end
		end
	end
	return selected
end

function M.setup()
	local group = api.nvim_create_augroup("ComponentData", { clear = true })
	local function update_diagnostics(buf)
		if api.nvim_buf_is_valid(buf) then
			diagnostics[buf] = vim.diagnostic.count(buf)
		end
	end
	for _, buf in ipairs(api.nvim_list_bufs()) do
		update_diagnostics(buf)
	end
	refresh_users(false)

	api.nvim_create_autocmd("DiagnosticChanged", {
		group = group,
		callback = function(ev)
			update_diagnostics(ev.buf)
			redraw(true, true)
		end,
	})
	api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function(ev)
			diagnostics[ev.buf] = nil
		end,
	})
	api.nvim_create_autocmd("User", {
		group = group,
		pattern = { "MiniGitUpdated", "MiniDiffUpdated" },
		callback = function(ev)
			if ev.match == "MiniGitUpdated" then
				local summary = vim.b[ev.buf].minigit_summary
				if summary then
					refresh_user(summary.root, false)
				end
			end
			redraw(true, false)
		end,
	})
	api.nvim_create_autocmd("FocusGained", {
		group = group,
		callback = function()
			refresh_users(true)
		end,
	})
	api.nvim_create_autocmd("LspProgress", {
		group = group,
		callback = function(ev)
			local id, params = ev.data.client_id, ev.data.params
			local value = params.value
			if type(value) ~= "table" then
				return
			end
			local tasks = progress[id] or {}
			if value.kind == "end" then
				tasks[params.token] = nil
			elseif value.kind == "begin" or value.kind == "report" then
				local task = tasks[params.token]
				if not task or value.kind == "begin" then
					sequence = sequence + 1
					task = { title = "", message = "", sequence = sequence }
				end
				for _, key in ipairs({ "title", "message", "percentage" }) do
					if value[key] ~= nil then
						task[key] = value[key]
					end
				end
				tasks[params.token] = task
			end
			progress[id] = next(tasks) and tasks or nil
			redraw(true, false)
		end,
	})
	api.nvim_create_autocmd("LspDetach", {
		group = group,
		callback = function(ev)
			local id = ev.data.client_id
			vim.schedule(function()
				local client = vim.lsp.get_client_by_id(id)
				if not client or client:is_stopped() or next(client.attached_buffers) == nil then
					progress[id] = nil
				end
				redraw(true, false)
			end)
		end,
	})
end

return M
