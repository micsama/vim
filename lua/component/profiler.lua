-- 两条栏的完整 Lua render 耗时；不包含 Neovim 绘制与屏幕呈现。
-- 默认关闭；只在采样开启时读时钟、写入最近 200 次样本。
local M = { enabled = false, stats = {} }
local uv = vim.uv
local SAMPLE_COUNT = 200

function M.reset()
	M.stats = {}
end

-- 只用于返回一个渲染字符串的函数。
function M.wrap(name, render)
	return function(...)
		if not M.enabled then
			return render(...)
		end
		local started = uv.hrtime()
		local result = render(...)
		local elapsed = uv.hrtime() - started
		local stat = M.stats[name]
		if not stat then
			stat = { calls = 0, samples = {}, head = 1 }
			M.stats[name] = stat
		end
		stat.samples[stat.head] = elapsed
		stat.head = stat.head % SAMPLE_COUNT + 1
		stat.calls = stat.calls + 1
		return result
	end
end

function M.print_stats()
	print("Lua render 耗时（ms），最近最多 200 次；Calls 自 reset 起累计")
	print(string.format("%-12s %8s %10s %10s %10s", "Component", "Calls", "Avg", "P95", "Max"))
	for _, name in ipairs({ "statusline", "tabline" }) do
		local stat = M.stats[name]
		if stat then
			local samples = vim.list_extend({}, stat.samples)
			table.sort(samples)
			local total = 0
			for _, value in ipairs(samples) do
				total = total + value
			end
			local n = #samples
			print(
				string.format(
					"%-12s %8d %10.4f %10.4f %10.4f",
					name,
					stat.calls,
					total / n / 1e6,
					samples[math.ceil(n * 0.95)] / 1e6,
					samples[n] / 1e6
				)
			)
		end
	end
end

return M
